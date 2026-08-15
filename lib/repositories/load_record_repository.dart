import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/services/firebase_rest_service.dart';
import '../models/load_record.dart';

class LoadRecordRepository {
  LoadRecordRepository({
    FirebaseFirestore? firestore,
  }) {
    if (!_windows) {
      _firestore =
          firestore ?? FirebaseFirestore.instance;
    }
  }

  FirebaseFirestore? _firestore;

  static const int _homeLimit = 300;
  static const int _searchLimit = 500;

  bool get _windows {
    return !kIsWeb &&
        defaultTargetPlatform ==
            TargetPlatform.windows;
  }

  FirebaseFirestore get _nativeFirestore {
    final firestore = _firestore;

    if (firestore == null) {
      throw StateError(
        'Firebase Native غير مستخدم على Windows.',
      );
    }

    return firestore;
  }

  CollectionReference<Map<String, dynamic>>
      get _records {
    return _nativeFirestore.collection(
      'load_records',
    );
  }

  CollectionReference<Map<String, dynamic>>
      get _distributors {
    return _nativeFirestore.collection(
      'distributors',
    );
  }

  // =========================================================
  // WATCH ALL
  // =========================================================

  Stream<List<LoadRecord>> watchAll() {
    if (_windows) {
      return Stream<List<LoadRecord>>.periodic(
        const Duration(seconds: 30),
      ).asyncMap(
        (_) => search(
          limit: _homeLimit,
        ),
      ).startWith(
        search(
          limit: _homeLimit,
        ),
      );
    }

    return _records
        .orderBy(
          'recordedAt',
          descending: true,
        )
        .limit(_homeLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                LoadRecord.fromFirestore,
              )
              .toList(
                growable: false,
              ),
        );
  }

  // =========================================================
  // WATCH DISTRIBUTOR
  // =========================================================

  Stream<List<LoadRecord>>
      watchForDistributor(
    String distributorId,
  ) {
    if (_windows) {
      return Stream<List<LoadRecord>>.periodic(
        const Duration(seconds: 30),
      ).asyncMap(
        (_) => search(
          distributorId: distributorId,
          limit: _homeLimit,
        ),
      ).startWith(
        search(
          distributorId: distributorId,
          limit: _homeLimit,
        ),
      );
    }

    return _records
        .where(
          'distributorId',
          isEqualTo:
              distributorId.trim(),
        )
        .orderBy(
          'recordedAt',
          descending: true,
        )
        .limit(_homeLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                LoadRecord.fromFirestore,
              )
              .toList(
                growable: false,
              ),
        );
  }

  // =========================================================
  // LAST RECORD
  // =========================================================

  Future<DateTime?> getLastRecordTime(
    String distributorId,
  ) async {
    if (_windows) {
      final doc =
          await FirebaseRestService.getDocument(
        collection: 'distributors',
        documentId:
            distributorId.trim(),
      );

      if (doc == null) {
        return null;
      }

      final data =
          FirebaseRestService.documentData(
        doc,
      );

      final value =
          data['lastRecordAt'];

      if (value is String) {
        return DateTime.tryParse(
          value,
        );
      }

      return null;
    }

    final document = await _distributors
        .doc(
          distributorId.trim(),
        )
        .get();

    final data =
        document.data();

    if (data == null) {
      return null;
    }

    final value =
        data['lastRecordAt'];

    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  // =========================================================
  // REMAINING TIME
  // =========================================================

  Future<Duration?>
      remainingUntilNextRecord(
    String distributorId,
  ) async {
    final last =
        await getLastRecordTime(
      distributorId,
    );

    if (last == null) {
      return null;
    }

    final remaining = last
        .add(
          const Duration(hours: 1),
        )
        .difference(
          DateTime.now(),
        );

    if (remaining <=
        Duration.zero) {
      return null;
    }

    return remaining;
  }

  // =========================================================
  // CREATE RECORD
  // =========================================================

  Future<String> createRecord({
    required LoadRecord record,
  }) async {
    final remaining =
        await remainingUntilNextRecord(
      record.distributorId,
    );

    if (remaining != null) {
      throw StateError(
        'لا يمكن تسجيل أحمال جديدة قبل مرور ساعة.',
      );
    }

    if (_windows) {
      final now =
          DateTime.now();

      final id =
          await FirebaseRestService
              .createDocument(
        collection: 'load_records',
        data: {
          'distributorId':
              record.distributorId,
          'distributorName':
              record.distributorName,
          'operatorName':
              record.operatorName,
          'createdByUid':
              record.createdByUid,
          'createdByCode':
              record.createdByCode,
          'totalLoad':
              record.totalLoad,
          'cellValues':
              record.cellValues.map(
            (key, value) => MapEntry(
              key.toString(),
              value,
            ),
          ),
          'cellRunningStates':
              record.cellRunningStates.map(
            (key, value) => MapEntry(
              key.toString(),
              value,
            ),
          ),
          'manualEntryStates':
              record.manualEntryStates.map(
            (key, value) => MapEntry(
              key.toString(),
              value,
            ),
          ),
          'recordedAt':
              now,
          'createdAt':
              now,
        },
      );

      await FirebaseRestService
          .patchDocument(
        collection: 'distributors',
        documentId:
            record.distributorId,
        data: {
          'lastRecordAt':
              now,
          'lastTotalLoad':
              record.totalLoad,
          'updatedAt':
              now,
        },
      );

      return id;
    }

    final document =
        _records.doc();

    await document.set(
      record.toFirestore(),
    );

    await _distributors
        .doc(
          record.distributorId,
        )
        .update(
      {
        'lastRecordAt':
            FieldValue.serverTimestamp(),
        'lastTotalLoad':
            record.totalLoad,
      },
    );

    return document.id;
  }

  // =========================================================
  // SEARCH
  // =========================================================

  Future<List<LoadRecord>> search({
    String? distributorId,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = _searchLimit,
  }) async {
    final normalizedDistributorId =
        distributorId?.trim();

    if (_windows) {
      final documents =
          await FirebaseRestService.runQuery(
        collection: 'load_records',
        distributorId:
            normalizedDistributorId,
        fromDate:
            fromDate,
        toDate:
            toDate,
        limit:
            limit,
      );

      final records =
          documents.map(
        (document) {
          final data =
              FirebaseRestService
                  .documentData(
            document,
          );

          return _fromRest(
            FirebaseRestService
                .documentId(
              document,
            ),
            data,
          );
        },
      ).toList(
        growable: false,
      );

      return records;
    }

    Query<Map<String, dynamic>>
        query = _records;

    if (normalizedDistributorId !=
            null &&
        normalizedDistributorId
            .isNotEmpty) {
      query = query.where(
        'distributorId',
        isEqualTo:
            normalizedDistributorId,
      );
    }

    if (fromDate != null) {
      query = query.where(
        'recordedAt',
        isGreaterThanOrEqualTo:
            Timestamp.fromDate(
          fromDate,
        ),
      );
    }

    if (toDate != null) {
      query = query.where(
        'recordedAt',
        isLessThanOrEqualTo:
            Timestamp.fromDate(
          toDate,
        ),
      );
    }

    query = query.orderBy(
      'recordedAt',
      descending: true,
    );

    final snapshot =
        await query
            .limit(
              limit,
            )
            .get();

    return snapshot.docs
        .map(
          LoadRecord.fromFirestore,
        )
        .toList(
          growable: false,
        );
  }

  // =========================================================
  // SEARCH BY HOUR
  // =========================================================

  Future<List<LoadRecord>> searchHour({
    String? distributorId,
    required DateTime date,
    required int hour,
    int limit = _searchLimit,
  }) async {
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      hour,
    );

    final end =
        start.add(
      const Duration(hours: 1),
    ).subtract(
      const Duration(
        milliseconds: 1,
      ),
    );

    return search(
      distributorId:
          distributorId,
      fromDate:
          start,
      toDate:
          end,
      limit:
          limit,
    );
  }

  // =========================================================
  // REST MODEL
  // =========================================================

  LoadRecord _fromRest(
    String id,
    Map<String, dynamic> data,
  ) {
    final cellValues =
        Map<String, dynamic>.from(
      data['cellValues']
              as Map? ??
          {},
    );

    final states =
        Map<String, dynamic>.from(
      data['cellRunningStates']
              as Map? ??
          {},
    );

    final manual =
        Map<String, dynamic>.from(
      data['manualEntryStates']
              as Map? ??
          {},
    );

    return LoadRecord(
      id: id,
      distributorId:
          (data['distributorId'] ?? '')
              .toString(),
      distributorName:
          (data['distributorName'] ?? '')
              .toString(),
      operatorName:
          (data['operatorName'] ?? '')
              .toString(),
      createdByUid:
          (data['createdByUid'] ?? '')
              .toString(),
      createdByCode:
          (data['createdByCode'] ?? '')
              .toString(),
      recordedAt:
          _parseDate(
                data['recordedAt'],
              ) ??
              DateTime.now(),
      totalLoad:
          _parseDouble(
                data['totalLoad'],
              ) ??
              0,
      cellValues:
          cellValues.map(
        (key, value) => MapEntry(
          int.tryParse(key) ?? 0,
          _parseDouble(value) ?? 0,
        ),
      ),
      cellRunningStates:
          states.map(
        (key, value) => MapEntry(
          int.tryParse(key) ?? 0,
          value == true,
        ),
      ),
      manualEntryStates:
          manual.map(
        (key, value) => MapEntry(
          int.tryParse(key) ?? 0,
          value == true,
        ),
      ),
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================

  static DateTime? _parseDate(
    dynamic value,
  ) {
    if (value is DateTime) {
      return value;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is String) {
      return DateTime.tryParse(
        value,
      )?.toLocal();
    }

    return null;
  }

  static double? _parseDouble(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }
}

extension _LoadStreamStart<T>
    on Stream<T> {
  Stream<T> startWith(
    Future<T> first,
  ) async* {
    yield await first;
    yield* this;
  }
}
