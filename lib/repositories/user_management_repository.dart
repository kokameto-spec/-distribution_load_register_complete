import 'package:firebase_auth/firebase_auth.dart';

import '../core/services/user_management_api.dart';

class UserManagementRepository {
  UserManagementRepository({
    UserManagementApi? api,
    FirebaseAuth? auth,
  })  : _api = api ?? UserManagementApi(),
        _auth = auth ?? FirebaseAuth.instance;

  final UserManagementApi _api;
  final FirebaseAuth _auth;

  Future<String> _token() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'انتهت جلسة تسجيل الدخول. سجل الدخول مرة أخرى.',
      );
    }

    final token = await user.getIdToken(true);

    if (token == null || token.trim().isEmpty) {
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
    final token = await _token();

    await _api.createUser(
      token: token,
      code: code,
      name: name,
      password: password,
      role: role,
      distributorId: distributorId,
      distributorName: distributorName,
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
    final token = await _token();

    await _api.updateUser(
      token: token,
      uid: uid,
      code: code,
      name: name,
      role: role,
      active: active,
      distributorId: distributorId,
      distributorName: distributorName,
    );
  }

  Future<void> changePassword({
    required String uid,
    required String password,
  }) async {
    final token = await _token();

    await _api.changePassword(
      token: token,
      uid: uid,
      password: password,
    );
  }

  Future<void> deleteUser(
      String uid,
      ) async {
    final token = await _token();

    await _api.deleteUser(
      token: token,
      uid: uid,
    );
  }

  Future<void> setActive({
    required String uid,
    required bool active,
  }) async {
    final token = await _token();

    await _api.setActive(
      token: token,
      uid: uid,
      active: active,
    );
  }

  void dispose() {
    _api.dispose();
  }
}