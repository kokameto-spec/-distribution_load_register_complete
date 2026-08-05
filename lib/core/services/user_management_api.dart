import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class UserManagementApiException
    implements Exception {
  const UserManagementApiException({
    required this.message,
    this.code,
    this.statusCode,
  });

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class UserManagementApi {
  UserManagementApi({
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String baseUrl =
      'https://bohvzsjdbrywnrspmpym.supabase.co/'
      'functions/v1/manage-firebase-user';

  final http.Client _client;

  Future<Map<String, dynamic>> call({
    required String firebaseToken,
    required Map<String, dynamic> body,
  }) async {
    final normalizedToken =
    firebaseToken.trim();

    if (normalizedToken.isEmpty) {
      throw const UserManagementApiException(
        message:
        'رمز تسجيل الدخول غير موجود.',
        code: 'missing-firebase-token',
      );
    }

    late final http.Response response;

    try {
      response = await _client
          .post(
        Uri.parse(baseUrl),
        headers: <String, String>{
          /*
               * Firebase Token يرسل في Header مستقل.
               */
          'X-Firebase-Token':
          normalizedToken,

          'Content-Type':
          'application/json; charset=utf-8',

          'Accept':
          'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(
        const Duration(seconds: 40),
      );
    } on TimeoutException {
      throw const UserManagementApiException(
        message:
        'انتهت مهلة الاتصال بخادم إدارة المستخدمين.',
        code: 'request-timeout',
      );
    } on http.ClientException catch (error) {
      throw UserManagementApiException(
        message:
        'تعذر الاتصال بالخادم: ${error.message}',
        code: 'network-error',
      );
    } catch (error) {
      throw UserManagementApiException(
        message:
        'تعذر إرسال الطلب إلى الخادم: $error',
        code: 'request-error',
      );
    }

    Map<String, dynamic> responseData =
    <String, dynamic>{};

    if (response.body.trim().isNotEmpty) {
      try {
        final decoded =
        jsonDecode(response.body);

        if (decoded is Map) {
          responseData =
          Map<String, dynamic>.from(
            decoded,
          );
        }
      } catch (_) {
        responseData =
        <String, dynamic>{};
      }
    }

    final success =
        responseData['success'] == true;

    final message =
    (responseData['message'] ??
        _defaultMessageForStatus(
          response.statusCode,
        ))
        .toString();

    final code =
    responseData['code']?.toString();

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        !success) {
      throw UserManagementApiException(
        message: message,
        code: code,
        statusCode: response.statusCode,
      );
    }

    return responseData;
  }

  String _defaultMessageForStatus(
      int statusCode,
      ) {
    switch (statusCode) {
      case 400:
        return 'بيانات الطلب غير صحيحة.';

      case 401:
        return 'جلسة تسجيل الدخول غير صالحة أو انتهت.';

      case 403:
        return 'لا توجد صلاحية لتنفيذ هذه العملية.';

      case 404:
        return 'المستخدم أو الخدمة غير موجودة.';

      case 409:
        return 'توجد بيانات مسجلة بنفس الكود.';

      case 500:
        return 'حدث خطأ داخل الخادم.';

      case 502:
      case 503:
      case 504:
        return 'الخدمة غير متاحة حاليًا. أعد المحاولة.';

      default:
        return 'تعذر تنفيذ العملية.';
    }
  }

  Future<void> createUser({
    required String token,
    required String code,
    required String name,
    required String password,
    required String role,
    required String distributorId,
    required String distributorName,
  }) async {
    await call(
      firebaseToken: token,
      body: <String, dynamic>{
        'action': 'create',
        'code': code.trim(),
        'name': name.trim(),
        'password': password,
        'role': role.trim(),

        'distributorId':
        distributorId.trim(),

        'distributorName':
        distributorName.trim(),
      },
    );
  }

  Future<void> updateUser({
    required String token,
    required String uid,
    required String code,
    required String name,
    required String role,
    required bool active,
    required String distributorId,
    required String distributorName,
  }) async {
    await call(
      firebaseToken: token,
      body: <String, dynamic>{
        'action': 'update',
        'uid': uid.trim(),
        'code': code.trim(),
        'name': name.trim(),
        'role': role.trim(),
        'active': active,

        'distributorId':
        distributorId.trim(),

        'distributorName':
        distributorName.trim(),
      },
    );
  }

  Future<void> changePassword({
    required String token,
    required String uid,
    required String password,
  }) async {
    await call(
      firebaseToken: token,
      body: <String, dynamic>{
        'action': 'change_password',
        'uid': uid.trim(),
        'password': password,
      },
    );
  }

  Future<void> setActive({
    required String token,
    required String uid,
    required bool active,
  }) async {
    await call(
      firebaseToken: token,
      body: <String, dynamic>{
        'action': 'set_active',
        'uid': uid.trim(),
        'active': active,
      },
    );
  }

  Future<void> deleteUser({
    required String token,
    required String uid,
  }) async {
    await call(
      firebaseToken: token,
      body: <String, dynamic>{
        'action': 'delete',
        'uid': uid.trim(),
      },
    );
  }

  void dispose() {
    _client.close();
  }
}