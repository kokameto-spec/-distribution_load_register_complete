import 'package:cloud_firestore/cloud_firestore.dart';

class Distributor {
  const Distributor({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.active,
    required this.createdAt,
    this.lastRecordAt,
    this.lastTotalLoad,
  });

  final String id;
  final String code;
  final String name;
  final String type;
  final bool active;
  final DateTime createdAt;
  final DateTime? lastRecordAt;
  final double? lastTotalLoad;

  factory Distributor.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'بيانات الموزع غير موجودة: ${document.id}',
      );
    }

    return Distributor(
      id: document.id,
      code: (data['code'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      type: (data['type'] ?? '').toString(),
      active: data['active'] == true,
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      lastRecordAt: _dateTimeFromValue(data['lastRecordAt']),
      lastTotalLoad: _doubleFromValue(data['lastTotalLoad']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'code': code.trim().toUpperCase(),
      'name': name.trim(),
      'type': type.trim(),
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastRecordAt': lastRecordAt == null
          ? null
          : Timestamp.fromDate(lastRecordAt!),
      'lastTotalLoad': lastTotalLoad,
    };
  }

  Distributor copyWith({
    String? id,
    String? code,
    String? name,
    String? type,
    bool? active,
    DateTime? createdAt,
    DateTime? lastRecordAt,
    double? lastTotalLoad,
    bool clearLastRecordAt = false,
    bool clearLastTotalLoad = false,
  }) {
    return Distributor(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      type: type ?? this.type,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      lastRecordAt: clearLastRecordAt
          ? null
          : lastRecordAt ?? this.lastRecordAt,
      lastTotalLoad: clearLastTotalLoad
          ? null
          : lastTotalLoad ?? this.lastTotalLoad,
    );
  }

  static DateTime? _dateTimeFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static double? _doubleFromValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }
}