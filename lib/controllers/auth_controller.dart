import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/services/connectivity_service.dart';
import '../models/app_user.dart';
import '../repositories/user_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    UserRepository? users,
    ConnectivityService? connectivity,
  })  : _users = users ?? UserRepository(),
        _connectivity = connectivity ?? ConnectivityService();

  final UserRepository _users;
  final ConnectivityService _connectivity;

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;

  Future<bool> login({
    required String code,
    required String password,
  }) async {
    _errorMessage = null;

    if (code.trim().isEmpty || password.isEmpty) {
      _errorMessage = 'أدخل كود الدخول وكلمة المرور.';
      notifyListeners();
      return false;
    }

    _setLoading(true);

    try {
      if (!await _connectivity.hasConnection()) {
        _errorMessage = 'لا يوجد اتصال بالإنترنت.';
        return false;
      }

      _currentUser = await _users.login(
        code: code,
        password: password,
      );

      if (_currentUser == null) {
        _errorMessage = 'بيانات الدخول غير صحيحة أو الحساب موقوف.';
        return false;
      }

      return true;
    } on FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-email':
          _errorMessage = 'كود الدخول أو كلمة المرور غير صحيحة.';
          break;

        case 'user-disabled':
          _errorMessage = 'هذا الحساب موقوف.';
          break;

        case 'too-many-requests':
          _errorMessage =
          'تم إجراء محاولات كثيرة. انتظر قليلًا ثم أعد المحاولة.';
          break;

        case 'network-request-failed':
          _errorMessage = 'لا يوجد اتصال بالإنترنت.';
          break;

        default:
          _errorMessage = 'تعذر تسجيل الدخول.';
      }

      return false;
    } catch (_) {
      _errorMessage = 'تعذر الاتصال بالخدمة السحابية.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> restoreSession() async {
    _setLoading(true);

    try {
      if (!await _connectivity.hasConnection()) {
        _errorMessage = 'لا يوجد اتصال بالإنترنت.';
        return false;
      }

      _currentUser = await _users.restoreSession();
      return _currentUser != null;
    } catch (_) {
      _currentUser = null;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _users.logout();

    _currentUser = null;
    _errorMessage = null;

    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}