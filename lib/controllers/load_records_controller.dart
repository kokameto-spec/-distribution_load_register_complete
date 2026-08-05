import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/load_record.dart';
import '../repositories/load_record_repository.dart';

class LoadRecordsController extends ChangeNotifier {
  LoadRecordsController({
    LoadRecordRepository? repository,
  }) : _repository = repository ?? LoadRecordRepository();

  final LoadRecordRepository _repository;

  StreamSubscription<List<LoadRecord>>? _subscription;

  List<LoadRecord> _records = <LoadRecord>[];
  bool _isLoading = false;
  String? _errorMessage;

  List<LoadRecord> get records {
    return List<LoadRecord>.unmodifiable(_records);
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  LoadRecord? get maximumLoadRecord {
    if (_records.isEmpty) {
      return null;
    }

    LoadRecord result = _records.first;

    for (final record in _records.skip(1)) {
      if (record.totalLoad > result.totalLoad) {
        result = record;
      }
    }

    return result;
  }

  LoadRecord? get minimumLoadRecord {
    if (_records.isEmpty) {
      return null;
    }

    LoadRecord result = _records.first;

    for (final record in _records.skip(1)) {
      if (record.totalLoad < result.totalLoad) {
        result = record;
      }
    }

    return result;
  }

  double? get maximumLoad => maximumLoadRecord?.totalLoad;
  double? get minimumLoad => minimumLoadRecord?.totalLoad;

  void startListeningAll() {
    _subscription?.cancel();

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _repository.watchAll().listen(
          (items) {
        _records = items;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (_) {
        _isLoading = false;
        _errorMessage = 'تعذر تحميل سجلات الأحمال.';
        notifyListeners();
      },
    );
  }

  void startListeningForDistributor(
      String distributorId,
      ) {
    _subscription?.cancel();

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _repository
        .watchForDistributor(distributorId)
        .listen(
          (items) {
        _records = items;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (_) {
        _isLoading = false;
        _errorMessage = 'تعذر تحميل سجلات الموزع.';
        notifyListeners();
      },
    );
  }

  Future<List<LoadRecord>> search({
    String? distributorId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      _records = await _repository.search(
        distributorId: distributorId,
        fromDate: fromDate,
        toDate: toDate,
      );

      return records;
    } catch (_) {
      _errorMessage = 'تعذر البحث في سجلات الأحمال.';
      return <LoadRecord>[];
    } finally {
      _setLoading(false);
    }
  }

  Future<Duration?> getRemainingTime(
      String distributorId,
      ) {
    return _repository.remainingUntilNextRecord(
      distributorId,
    );
  }

  Future<bool> saveRecord(
      LoadRecord record,
      ) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _repository.createRecord(
        record: record,
      );

      return true;
    } on StateError catch (error) {
      _errorMessage = error.message.toString();
      return false;
    } catch (_) {
      _errorMessage =
      'تعذر حفظ سجل الأحمال. تحقق من الاتصال بالإنترنت.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
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