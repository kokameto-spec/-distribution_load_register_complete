import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/load_record.dart';
import '../repositories/load_record_repository.dart';

class LoadRecordsController extends ChangeNotifier {
  LoadRecordsController({
    LoadRecordRepository? repository,
  }) : _repository =
            repository ?? LoadRecordRepository();

  final LoadRecordRepository _repository;

  StreamSubscription<List<LoadRecord>>? _subscription;

  List<LoadRecord> _records = <LoadRecord>[];

  bool _isLoading = false;
  String? _errorMessage;

  List<LoadRecord> get records {
    return List<LoadRecord>.unmodifiable(
      _records,
    );
  }

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  LoadRecord? get maximumLoadRecord {
    if (_records.isEmpty) {
      return null;
    }

    var result = _records.first;

    for (final record in _records.skip(1)) {
      if (record.totalLoad >
          result.totalLoad) {
        result = record;
      }
    }

    return result;
  }

  LoadRecord? get minimumLoadRecord {
    if (_records.isEmpty) {
      return null;
    }

    var result = _records.first;

    for (final record in _records.skip(1)) {
      if (record.totalLoad <
          result.totalLoad) {
        result = record;
      }
    }

    return result;
  }

  double? get maximumLoad =>
      maximumLoadRecord?.totalLoad;

  double? get minimumLoad =>
      minimumLoadRecord?.totalLoad;

  // =========================================================
  // LISTEN ALL
  // =========================================================

  void startListeningAll() {
    _subscription?.cancel();

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    _subscription =
        _repository.watchAll().listen(
      (items) {
        _records = items;

        _isLoading = false;
        _errorMessage = null;

        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;

        _errorMessage =
            'تعذر تحميل سجلات الأحمال.\n$error';

        notifyListeners();
      },
    );
  }

  // =========================================================
  // LISTEN FOR DISTRIBUTOR
  // =========================================================

  void startListeningForDistributor(
    String distributorId,
  ) {
    _subscription?.cancel();

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    _subscription = _repository
        .watchForDistributor(
          distributorId,
        )
        .listen(
      (items) {
        _records = items;

        _isLoading = false;
        _errorMessage = null;

        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;

        _errorMessage =
            'تعذر تحميل سجلات الموزع.\n$error';

        notifyListeners();
      },
    );
  }

  // =========================================================
  // NORMAL SEARCH
  // =========================================================

