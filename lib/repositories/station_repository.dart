import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/services/firebase_rest_service.dart';
import '../models/station_model.dart';

class StationRepository {
  StationRepository({
    FirebaseFirestore? firestore,
  }) {
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
      get _stations {
    return _nativeFirestore.collection(
      'stations',
    );
  }

  Stream<List<Station>> watchAll() {
    if (_windows) {
      return Stream<List<Station>>.periodic(
        const Duration(seconds: 15),
      ).asyncMap(
        (_) => _getAllRest(),
      ).startWith(
        _getAllRest(),
      );
    }

    return _stations.snapshots().map(
      (snapshot) {
        final stations =
            snapshot.docs
                .map(
                  Station.fromFirestore,
                )
                .toList();

        stations.sort(
          (a, b) =>
              a.name.compareTo(
            b.name,
          ),
        );

        return stations;
      },
    );
  }

  Future<List<Station>>
      _getAllRest() async {
    final docs =
        await FirebaseRestService
            .getCollection(
      collection: 'stations',
    );

    final stations =
        docs.map(
      (doc) {
        final data =
            FirebaseRestService
                .documentData(
          doc,
        );

        final rawTransformers =
            data['transformers']
                    as List? ??
                const [];

        return Station(
          id: FirebaseRestService
              .documentId(
            doc,
          ),
          name:
              (data['name'] ?? '')
                  .toString(),
          active:
              data['active'] != false,
          createdAt:
              _date(
                data['createdAt'],
              ) ??
              DateTime.now(),
          transformers:
              rawTransformers
                  .whereType<Map>()
                  .map(
                    (item) =>
                        StationTransformer
                            .fromMap(
                      Map<String, dynamic>
                          .from(
                        item,
                      ),
                    ),
                  )
                  .toList(
                    growable: false,
                  ),
        );
      },
    ).toList();

    stations.sort(
      (a, b) =>
          a.name.compareTo(
        b.name,
      ),
    );

    return stations;
  }

  Future<String> create({
    required String name,
    required List<StationTransformer>
        transformers,
  }) async {
    final normalizedName =
        name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError(
        'اسم المحطة مطلوب.',
      );
    }

    if (transformers.isEmpty) {
      throw ArgumentError(
        'أضف محولًا واحدًا على الأقل للمحطة.',
      );
    }

    if (transformers.any(
      (item) =>
          item.inputLinks.isEmpty,
    )) {
      throw ArgumentError(
        'كل محول يجب أن يحتوي على خلية دخول واحدة على الأقل.',
      );
    }

    if (_windows) {
      return FirebaseRestService
          .createDocument(
        collection: 'stations',
        data: {
          'name':
              normalizedName,
          'active':
              true,
          'transformers':
              transformers
                  .map(
                    (e) => e.toMap(),
                  )
                  .toList(),
          'createdAt':
              DateTime.now(),
          'updatedAt':
              DateTime.now(),
        },
      );
    }

    final document =
        _stations.doc();

    await document.set(
      {
        'name':
            normalizedName,
        'active':
            true,
        'transformers':
            transformers
                .map(
                  (e) => e.toMap(),
                )
                .toList(),
        'createdAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
    );

    return document.id;
  }

  Future<void> update({
    required String id,
    required String name,
    required bool active,
    required List<StationTransformer>
        transformers,
  }) async {
    if (_windows) {
      await FirebaseRestService
          .patchDocument(
        collection: 'stations',
        documentId:
            id.trim(),
        data: {
          'name':
              name.trim(),
          'active':
              active,
          'transformers':
              transformers
                  .map(
                    (e) => e.toMap(),
                  )
                  .toList(),
          'updatedAt':
              DateTime.now(),
        },
      );

      return;
    }

    await _stations
        .doc(
          id.trim(),
        )
        .update(
      {
        'name':
            name.trim(),
        'active':
            active,
        'transformers':
            transformers
                .map(
                  (e) => e.toMap(),
                )
                .toList(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> delete(
    String id,
  ) async {
    if (_windows) {
      await FirebaseRestService
          .deleteDocument(
        collection: 'stations',
        documentId:
            id.trim(),
      );

      return;
    }

    await _stations
        .doc(
          id.trim(),
        )
        .delete();
  }

  static DateTime? _date(
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
      );
    }

    return null;
  }
}

extension _StationStreamStart<T>
    on Stream<T> {
  Stream<T> startWith(
    Future<T> first,
  ) async* {
    yield await first;
    yield* this;
  }
}
