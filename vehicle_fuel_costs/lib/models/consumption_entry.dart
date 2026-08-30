import 'package:cloud_firestore/cloud_firestore.dart';

class ConsumptionEntry {
  final String id;
  final DateTime date;
  final String vehicleNumber;
  final int? previousOdometer;
  final int currentOdometer;
  final int? distance;
  final String driverName;

  const ConsumptionEntry({
    required this.id,
    required this.date,
    required this.vehicleNumber,
    required this.previousOdometer,
    required this.currentOdometer,
    required this.distance,
    required this.driverName,
  });

  factory ConsumptionEntry.fromMap(String id, Map<String, dynamic> map) {
    final rawDate = map['createdAt'];
    final date = rawDate is Timestamp ? rawDate.toDate() : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    return ConsumptionEntry(
      id: id,
      date: date,
      vehicleNumber: (map['vehicleNumber'] ?? '').toString(),
      previousOdometer: (map['previousOdometer'] as num?)?.toInt(),
      currentOdometer: (map['currentOdometer'] as num?)?.toInt() ?? 0,
      distance: (map['distance'] as num?)?.toInt(),
      driverName: (map['driverName'] ?? '').toString(),
    );
  }
}
