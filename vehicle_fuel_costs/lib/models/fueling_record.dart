import 'package:cloud_firestore/cloud_firestore.dart';

class FuelingRecord {
  final String id;
  final String vehicleCode;
  final String vehicleNumber;
  final String fuelType;
  final String vehicleModel;
  final String driverName;
  final int odometer;
  final DateTime createdAt;
  final String monthKey;
  final List<String> imageUrls;

  const FuelingRecord({
    required this.id,
    required this.vehicleCode,
    required this.vehicleNumber,
    required this.fuelType,
    required this.vehicleModel,
    required this.driverName,
    required this.odometer,
    required this.createdAt,
    required this.monthKey,
    required this.imageUrls,
  });

  factory FuelingRecord.fromMap(String id, Map<String, dynamic> map) {
    final rawDate = map['createdAt'];
    final date = rawDate is Timestamp ? rawDate.toDate() : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    return FuelingRecord(
      id: id,
      vehicleCode: (map['vehicleCode'] ?? '').toString(),
      vehicleNumber: (map['vehicleNumber'] ?? '').toString(),
      fuelType: (map['fuelType'] ?? '').toString(),
      vehicleModel: (map['vehicleModel'] ?? '').toString(),
      driverName: (map['driverName'] ?? '').toString(),
      odometer: (map['odometer'] as num?)?.toInt() ?? 0,
      createdAt: date,
      monthKey: (map['monthKey'] ?? '').toString(),
      imageUrls: List<String>.from(map['imageUrls'] ?? const []),
    );
  }
}
