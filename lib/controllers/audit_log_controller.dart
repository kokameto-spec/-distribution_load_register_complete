import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/audit_log.dart';
import '../repositories/audit_log_repository.dart';

class AuditLogController
    extends ChangeNotifier {
  AuditLogController({
    AuditLogRepository? repository,
  }) : _repository =
            repository ??
            AuditLogRepository();

  final AuditLogRepository _repository;

  StreamSubscription<List<AuditLog>>?
      _subscription;

  List<AuditLog> _logs =
      <AuditLog>[];

  bool _isLoading = false;
  bool _isListening = false;
  bool _isSearchMode = false;

  String? _errorMessage;

  // =========================================================
  // GETTERS
  // =========================================================

  List<AuditLog> get logs {
    return List<AuditLog>.unmodifiable(
      _logs,
    );
  }

  bool get isLoading =>
      _isLoading;

  bool get isListening =>
      _isListening;

  bool get isSearchMode =>
      _isSearchMode;

  String? get errorMessage =>
      _errorMessage;

  // =========================================================
  // START
  // =========================================================

  Future<void> startListening() async {
    await _subscription?.cancel();

    _subscription = null;

    _isLoading = true;
    _isListening = true;
    _isSearchMode = false;
    _errorMessage = null;

    notifyListeners();

    _subscription =
        _repository
            .watchAll()
            .listen(
      (items) {
        /*
         * لو المستخدم دخل وضع البحث،
         * لا نسمح للـstream الدوري
         * أن يمسح نتائج البحث.
         */
        if (_isSearchMode) {
          return;
        }

        _logs = items;

        _isLoading = false;
        _isListening = true;
        _errorMessage = null;

        notifyListeners();
      },
      onError:
          (Object error) {
        if (_isSearchMode) {
          return;
        }

        _isLoading = false;
        _isListening = false;

        _errorMessage =
            _errorText(
          error,
        );

        notifyListeners();
      },
      onDone: () {
        if (_isSearchMode) {
          return;
        }

        _isListening = false;

        notifyListeners();
      },
    );
  }

  // =========================================================
  // STOP
  // =========================================================

  Future<void> stopListening() async {
    await _subscription?.cancel();

    _subscription = null;

    _isListening = false;

    notifyListeners();
  }

  // =========================================================
  // SEARCH
  // =========================================================

  Future<void> search({
    String? action,
    String? targetCode,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    /*
     * مهم:
     * إيقاف الـstream العادي قبل البحث.
     *
     * في النسخة القديمة كان الـstream
     * يستطيع الكتابة فوق نتائج البحث
     * بعد عدة ثوانٍ.
     */
    await _subscription?.cancel();

    _subscription = null;

    _isListening = false;
    _isSearchMode = true;
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      _logs = await _repository
          .search(
            action:
                action,
            targetCode:
                targetCode,
            fromDate:
                fromDate,
            toDate:
                toDate,
          )
          .timeout(
            const Duration(
              seconds: 30,
            ),
          );
    } on TimeoutException {
      _logs =
          <AuditLog>[];

      _errorMessage =
          'انتهت مهلة البحث في سجل العمليات.';
    } catch (error) {
      _logs =
          <AuditLog>[];

      _errorMessage =
          _errorText(
        error,
      );
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // =========================================================
  // CLEAR SEARCH
  // =========================================================

  Future<void> clearSearch() async {
    _isSearchMode = false;
    _errorMessage = null;

    await startListening();
  }

  // =========================================================
  // REFRESH
  // =========================================================

  Future<void> refresh() async {
    if (_isSearchMode) {
      return;
    }

    await startListening();
  }

  // =========================================================
  // CLEAR ERROR
  // =========================================================

  void clearError() {
    _errorMessage = null;

    notifyListeners();
  }

  // =========================================================
  // ERROR
  // =========================================================

  String _errorText(
    Object error,
  ) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'لا توجد صلاحية لقراءة سجل العمليات.';

        case 'unavailable':
          return 'خدمة قاعدة البيانات غير متاحة حاليًا.';

        case 'unauthenticated':
          return 'انتهت جلسة تسجيل الدخول.';

        default:
          return error.message ??
              'تعذر تحميل سجل العمليات.';
      }
    }

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

    if (text.startsWith(
      'Bad state:',
    )) {
      return text
          .substring(
            'Bad state:'.length,
          )
          .trim();
    }

    if (text.contains(
      'PERMISSION_DENIED',
    )) {
      return 'لا توجد صلاحية لقراءة سجل العمليات.';
    }

    if (text.contains(
      'UNAUTHENTICATED',
    )) {
      return 'انتهت جلسة تسجيل الدخول.';
    }

    return text.isEmpty
        ? 'تعذر تحميل سجل العمليات.'
        : text;
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _subscription?.cancel();

    super.dispose();
  }
}
