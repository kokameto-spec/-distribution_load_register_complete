import 'package:flutter/foundation.dart';

import '../core/services/station_load_analytics_service.dart';
import '../models/station_load_report.dart';
import '../models/station_model.dart';
import '../repositories/load_record_repository.dart';

class StationReportController extends ChangeNotifier {
  StationReportController({LoadRecordRepository? repository})
      : _repository = repository ?? LoadRecordRepository();

  final LoadRecordRepository _repository;

  bool _isLoading = false;
  String? _errorMessage;
  StationLoadReportResult? _result;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  StationLoadReportResult? get result => _result;

  Future<bool> search({
    required Station station,
    String? transformerId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final records = await _repository.search(
        fromDate: fromDate,
        toDate: toDate,
      );

      _result = StationLoadAnalyticsService.buildReport(
        station: station,
        records: records,
        transformerId: transformerId,
        fromDate: fromDate,
        toDate: toDate,
      );
      return true;
    } catch (_) {
      _errorMessage = 'تعذر تحميل تقرير أحمال المحطة. تحقق من الاتصال بالإنترنت.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _result = null;
    _errorMessage = null;
    notifyListeners();
  }
}