  Future<List<LoadRecord>> search({
    String? distributorId,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 500,
  }) async {
    _setLoading(true);

    _errorMessage = null;

    try {
      _records = await _repository
          .search(
            distributorId:
                distributorId,
            fromDate:
                fromDate,
            toDate:
                toDate,
            limit:
                limit,
          )
          .timeout(
            const Duration(
              seconds: 35,
            ),
          );

      return records;
    } on TimeoutException {
      _records = <LoadRecord>[];

      _errorMessage =
          'انتهت مهلة البحث. '
          'حاول مرة أخرى أو قلل الفترة.';

      return <LoadRecord>[];
    } catch (error) {
      _records = <LoadRecord>[];

      _errorMessage =
          'تعذر البحث في سجلات الأحمال.\n$error';

      return <LoadRecord>[];
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // ALL DISTRIBUTORS - ONE HOUR FOR MANY DAYS
  // =========================================================

  Future<List<LoadRecord>>
      searchAllDistributorsByHour({
    required DateTime fromDate,
    required DateTime toDate,
    required int hour,
  }) async {
    _setLoading(true);

    _errorMessage = null;
    _records = <LoadRecord>[];

    try {
      final startDay = DateTime(
        fromDate.year,
        fromDate.month,
        fromDate.day,
      );

      final endDay = DateTime(
        toDate.year,
        toDate.month,
        toDate.day,
      );

      if (startDay.isAfter(endDay)) {
        throw ArgumentError(
          'تاريخ البداية يجب أن يكون قبل تاريخ النهاية.',
        );
      }

      final totalDays =
          endDay.difference(startDay).inDays +
              1;

      /*
       * خمس أيام فقط في كل دفعة.
       * مناسب للأجهزة القديمة ولا يفتح عددًا كبيرًا
       * من الطلبات في نفس الوقت.
       */
      const batchSize = 5;

      final result =
          <LoadRecord>[];

      var dayIndex = 0;

      while (dayIndex < totalDays) {
        final futures =
            <Future<List<LoadRecord>>>[];

        for (var i = 0;
            i < batchSize &&
                dayIndex + i < totalDays;
            i++) {
          final day =
              startDay.add(
            Duration(
              days: dayIndex + i,
            ),
          );

          final from = DateTime(
            day.year,
            day.month,
            day.day,
            hour,
            0,
            0,
            0,
          );

          final to = DateTime(
            day.year,
            day.month,
            day.day,
            hour,
            59,
            59,
            999,
          );

          futures.add(
            _repository.search(
              fromDate: from,
              toDate: to,

              /*
               * كل موزع يسجل مرة تقريبًا
               * في الساعة، وبالتالي 200 نتيجة
               * كافية جدًا للساعة الواحدة.
               */
              limit: 200,
            ),
          );
        }

        final batchResults =
            await Future.wait(
          futures,
        ).timeout(
          const Duration(
            seconds: 40,
          ),
        );

        for (final items
            in batchResults) {
          result.addAll(items);
        }

        dayIndex += batchSize;

        /*
         * تحديث النتائج بالتدريج.
         */
        _records =
            List<LoadRecord>.from(
          result,
        );

        notifyListeners();

        /*
         * إعطاء Flutter فرصة لتحديث الواجهة
         * بدل تجميد الـUI.
         */
        await Future<void>.delayed(
          const Duration(
            milliseconds: 2,
          ),
        );
      }

      result.sort(
        (a, b) => b.recordedAt.compareTo(
          a.recordedAt,
        ),
      );

      _records = result;

      return records;
    } on TimeoutException {
      _errorMessage =
          'استغرق تحميل الفترة وقتًا أطول من المتوقع. '
          'تم الاحتفاظ بالبيانات التي تم تحميلها.';

      return records;
    } catch (error) {
      _errorMessage =
          'تعذر تحميل بيانات جميع الموزعات.\n$error';

      return records;
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // ONE DAY / ONE HOUR
  // =========================================================

  Future<List<LoadRecord>> searchDayHour({
    required DateTime day,
    required int hour,
  }) async {
    final from = DateTime(
      day.year,
      day.month,
      day.day,
      hour,
    );

    final to = DateTime(
      day.year,
      day.month,
      day.day,
      hour,
      59,
      59,
      999,
    );

    return search(
      fromDate: from,
      toDate: to,
      limit: 200,
    );
  }

  // =========================================================
  // REMAINING TIME
  // =========================================================

  Future<Duration?> getRemainingTime(
    String distributorId,
  ) {
    return _repository
        .remainingUntilNextRecord(
      distributorId,
    );
  }

  // =========================================================
  // SAVE
  // =========================================================

  Future<bool> saveRecord(
    LoadRecord record,
  ) async {
    _setLoading(true);

    _errorMessage = null;

    try {
      await _repository
          .createRecord(
            record: record,
          )
          .timeout(
            const Duration(
              seconds: 30,
            ),
          );

      return true;
    } on StateError catch (error) {
      _errorMessage =
          error.message.toString();

      return false;
    } on TimeoutException {
      _errorMessage =
          'انتهت مهلة حفظ الأحمال. '
          'تحقق من الاتصال بالإنترنت.';

      return false;
    } catch (error) {
      _errorMessage =
          'تعذر حفظ سجل الأحمال.\n$error';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // STOP
  // =========================================================

  Future<void> stopListening() async {
    await _subscription?.cancel();

    _subscription = null;
  }

  // =========================================================
  // CLEAR
  // =========================================================

  void clearRecords() {
    _records = <LoadRecord>[];
    _errorMessage = null;

    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;

    notifyListeners();
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

  @override
  void dispose() {
    _subscription?.cancel();

    super.dispose();
  }
}
