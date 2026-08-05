import {
  cert,
  getApps,
  initializeApp,
} from "npm:firebase-admin@13.4.0/app";

import {
  getAuth,
} from "npm:firebase-admin@13.4.0/auth";

import {
  FieldValue,
  initializeFirestore,
} from "npm:firebase-admin@13.4.0/firestore";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-firebase-token, x-client-info, apikey, content-type, accept",
  "Access-Control-Allow-Methods":
    "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

type UserRole =
  | "president"
  | "manager"
  | "data_entry";

type RequestBody = {
  action?: string;
  uid?: string;
  code?: string;
  name?: string;
  password?: string;
  role?: string;
  active?: boolean;
  distributorId?: string;
  distributorName?: string;
};

class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

function textValue(value: unknown): string {
  return String(value ?? "").trim();
}

function normalizeCode(value: unknown): string {
  return textValue(value).toLowerCase();
}

function emailFromCode(code: string): string {
  return `${code}@distribution.local`;
}

function requiredSecret(name: string): string {
  const value = Deno.env.get(name);

  if (!value) {
    throw new ApiError(
      500,
      "missing-secret",
      `متغير الخادم غير موجود: ${name}`,
    );
  }

  return value;
}

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(
    JSON.stringify(body),
    {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type":
          "application/json; charset=utf-8",
      },
    },
  );
}

// =====================================================
// Firebase lazy initialization
// =====================================================

let firebaseAuth:
  | ReturnType<typeof getAuth>
  | null = null;

let firestore:
  | ReturnType<typeof initializeFirestore>
  | null = null;

function initializeFirebaseServices(): void {
  if (firebaseAuth != null && firestore != null) {
    return;
  }

  const projectId = requiredSecret(
    "FIREBASE_PROJECT_ID",
  );

  const clientEmail = requiredSecret(
    "FIREBASE_CLIENT_EMAIL",
  );

  const privateKey = requiredSecret(
    "FIREBASE_PRIVATE_KEY",
  )
    .replace(/\\n/g, "\n")
    .trim();

  const firebaseApp = getApps().length > 0
    ? getApps()[0]
    : initializeApp({
        credential: cert({
          projectId,
          clientEmail,
          privateKey,
        }),
        projectId,
      });

  firebaseAuth = getAuth(firebaseApp);

  firestore = initializeFirestore(
    firebaseApp,
    {
      /*
       * استخدام REST بدل gRPC داخل Supabase Edge Functions.
       */
      preferRest: true,
    },
  );
}

function getFirebaseAuth() {
  initializeFirebaseServices();

  if (firebaseAuth == null) {
    throw new ApiError(
      500,
      "firebase-auth-not-ready",
      "تعذر تهيئة Firebase Authentication.",
    );
  }

  return firebaseAuth;
}

function getFirebaseFirestore() {
  initializeFirebaseServices();

  if (firestore == null) {
    throw new ApiError(
      500,
      "firestore-not-ready",
      "تعذر تهيئة Firestore.",
    );
  }

  return firestore;
}

// =====================================================
// Validation
// =====================================================

function validateRole(
  role: string,
): asserts role is UserRole {
  const allowedRoles: UserRole[] = [
    "president",
    "manager",
    "data_entry",
  ];

  if (!allowedRoles.includes(role as UserRole)) {
    throw new ApiError(
      400,
      "invalid-role",
      "صلاحية المستخدم غير صحيحة.",
    );
  }
}

function validateDistributor({
  role,
  distributorId,
  distributorName,
}: {
  role: UserRole;
  distributorId: string;
  distributorName: string;
}): void {
  if (
    role === "data_entry" &&
    (!distributorId || !distributorName)
  ) {
    throw new ApiError(
      400,
      "distributor-required",
      "يجب ربط مدخل البيانات بموزع.",
    );
  }
}

// =====================================================
// President authentication
// =====================================================

async function verifyPresident(
  request: Request,
): Promise<string> {
  const token = textValue(
    request.headers.get("X-Firebase-Token"),
  );

  if (!token) {
    throw new ApiError(
      401,
      "missing-firebase-token",
      "رمز جلسة Firebase غير موجود.",
    );
  }

  const auth = getFirebaseAuth();
  const db = getFirebaseFirestore();

  let decodedToken;

  try {
    decodedToken = await auth.verifyIdToken(
      token,
      true,
    );
  } catch (error) {
    console.error(
      "Firebase token verification failed:",
      error,
    );

    throw new ApiError(
      401,
      "invalid-firebase-token",
      "جلسة تسجيل الدخول غير صالحة أو انتهت.",
    );
  }

  const userDocument = await db
    .collection("users")
    .doc(decodedToken.uid)
    .get();

  if (!userDocument.exists) {
    throw new ApiError(
      403,
      "user-document-not-found",
      "بيانات المستخدم غير موجودة.",
    );
  }

  const userData = userDocument.data();

  if (userData?.active !== true) {
    throw new ApiError(
      403,
      "user-disabled",
      "الحساب الحالي موقوف.",
    );
  }

  if (userData?.role !== "president") {
    throw new ApiError(
      403,
      "permission-denied",
      "هذه العملية متاحة للرئيس فقط.",
    );
  }

  return decodedToken.uid;
}

