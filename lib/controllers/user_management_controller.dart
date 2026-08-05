import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../repositories/user_management_repository.dart';

class UserManagementController extends ChangeNotifier {
  UserManagementController({
    FirebaseFirestore? firestore,
    UserManagementRepository? repository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _repository =
            repository ?? UserManagementRepository();

  final FirebaseFirestore _firestore;
  final UserManagementRepository _repository;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _subscription;

  List<AppUser> _users = <AppUser>[];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isListening = false;

  List<AppUser> get users {
    return List<AppUser>.unmodifiable(_users);
  }

  bool get isLoading => _isLoading;
  bool get isListening => _isListening;
  String? get errorMessage => _errorMessage;

  List<AppUser> get presidents {
    return _users
        .where((user) => user.isPresident)
        .toList(growable: false);
  }

  List<AppUser> get managers {
    return _users
        .where((user) => user.isManager)
        .toList(growable: false);
  }

  List<AppUser> get dataEntryUsers {
    return _users
        .where((user) => user.isDataEntry)
        .toList(growable: false);
  }

  List<AppUser> get activeUsers {
    return _users
        .where((user) => user.active)
        .toList(growable: false);
  }

  Future<void> startListening() async {
    await _subscription?.cancel();

    _isLoading = true;
    _isListening = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _firestore
        .collection('users')
        .snapshots()
        .listen(
          (snapshot) {
        final items = snapshot.docs
            .map(
              (document) => AppUser.fromMap(
            uid: document.id,
            data: document.data(),
          ),
        )
            .toList();

        items.sort(
              (first, second) => first.displayName
              .toLowerCase()
              .compareTo(
            second.displayName.toLowerCase(),
          ),
        );

        _users = items;
        _isLoading = false;
        _isListening = true;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _isListening = false;
        _errorMessage = _errorText(error);
        notifyListeners();
      },
      onDone: () {
        _isListening = false;
        notifyListeners();
      },
    );
  }

  Future<void> stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    notifyListeners();
  }

  Future<bool> createUser({
    required String code,
    required String name,
    required String password,
    required String role,
    required String distributorId,
    required String distributorName,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _repository.createUser(
        code: code,
        name: name,
        password: password,
        role: role,
        distributorId: distributorId,
        distributorName: distributorName,
      );

      return true;
    } catch (error) {
      _errorMessage = _errorText(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateUser({
    required String uid,
    required String code,
    required String name,
    required String role,
    required bool active,
    required String distributorId,
    required String distributorName,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _repository.updateUser(
        uid: uid,
        code: code,
        name: name,
        role: role,
        active: active,
        distributorId: distributorId,
        distributorName: distributorName,
      );

      return true;
    } catch (error) {
      _errorMessage = _errorText(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> changePassword({
    required String uid,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _repository.changePassword(
        uid: uid,
        password: password,
      );

      return true;
    } catch (error) {
      _errorMessage = _errorText(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteUser(
      String uid,
      ) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _repository.deleteUser(uid);
      return true;
    } catch (error) {
      _errorMessage = _errorText(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> setActive({
    required String uid,
    required bool active,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _repository.setActive(
        uid: uid,
        active: active,
      );

      return true;
    } catch (error) {
      _errorMessage = _errorText(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  AppUser? findByUid(
      String uid,
      ) {
    final normalizedUid = uid.trim();

    for (final user in _users) {
      if (user.uid == normalizedUid) {
        return user;
      }
    }

    return null;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _errorText(
      Object error,
      ) {
    final text = error.toString().trim();

    if (text.startsWith('Exception:')) {
      return text
          .substring('Exception:'.length)
          .trim();
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'لا توجد صلاحية لقراءة بيانات المستخدمين.';

        case 'unavailable':
          return 'الخدمة غير متاحة حاليًا. تحقق من الاتصال بالإنترنت.';

        case 'unauthenticated':
          return 'انتهت جلسة تسجيل الدخول. سجل الدخول مرة أخرى.';

        default:
          return error.message ??
              'حدث خطأ أثناء الاتصال بقاعدة البيانات.';
      }
    }

    return text.isEmpty
        ? 'حدث خطأ غير متوقع.'
        : text;
  }

  void _setLoading(
      bool value,
      ) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}