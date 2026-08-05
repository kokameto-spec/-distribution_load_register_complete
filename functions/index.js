const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");

initializeApp();

const db = getFirestore();

const allowedRoles = new Set([
  "president",
  "manager",
  "data_entry",
]);

function normalizeText(value) {
  return String(value ?? "").trim();
}

function normalizeCode(value) {
  return normalizeText(value).toLowerCase();
}

function emailForCode(code) {
  return `${normalizeCode(code)}@distribution.local`;
}

async function requirePresident(request) {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "يجب تسجيل الدخول أولًا.",
    );
  }

  const userDocument = await db
    .collection("users")
    .doc(request.auth.uid)
    .get();

  if (!userDocument.exists) {
    throw new HttpsError(
      "permission-denied",
      "بيانات المستخدم غير موجودة.",
    );
  }

  const userData = userDocument.data();

  if (
    userData.active !== true ||
    userData.role !== "president"
  ) {
    throw new HttpsError(
      "permission-denied",
      "هذه العملية متاحة للرئيس فقط.",
    );
  }

  return {
    uid: request.auth.uid,
    data: userData,
  };
}

function validateRoleAndDistributor({
  role,
  distributorId,
  distributorName,
}) {
  if (!allowedRoles.has(role)) {
    throw new HttpsError(
      "invalid-argument",
      "صلاحية المستخدم غير صحيحة.",
    );
  }

  if (
    role === "data_entry" &&
    (!distributorId || !distributorName)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "يجب ربط مدخل البيانات بموزع.",
    );
  }
}

async function ensureCodeAvailable(
  code,
  excludingUid = null,
) {
  const snapshot = await db
    .collection("users")
    .where("code", "==", code)
    .limit(2)
    .get();

  for (const document of snapshot.docs) {
    if (
      excludingUid === null ||
      document.id !== excludingUid
    ) {
      throw new HttpsError(
        "already-exists",
        "كود الدخول مستخدم بالفعل.",
      );
    }
  }
}

exports.createAppUser = onCall(
  {
    region: "europe-west1",
  },
  async (request) => {
    const president = await requirePresident(request);

    const code = normalizeCode(request.data?.code);
    const name = normalizeText(request.data?.name);
    const password = normalizeText(
      request.data?.password,
    );
    const role = normalizeText(request.data?.role);
    const distributorId = normalizeText(
      request.data?.distributorId,
    );
    const distributorName = normalizeText(
      request.data?.distributorName,
    );

    if (!code) {
      throw new HttpsError(
        "invalid-argument",
        "كود الدخول مطلوب.",
      );
    }

    if (!name) {
      throw new HttpsError(
        "invalid-argument",
        "اسم المستخدم مطلوب.",
      );
    }

    if (password.length < 6) {
      throw new HttpsError(
        "invalid-argument",
        "كلمة المرور يجب ألا تقل عن 6 أحرف أو أرقام.",
      );
    }

    validateRoleAndDistributor({
      role,
      distributorId,
      distributorName,
    });

    await ensureCodeAvailable(code);

    let authUser = null;

    try {
      authUser = await getAuth().createUser({
        email: emailForCode(code),
        password,
        displayName: name,
        disabled: false,
      });

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
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          createdByUid: president.uid,
        });

      await db.collection("audit_logs").add({
        action: "create_user",
        targetUid: authUser.uid,
        targetCode: code,
        performedByUid: president.uid,
        createdAt: FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        uid: authUser.uid,
      };
    } catch (error) {
      if (authUser?.uid) {
        await getAuth()
          .deleteUser(authUser.uid)
          .catch(() => {});
      }

      if (
        error.code === "auth/email-already-exists"
      ) {
        throw new HttpsError(
          "already-exists",
          "كود الدخول مستخدم بالفعل.",
        );
      }

      throw new HttpsError(
        "internal",
        error.message || "تعذر إنشاء المستخدم.",
      );
    }
  },
);

exports.updateAppUser = onCall(
  {
    region: "europe-west1",
  },
  async (request) => {
    const president = await requirePresident(request);

    const uid = normalizeText(request.data?.uid);
    const code = normalizeCode(request.data?.code);
    const name = normalizeText(request.data?.name);
    const role = normalizeText(request.data?.role);
    const active = request.data?.active === true;
    const distributorId = normalizeText(
      request.data?.distributorId,
    );
    const distributorName = normalizeText(
      request.data?.distributorName,
    );

    if (!uid || !code || !name) {
      throw new HttpsError(
        "invalid-argument",
        "بيانات المستخدم غير مكتملة.",
      );
    }

    validateRoleAndDistributor({
      role,
      distributorId,
      distributorName,
    });

    await ensureCodeAvailable(code, uid);

    const oldDocument = await db
      .collection("users")
      .doc(uid)
      .get();

    if (!oldDocument.exists) {
      throw new HttpsError(
        "not-found",
        "المستخدم غير موجود.",
      );
    }

    await getAuth().updateUser(uid, {
      email: emailForCode(code),
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
        updatedAt: FieldValue.serverTimestamp(),
        updatedByUid: president.uid,
      });

    await db.collection("audit_logs").add({
      action: "update_user",
      targetUid: uid,
      targetCode: code,
      performedByUid: president.uid,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
    };
  },
);

exports.changeAppUserPassword = onCall(
  {
    region: "europe-west1",
  },
  async (request) => {
    const president = await requirePresident(request);

    const uid = normalizeText(request.data?.uid);
    const password = normalizeText(
      request.data?.password,
    );

    if (!uid) {
      throw new HttpsError(
        "invalid-argument",
        "معرف المستخدم مطلوب.",
      );
    }

    if (password.length < 6) {
      throw new HttpsError(
        "invalid-argument",
        "كلمة المرور يجب ألا تقل عن 6 أحرف أو أرقام.",
      );
    }

    await getAuth().updateUser(uid, {
      password,
    });

    await db.collection("audit_logs").add({
      action: "change_user_password",
      targetUid: uid,
      performedByUid: president.uid,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
    };
  },
);

exports.deleteAppUser = onCall(
  {
    region: "europe-west1",
  },
  async (request) => {
    const president = await requirePresident(request);

    const uid = normalizeText(request.data?.uid);

    if (!uid) {
      throw new HttpsError(
        "invalid-argument",
        "معرف المستخدم مطلوب.",
      );
    }

    if (uid === president.uid) {
      throw new HttpsError(
        "failed-precondition",
        "لا يمكن للرئيس حذف حسابه الحالي.",
      );
    }

    const userDocument = await db
      .collection("users")
      .doc(uid)
      .get();

    if (!userDocument.exists) {
      throw new HttpsError(
        "not-found",
        "المستخدم غير موجود.",
      );
    }

    const userData = userDocument.data();

    await getAuth().deleteUser(uid);

    await db
      .collection("users")
      .doc(uid)
      .delete();

    await db.collection("audit_logs").add({
      action: "delete_user",
      targetUid: uid,
      targetCode: userData.code ?? "",
      performedByUid: president.uid,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
    };
  },
);