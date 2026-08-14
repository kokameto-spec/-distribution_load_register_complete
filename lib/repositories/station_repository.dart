import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/station_model.dart';

class StationRepository {
  StationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _stations =>
      _firestore.collection('stations');

  Stream<List<Station>> watchAll() {
    return _stations.snapshots().map((snapshot) {
      final stations = snapshot.docs.map(Station.fromFirestore).toList();
      stations.sort((a, b) => a.name.compareTo(b.name));
      return stations;
    });
  }

  Future<String> create({
    required String name,
    required List<StationTransformer> transformers,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('اسم المحطة مطلوب.');
    }
    if (transformers.isEmpty) {
      throw ArgumentError('أضف محولًا واحدًا على الأقل للمحطة.');
    }
    if (transformers.any((item) => item.inputLinks.isEmpty)) {
      throw ArgumentError('كل محول يجب أن يحتوي على خلية دخول واحدة على الأقل.');
    }

    final document = _stations.doc();
    await document.set(<String, dynamic>{
      'name': normalizedName,
      'active': true,
      'transformers': transformers.map((item) => item.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _firestore.waitForPendingWrites();

    final saved = await document.get(
      const GetOptions(source: Source.server),
    );
    if (!saved.exists) {
      throw StateError('تعذر التأكد من حفظ المحطة على Firebase.');
    }
    return document.id;
  }

  Future<void> update({
    required String id,
    required String name,
    required bool active,
    required List<StationTransformer> transformers,
  }) async {
    if (id.trim().isEmpty) throw ArgumentError('معرف المحطة غير صحيح.');
    if (name.trim().isEmpty) throw ArgumentError('اسم المحطة مطلوب.');
    if (transformers.isEmpty) {
      throw ArgumentError('أضف محولًا واحدًا على الأقل للمحطة.');
    }
    if (transformers.any((item) => item.inputLinks.isEmpty)) {
      throw ArgumentError('كل محول يجب أن يحتوي على خلية دخول واحدة على الأقل.');
    }

    final document = _stations.doc(id.trim());
    await document.update(<String, dynamic>{
      'name': name.trim(),
      'active': active,
      'transformers': transformers.map((item) => item.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _firestore.waitForPendingWrites();

    final saved = await document.get(
      const GetOptions(source: Source.server),
    );
    if (!saved.exists) {
      throw StateError('تعذر التأكد من تعديل المحطة على Firebase.');
    }
  }

  Future<void> delete(String id) async {
    if (id.trim().isEmpty) throw ArgumentError('معرف المحطة غير صحيح.');
    final document = _stations.doc(id.trim());
    await document.delete();
    await _firestore.waitForPendingWrites();
  }
}
