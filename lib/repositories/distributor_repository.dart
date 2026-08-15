import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/services/firebase_rest_service.dart';
import '../models/distributor_model.dart';

class DistributorRepository {
  DistributorRepository({
    FirebaseFirestore? firestore,
  }) {
    // على Windows لا ننشئ FirebaseFirestore Native نهائيًا.
    // Windows سيستخدم Firebase REST فقط.
    if (!_windows) {
      _firestore =
          firestore ?? FirebaseFirestore.instance;
    }
  }

  FirebaseFirestore? _firestore;

  bool get _windows {
    return !kIsWeb &&
        defaultTargetPlatform ==
            TargetPlatform.windows;
  }

  CollectionReference<Map<String, dynamic>>
      get _collection {
    final firestore = _firestore;

    if (firestore == null) {
      throw StateError(
        'Firestore Native غير مستخدم على Windows.',
      );
    }

    return firestore.collection('distributors');
  }

  // =========================================================
  // WATCH ALL
  // =========================================================

  Stream<List<Distributor>> watchAll() {
    if (_windows) {
      return Stream<List<Distributor>>.periodic(
        const Duration(seconds: 15),
      ).asyncMap(
        (_) => getAll(),
      ).startWith(
        getAll(),
      );
    }

    return _collection.snapshots().map(
      (snapshot) {
        final distributors = snapshot.docs
            .map(
              Distributor.fromFirestore,
            )
            .toList();

        distributors.sort(
          (a, b) => a.name.compareTo(b.name),
        );

        return distributors;
      },
    );
  }

  // =========================================================
  // GET ALL
  // =========================================================

  Future<List<Distributor>> getAll() async {
    if (_windows) {
      final docs =
          await FirebaseRestService.getCollection(
        collection: 'distributors',
      );

      final result = docs.map(
        (doc) {
          final data =
              FirebaseRestService.documentData(
            doc,
          );

          return Distributor(
            id: FirebaseRestService.documentId(
              doc,
            ),
            code:
                (data['code'] ?? '').toString(),
            name:
                (data['name'] ?? '').toString(),
            type:
                (data['type'] ?? '').toString(),
            active:
                data['active'] == true,
            createdAt:
                _date(data['createdAt']) ??
                    DateTime.now(),
            lastRecordAt:
                _date(data['lastRecordAt']),
            lastTotalLoad:
                _double(
              data['lastTotalLoad'],
            ),
          );
        },
      ).toList();

      result.sort(
        (a, b) => a.name.compareTo(b.name),
      );

      return result;
    }

    final snapshot =
        await _collection.get();

    final result = snapshot.docs
        .map(
          Distributor.fromFirestore,
        )
        .toList();

    result.sort(
      (a, b) => a.name.compareTo(b.name),
    );

    return result;
  }

  // =========================================================
  // GET BY ID
  // =========================================================

  Future<Distributor?> getById(
    String id,
  ) async {
    final normalizedId = id.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    if (_windows) {
      final doc =
          await FirebaseRestService.getDocument(
        collection: 'distributors',
        documentId: normalizedId,
      );

      if (doc == null) {
        return null;
      }

      final data =
          FirebaseRestService.documentData(
        doc,
      );

      return Distributor(
        id: normalizedId,
        code:
            (data['code'] ?? '').toString(),
        name:
            (data['name'] ?? '').toString(),
        type:
            (data['type'] ?? '').toString(),
        active:
            data['active'] == true,
        createdAt:
            _date(data['createdAt']) ??
                DateTime.now(),
        lastRecordAt:
            _date(data['lastRecordAt']),
        lastTotalLoad:
            _double(
          data['lastTotalLoad'],
        ),
      );
    }

    final document =
        await _collection
            .doc(normalizedId)
            .get();

    if (!document.exists ||
        document.data() == null) {
      return null;
    }

    return Distributor.fromFirestore(
      document,
    );
  }

  // =========================================================
  // CODE EXISTS
  // =========================================================

  Future<bool> codeExists(
    String code, {
    String? excludingId,
  }) async {
    final normalizedCode =
        code.trim().toUpperCase();

    if (normalizedCode.isEmpty) {
      return false;
    }

    if (_windows) {
      final all = await getAll();

      return all.any(
        (item) {
          return item.code
                      .trim()
                      .toUpperCase() ==
                  normalizedCode &&
              item.id != excludingId;
        },
      );
    }

    final snapshot =
        await _collection
            .where(
              'code',
              isEqualTo:
                  normalizedCode,
            )
            .limit(2)
            .get();

    return snapshot.docs.any(
      (doc) {
        return excludingId == null ||
            doc.id != excludingId;
      },
    );
  }

  // =========================================================
  // CREATE
  // =========================================================

