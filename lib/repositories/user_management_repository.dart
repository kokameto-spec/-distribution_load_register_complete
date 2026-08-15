import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/services/firebase_rest_service.dart';
import '../core/services/user_management_api.dart';

class UserManagementRepository {
  UserManagementRepository({
    UserManagementApi? api,
    FirebaseAuth? auth,
  }) : _api =
            api ?? UserManagementApi() {
    /*
     * Windows لا ينشئ FirebaseAuth Native.
     */
    if (!_windows) {
      _auth =
          auth ?? FirebaseAuth.instance;
    }
  }

  final UserManagementApi _api;

  FirebaseAuth? _auth;

  // =========================================================
  // PLATFORM
  // =========================================================

  bool get _windows {
    return !kIsWeb &&
        defaultTargetPlatform ==
            TargetPlatform.windows;
  }

  // =========================================================
  // TOKEN
  // =========================================================

  Future<String> _token({
    bool forceRefresh = false,
  }) async {
    if (_windows) {
      /*
       * لا نستخدم FirebaseRestService.token
       * مباشرة بعد الآن.
       *
       * الدالة دي تتأكد إن التوكن صالح
       * وتجدد الجلسة عند الحاجة.
       */
      return FirebaseRestService
          .getValidIdToken(
        forceRefresh:
            forceRefresh,
      );
    }

    final auth =
        _auth;

    if (auth == null) {
      throw Exception(
        'Firebase Auth غير مهيأ.',
      );
    }

    final user =
        auth.currentUser;

    if (user == null) {
      throw Exception(
        'انتهت جلسة تسجيل الدخول. '
        'سجل الدخول مرة أخرى.',
      );
    }

    final token =
        await user.getIdToken(
      forceRefresh,
    );

    if (token == null ||
        token.trim().isEmpty) {
      throw Exception(
        'تعذر الحصول على رمز تسجيل الدخول.',
      );
    }

    return token;
  }

  // =========================================================
  // EXECUTE WITH TOKEN RETRY
  // =========================================================

  Future<void> _execute(
    Future<void> Function(
      String token,
    ) action,
  ) async {
    var token =
        await _token();

    try {
      await action(
        token,
      );
    } on UserManagementApiException
        catch (error) {
      /*
       * لو Supabase Function قالت إن
       * Firebase Token انتهى:
       *
       * نجدد التوكن ثم نكرر العملية مرة واحدة.
       */
      if (_windows &&
          error.statusCode == 401) {
        token =
            await _token(
          forceRefresh:
              true,
        );

        await action(
          token,
        );

        return;
      }

      rethrow;
    }
  }

  // =========================================================
  // CREATE USER
  // =========================================================

  Future<void> createUser({
    required String code,
    required String name,
    required String password,
    required String role,
    required String distributorId,
    required String distributorName,
  }) async {
    await _execute(
      (token) {
        return _api.createUser(
          token:
              token,
          code:
              code,
          name:
              name,
          password:
              password,
          role:
              role,
          distributorId:
              distributorId,
          distributorName:
              distributorName,
        );
      },
    );
  }

  // =========================================================
  // UPDATE USER
  // =========================================================

  Future<void> updateUser({
    required String uid,
    required String code,
    required String name,
    required String role,
    required bool active,
    required String distributorId,
    required String distributorName,
  }) async {
    await _execute(
      (token) {
        return _api.updateUser(
          token:
              token,
          uid:
              uid,
          code:
              code,
          name:
              name,
          role:
              role,
          active:
              active,
          distributorId:
              distributorId,
          distributorName:
              distributorName,
        );
      },
    );
  }

  // =========================================================
  // CHANGE PASSWORD
  // =========================================================

  Future<void> changePassword({
    required String uid,
    required String password,
  }) async {
    await _execute(
      (token) {
        return _api.changePassword(
          token:
              token,
          uid:
              uid,
          password:
              password,
        );
      },
    );
  }

  // =========================================================
  // DELETE USER
  // =========================================================

  Future<void> deleteUser(
    String uid,
  ) async {
    await _execute(
      (token) {
        return _api.deleteUser(
          token:
              token,
          uid:
              uid,
        );
      },
    );
  }

  // =========================================================
  // ACTIVE / INACTIVE
  // =========================================================

  Future<void> setActive({
    required String uid,
    required bool active,
  }) async {
    await _execute(
      (token) {
        return _api.setActive(
          token:
              token,
          uid:
              uid,
          active:
              active,
        );
      },
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  void dispose() {
    _api.dispose();
  }
}
