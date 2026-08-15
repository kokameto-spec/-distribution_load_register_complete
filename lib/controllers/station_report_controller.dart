import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/services/station_load_analytics_service.dart';
import '../models/load_record.dart';
import '../models/station_load_report.dart';
import '../models/station_model.dart';
import '../repositories/load_record_repository.dart';

class StationReportController extends ChangeNotifier {
  StationReportController({
    LoadRecordRepository? repository,
  }) : _repository =
            repository ?? LoadRecordRepository();

  final LoadRecordRepository _repository;

  bool _isLoading = false;
  String? _errorMessage;
  StationLoadReportResult? _result;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  StationLoadReportResult? get result => _result;

  // =========================================================
  // SEARCH
  // =========================================================

  Future<bool> search({
    required Station station,
    String? transformerId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (_isLoading) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _result = null;

    notifyListeners();

    try {
      final start =
          fromDate ??
          DateTime.now().subtract(
            const Duration(days: 1),
          );

      final end =
          toDate ??
          DateTime.now();

      if (start.isAfter(end)) {
        throw ArgumentError(
          'بداية الفترة يجب أن تسبق نهاية الفترة.',
        );
      }

      final distributorIds =
          _linkedDistributorIds(
        station: station,
        transformerId: transformerId,
      );

      if (distributorIds.isEmpty) {
        throw StateError(
          'لا توجد موزعات مرتبطة بالمحطة أو المحول المحدد.',
        );
      }

      final records =
          await _loadRecordsInBatches(
        distributorIds: distributorIds,
        fromDate: start,
        toDate: end,
      );

      _result =
          StationLoadAnalyticsService.buildReport(
        station: station,
        records: records,
        transformerId: transformerId,
        fromDate: start,
        toDate: end,
      );

      return true;
    } on TimeoutException {
      _errorMessage =
          'استغرق تحميل تقرير المحطة وقتًا أطول من المتوقع. '
          'حاول مرة أخرى أو قلل الفترة.';

      return false;
    } on ArgumentError catch (error) {
      _errorMessage =
          error.message?.toString() ??
          'بيانات فترة البحث غير صحيحة.';

      return false;
    } on StateError catch (error) {
      _errorMessage =
          error.message.toString();

      return false;
    } catch (error) {
      _errorMessage =
          'تعذر تحميل تقرير أحمال المحطة.\n$error';

      return false;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // =========================================================
  // LINKED DISTRIBUTORS
  // =========================================================

  Set<String> _linkedDistributorIds({
    required Station station,
    String? transformerId,
  }) {
    final ids = <String>{};

    for (final transformer
        in station.transformers) {
      if (transformerId != null &&
          transformerId.trim().isNotEmpty &&
          transformer.id != transformerId) {
        continue;
      }

      for (final link
          in transformer.inputLinks) {
        final id =
            link.distributorId.trim();

        if (id.isNotEmpty) {
          ids.add(id);
        }
      }
    }

    return ids;
  }

  // =========================================================
  // LOAD IN SMALL BATCHES
  // =========================================================

  Future<List<LoadRecord>>
      _loadRecordsInBatches({
    required Set<String> distributorIds,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final result = <LoadRecord>[];

    /*
     * تقسيم الفترة إلى 7 أيام.
     *
     * بهذه الطريقة:
     * - لا نحمل شهورًا كاملة دفعة واحدة.
     * - لا نصطدم بحد 500 نتيجة.
     * - يقل الضغط على RAM والمعالج.
     */
    const daysPerBatch = 7;

    var currentStart =
        fromDate;

    while (!currentStart.isAfter(
      toDate,
    )) {
      var currentEnd =
          currentStart.add(
        const Duration(
          days: daysPerBatch,
        ),
      );

      if (currentEnd.isAfter(toDate)) {
        currentEnd = toDate;
      }

      final futures =
          <Future<List<LoadRecord>>>[];

      for (final distributorId
          in distributorIds) {
        futures.add(
          _repository
              .search(
                distributorId:
                    distributorId,
                fromDate:
                    currentStart,
                toDate:
                    currentEnd,

                /*
                 * 7 أيام × 24 ساعة
                 * أقل بكثير من 500،
                 * لكن نترك مساحة لأي تسجيلات إضافية.
                 */
                limit: 500,
              )
              .timeout(
                const Duration(
                  seconds: 30,
                ),
              ),
        );
      }

      /*
       * كل موزعات الدفعة الحالية
       * تُحمّل بالتوازي.
       */
      final batch =
          await Future.wait(
        futures,
      ).timeout(
        const Duration(
          seconds: 40,
        ),
      );

      for (final items in batch) {
        result.addAll(items);
      }

      /*
       * السماح للواجهة بالتنفس
       * بين الدفعات.
       */
      await Future<void>.delayed(
        const Duration(
          milliseconds: 2,
        ),
      );

      if (currentEnd ==
          toDate) {
        break;
      }

      currentStart =
          currentEnd.add(
        const Duration(
          milliseconds: 1,
        ),
      );
    }

    // =======================================================
    // إزالة أي تكرار محتمل
    // =======================================================

    final unique =
        <String, LoadRecord>{};

    for (final record in result) {
      final key =
          record.id.trim().isNotEmpty
              ? record.id
              : '${record.distributorId}-'
                  '${record.recordedAt.microsecondsSinceEpoch}';

      unique[key] = record;
    }

    final records =
        unique.values.toList();

    records.sort(
      (a, b) =>
          a.recordedAt.compareTo(
        b.recordedAt,
      ),
    );

    return records;
  }

  // =========================================================
  // CLEAR
  // =========================================================

  void clear() {
    _result = null;
    _errorMessage = null;

    notifyListeners();
  }

  // =========================================================
  // CLEAR ERROR
  // =========================================================

  void clearError() {
    _errorMessage = null;

    notifyListeners();
  }
}