// =====================================================
// Code availability
// =====================================================

async function ensureCodeAvailable(
  code: string,
  excludingUid?: string,
): Promise<void> {
  const auth = getFirebaseAuth();
  const db = getFirebaseFirestore();

  const snapshot = await db
    .collection("users")
    .where("code", "==", code)
    .limit(2)
    .get();

  for (const document of snapshot.docs) {
    if (
      excludingUid == null ||
      document.id !== excludingUid
    ) {
      throw new ApiError(
        409,
        "code-already-exists",
        "كود الدخول مستخدم بالفعل.",
      );
    }
  }

  try {
    const authUser =
      await auth.getUserByEmail(
        emailFromCode(code),
      );

    if (
      excludingUid == null ||
      authUser.uid !== excludingUid
    ) {
      throw new ApiError(
        409,
        "code-already-exists",
        "كود الدخول مستخدم بالفعل.",
      );
    }
  } catch (error) {
    if (error instanceof ApiError) {
      throw error;
    }

    const firebaseCode =
      (error as { code?: string }).code ?? "";

    if (firebaseCode !== "auth/user-not-found") {
      throw error;
    }
  }
}

// =====================================================
// Audit log
// =====================================================

async function addAuditLog({
  action,
  presidentUid,
  targetUid,
  targetCode,
  details = {},
}: {
  action: string;
  presidentUid: string;
  targetUid: string;
  targetCode: string;
  details?: Record<string, unknown>;
}): Promise<void> {
  const db = getFirebaseFirestore();

  await db
    .collection("audit_logs")
    .add({
      action,
      performedByUid: presidentUid,
      targetUid,
      targetCode,
      details,
      createdAt: FieldValue.serverTimestamp(),
    });
}

// =====================================================
// Create user
// =====================================================

async function createUser(
  body: RequestBody,
  presidentUid: string,
): Promise<Response> {
  const auth = getFirebaseAuth();
  const db = getFirebaseFirestore();

  const code = normalizeCode(body.code);
  const name = textValue(body.name);
  const password = textValue(body.password);
  const role = textValue(body.role);

  const distributorId = textValue(
    body.distributorId,
  );

  const distributorName = textValue(
    body.distributorName,
  );

  if (!code) {
    throw new ApiError(
      400,
      "code-required",
      "كود الدخول مطلوب.",
    );
  }

  if (!name) {
    throw new ApiError(
      400,
      "name-required",
      "اسم المستخدم مطلوب.",
    );
  }

  if (password.length < 6) {
    throw new ApiError(
      400,
      "weak-password",
      "كلمة المرور يجب ألا تقل عن 6 أحرف أو أرقام.",
    );
  }

  validateRole(role);

  validateDistributor({
    role,
    distributorId,
    distributorName,
  });

  await ensureCodeAvailable(code);

  let createdUid = "";

  try {
    const authUser = await auth.createUser({
      email: emailFromCode(code),
      password,
      displayName: name,
      disabled: false,
    });

    createdUid = authUser.uid;

    await db
      .collection("users")
      .doc(authUser.uid)
      .set({
        code,
        name,
        role,
        active: true,

        distributorId:
          role === "data_entry"
            ? distributorId
            : "",

        distributorName:
          role === "data_entry"
            ? distributorName
            : "",

        createdAt:
          FieldValue.serverTimestamp(),

        updatedAt:
          FieldValue.serverTimestamp(),

        createdByUid: presidentUid,
      });

    await addAuditLog({
      action: "create_user",
      presidentUid,
      targetUid: authUser.uid,
      targetCode: code,
      details: {
        name,
        role,

        distributorId:
          role === "data_entry"
            ? distributorId
            : "",

        distributorName:
          role === "data_entry"
            ? distributorName
            : "",
      },
    });

    return jsonResponse({
      success: true,
      message: "تم إنشاء المستخدم بنجاح.",
      uid: authUser.uid,
    });
  } catch (error) {
    if (createdUid.isNotEmpty) {
      await auth
        .deleteUser(createdUid)
        .catch(() => undefined);
    }

    throw error;
  }
}

