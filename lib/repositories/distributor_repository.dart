import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/distributor_model.dart';

class DistributorRepository {
  DistributorRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection {
    return _firestore.collection('distributors');
  }

  Stream<List<Distributor>> watchAll() {
    return _collection.snapshots().map((snapshot) {
      final distributors = snapshot.docs
          .map(Distributor.fromFirestore)
          .toList();

      distributors.sort(
            (first, second) => first.name.compareTo(second.name),
      );

      return distributors;
    });
  }

  Future<List<Distributor>> getAll() async {
    final snapshot = await _collection.get();

    final distributors = snapshot.docs
        .map(Distributor.fromFirestore)
        .toList();

    distributors.sort(
          (first, second) => first.name.compareTo(second.name),
    );

    return distributors;
  }

  Future<Distributor?> getById(String id) async {
    final normalizedId = id.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    final document = await _collection.doc(normalizedId).get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    return Distributor.fromFirestore(document);
  }

  Future<bool> codeExists(
      String code, {
        String? excludingId,
      }) async {
    final normalizedCode = code.trim().toUpperCase();

    if (normalizedCode.isEmpty) {
      return false;
    }

    final snapshot = await _collection
        .where('code', isEqualTo: normalizedCode)
        .limit(2)
        .get();

    for (final document in snapshot.docs) {
      if (excludingId == null || document.id != excludingId) {
        return true;
      }
    }

    return false;
  }

  Future<String> create({
    required String code,
    required String name,
    required String type,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    final normalizedName = name.trim();
    final normalizedType = type.trim();

    if (normalizedCode.isEmpty) {
      throw ArgumentError('كود الموزع مطلوب.');
    }

    if (normalizedName.isEmpty) {
      throw ArgumentError('اسم الموزع مطلوب.');
    }

    if (normalizedType.isEmpty) {
      throw ArgumentError('نوع الموزع مطلوب.');
    }

    if (await codeExists(normalizedCode)) {
      throw StateError('كود الموزع مستخدم بالفعل.');
    }

    final document = _collection.doc();

    await document.set(<String, dynamic>{
      'code': normalizedCode,
      'name': normalizedName,
      'type': normalizedType,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastRecordAt': null,
      'lastTotalLoad': null,
    });

    return document.id;
  }

  Future<void> update({
    required String id,
    required String code,
    required String name,
    required String type,
    required bool active,
  }) async {
    final normalizedId = id.trim();
    final normalizedCode = code.trim().toUpperCase();
    final normalizedName = name.trim();
    final normalizedType = type.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError('معرف الموزع غير صحيح.');
    }

    if (normalizedCode.isEmpty) {
      throw ArgumentError('كود الموزع مطلوب.');
    }

    if (normalizedName.isEmpty) {
      throw ArgumentError('اسم الموزع مطلوب.');
    }

    if (normalizedType.isEmpty) {
      throw ArgumentError('نوع الموزع مطلوب.');
    }

    if (await codeExists(
      normalizedCode,
      excludingId: normalizedId,
    )) {
      throw StateError('كود الموزع مستخدم بالفعل.');
    }

    await _collection.doc(normalizedId).update(<String, dynamic>{
      'code': normalizedCode,
      'name': normalizedName,
      'type': normalizedType,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateLastRecord({
    required String distributorId,
    required double totalLoad,
  }) async {
    final normalizedId = distributorId.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError('معرف الموزع غير صحيح.');
    }

    await _collection.doc(normalizedId).update(<String, dynamic>{
      'lastRecordAt': FieldValue.serverTimestamp(),
      'lastTotalLoad': totalLoad,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) async {
    final normalizedId = id.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError('معرف الموزع غير صحيح.');
    }

    await _collection.doc(normalizedId).delete();
  }
}