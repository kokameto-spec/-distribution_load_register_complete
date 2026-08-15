import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/services/firebase_rest_service.dart';
import '../models/app_user.dart';
import '../repositories/user_management_repository.dart';

class UserManagementController extends ChangeNotifier {
  UserManagementController({
    FirebaseFirestore? firestore,
    UserManagementRepository? repository,
  }) : _repository =
            repository ?? UserManagementRepository() {
    if (!_windows) {
      _firestore =
          firestore ?? FirebaseFirestore.instance;
    }
  }

  FirebaseFirestore? _firestore;

  final UserManagementRepository _repository;

  StreamSubscription<
      QuerySnapshot<Map<String, dynamic>>>? _subscription;

  Timer? _windowsRefreshTimer;

  List<AppUser> _users = <AppUser>[];

  bool _isLoading = false;
  bool _isListening = false;

  String? _errorMessage;

  // =========================================================
  // PLATFORM
  // =========================================================

  bool get _windows {
    return !kIsWeb &&
        defaultTargetPlatform ==
            TargetPlatform.windows;
  }

  // =========================================================
  // GETTERS
  // =========================================================

  List<AppUser> get users {
    return List<AppUser>.unmodifiable(
      _users,
    );
  }

  bool get isLoading => _isLoading;

  bool get isListening => _isListening;

  String? get errorMessage => _errorMessage;

  List<AppUser> get presidents {
    return _users
        .where(
          (user) => user.isPresident,
        )
        .toList(
          growable: false,
        );
  }

  List<AppUser> get managers {
    return _users
        .where(
          (user) => user.isManager,
        )
        .toList(
          growable: false,
        );
  }

  List<AppUser> get dataEntryUsers {
    return _users
        .where(
          (user) => user.isDataEntry,
        )
        .toList(
          growable: false,
        );
  }

  List<AppUser> get activeUsers {
    return _users
        .where(
          (user) => user.active,
        )
        .toList(
          growable: false,
        );
  }

  // =========================================================
  // START LISTENING
  // =========================================================

  Future<void> startListening() async {
    if (_isListening) {
      return;
    }

    await _subscription?.cancel();
    _subscription = null;

    _windowsRefreshTimer?.cancel();
    _windowsRefreshTimer = null;

    _isLoading = true;
    _isListening = true;
    _errorMessage = null;

    notifyListeners();

    if (_windows) {
      await _loadUsersWindows();

      _windowsRefreshTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) {
          _refreshWindowsSilently();
        },
      );

