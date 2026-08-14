import 'package:cloud_firestore/cloud_firestore.dart';

class LoadRecord {
  const LoadRecord({
    required this.id,
    required this.distributorId,
    required this.distributorName,
    required this.operatorName,
    required this.createdByUid,
    required this.createdByCode,
    required this.recordedAt,
    required this.totalLoad,
    required this.cellValues,
    required this.cellRunningStates,
    this.manualEntryStates = const <int, bool>{},
  });

  final String id;
  final String distributorId;
  final String distributorName;
  final String operatorName;
  final String createdByUid;
  final String createdByCode;
  final DateTime recordedAt;
  final double totalLoad;

  final Map<int, double> cellValues;
  final Map<int, bool> cellRunningStates;
  final Map<int, bool> manualEntryStates;

  factory LoadRecord.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'بيانات سجل الأحمال غير موجودة: ${document.id}',
      );
    }

    final rawCellValues = Map<String, dynamic>.from(
      data['cellValues'] as Map? ?? <String, dynamic>{},
    );

    final rawRunningStates = Map<String, dynamic>.from(
      data['cellRunningStates'] as Map? ?? <String, dynamic>{},
    );

    final rawManualEntryStates = Map<String, dynamic>.from(
      data['manualEntryStates'] as Map? ?? <String, dynamic>{},
    );

    return LoadRecord(
      id: document.id,
      distributorId: (data['distributorId'] ?? '').toString(),
      distributorName: (data['distributorName'] ?? '').toString(),
      operatorName: (data['operatorName'] ?? '').toString(),
      createdByUid: (data['createdByUid'] ?? '').toString(),
      createdByCode: (data['createdByCode'] ?? '').toString(),
      recordedAt:
      _dateTimeFromValue(data['recordedAt']) ?? DateTime.now(),
      totalLoad: _doubleFromValue(data['totalLoad']),
      cellValues: rawCellValues.map(
            (key, value) => MapEntry(
          int.tryParse(key) ?? 0,
          _doubleFromValue(value),
        ),
      ),
      cellRunningStates: rawRunningStates.map(
            (key, value) => MapEntry(
          int.tryParse(key) ?? 0,
          value == true,
        ),
      ),
      manualEntryStates: rawManualEntryStates.map(
            (key, value) => MapEntry(
          int.tryParse(key) ?? 0,
          value == true,
        ),
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'distributorId': distributorId,
      'distributorName': distributorName,
      'operatorName': operatorName,
      'createdByUid': createdByUid,
      'createdByCode': createdByCode,
      'recordedAt': Timestamp.fromDate(recordedAt),
      'totalLoad': totalLoad,
      'cellValues': cellValues.map(
            (key, value) => MapEntry(key.toString(), value),
      ),
      'cellRunningStates': cellRunningStates.map(
            (key, value) => MapEntry(key.toString(), value),
      ),
      'manualEntryStates': manualEntryStates.map(
            (key, value) => MapEntry(key.toString(), value),
      ),
    };
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

  static double _doubleFromValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}