import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class FirebaseRestSession {
  const FirebaseRestSession({
    required this.localId,
    required this.idToken,
    required this.refreshToken,
  });

  final String localId;
  final String idToken;
  final String refreshToken;
}

class FirebaseRestService {
  FirebaseRestService._();

  // =========================================================
  // FIREBASE CONFIG
  // =========================================================

  static const String apiKey =
      'AIzaSyDXOJw0_HBNUYlyTMfYofFVMOiu3X0jQPw';

  static const String projectId =
      'distribution-load-register';

  // =========================================================
  // SESSION
  // =========================================================

  static FirebaseRestSession? _session;

  static DateTime? _tokenExpiresAt;

  static Future<bool>? _refreshingFuture;

  static FirebaseRestSession? get session =>
      _session;

  /*
   * للتوافق مع الملفات القديمة.
   *
   * الأفضل في العمليات الجديدة استخدام:
   * getValidIdToken()
   */
  static String? get token =>
      _session?.idToken;

  // =========================================================
  // SIGN IN
  // =========================================================

  static Future<FirebaseRestSession?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              'https://identitytoolkit.googleapis.com/v1/'
              'accounts:signInWithPassword?key=$apiKey',
            ),
            headers: const <String, String>{
              'Content-Type':
                  'application/json',
              'Accept':
                  'application/json',
            },
            body: jsonEncode(
              <String, dynamic>{
                'email':
                    email,
                'password':
                    password,
                'returnSecureToken':
                    true,
              },
            ),
          )
          .timeout(
            const Duration(
              seconds: 20,
            ),
          );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        _clearSession();

        return null;
      }

      final decoded =
          jsonDecode(
        response.body,
      );

      if (decoded
          is! Map<String, dynamic>) {
        _clearSession();

        return null;
      }

      final localId =
          (decoded['localId'] ?? '')
              .toString()
              .trim();

      final idToken =
          (decoded['idToken'] ?? '')
              .toString()
              .trim();

      final refreshToken =
          (decoded['refreshToken'] ?? '')
              .toString()
              .trim();

      if (localId.isEmpty ||
          idToken.isEmpty ||
          refreshToken.isEmpty) {
        _clearSession();

        return null;
      }

      final expiresIn =
          int.tryParse(
                (decoded['expiresIn'] ??
                        '3600')
                    .toString(),
              ) ??
              3600;

      final result =
          FirebaseRestSession(
        localId:
            localId,
        idToken:
            idToken,
        refreshToken:
            refreshToken,
      );

      _session =
          result;

      _setTokenExpiry(
        expiresIn,
      );

      return result;
    } on TimeoutException {
      _clearSession();

      return null;
    } catch (_) {
      _clearSession();

      return null;
    }
  }

  // =========================================================
  // SIGN OUT
  // =========================================================

  static void signOut() {
    _clearSession();
  }

  static void _clearSession() {
    _session = null;
    _tokenExpiresAt = null;
    _refreshingFuture = null;
  }

  // =========================================================
  // TOKEN EXPIRY
  // =========================================================

  static void _setTokenExpiry(
    int expiresInSeconds,
  ) {
    /*
     * نجدد قبل انتهاء التوكن بدقيقتين.
     */
    final safeSeconds =
        expiresInSeconds > 120
            ? expiresInSeconds - 120
            : expiresInSeconds;

    _tokenExpiresAt =
        DateTime.now().add(
      Duration(
        seconds:
            safeSeconds,
      ),
    );
  }

  static bool get _tokenNeedsRefresh {
    final session =
        _session;

    if (session == null ||
        session.idToken.trim().isEmpty) {
      return true;
    }

    final expiresAt =
        _tokenExpiresAt;

    if (expiresAt == null) {
      return true;
    }

    return !DateTime.now()
        .isBefore(
      expiresAt,
    );
  }

  // =========================================================
  // GET VALID ID TOKEN
  // =========================================================

  static Future<String> getValidIdToken({
    bool forceRefresh = false,
  }) async {
    final current =
        _session;

    if (current == null) {
      throw StateError(
        'جلسة تسجيل الدخول غير موجودة.',
      );
    }

    if (!forceRefresh &&
        !_tokenNeedsRefresh) {
      return current.idToken;
    }

    final success =
        await refreshIdToken();

    if (!success) {
      throw StateError(
        'انتهت جلسة تسجيل الدخول. '
        'سجل الدخول مرة أخرى.',
      );
    }

    final refreshed =
        _session;

    if (refreshed == null ||
        refreshed.idToken
            .trim()
            .isEmpty) {
      throw StateError(
        'تعذر تجديد جلسة تسجيل الدخول.',
      );
    }

    return refreshed.idToken;
  }

  // =========================================================
  // REFRESH TOKEN
  // =========================================================

  static Future<bool> refreshIdToken() async {
    /*
     * لو أكثر من شاشة طلبت Refresh
     * في نفس اللحظة، ننفذ طلبًا واحدًا فقط.
     */
    final existing =
        _refreshingFuture;

    if (existing != null) {
      return existing;
    }

    final future =
        _refreshIdTokenInternal();

    _refreshingFuture =
        future;

    try {
      return await future;
    } finally {
      _refreshingFuture = null;
    }
  }

  static Future<bool>
      _refreshIdTokenInternal() async {
    final current =
        _session;

    if (current == null) {
      return false;
    }

    final refreshToken =
        current.refreshToken.trim();

    if (refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse(
              'https://securetoken.googleapis.com/v1/'
              'token?key=$apiKey',
            ),
            headers: const <String, String>{
              'Content-Type':
                  'application/x-www-form-urlencoded',
              'Accept':
                  'application/json',
            },
            body: <String, String>{
              'grant_type':
                  'refresh_token',
              'refresh_token':
                  refreshToken,
            },
          )
          .timeout(
            const Duration(
              seconds: 20,
            ),
          );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        /*
         * Refresh Token غير صالح.
         * لا نستمر بتوكن قديم.
         */
        _clearSession();

        return false;
      }

      final decoded =
          jsonDecode(
        response.body,
      );

      if (decoded
          is! Map<String, dynamic>) {
        _clearSession();

        return false;
      }

      final newIdToken =
          (decoded['id_token'] ?? '')
              .toString()
              .trim();

      final newRefreshToken =
          (decoded['refresh_token'] ??
                  refreshToken)
              .toString()
              .trim();

      final userId =
          (decoded['user_id'] ??
                  current.localId)
              .toString()
              .trim();

      if (newIdToken.isEmpty ||
          newRefreshToken.isEmpty ||
          userId.isEmpty) {
        _clearSession();

        return false;
      }

      final expiresIn =
          int.tryParse(
                (decoded['expires_in'] ??
                        '3600')
                    .toString(),
              ) ??
              3600;

      _session =
          FirebaseRestSession(
        localId:
            userId,
        idToken:
            newIdToken,
        refreshToken:
            newRefreshToken,
      );

      _setTokenExpiry(
        expiresIn,
      );

      return true;
    } on TimeoutException {
      /*
       * Timeout لا يعني بالضرورة
       * أن Refresh Token غير صالح.
       *
       * نحافظ على الجلسة الحالية.
       */
      return false;
    } catch (_) {
      return false;
    }
  }

  // =========================================================
  // VALID AUTH HEADERS
  // =========================================================

  static Future<Map<String, String>>
      getValidAuthHeaders({
    bool forceRefresh = false,
  }) async {
    final idToken =
        await getValidIdToken(
      forceRefresh:
          forceRefresh,
    );

    return <String, String>{
      'Content-Type':
          'application/json',
      'Accept':
          'application/json',
      'Authorization':
          'Bearer $idToken',
    };
  }

  /*
   * للتوافق مع ملفات قديمة فقط.
   *
   * لا يقوم هذا Getter بتجديد التوكن
   * لأنه synchronous.
   */
  static Map<String, String>
      get authHeaders {
    final value =
        token;

    return <String, String>{
      'Content-Type':
          'application/json',
      'Accept':
          'application/json',
      if (value != null &&
          value.trim().isNotEmpty)
        'Authorization':
            'Bearer $value',
    };
  }

  // =========================================================
  // URLS
  // =========================================================

  static Uri documentUrl(
    String collection,
    String documentId,
  ) {
    return Uri.parse(
      'https://firestore.googleapis.com/v1/'
      'projects/$projectId/'
      'databases/(default)/documents/'
      '$collection/$documentId',
    );
  }

  static Uri collectionUrl(
    String collection,
  ) {
    return Uri.parse(
      'https://firestore.googleapis.com/v1/'
      'projects/$projectId/'
      'databases/(default)/documents/'
      '$collection',
    );
  }

  static Uri runQueryUrl() {
    return Uri.parse(
      'https://firestore.googleapis.com/v1/'
      'projects/$projectId/'
      'databases/(default)/documents:runQuery',
    );
  }

  // =========================================================
  // AUTHENTICATED REQUEST
  // =========================================================

  static Future<http.Response>
      _authenticatedRequest(
    Future<http.Response> Function(
      Map<String, String> headers,
    ) request, {
    Duration timeout =
        const Duration(
      seconds: 30,
    ),
  }) async {
    var headers =
        await getValidAuthHeaders();

    var response =
        await request(
      headers,
    ).timeout(
      timeout,
    );

    /*
     * لو التوكن انتهى بين لحظة الفحص
     * ولحظة تنفيذ الطلب:
     *
     * Refresh ثم إعادة الطلب مرة واحدة.
     */
    if (response.statusCode == 401) {
      final refreshed =
          await refreshIdToken();

      if (!refreshed) {
        throw StateError(
          'انتهت جلسة تسجيل الدخول. '
          'سجل الدخول مرة أخرى.',
        );
      }

      headers =
          await getValidAuthHeaders();

      response =
          await request(
        headers,
      ).timeout(
        timeout,
      );
    }

    return response;
  }

  // =========================================================
  // GET DOCUMENT
  // =========================================================

  static Future<Map<String, dynamic>?>
      getDocument({
    required String collection,
    required String documentId,
  }) async {
    final response =
        await _authenticatedRequest(
      (headers) {
        return http.get(
          documentUrl(
            collection,
            documentId,
          ),
          headers:
              headers,
        );
      },
      timeout:
          const Duration(
        seconds: 20,
      ),
    );

    if (response.statusCode == 404) {
      return null;
    }

    _throwIfFailed(
      response,
      operation:
          'قراءة المستند',
    );

    final decoded =
        jsonDecode(
      response.body,
    );

    if (decoded
        is! Map<String, dynamic>) {
      return null;
    }

    return decoded;
  }

  // =========================================================
  // GET COLLECTION
  // =========================================================

  static Future<List<Map<String, dynamic>>>
      getCollection({
    required String collection,
    int pageSize = 1000,
  }) async {
    final uri =
        collectionUrl(
      collection,
    ).replace(
      queryParameters:
          <String, String>{
        'pageSize':
            pageSize.toString(),
      },
    );

    final response =
        await _authenticatedRequest(
      (headers) {
        return http.get(
          uri,
          headers:
              headers,
        );
      },
      timeout:
          const Duration(
        seconds: 25,
      ),
    );

    _throwIfFailed(
      response,
      operation:
          'قراءة المجموعة',
    );

    final decoded =
        jsonDecode(
      response.body,
    );

    if (decoded
        is! Map<String, dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final rawDocuments =
        decoded['documents'];

    if (rawDocuments is! List) {
      return <Map<String, dynamic>>[];
    }

    return rawDocuments
        .whereType<Map>()
        .map(
          (item) =>
              Map<String, dynamic>.from(
            item,
          ),
        )
        .toList(
          growable:
              false,
        );
  }

  // =========================================================
  // RUN QUERY
  // =========================================================

  static Future<List<Map<String, dynamic>>>
      runQuery({
    required String collection,
    String? distributorId,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 500,
  }) async {
    final filters =
        <Map<String, dynamic>>[];

    if (distributorId != null &&
        distributorId
            .trim()
            .isNotEmpty) {
      filters.add(
        <String, dynamic>{
          'fieldFilter':
              <String, dynamic>{
            'field':
                <String, dynamic>{
              'fieldPath':
                  'distributorId',
            },
            'op':
                'EQUAL',
            'value':
                <String, dynamic>{
              'stringValue':
                  distributorId
                      .trim(),
            },
          },
        },
      );
    }

    if (fromDate != null) {
      filters.add(
        <String, dynamic>{
          'fieldFilter':
              <String, dynamic>{
            'field':
                <String, dynamic>{
              'fieldPath':
                  'recordedAt',
            },
            'op':
                'GREATER_THAN_OR_EQUAL',
            'value':
                <String, dynamic>{
              'timestampValue':
                  fromDate
                      .toUtc()
                      .toIso8601String(),
            },
          },
        },
      );
    }

    if (toDate != null) {
      filters.add(
        <String, dynamic>{
          'fieldFilter':
              <String, dynamic>{
            'field':
                <String, dynamic>{
              'fieldPath':
                  'recordedAt',
            },
            'op':
                'LESS_THAN_OR_EQUAL',
            'value':
                <String, dynamic>{
              'timestampValue':
                  toDate
                      .toUtc()
                      .toIso8601String(),
            },
          },
        },
      );
    }

    Map<String, dynamic>? where;

    if (filters.length == 1) {
      where =
          filters.first;
    } else if (filters.length > 1) {
      where =
          <String, dynamic>{
        'compositeFilter':
            <String, dynamic>{
          'op':
              'AND',
          'filters':
              filters,
        },
      };
    }

    final structuredQuery =
        <String, dynamic>{
      'from':
          <Map<String, dynamic>>[
        <String, dynamic>{
          'collectionId':
              collection,
        },
      ],

      if (where != null)
        'where':
            where,

      /*
       * load_records فقط هي التي
       * تستخدم هذه الدالة حاليًا،
       * لذلك recordedAt صحيح.
       */
      'orderBy':
          <Map<String, dynamic>>[
        <String, dynamic>{
          'field':
              <String, dynamic>{
            'fieldPath':
                'recordedAt',
          },
          'direction':
              'DESCENDING',
        },
      ],

      'limit':
          limit,
    };

    final response =
        await _authenticatedRequest(
      (headers) {
        return http.post(
          runQueryUrl(),
          headers:
              headers,
          body:
              jsonEncode(
            <String, dynamic>{
              'structuredQuery':
                  structuredQuery,
            },
          ),
        );
      },
      timeout:
          const Duration(
        seconds: 30,
      ),
    );

    _throwIfFailed(
      response,
      operation:
          'البحث في السجلات',
    );

    final decoded =
        jsonDecode(
      response.body,
    );

    if (decoded is! List) {
      return <Map<String, dynamic>>[];
    }

    final result =
        <Map<String, dynamic>>[];

    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }

      final map =
          Map<String, dynamic>.from(
        item,
      );

      final document =
          map['document'];

      if (document is Map) {
        result.add(
          Map<String, dynamic>.from(
            document,
          ),
        );
      }
    }

    return result;
  }

  // =========================================================
  // CREATE DOCUMENT
  // =========================================================

  static Future<String> createDocument({
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    final response =
        await _authenticatedRequest(
      (headers) {
        return http.post(
          collectionUrl(
            collection,
          ),
          headers:
              headers,
          body:
              jsonEncode(
            <String, dynamic>{
              'fields':
                  encodeFields(
                data,
              ),
            },
          ),
        );
      },
      timeout:
          const Duration(
        seconds: 25,
      ),
    );

    _throwIfFailed(
      response,
      operation:
          'إضافة المستند',
    );

    final decoded =
        jsonDecode(
      response.body,
    );

    if (decoded
        is! Map<String, dynamic>) {
      throw StateError(
        'استجابة Firestore غير صالحة.',
      );
    }

    return documentId(
      decoded,
    );
  }

  // =========================================================
  // PATCH DOCUMENT
  // =========================================================

  static Future<void> patchDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    if (data.isEmpty) {
      return;
    }

    final fields =
        data.keys.toList(
      growable:
          false,
    );

    /*
     * Firestore يقبل updateMask.fieldPaths
     * كقيمة متكررة.
     */
    final uri =
        documentUrl(
      collection,
      documentId,
    ).replace(
      queryParameters:
          <String, dynamic>{
        'updateMask.fieldPaths':
            fields,
      },
    );

    final response =
        await _authenticatedRequest(
      (headers) {
        return http.patch(
          uri,
          headers:
              headers,
          body:
              jsonEncode(
            <String, dynamic>{
              'fields':
                  encodeFields(
                data,
              ),
            },
          ),
        );
      },
      timeout:
          const Duration(
        seconds: 25,
      ),
    );

    _throwIfFailed(
      response,
      operation:
          'تعديل المستند',
    );
  }

  // =========================================================
  // DELETE DOCUMENT
  // =========================================================

  static Future<void> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    final response =
        await _authenticatedRequest(
      (headers) {
        return http.delete(
          documentUrl(
            collection,
            documentId,
          ),
          headers:
              headers,
        );
      },
      timeout:
          const Duration(
        seconds: 20,
      ),
    );

    if (response.statusCode == 200 ||
        response.statusCode == 204 ||
        response.statusCode == 404) {
      return;
    }

    _throwIfFailed(
      response,
      operation:
          'حذف المستند',
    );
  }

  // =========================================================
  // DOCUMENT ID
  // =========================================================

  static String documentId(
    Map<String, dynamic> document,
  ) {
    final name =
        (document['name'] ?? '')
            .toString();

    if (name.isEmpty) {
      return '';
    }

    final parts =
        name.split('/');

    if (parts.isEmpty) {
      return '';
    }

    return parts.last;
  }

  // =========================================================
  // DOCUMENT DATA
  // =========================================================

  static Map<String, dynamic> documentData(
    Map<String, dynamic> document,
  ) {
    final raw =
        document['fields'];

    if (raw is! Map) {
      return <String, dynamic>{};
    }

    return decodeFields(
      Map<String, dynamic>.from(
        raw,
      ),
    );
  }

  // =========================================================
  // DECODE FIELDS
  // =========================================================

  static Map<String, dynamic> decodeFields(
    Map<String, dynamic>? fields,
  ) {
    if (fields == null) {
      return <String, dynamic>{};
    }

    final result =
        <String, dynamic>{};

    for (final entry
        in fields.entries) {
      final rawValue =
          entry.value;

      if (rawValue is Map) {
        result[entry.key] =
            _decodeValue(
          Map<String, dynamic>.from(
            rawValue,
          ),
        );
      }
    }

    return result;
  }

  // =========================================================
  // DECODE VALUE
  // =========================================================

  static dynamic _decodeValue(
    Map<String, dynamic> value,
  ) {
    if (value.containsKey(
      'stringValue',
    )) {
      return value['stringValue'];
    }

    if (value.containsKey(
      'booleanValue',
    )) {
      return value['booleanValue'];
    }

    if (value.containsKey(
      'integerValue',
    )) {
      return int.tryParse(
        value['integerValue']
            .toString(),
      );
    }

    if (value.containsKey(
      'doubleValue',
    )) {
      final raw =
          value['doubleValue'];

      if (raw is num) {
        return raw.toDouble();
      }

      return double.tryParse(
        raw?.toString() ?? '',
      );
    }

    if (value.containsKey(
      'timestampValue',
    )) {
      return value[
              'timestampValue']
          ?.toString();
    }

    if (value.containsKey(
      'nullValue',
    )) {
      return null;
    }

    if (value.containsKey(
      'mapValue',
    )) {
      final rawMap =
          value['mapValue'];

      if (rawMap is! Map) {
        return <String, dynamic>{};
      }

      final mapValue =
          Map<String, dynamic>.from(
        rawMap,
      );

      final rawFields =
          mapValue['fields'];

      if (rawFields is! Map) {
        return <String, dynamic>{};
      }

      return decodeFields(
        Map<String, dynamic>.from(
          rawFields,
        ),
      );
    }

    if (value.containsKey(
      'arrayValue',
    )) {
      final rawArray =
          value['arrayValue'];

      if (rawArray is! Map) {
        return <dynamic>[];
      }

      final arrayValue =
          Map<String, dynamic>.from(
        rawArray,
      );

      final rawValues =
          arrayValue['values'];

      if (rawValues is! List) {
        return <dynamic>[];
      }

      return rawValues.map(
        (item) {
          if (item is! Map) {
            return null;
          }

          return _decodeValue(
            Map<String, dynamic>.from(
              item,
            ),
          );
        },
      ).toList(
        growable:
            false,
      );
    }

    if (value.containsKey(
      'referenceValue',
    )) {
      return value[
          'referenceValue'];
    }

    if (value.containsKey(
      'geoPointValue',
    )) {
      return value[
          'geoPointValue'];
    }

    return null;
  }

  // =========================================================
  // ENCODE FIELDS
  // =========================================================

  static Map<String, dynamic> encodeFields(
    Map<String, dynamic> data,
  ) {
    final result =
        <String, dynamic>{};

    for (final entry
        in data.entries) {
      result[entry.key] =
          _encodeValue(
        entry.value,
      );
    }

    return result;
  }

  // =========================================================
  // ENCODE VALUE
  // =========================================================

  static Map<String, dynamic> _encodeValue(
    dynamic value,
  ) {
    if (value == null) {
      return <String, dynamic>{
        'nullValue':
            null,
      };
    }

    if (value is String) {
      return <String, dynamic>{
        'stringValue':
            value,
      };
    }

    if (value is bool) {
      return <String, dynamic>{
        'booleanValue':
            value,
      };
    }

    if (value is int) {
      return <String, dynamic>{
        'integerValue':
            value.toString(),
      };
    }

    if (value is double) {
      return <String, dynamic>{
        'doubleValue':
            value,
      };
    }

    if (value is num) {
      return <String, dynamic>{
        'doubleValue':
            value.toDouble(),
      };
    }

    if (value is DateTime) {
      return <String, dynamic>{
        'timestampValue':
            value
                .toUtc()
                .toIso8601String(),
      };
    }

    if (value is Map) {
      return <String, dynamic>{
        'mapValue':
            <String, dynamic>{
          'fields':
              encodeFields(
            Map<String, dynamic>.from(
              value,
            ),
          ),
        },
      };
    }

    if (value is List) {
      return <String, dynamic>{
        'arrayValue':
            <String, dynamic>{
          'values':
              value
                  .map(
                    _encodeValue,
                  )
                  .toList(
                    growable:
                        false,
                  ),
        },
      };
    }

    return <String, dynamic>{
      'stringValue':
          value.toString(),
    };
  }

  // =========================================================
  // ERROR
  // =========================================================

  static void _throwIfFailed(
    http.Response response, {
    required String operation,
  }) {
    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return;
    }

    String message =
        '$operation فشل';

    try {
      final decoded =
          jsonDecode(
        response.body,
      );

      if (decoded is Map) {
        final error =
            decoded['error'];

        if (error is Map) {
          final serverMessage =
              error['message'];

          if (serverMessage != null &&
              serverMessage
                  .toString()
                  .trim()
                  .isNotEmpty) {
            message =
                serverMessage
                    .toString();
          }
        }
      }
    } catch (_) {
      // نستخدم الرسالة الافتراضية.
    }

    switch (response.statusCode) {
      case 401:
        throw StateError(
          'انتهت جلسة تسجيل الدخول. '
          'سجل الدخول مرة أخرى.',
        );

      case 403:
        throw StateError(
          'لا توجد صلاحية لتنفيذ هذه العملية.',
        );

      case 404:
        throw StateError(
          'البيانات المطلوبة غير موجودة.',
        );

      case 429:
        throw StateError(
          'تم إرسال طلبات كثيرة. '
          'أعد المحاولة بعد قليل.',
        );

      case 500:
      case 502:
      case 503:
      case 504:
        throw StateError(
          'الخدمة السحابية غير متاحة حاليًا. '
          'أعد المحاولة.',
        );

      default:
        throw StateError(
          '$message '
          '(HTTP ${response.statusCode})',
        );
    }
  }
}
