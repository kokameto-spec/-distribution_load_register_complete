import 'package:cloud_firestore/cloud_firestore.dart';

class SavedReport {
  const SavedReport({
    required this.id,
    required this.title,
    required this.reportType,
    required this.targetId,
    required this.targetName,
    required this.fromDate,
    required this.toDate,
    required this.hour,
    required this.notes,
    required this.createdByUid,
    required this.createdByCode,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;

  /// all_distributors_hourly | single_distributor | station
  final String reportType;

  final String targetId;
  final String targetName;

  final DateTime fromDate;
  final DateTime toDate;

  /// -1 يعني غير مستخدم.
  final int hour;

  final String notes;

  final String createdByUid;
  final String createdByCode;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isAllDistributorsHourly =>
      reportType == 'all_distributors_hourly';

  bool get isSingleDistributor =>
      reportType == 'single_distributor';

  bool get isStation =>
      reportType == 'station';

  factory SavedReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return SavedReport(
      id: document.id,
      title: (data['title'] ?? '').toString(),
      reportType: (data['reportType'] ?? '').toString(),
      targetId: (data['targetId'] ?? '').toString(),
      targetName: (data['targetName'] ?? '').toString(),
      fromDate: _dateTime(data['fromDate']),
      toDate: _dateTime(data['toDate']),
      hour: (data['hour'] is num)
          ? (data['hour'] as num).toInt()
          : -1,
      notes: (data['notes'] ?? '').toString(),
      createdByUid: (data['createdByUid'] ?? '').toString(),
      createdByCode: (data['createdByCode'] ?? '').toString(),
      createdAt: _dateTime(data['createdAt']),
      updatedAt: _dateTime(data['updatedAt']),
    );
  }

  static DateTime _dateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
