import '../../models/load_record.dart';
import '../../models/station_load_report.dart';
import '../../models/station_model.dart';

class StationLoadAnalyticsService {
  StationLoadAnalyticsService._();

  static StationLoadReportResult buildReport({
    required Station station,
    required List<LoadRecord> records,
    String? transformerId,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    final filteredRecords = records.where((record) {
      if (fromDate != null && record.recordedAt.isBefore(fromDate)) return false;
      if (toDate != null && record.recordedAt.isAfter(toDate)) return false;
      return true;
    }).toList(growable: false);

    final selectedTransformers = station.transformers.where((transformer) {
      return transformerId == null ||
          transformerId.trim().isEmpty ||
          transformer.id == transformerId;
    }).toList(growable: false);

    final summaries = selectedTransformers.map((transformer) {
      final readings = _buildTransformerReadings(
        transformer: transformer,
        records: filteredRecords,
      );

      return TransformerReportSummary(
        transformer: transformer,
        readings: List<TransformerLoadReading>.unmodifiable(readings),
        statistics: _transformerStatistics(readings),
      );
    }).toList(growable: false);

    final stationSnapshots = _buildStationSnapshots(
      station: station,
      records: filteredRecords,
    );

    return StationLoadReportResult(
      station: station,
      fromDate: fromDate,
      toDate: toDate,
      transformerSummaries: summaries,
      stationSnapshots: List<StationLoadSnapshot>.unmodifiable(stationSnapshots),
      stationStatistics: _stationStatistics(stationSnapshots),
    );
  }

  static List<TransformerLoadReading> _buildTransformerReadings({
    required StationTransformer transformer,
    required List<LoadRecord> records,
  }) {
    if (transformer.inputLinks.isEmpty) return <TransformerLoadReading>[];

    final requiredDistributorIds = transformer.inputLinks
        .map((link) => link.distributorId)
        .where((id) => id.isNotEmpty)
        .toSet();

    final byHour = _latestRecordsByHour(
      records: records,
      distributorIds: requiredDistributorIds,
    );

    final readings = <TransformerLoadReading>[];

    for (final entry in byHour.entries) {
      final recordsByDistributor = entry.value;
      final allAvailable = requiredDistributorIds.every(recordsByDistributor.containsKey);
      if (!allAvailable) continue;

      double load = 0;
      bool running = true;

      for (final link in transformer.inputLinks) {
        final record = recordsByDistributor[link.distributorId];
        if (record == null) {
          running = false;
          continue;
        }
        load += record.cellValues[link.cellNumber] ?? 0;
        running = running && (record.cellRunningStates[link.cellNumber] ?? true);
      }

      readings.add(
        TransformerLoadReading(
          transformer: transformer,
          recordedAt: entry.key,
          load: load,
          running: running,
        ),
      );
    }

    readings.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return readings;
  }

  static List<StationLoadSnapshot> _buildStationSnapshots({
    required Station station,
    required List<LoadRecord> records,
  }) {
    if (station.transformers.isEmpty) return <StationLoadSnapshot>[];

    final distributorIds = station.transformers
        .expand((transformer) => transformer.inputLinks)
        .map((link) => link.distributorId)
        .where((id) => id.isNotEmpty)
        .toSet();

    if (distributorIds.isEmpty) return <StationLoadSnapshot>[];

    final byHour = _latestRecordsByHour(
      records: records,
      distributorIds: distributorIds,
    );

    final snapshots = <StationLoadSnapshot>[];

    for (final entry in byHour.entries) {
      final recordsByDistributor = entry.value;
      final allAvailable = distributorIds.every(recordsByDistributor.containsKey);
      if (!allAvailable) continue;

      final transformerLoads = <String, double>{};
      double total = 0;

      for (final transformer in station.transformers) {
        double transformerLoad = 0;
        for (final link in transformer.inputLinks) {
          final record = recordsByDistributor[link.distributorId];
          if (record == null) continue;
          transformerLoad += record.cellValues[link.cellNumber] ?? 0;
        }
        transformerLoads[transformer.id] = transformerLoad;
        total += transformerLoad;
      }

      snapshots.add(
        StationLoadSnapshot(
          recordedAt: entry.key,
          totalLoad: total,
          transformerLoads: Map<String, double>.unmodifiable(transformerLoads),
        ),
      );
    }

    snapshots.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return snapshots;
  }

  static Map<DateTime, Map<String, LoadRecord>> _latestRecordsByHour({
    required List<LoadRecord> records,
    required Set<String> distributorIds,
  }) {
    final byHour = <DateTime, Map<String, LoadRecord>>{};

    for (final record in records) {
      if (!distributorIds.contains(record.distributorId)) continue;

      final bucket = DateTime(
        record.recordedAt.year,
        record.recordedAt.month,
        record.recordedAt.day,
        record.recordedAt.hour,
      );

      final distributorRecords =
          byHour.putIfAbsent(bucket, () => <String, LoadRecord>{});
      final previous = distributorRecords[record.distributorId];
      if (previous == null || record.recordedAt.isAfter(previous.recordedAt)) {
        distributorRecords[record.distributorId] = record;
      }
    }

    return byHour;
  }

  static LoadPointStatistics<TransformerLoadReading> _transformerStatistics(
    List<TransformerLoadReading> readings,
  ) {
    if (readings.isEmpty) {
      return const LoadPointStatistics<TransformerLoadReading>(
        count: 0,
        average: 0,
        minimum: null,
        maximum: null,
        minimumPoint: null,
        maximumPoint: null,
      );
    }

    var minimumPoint = readings.first;
    var maximumPoint = readings.first;
    double total = 0;

    for (final reading in readings) {
      total += reading.load;
      if (reading.load < minimumPoint.load) minimumPoint = reading;
      if (reading.load > maximumPoint.load) maximumPoint = reading;
    }

    return LoadPointStatistics<TransformerLoadReading>(
      count: readings.length,
      average: total / readings.length,
      minimum: minimumPoint.load,
      maximum: maximumPoint.load,
      minimumPoint: minimumPoint,
      maximumPoint: maximumPoint,
    );
  }

  static LoadPointStatistics<StationLoadSnapshot> _stationStatistics(
    List<StationLoadSnapshot> snapshots,
  ) {
    if (snapshots.isEmpty) {
      return const LoadPointStatistics<StationLoadSnapshot>(
        count: 0,
        average: 0,
        minimum: null,
        maximum: null,
        minimumPoint: null,
        maximumPoint: null,
      );
    }

    var minimumPoint = snapshots.first;
    var maximumPoint = snapshots.first;
    double total = 0;

    for (final snapshot in snapshots) {
      total += snapshot.totalLoad;
      if (snapshot.totalLoad < minimumPoint.totalLoad) minimumPoint = snapshot;
      if (snapshot.totalLoad > maximumPoint.totalLoad) maximumPoint = snapshot;
    }

    return LoadPointStatistics<StationLoadSnapshot>(
      count: snapshots.length,
      average: total / snapshots.length,
      minimum: minimumPoint.totalLoad,
      maximum: maximumPoint.totalLoad,
      minimumPoint: minimumPoint,
      maximumPoint: maximumPoint,
    );
  }
}
