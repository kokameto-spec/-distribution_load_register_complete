import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/audit_log.dart';
import '../repositories/audit_log_repository.dart';

class AuditLogController extends ChangeNotifier {
  AuditLogController({
    AuditLogRepository? repository,
  }) : _repository =
            repository ?? AuditLogRepository();

  final AuditLogRepository _repository;

  StreamSubscription<List<AuditLog>>?
      _subscription;

  List<AuditLog> _logs =
      <AuditLog>[];

  bool _isLoading = false;
  bool _isListening = false;
  bool _isSearchMode = false;

  String? _errorMessage;

  List<AuditLog> get logs =>
      List<AuditLog>.unmodifiable(
        _logs,
      );

  bool get isLoading =>
      _isLoading;

  bool get isListening =>
      _isListening;

  bool get isSearchMode =>
      _isSearchMode;

  String? get errorMessage =>
      _errorMessage;

  bool get _windows {
    return !kIsWeb &&
        defaultTargetPlatform ==
            TargetPlatform.windows;
  }

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

    if (_windows) {
      try {
        _logs =
            await _repository
                .latest()
                .timeout(
          const Duration(
            seconds: 25,
          ),
        );

        _errorMessage = null;
      } on TimeoutException {
        _logs = <AuditLog>[];

        _errorMessage =
            'استغرق تحميل سجل العمليات وقتًا طويلًا. '
            'تحقق من الإنترنت ثم أعد المحاولة.';
      } catch (error) {
        _logs = <AuditLog>[];

        _errorMessage =
            _errorText(error);
      } finally {
        _isLoading = false;
        _isListening = false;

        notifyListeners();
      }

      return;
    }

    _subscription =
        _repository
            .watchAll()
            .listen(
      (items) {
        if (_isSearchMode) {
          return;
        }

        _logs = items;
        _isLoading = false;
        _isListening = true;
        _errorMessage = null;

        notifyListeners();
      },
      onError: (
        Object error,
      ) {
        if (_isSearchMode) {
          return;
        }

        _isLoading = false;
        _isListening = false;
        _errorMessage =
            _errorText(error);

        notifyListeners();
      },
      onDone: () {
        if (_isSearchMode) {
          return;
        }

        _isLoading = false;
        _isListening = false;

        notifyListeners();
      },
    );
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
    await _subscription?.cancel();
    _subscription = null;

    _isListening = false;
    _isSearchMode = true;
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      _logs =
          await _repository
              .search(
                action: action,
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

      _errorMessage = null;
    } on TimeoutException {
      _logs = <AuditLog>[];

      _errorMessage =
          'انتهت مهلة البحث في سجل العمليات.';
    } catch (error) {
      _logs = <AuditLog>[];

      _errorMessage =
          _errorText(error);
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // =========================================================
  // UPDATE
  // =========================================================

  Future<bool> updateLog({
    required AuditLog original,
    required String action,
    required String targetCode,
    required Map<String, dynamic> details,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository
          .updateLog(
            id: original.id,
            action: action,
            targetCode:
                targetCode,
            details: details,
          )
          .timeout(
        const Duration(
          seconds: 30,
        ),
      );

      await _reloadAfterWrite();

      return true;
    } on TimeoutException {
      _errorMessage =
          'انتهت مهلة تعديل سجل العملية.';
      return false;
    } catch (error) {
      _errorMessage =
          _errorText(error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =========================================================
  // DELETE
  // =========================================================

  Future<bool> deleteLog(
    AuditLog log,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository
          .deleteLog(
            log.id,
          )
          .timeout(
        const Duration(
          seconds: 30,
        ),
      );

      _logs.removeWhere(
        (item) =>
            item.id == log.id,
      );

      notifyListeners();

      return true;
    } on TimeoutException {
      _errorMessage =
          'انتهت مهلة حذف سجل العملية.';
      return false;
    } catch (error) {
      _errorMessage =
          _errorText(error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadAfterWrite() async {
    if (_isSearchMode) {
      _logs =
          await _repository.latest();
      _isSearchMode = false;
    } else {
      _logs =
          await _repository.latest();
    }
  }

  // =========================================================
  // CLEAR / REFRESH
  // =========================================================

  Future<void> clearSearch() async {
    _isSearchMode = false;
    _errorMessage = null;

    await startListening();
  }

  Future<void> refresh() async {
    if (_isSearchMode) {
      return;
    }

    await startListening();
  }

  Future<void> stopListening() async {
    await _subscription?.cancel();

    _subscription = null;
    _isListening = false;
    _isLoading = false;

    notifyListeners();
  }

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
          return 'لا توجد صلاحية لتنفيذ العملية على سجل العمليات.';

        case 'unavailable':
          return 'خدمة قاعدة البيانات غير متاحة حاليًا.';

        case 'unauthenticated':
          return 'انتهت جلسة تسجيل الدخول.';

        default:
          return error.message ??
              'تعذر تنفيذ العملية.';
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
      return 'لا توجد صلاحية لتنفيذ العملية على سجل العمليات.';
    }

    if (text.contains(
      'UNAUTHENTICATED',
    )) {
      return 'انتهت جلسة تسجيل الدخول.';
    }

    return text.isEmpty
        ? 'تعذر تنفيذ العملية.'
        : text;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
