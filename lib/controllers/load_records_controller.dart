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

  StreamSubscription<List<LoadRecord>>?
      _subscription;

  List<LoadRecord> _records =
      <LoadRecord>[];

  bool _isLoading = false;

  String? _errorMessage;

  // =========================================================
  // GETTERS
  // =========================================================

  List<LoadRecord> get records {
    return List<LoadRecord>.unmodifiable(
      _records,
    );
  }

  bool get isLoading =>
      _isLoading;

  String? get errorMessage =>
      _errorMessage;

  LoadRecord? get maximumLoadRecord {
    if (_records.isEmpty) {
      return null;
    }

    var result =
        _records.first;

    for (final record
        in _records.skip(1)) {
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

    var result =
        _records.first;

    for (final record
        in _records.skip(1)) {
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
        _repository
            .watchAll()
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
    final normalizedDistributorId =
        distributorId?.trim();

    /*
     * لو البحث لموزع محدد ومعاه فترة زمنية،
     * نستخدم البحث الآمن بدون Composite Index.
     */
    if (normalizedDistributorId != null &&
        normalizedDistributorId.isNotEmpty &&
        fromDate != null &&
        toDate != null) {
      return searchDistributorPeriod(
        distributorId:
            normalizedDistributorId,
        fromDate:
            fromDate,
        toDate:
            toDate,
      );
    }

    _setLoading(true);

    _errorMessage = null;

    try {
      _records = await _repository
          .search(
            distributorId:
                normalizedDistributorId,
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
      _records =
          <LoadRecord>[];

      _errorMessage =
          'انتهت مهلة البحث. '
          'حاول مرة أخرى أو قلل الفترة.';

      return <LoadRecord>[];
    } catch (error) {
      _records =
          <LoadRecord>[];

      _errorMessage =
          'تعذر البحث في سجلات الأحمال.\n$error';

      return <LoadRecord>[];
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // DISTRIBUTOR PERIOD SEARCH
  //
  // بدون Composite Index
  // =========================================================

  Future<List<LoadRecord>>
      searchDistributorPeriod({
    required String distributorId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    _setLoading(true);

    _errorMessage = null;

    _records =
        <LoadRecord>[];

    try {
      final normalizedDistributorId =
          distributorId.trim();

      if (normalizedDistributorId
          .isEmpty) {
        throw ArgumentError(
          'معرف الموزع غير صحيح.',
        );
      }

      final startDay =
          DateTime(
        fromDate.year,
        fromDate.month,
        fromDate.day,
      );

      final endDay =
          DateTime(
        toDate.year,
        toDate.month,
        toDate.day,
      );

      if (startDay.isAfter(
        endDay,
      )) {
        throw ArgumentError(
          'تاريخ البداية يجب أن يكون قبل تاريخ النهاية.',
        );
      }

      final totalDays =
          endDay
                  .difference(
                    startDay,
                  )
                  .inDays +
              1;

      /*
       * 4 أيام في كل دفعة.
       *
       * مناسب للأجهزة القديمة
       * ومش بيعمل ضغط كبير.
       */
      const batchSize = 4;

      final result =
          <LoadRecord>[];

      var dayIndex = 0;

      while (dayIndex <
          totalDays) {
        final futures =
            <Future<List<LoadRecord>>>[];

        for (var i = 0;
            i < batchSize &&
                dayIndex + i <
                    totalDays;
            i++) {
          final day =
              startDay.add(
            Duration(
              days:
                  dayIndex + i,
            ),
          );

          final dayFrom =
              DateTime(
            day.year,
            day.month,
            day.day,
            0,
            0,
            0,
            0,
          );

          final dayTo =
              DateTime(
            day.year,
            day.month,
            day.day,
            23,
            59,
            59,
            999,
          );

          /*
           * مهم:
           *
           * لا نرسل distributorId إلى Firestore.
           *
           * نبحث بالتاريخ فقط،
           * وبعدها نفلتر الموزع محليًا.
           *
           * كده لا نحتاج Composite Index.
           */
          futures.add(
            _repository.search(
              fromDate:
                  dayFrom,
              toDate:
                  dayTo,

              /*
               * يوم كامل:
               * 500 سجل كحد أعلى.
               */
              limit: 500,
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

        for (final dayRecords
            in batchResults) {
          for (final record
              in dayRecords) {
            if (record.distributorId
                    .trim() ==
                normalizedDistributorId) {
              result.add(
                record,
              );
            }
          }
        }

        dayIndex +=
            batchSize;

        /*
         * تحديث تدريجي للشاشة.
         */
        _records =
            List<LoadRecord>.from(
          result,
        );

        _records.sort(
          (a, b) =>
              b.recordedAt.compareTo(
            a.recordedAt,
          ),
        );

        notifyListeners();

        /*
         * فرصة للواجهة للتحديث
         * وعدم التجميد.
         */
        await Future<void>.delayed(
          const Duration(
            milliseconds: 2,
          ),
        );
      }

      result.sort(
        (a, b) =>
            b.recordedAt.compareTo(
          a.recordedAt,
        ),
      );

      _records =
          result;

      return records;
    } on TimeoutException {
      _errorMessage =
          'استغرق تحميل بيانات الموزع '
          'وقتًا أطول من المتوقع. '
          'تم الاحتفاظ بالبيانات التي تم تحميلها.';

      return records;
    } on ArgumentError catch (error) {
      _errorMessage =
          error.message
                  ?.toString() ??
              'بيانات البحث غير صحيحة.';

      return records;
    } catch (error) {
      _errorMessage =
          'تعذر البحث عن أحمال الموزع.\n$error';

      return records;
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // ALL DISTRIBUTORS
  // ONE HOUR FOR MANY DAYS
  // =========================================================

  Future<List<LoadRecord>>
      searchAllDistributorsByHour({
    required DateTime fromDate,
    required DateTime toDate,
    required int hour,
  }) async {
    _setLoading(true);

    _errorMessage = null;

    _records =
        <LoadRecord>[];

    try {
      final startDay =
          DateTime(
        fromDate.year,
        fromDate.month,
        fromDate.day,
      );

      final endDay =
          DateTime(
        toDate.year,
        toDate.month,
        toDate.day,
      );

      if (startDay.isAfter(
        endDay,
      )) {
        throw ArgumentError(
          'تاريخ البداية يجب أن يكون قبل تاريخ النهاية.',
        );
      }

      final totalDays =
          endDay
                  .difference(
                    startDay,
                  )
                  .inDays +
              1;

      /*
       * خمس أيام فقط في كل دفعة.
       */
      const batchSize = 5;

      final result =
          <LoadRecord>[];

      var dayIndex = 0;

      while (dayIndex <
          totalDays) {
        final futures =
            <Future<List<LoadRecord>>>[];

        for (var i = 0;
            i < batchSize &&
                dayIndex + i <
                    totalDays;
            i++) {
          final day =
              startDay.add(
            Duration(
              days:
                  dayIndex + i,
            ),
          );

          final from =
              DateTime(
            day.year,
            day.month,
            day.day,
            hour,
            0,
            0,
            0,
          );

          final to =
              DateTime(
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
              fromDate:
                  from,
              toDate:
                  to,
              limit:
                  200,
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
          result.addAll(
            items,
          );
        }

        dayIndex +=
            batchSize;

        _records =
            List<LoadRecord>.from(
          result,
        );

        notifyListeners();

        await Future<void>.delayed(
          const Duration(
            milliseconds: 2,
          ),
        );
      }

      result.sort(
        (a, b) =>
            b.recordedAt.compareTo(
          a.recordedAt,
        ),
      );

      _records =
          result;

      return records;
    } on TimeoutException {
      _errorMessage =
          'استغرق تحميل الفترة '
          'وقتًا أطول من المتوقع. '
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

  Future<List<LoadRecord>>
      searchDayHour({
    required DateTime day,
    required int hour,
  }) async {
    final from =
        DateTime(
      day.year,
      day.month,
      day.day,
      hour,
    );

    final to =
        DateTime(
      day.year,
      day.month,
      day.day,
      hour,
      59,
      59,
      999,
    );

    return search(
      fromDate:
          from,
      toDate:
          to,
      limit:
          200,
    );
  }

  // =========================================================
  // REMAINING TIME
  // =========================================================

  Future<Duration?>
      getRemainingTime(
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
            record:
                record,
          )
          .timeout(
            const Duration(
              seconds: 30,
            ),
          );

      return true;
    } on StateError catch (error) {
      _errorMessage =
          error.message
              .toString();

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
    await _subscription
        ?.cancel();

    _subscription =
        null;
  }

  // =========================================================
  // CLEAR
  // =========================================================

  void clearRecords() {
    _records =
        <LoadRecord>[];

    _errorMessage =
        null;

    notifyListeners();
  }

  void clearError() {
    _errorMessage =
        null;

    notifyListeners();
  }

  // =========================================================
  // LOADING
  // =========================================================

  void _setLoading(
    bool value,
  ) {
    _isLoading =
        value;

    notifyListeners();
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _subscription
        ?.cancel();

    super.dispose();
  }
}
