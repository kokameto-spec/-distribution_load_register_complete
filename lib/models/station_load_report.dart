import 'station_model.dart';

class TransformerLoadReading {
  const TransformerLoadReading({
    required this.transformer,
    required this.recordedAt,
    required this.load,
    required this.running,
  });

  final StationTransformer transformer;
  final DateTime recordedAt;
  final double load;
  final bool running;
}

class StationLoadSnapshot {
  const StationLoadSnapshot({
    required this.recordedAt,
    required this.totalLoad,
    required this.transformerLoads,
  });

  final DateTime recordedAt;
  final double totalLoad;
  final Map<String, double> transformerLoads;
}

class LoadPointStatistics<T> {
  const LoadPointStatistics({
    required this.count,
    required this.average,
    required this.minimum,
    required this.maximum,
    required this.minimumPoint,
    required this.maximumPoint,
  });

  final int count;
  final double average;
  final double? minimum;
  final double? maximum;
  final T? minimumPoint;
  final T? maximumPoint;
}

class TransformerReportSummary {
  const TransformerReportSummary({
    required this.transformer,
    required this.readings,
    required this.statistics,
  });

  final StationTransformer transformer;
  final List<TransformerLoadReading> readings;
  final LoadPointStatistics<TransformerLoadReading> statistics;

  TransformerLoadReading? get currentReading =>
      readings.isEmpty ? null : readings.first;
}

class StationLoadReportResult {
  const StationLoadReportResult({
    required this.station,
    required this.fromDate,
    required this.toDate,
    required this.transformerSummaries,
    required this.stationSnapshots,
    required this.stationStatistics,
  });

  final Station station;
  final DateTime? fromDate;
  final DateTime? toDate;
  final List<TransformerReportSummary> transformerSummaries;
  final List<StationLoadSnapshot> stationSnapshots;
  final LoadPointStatistics<StationLoadSnapshot> stationStatistics;

  StationLoadSnapshot? get currentStationSnapshot =>
      stationSnapshots.isEmpty ? null : stationSnapshots.first;
}