      return;
    }

    _startFirebaseListening();
  }

  // =========================================================
  // ANDROID / FIREBASE NATIVE
  // =========================================================

  void _startFirebaseListening() {
    final firestore = _firestore;

    if (firestore == null) {
      _isLoading = false;
      _isListening = false;

      _errorMessage =
          'Firebase Firestore غير مهيأ.';

      notifyListeners();

      return;
    }

    _subscription = firestore
        .collection('users')
        .snapshots()
        .listen(
      (snapshot) {
        final items = snapshot.docs.map(
          (document) {
            return AppUser.fromMap(
              uid: document.id,
              data: document.data(),
            );
          },
        ).toList();

        _sortUsers(
          items,
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

        _errorMessage =
            _errorText(
          error,
        );

        notifyListeners();
      },
      onDone: () {
        _isListening = false;

        notifyListeners();
      },
    );
  }

  // =========================================================
  // WINDOWS REST
  // =========================================================

  Future<void> _loadUsersWindows() async {
    try {
      final documents =
          await FirebaseRestService
              .getCollection(
        collection: 'users',
        pageSize: 500,
      ).timeout(
        const Duration(seconds: 20),
      );

      final items =
          <AppUser>[];

      for (final document in documents) {
        final uid =
            FirebaseRestService.documentId(
          document,
        );

        if (uid.isEmpty) {
          continue;
        }

        final data =
            FirebaseRestService.documentData(
          document,
        );

        items.add(
          AppUser.fromMap(
            uid: uid,
            data: data,
          ),
        );
      }

      _sortUsers(
        items,
      );

      _users = items;

      _isLoading = false;
      _isListening = true;
      _errorMessage = null;
    } on TimeoutException {
      _isLoading = false;

      _errorMessage =
          'انتهت مهلة تحميل بيانات المستخدمين.';
    } catch (error) {
      _isLoading = false;

      _errorMessage =
          _errorText(
        error,
      );
    }

    notifyListeners();
  }

  Future<void> _refreshWindowsSilently() async {
    if (!_windows ||
        !_isListening) {
      return;
    }

    try {
      final documents =
          await FirebaseRestService
              .getCollection(
        collection: 'users',
        pageSize: 500,
      ).timeout(
        const Duration(seconds: 20),
      );

      final items =
          <AppUser>[];

      for (final document in documents) {
        final uid =
            FirebaseRestService.documentId(
          document,
        );

        if (uid.isEmpty) {
          continue;
        }

        final data =
            FirebaseRestService.documentData(
          document,
        );

        items.add(
          AppUser.fromMap(
            uid: uid,
            data: data,
          ),
        );
      }

      _sortUsers(
        items,
      );

      _users = items;
      _errorMessage = null;

      notifyListeners();
    } catch (_) {
      // نحتفظ بالبيانات القديمة
      // إذا فشل التحديث الدوري.
    }
  }

  // =========================================================
  // REFRESH
  // =========================================================

  Future<void> refresh() async {
    if (_windows) {
      _isLoading = true;
      _errorMessage = null;

      notifyListeners();

      await _loadUsersWindows();

      return;
    }

    if (!_isListening) {
      await startListening();
    }
  }

  // =========================================================
  // STOP
  // =========================================================

  Future<void> stopListening() async {
    await _subscription?.cancel();

    _subscription = null;

    _windowsRefreshTimer?.cancel();
    _windowsRefreshTimer = null;

    _isListening = false;

    notifyListeners();
  }

  // =========================================================
  // CREATE USER
  // =========================================================

  Future<bool> createUser({
    required String code,
    required String name,
    required String password,
    required String role,
    required String distributorId,
    required String distributorName,
  }) async {
    _setLoading(
      true,
    );

    _errorMessage = null;

    try {
      await _repository.createUser(
        code: code,
        name: name,
        password: password,
        role: role,
        distributorId:
            distributorId,
        distributorName:
            distributorName,
      );

      if (_windows) {
        await _loadUsersWindows();
      }

      return true;
    } catch (error) {
      _errorMessage =
          _errorText(
        error,
      );

      return false;
    } finally {
      _setLoading(
        false,
      );
    }
  }

  // =========================================================
  // UPDATE USER
  // =========================================================

  Future<bool> updateUser({
    required String uid,
    required String code,
    required String name,
    required String role,
    required bool active,
    required String distributorId,
    required String distributorName,
  }) async {
    _setLoading(
      true,
    );

    _errorMessage = null;

    try {
      await _repository.updateUser(
        uid: uid,
        code: code,
        name: name,
        role: role,
        active: active,
        distributorId:
            distributorId,
        distributorName:
            distributorName,
      );

      if (_windows) {
        await _loadUsersWindows();
      }

      return true;
    } catch (error) {
      _errorMessage =
          _errorText(
        error,
      );

      return false;
    } finally {
      _setLoading(
        false,
      );
    }
  }

  // =========================================================
  // CHANGE PASSWORD
  // =========================================================

  Future<bool> changePassword({
    required String uid,
    required String password,
  }) async {
    _setLoading(
      true,
    );

    _errorMessage = null;

    try {
      await _repository.changePassword(
        uid: uid,
        password: password,
      );

      return true;
    } catch (error) {
      _errorMessage =
          _errorText(
        error,
      );

      return false;
    } finally {
      _setLoading(
        false,
      );
    }
  }

  // =========================================================
  // DELETE USER
  // =========================================================

  Future<bool> deleteUser(
    String uid,
  ) async {
    _setLoading(
      true,
    );

    _errorMessage = null;

    try {
      await _repository.deleteUser(
        uid,
      );

      if (_windows) {
        await _loadUsersWindows();
      }

      return true;
    } catch (error) {
      _errorMessage =
          _errorText(
        error,
      );

      return false;
    } finally {
      _setLoading(
        false,
      );
    }
  }

  // =========================================================
  // ACTIVE / INACTIVE
  // =========================================================

  Future<bool> setActive({
    required String uid,
    required bool active,
  }) async {
    _setLoading(
      true,
    );

    _errorMessage = null;

    try {
      await _repository.setActive(
        uid: uid,
        active: active,
      );

      if (_windows) {
        await _loadUsersWindows();
      }

      return true;
    } catch (error) {
      _errorMessage =
          _errorText(
        error,
      );

      return false;
    } finally {
      _setLoading(
        false,
      );
    }
  }

  // =========================================================
  // FIND USER
  // =========================================================

  AppUser? findByUid(
    String uid,
  ) {
    final normalizedUid =
        uid.trim();

    for (final user in _users) {
      if (user.uid ==
          normalizedUid) {
        return user;
      }
    }

    return null;
  }

  // =========================================================
  // SORT
  // =========================================================

  void _sortUsers(
    List<AppUser> items,
  ) {
    items.sort(
      (first, second) =>
          first.displayName
              .toLowerCase()
              .compareTo(
                second.displayName
                    .toLowerCase(),
              ),
    );
  }

  // =========================================================
  // ERROR
  // =========================================================

  void clearError() {
    _errorMessage = null;

    notifyListeners();
  }

  String _errorText(
    Object error,
  ) {
    final text =
        error.toString().trim();

    if (text.startsWith(
      'Exception:',
    )) {
      return text
          .substring(
            'Exception:'.length,
          )
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

    if (text.contains(
      'PERMISSION_DENIED',
    )) {
      return 'لا توجد صلاحية لقراءة بيانات المستخدمين.';
    }

    if (text.contains(
      'UNAUTHENTICATED',
    )) {
      return 'انتهت جلسة تسجيل الدخول. سجل الدخول مرة أخرى.';
    }

    return text.isEmpty
        ? 'حدث خطأ غير متوقع.'
        : text;
  }

  // =========================================================
  // LOADING
  // =========================================================

  void _setLoading(
    bool value,
  ) {
    _isLoading = value;

    notifyListeners();
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _subscription?.cancel();

    _windowsRefreshTimer?.cancel();

    _repository.dispose();

    super.dispose();
  }
}