  Future<String> create({
    required String code,
    required String name,
    required String type,
  }) async {
    final normalizedCode =
        code.trim().toUpperCase();

    final normalizedName =
        name.trim();

    final normalizedType =
        type.trim();

    if (normalizedCode.isEmpty) {
      throw ArgumentError(
        'كود الموزع مطلوب.',
      );
    }

    if (normalizedName.isEmpty) {
      throw ArgumentError(
        'اسم الموزع مطلوب.',
      );
    }

    if (normalizedType.isEmpty) {
      throw ArgumentError(
        'نوع الموزع مطلوب.',
      );
    }

    if (await codeExists(
      normalizedCode,
    )) {
      throw StateError(
        'كود الموزع مستخدم بالفعل.',
      );
    }

    if (_windows) {
      return FirebaseRestService.createDocument(
        collection: 'distributors',
        data: {
          'code':
              normalizedCode,
          'name':
              normalizedName,
          'type':
              normalizedType,
          'active':
              true,
          'createdAt':
              DateTime.now(),
          'updatedAt':
              DateTime.now(),
          'lastRecordAt':
              null,
          'lastTotalLoad':
              null,
        },
      );
    }

    final document =
        _collection.doc();

    await document.set(
      {
        'code':
            normalizedCode,
        'name':
            normalizedName,
        'type':
            normalizedType,
        'active':
            true,
        'createdAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
        'lastRecordAt':
            null,
        'lastTotalLoad':
            null,
      },
    );

    return document.id;
  }

  // =========================================================
  // UPDATE
  // =========================================================

  Future<void> update({
    required String id,
    required String code,
    required String name,
    required String type,
    required bool active,
  }) async {
    final normalizedId =
        id.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError(
        'معرف الموزع غير صحيح.',
      );
    }

    final normalizedCode =
        code.trim().toUpperCase();

    final normalizedName =
        name.trim();

    final normalizedType =
        type.trim();

    if (normalizedCode.isEmpty) {
      throw ArgumentError(
        'كود الموزع مطلوب.',
      );
    }

    if (normalizedName.isEmpty) {
      throw ArgumentError(
        'اسم الموزع مطلوب.',
      );
    }

    if (normalizedType.isEmpty) {
      throw ArgumentError(
        'نوع الموزع مطلوب.',
      );
    }

    if (await codeExists(
      normalizedCode,
      excludingId:
          normalizedId,
    )) {
      throw StateError(
        'كود الموزع مستخدم بالفعل.',
      );
    }

    if (_windows) {
      await FirebaseRestService.patchDocument(
        collection: 'distributors',
        documentId:
            normalizedId,
        data: {
          'code':
              normalizedCode,
          'name':
              normalizedName,
          'type':
              normalizedType,
          'active':
              active,
          'updatedAt':
              DateTime.now(),
        },
      );

      return;
    }

    await _collection
        .doc(normalizedId)
        .update(
      {
        'code':
            normalizedCode,
        'name':
            normalizedName,
        'type':
            normalizedType,
        'active':
            active,
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
    );
  }

  // =========================================================
  // UPDATE LAST RECORD
  // =========================================================

  Future<void> updateLastRecord({
    required String distributorId,
    required double totalLoad,
  }) async {
    final id =
        distributorId.trim();

    if (id.isEmpty) {
      return;
    }

    if (_windows) {
      await FirebaseRestService.patchDocument(
        collection: 'distributors',
        documentId: id,
        data: {
          'lastRecordAt':
              DateTime.now(),
          'lastTotalLoad':
              totalLoad,
          'updatedAt':
              DateTime.now(),
        },
      );

      return;
    }

    await _collection
        .doc(id)
        .update(
      {
        'lastRecordAt':
            FieldValue.serverTimestamp(),
        'lastTotalLoad':
            totalLoad,
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
    );
  }

  // =========================================================
  // DELETE
  // =========================================================

  Future<void> delete(
    String id,
  ) async {
    final normalizedId =
        id.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError(
        'معرف الموزع غير صحيح.',
      );
    }

    if (_windows) {
      await FirebaseRestService.deleteDocument(
        collection: 'distributors',
        documentId:
            normalizedId,
      );

      return;
    }

    await _collection
        .doc(normalizedId)
        .delete();
  }

  // =========================================================
  // HELPERS
  // =========================================================

  static DateTime? _date(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is String) {
      return DateTime.tryParse(
        value,
      );
    }

    return null;
  }

  static double? _double(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }
}

// ===========================================================
// STREAM HELPER
// ===========================================================

extension _DistributorStreamStart<T>
    on Stream<T> {
  Stream<T> startWith(
    Future<T> first,
  ) async* {
    yield await first;
    yield* this;
  }
}
