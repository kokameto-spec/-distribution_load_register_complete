import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/load_record.dart';

class LoadRecordRepository {
  LoadRecordRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int _homeLimit = 300;
  static const int _searchLimit = 1000;

  CollectionReference<Map<String, dynamic>> get _records {
    return _firestore.collection('load_records');
  }

  CollectionReference<Map<String, dynamic>> get _distributors {
    return _firestore.collection('distributors');
  }

  Stream<List<LoadRecord>> watchAll() {
    return _records
        .orderBy(
          'recordedAt',
          descending: true,
        )
        .limit(_homeLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(LoadRecord.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<LoadRecord>> watchForDistributor(
    String distributorId,
  ) {
    return _records
        .where(
          'distributorId',
          isEqualTo: distributorId.trim(),
        )
        .limit(_homeLimit)
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs
          .map(LoadRecord.fromFirestore)
          .toList();

      records.sort(
        (first, second) =>
            second.recordedAt.compareTo(first.recordedAt),
      );

      return records;
    });
  }

  Future<DateTime?> getLastRecordTime(
    String distributorId,
  ) async {
    final normalizedId = distributorId.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError('معرف الموزع غير صحيح.');
    }

    final document = await _distributors.doc(normalizedId).get();

    if (!document.exists) {
      throw StateError('الموزع غير موجود.');
    }

    final data = document.data();

    if (data == null) {
      throw StateError('بيانات الموزع غير موجودة.');
    }

    final value = data['lastRecordAt'];

    if (value == null) {
      return null;
    }

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

  Future<Duration?> remainingUntilNextRecord(
    String distributorId,
  ) async {
    final lastRecordTime = await getLastRecordTime(
      distributorId,
    );

    if (lastRecordTime == null) {
      return null;
    }

    final nextAllowedTime = lastRecordTime.add(
      const Duration(hours: 1),
    );

    final remaining = nextAllowedTime.difference(
      DateTime.now(),
    );

    if (remaining <= Duration.zero) {
      return null;
    }

    return remaining;
  }

  Future<String> createRecord({
    required LoadRecord record,
  }) async {
    if (record.distributorId.trim().isEmpty) {
      throw ArgumentError('معرف الموزع غير صحيح.');
    }

    if (record.operatorName.trim().isEmpty) {
      throw ArgumentError('اسم مدخل البيانات مطلوب.');
    }

    final remaining = await remainingUntilNextRecord(
      record.distributorId,
    );

    if (remaining != null) {
      throw StateError(
        'لا يمكن تسجيل أحمال جديدة قبل مرور ساعة.',
      );
    }

    final recordDocument = _records.doc();

    final distributorDocument = _distributors.doc(
      record.distributorId,
    );

    final batch = _firestore.batch();

    batch.set(
      recordDocument,
      <String, dynamic>{
        'distributorId': record.distributorId,
        'distributorName': record.distributorName,
        'operatorName': record.operatorName,
        'createdByUid': record.createdByUid,
        'createdByCode': record.createdByCode,
        'totalLoad': record.totalLoad,
        'cellValues': record.cellValues.map(
          (key, value) => MapEntry(
            key.toString(),
            value,
          ),
        ),
        'cellRunningStates': record.cellRunningStates.map(
          (key, value) => MapEntry(
            key.toString(),
            value,
          ),
        ),
        'recordedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    batch.update(
      distributorDocument,
      <String, dynamic>{
        'lastRecordAt': FieldValue.serverTimestamp(),
        'lastTotalLoad': record.totalLoad,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();

    return recordDocument.id;
  }

  Future<List<LoadRecord>> search({
    String? distributorId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    Query<Map<String, dynamic>> query = _records;

    if (distributorId != null &&
        distributorId.trim().isNotEmpty) {
      query = query.where(
        'distributorId',
        isEqualTo: distributorId.trim(),
      );
    }

    if (fromDate != null) {
      query = query.where(
        'recordedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(
          fromDate,
        ),
      );
    }

    if (toDate != null) {
      query = query.where(
        'recordedAt',
        isLessThanOrEqualTo: Timestamp.fromDate(
          toDate,
        ),
      );
    }

    query = query.limit(_searchLimit);

    final snapshot = await query.get();

    final records = snapshot.docs
        .map(LoadRecord.fromFirestore)
        .toList();

    records.sort(
      (first, second) =>
          second.recordedAt.compareTo(first.recordedAt),
    );

    return records;
  }
}
