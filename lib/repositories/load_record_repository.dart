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
  static const int _searchLimit = 1000;

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

  Stream<List<LoadRecord>> watchAll() {
    if (_windows) {
      return Stream<List<LoadRecord>>.periodic(
        const Duration(seconds: 15),
      ).asyncMap(
        (_) => search(),
      ).startWith(
        search(),
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

  Stream<List<LoadRecord>>
      watchForDistributor(
    String distributorId,
  ) {
    if (_windows) {
      return Stream<List<LoadRecord>>.periodic(
        const Duration(seconds: 15),
      ).asyncMap(
        (_) => search(
          distributorId:
              distributorId,
        ),
      ).startWith(
        search(
          distributorId:
              distributorId,
        ),
      );
    }

    return _records
        .where(
          'distributorId',
          isEqualTo:
              distributorId.trim(),
        )
        .limit(_homeLimit)
        .snapshots()
        .map(
          (snapshot) {
            final records = snapshot.docs
                .map(
                  LoadRecord.fromFirestore,
                )
                .toList();

            records.sort(
              (a, b) => b.recordedAt
                  .compareTo(
                a.recordedAt,
              ),
            );

            return records;
          },
        );
  }

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
              DateTime.now(),
          'createdAt':
              DateTime.now(),
        },
      );

      await FirebaseRestService
          .patchDocument(
        collection: 'distributors',
        documentId:
            record.distributorId,
        data: {
          'lastRecordAt':
              DateTime.now(),
          'lastTotalLoad':
              record.totalLoad,
          'updatedAt':
              DateTime.now(),
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

  Future<List<LoadRecord>> search({
    String? distributorId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (_windows) {
      final docs =
          await FirebaseRestService
              .getCollection(
        collection: 'load_records',
        pageSize: _searchLimit,
      );

      final records =
          docs.map(
        (doc) {
          final data =
              FirebaseRestService
                  .documentData(
            doc,
          );

          return _fromRest(
            FirebaseRestService
                .documentId(
              doc,
            ),
            data,
          );
        },
      ).where(
        (record) {
          if (distributorId != null &&
              distributorId
                  .trim()
                  .isNotEmpty &&
              record.distributorId !=
                  distributorId.trim()) {
            return false;
          }

          if (fromDate != null &&
              record.recordedAt
                  .isBefore(
                fromDate,
              )) {
            return false;
          }

          if (toDate != null &&
              record.recordedAt
                  .isAfter(
                toDate,
              )) {
            return false;
          }

          return true;
        },
      ).toList();

      records.sort(
        (a, b) => b.recordedAt
            .compareTo(
          a.recordedAt,
        ),
      );

      if (records.length >
              _homeLimit &&
          distributorId == null &&
          fromDate == null &&
          toDate == null) {
        return records
            .take(
              _homeLimit,
            )
            .toList();
      }

      return records;
    }

    Query<Map<String, dynamic>>
        query = _records;

    if (distributorId != null &&
        distributorId
            .trim()
            .isNotEmpty) {
      query = query.where(
        'distributorId',
        isEqualTo:
            distributorId.trim(),
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

    final snapshot =
        await query
            .limit(
              _searchLimit,
            )
            .get();

    final records =
        snapshot.docs
            .map(
              LoadRecord.fromFirestore,
            )
            .toList();

    records.sort(
      (a, b) => b.recordedAt
          .compareTo(
        a.recordedAt,
      ),
    );

    return records;
  }

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
          DateTime.tryParse(
                (data['recordedAt'] ?? '')
                    .toString(),
              ) ??
              DateTime.now(),
      totalLoad:
          (data['totalLoad'] as num?)
                  ?.toDouble() ??
              0,
      cellValues:
          cellValues.map(
        (key, value) => MapEntry(
          int.tryParse(key) ?? 0,
          (value as num?)
                  ?.toDouble() ??
              0,
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