// =====================================================
// Update user
// =====================================================

async function updateUser(
  body: RequestBody,
  presidentUid: string,
): Promise<Response> {
  const auth = getFirebaseAuth();
  const db = getFirebaseFirestore();

  const uid = textValue(body.uid);
  const code = normalizeCode(body.code);
  const name = textValue(body.name);
  const role = textValue(body.role);
  const active = body.active === true;

  const distributorId = textValue(
    body.distributorId,
  );

  const distributorName = textValue(
    body.distributorName,
  );

  if (!uid) {
    throw new ApiError(
      400,
      "uid-required",
      "معرف المستخدم مطلوب.",
    );
  }

  if (!code) {
    throw new ApiError(
      400,
      "code-required",
      "كود الدخول مطلوب.",
    );
  }

  if (!name) {
    throw new ApiError(
      400,
      "name-required",
      "اسم المستخدم مطلوب.",
    );
  }

  validateRole(role);

  validateDistributor({
    role,
    distributorId,
    distributorName,
  });

  await ensureCodeAvailable(code, uid);

  const userDocument = await db
    .collection("users")
    .doc(uid)
    .get();

  if (!userDocument.exists) {
    throw new ApiError(
      404,
      "user-not-found",
      "المستخدم غير موجود.",
    );
  }

  await auth.updateUser(uid, {
    email: emailFromCode(code),
    displayName: name,
    disabled: !active,
  });

  await db
    .collection("users")
    .doc(uid)
    .update({
      code,
      name,
      role,
      active,

      distributorId:
        role === "data_entry"
          ? distributorId
          : "",

      distributorName:
        role === "data_entry"
          ? distributorName
          : "",

      updatedAt:
        FieldValue.serverTimestamp(),

      updatedByUid: presidentUid,
    });

  await addAuditLog({
    action: "update_user",
    presidentUid,
    targetUid: uid,
    targetCode: code,
    details: {
      name,
      role,
      active,

      distributorId:
        role === "data_entry"
          ? distributorId
          : "",

      distributorName:
        role === "data_entry"
          ? distributorName
          : "",
    },
  });

  return jsonResponse({
    success: true,
    message: "تم تعديل المستخدم بنجاح.",
  });
}

// =====================================================
// Change password
// =====================================================

async function changePassword(
  body: RequestBody,
  presidentUid: string,
): Promise<Response> {
  const auth = getFirebaseAuth();
  const db = getFirebaseFirestore();

  const uid = textValue(body.uid);
  const password = textValue(body.password);

  if (!uid) {
    throw new ApiError(
      400,
      "uid-required",
      "معرف المستخدم مطلوب.",
    );
  }

  if (password.length < 6) {
    throw new ApiError(
      400,
      "weak-password",
      "كلمة المرور يجب ألا تقل عن 6 أحرف أو أرقام.",
    );
  }

  const userDocument = await db
    .collection("users")
    .doc(uid)
    .get();

  if (!userDocument.exists) {
    throw new ApiError(
      404,
      "user-not-found",
      "المستخدم غير موجود.",
    );
  }

  await auth.updateUser(uid, {
    password,
  });

  const userData = userDocument.data();

  await addAuditLog({
    action: "change_user_password",
    presidentUid,
    targetUid: uid,
    targetCode: textValue(userData?.code),
  });

  return jsonResponse({
    success: true,
    message:
      "تم تغيير كلمة المرور بنجاح.",
  });
}

// =====================================================
// Activate / deactivate
// =====================================================

async function setActive(
  body: RequestBody,
  presidentUid: string,
): Promise<Response> {
  const auth = getFirebaseAuth();
  const db = getFirebaseFirestore();

  const uid = textValue(body.uid);
  const active = body.active === true;

  if (!uid) {
    throw new ApiError(
      400,
      "uid-required",
      "معرف المستخدم مطلوب.",
    );
  }

  if (uid === presidentUid && !active) {
    throw new ApiError(
      400,
      "cannot-disable-current-user",
      "لا يمكن للرئيس إيقاف حسابه الحالي.",
    );
  }

  const userDocument = await db
    .collection("users")
    .doc(uid)
    .get();

  if (!userDocument.exists) {
    throw new ApiError(
      404,
      "user-not-found",
      "المستخدم غير موجود.",
    );
  }

  await auth.updateUser(uid, {
    disabled: !active,
  });

  await db
    .collection("users")
    .doc(uid)
    .update({
      active,

      updatedAt:
        FieldValue.serverTimestamp(),

      updatedByUid: presidentUid,
    });

  const userData = userDocument.data();

  await addAuditLog({
    action: active
      ? "activate_user"
      : "deactivate_user",

    presidentUid,
    targetUid: uid,
    targetCode: textValue(userData?.code),
  });

  return jsonResponse({
    success: true,

    message: active
      ? "تم تفعيل المستخدم."
      : "تم إيقاف المستخدم.",
  });
}

