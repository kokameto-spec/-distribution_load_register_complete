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

  List<AuditLog> _logs = <AuditLog>[];
  bool _isLoading = false;
  bool _isListening = false;
  String? _errorMessage;

  List<AuditLog> get logs {
    return List<AuditLog>.unmodifiable(_logs);
  }

  bool get isLoading => _isLoading;
  bool get isListening => _isListening;
  String? get errorMessage => _errorMessage;

  Future<void> startListening() async {
    await _subscription?.cancel();

    _isLoading = true;
    _isListening = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _repository.watchAll().listen(
          (items) {
        _logs = items;
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

  Future<void> search({
    String? action,
    String? targetCode,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      _logs = await _repository.search(
        action: action,
        targetCode: targetCode,
        fromDate: fromDate,
        toDate: toDate,
      );
    } catch (error) {
      _errorMessage = _errorText(error);
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _errorText(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'لا توجد صلاحية لقراءة سجل العمليات.';

        case 'unavailable':
          return 'خدمة Firebase غير متاحة حاليًا.';

        case 'unauthenticated':
          return 'انتهت جلسة تسجيل الدخول.';

        default:
          return error.message ??
              'تعذر تحميل سجل العمليات.';
      }
    }

    final text = error.toString();

    if (text.startsWith('Exception:')) {
      return text
          .substring('Exception:'.length)
          .trim();
    }

    return text;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}