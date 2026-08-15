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
    if (!_windows) {
      _auth =
          auth ?? FirebaseAuth.instance;
    }
  }

  final UserManagementApi _api;

  FirebaseAuth? _auth;

  bool get _windows {
    return !kIsWeb &&
        defaultTargetPlatform ==
            TargetPlatform.windows;
  }

  Future<String> _token() async {
    if (_windows) {
      final token =
          FirebaseRestService.token;

      if (token == null ||
          token.trim().isEmpty) {
        throw Exception(
          'انتهت جلسة تسجيل الدخول. سجل الدخول مرة أخرى.',
        );
      }

      return token;
    }

    final auth = _auth;

    if (auth == null) {
      throw Exception(
        'Firebase Auth غير مهيأ.',
      );
    }

    final user =
        auth.currentUser;

    if (user == null) {
      throw Exception(
        'انتهت جلسة تسجيل الدخول. سجل الدخول مرة أخرى.',
      );
    }

    final token =
        await user.getIdToken(
      true,
    );

    if (token == null ||
        token.trim().isEmpty) {
      throw Exception(
        'تعذر الحصول على رمز تسجيل الدخول.',
      );
    }

    return token;
  }

  Future<void> createUser({
    required String code,
    required String name,
    required String password,
    required String role,
    required String distributorId,
    required String distributorName,
  }) async {
    await _api.createUser(
      token:
          await _token(),
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
  }

  Future<void> updateUser({
    required String uid,
    required String code,
    required String name,
    required String role,
    required bool active,
    required String distributorId,
    required String distributorName,
  }) async {
    await _api.updateUser(
      token:
          await _token(),
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
  }

  Future<void> changePassword({
    required String uid,
    required String password,
  }) async {
    await _api.changePassword(
      token:
          await _token(),
      uid:
          uid,
      password:
          password,
    );
  }

  Future<void> deleteUser(
    String uid,
  ) async {
    await _api.deleteUser(
      token:
          await _token(),
      uid:
          uid,
    );
  }

  Future<void> setActive({
    required String uid,
    required bool active,
  }) async {
    await _api.setActive(
      token:
          await _token(),
      uid:
          uid,
      active:
          active,
    );
  }

  void dispose() {
    _api.dispose();
  }
}