// =====================================================
// Delete user
// =====================================================

async function deleteUser(
  body: RequestBody,
  presidentUid: string,
): Promise<Response> {
  const auth = getFirebaseAuth();
  const db = getFirebaseFirestore();

  const uid = textValue(body.uid);

  if (!uid) {
    throw new ApiError(
      400,
      "uid-required",
      "معرف المستخدم مطلوب.",
    );
  }

  if (uid === presidentUid) {
    throw new ApiError(
      400,
      "cannot-delete-current-user",
      "لا يمكن للرئيس حذف حسابه الحالي.",
    );
  }

  const userDocument = await db
    .collection("users")
    .doc(uid)
    .get();

  if (!userDocument.exists) {
    throw new ApiError(
      404,
      "user-not-found",
      "المستخدم غير موجود.",
    );
  }

  const userData = userDocument.data();

  await auth.deleteUser(uid);

  await db
    .collection("users")
    .doc(uid)
    .delete();

  await addAuditLog({
    action: "delete_user",
    presidentUid,
    targetUid: uid,
    targetCode: textValue(userData?.code),

    details: {
      name: textValue(userData?.name),
      role: textValue(userData?.role),
    },
  });

  return jsonResponse({
    success: true,
    message: "تم حذف المستخدم بنجاح.",
  });
}

// =====================================================
// Error conversion
// =====================================================

function convertUnexpectedError(
  error: unknown,
): ApiError {
  const code =
    (error as { code?: string }).code ?? "";

  switch (code) {
    case "auth/email-already-exists":
      return new ApiError(
        409,
        "code-already-exists",
        "كود الدخول مستخدم بالفعل.",
      );

    case "auth/user-not-found":
      return new ApiError(
        404,
        "user-not-found",
        "المستخدم غير موجود.",
      );

    case "auth/invalid-email":
      return new ApiError(
        400,
        "invalid-code",
        "كود الدخول غير صالح.",
      );

    case "auth/invalid-password":
      return new ApiError(
        400,
        "invalid-password",
        "كلمة المرور غير صالحة.",
      );

    case "auth/insufficient-permission":
    case "app/invalid-credential":
      return new ApiError(
        500,
        "firebase-credential-error",
        "بيانات اتصال Firebase غير صحيحة.",
      );

    default:
      return new ApiError(
        500,
        "internal-error",
        error instanceof Error
          ? error.message
          : "حدث خطأ غير متوقع في الخادم.",
      );
  }
}

// =====================================================
// HTTP handler
// =====================================================

Deno.serve(async (request: Request) => {
  /*
   * الرد على OPTIONS قبل تهيئة Firebase.
   */
  if (request.method === "OPTIONS") {
    return new Response("ok", {
      status: 200,
      headers: corsHeaders,
    });
  }

  if (request.method !== "POST") {
    return jsonResponse(
      {
        success: false,
        code: "method-not-allowed",
        message: "يجب استخدام طلب POST.",
      },
      405,
    );
  }

  try {
    initializeFirebaseServices();

    const presidentUid =
      await verifyPresident(request);

    let body: RequestBody;

    try {
      body = await request.json();
    } catch (_) {
      throw new ApiError(
        400,
        "invalid-json",
        "بيانات الطلب غير صحيحة.",
      );
    }

    const action = textValue(body.action);

    switch (action) {
      case "create":
        return await createUser(
          body,
          presidentUid,
        );

      case "update":
        return await updateUser(
          body,
          presidentUid,
        );

      case "change_password":
        return await changePassword(
          body,
          presidentUid,
        );

      case "set_active":
        return await setActive(
          body,
          presidentUid,
        );

      case "delete":
        return await deleteUser(
          body,
          presidentUid,
        );

      default:
        throw new ApiError(
          400,
          "invalid-action",
          "نوع العملية غير صحيح.",
        );
    }
  } catch (error) {
    console.error(
      "manage-firebase-user error:",
      error,
    );

    const apiError =
      error instanceof ApiError
        ? error
        : convertUnexpectedError(error);

    return jsonResponse(
      {
        success: false,
        code: apiError.code,
        message: apiError.message,
      },
      apiError.status,
    );
  }
});