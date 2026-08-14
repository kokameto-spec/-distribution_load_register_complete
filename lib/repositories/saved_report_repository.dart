import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/services/firebase_rest_service.dart';
import '../models/saved_report.dart';

class SavedReportRepository {
  SavedReportRepository({
    FirebaseFirestore? firestore,
  }) : _firestore =
            firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  bool get _windows {
    return !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows;
  }

  CollectionReference<Map<String, dynamic>> get _reports {
    return _firestore.collection('saved_reports');
  }

  Stream<List<SavedReport>> watchAll() {
    if (_windows) {
      return Stream<List<SavedReport>>.periodic(
        const Duration(seconds: 15),
      ).asyncMap(
        (_) => _getAllRest(),
      ).startWith(
        _getAllRest(),
      );
    }

    return _reports
        .orderBy(
          'updatedAt',
          descending: true,
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(SavedReport.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<List<SavedReport>> _getAllRest() async {
    final documents =
        await FirebaseRestService.getCollection(
      collection: 'saved_reports',
    );

    final reports = documents.map((document) {
      final data =
          FirebaseRestService.documentData(
        document,
      );

      return _fromRest(
        FirebaseRestService.documentId(
          document,
        ),
        data,
      );
    }).toList();

    reports.sort(
      (a, b) =>
          b.updatedAt.compareTo(a.updatedAt),
    );

    return reports;
  }

  Future<String> create({
    required String title,
    required String reportType,
    required String targetId,
    required String targetName,
    required DateTime fromDate,
    required DateTime toDate,
    required int hour,
    required String notes,
    required String performedByUid,
    required String performedByCode,
  }) async {
    final normalizedTitle = title.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError(
        'اسم التقرير مطلوب.',
      );
    }

    if (_windows) {
      final now = DateTime.now();

      return FirebaseRestService.createDocument(
        collection: 'saved_reports',
        data: {
          'title': normalizedTitle,
          'reportType': reportType.trim(),
          'targetId': targetId.trim(),
          'targetName': targetName.trim(),
          'fromDate': fromDate,
          'toDate': toDate,
          'hour': hour,
          'notes': notes.trim(),
          'createdByUid': performedByUid,
          'createdByCode': performedByCode,
          'createdAt': now,
          'updatedAt': now,
        },
      );
    }

    final document = _reports.doc();

    await document.set(
      <String, dynamic>{
        'title': normalizedTitle,
        'reportType': reportType.trim(),
        'targetId': targetId.trim(),
        'targetName': targetName.trim(),
        'fromDate': Timestamp.fromDate(
          fromDate,
        ),
        'toDate': Timestamp.fromDate(
          toDate,
        ),
        'hour': hour,
        'notes': notes.trim(),
        'createdByUid': performedByUid,
        'createdByCode': performedByCode,
        'createdAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
    );

    return document.id;
  }

  Future<void> update({
    required SavedReport report,
    required String title,
    required String notes,
    required String performedByUid,
    required String performedByCode,
  }) async {
    final normalizedTitle = title.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError(
        'اسم التقرير مطلوب.',
      );
    }

    if (_windows) {
      await FirebaseRestService.patchDocument(
        collection: 'saved_reports',
        documentId: report.id,
        data: {
          'title': normalizedTitle,
          'notes': notes.trim(),
          'updatedAt': DateTime.now(),
        },
      );

      return;
    }

    await _reports.doc(report.id).update(
      <String, dynamic>{
        'title': normalizedTitle,
        'notes': notes.trim(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> delete({
    required SavedReport report,
    required String performedByUid,
    required String performedByCode,
  }) async {
    if (_windows) {
      await FirebaseRestService.deleteDocument(
        collection: 'saved_reports',
        documentId: report.id,
      );

      return;
    }

    await _reports.doc(report.id).delete();
  }

  Future<SavedReport?> getById(
    String id,
  ) async {
    final reportId = id.trim();

    if (reportId.isEmpty) {
      return null;
    }

    if (_windows) {
      final document =
          await FirebaseRestService.getDocument(
        collection: 'saved_reports',
        documentId: reportId,
      );

      if (document == null) {
        return null;
      }

      return _fromRest(
        reportId,
        FirebaseRestService.documentData(
          document,
        ),
      );
    }

    final document =
        await _reports.doc(reportId).get();

    if (!document.exists) {
      return null;
    }

    return SavedReport.fromFirestore(
      document,
    );
  }

  SavedReport _fromRest(
    String id,
    Map<String, dynamic> data,
  ) {
    return SavedReport(
      id: id,
      title:
          (data['title'] ?? '').toString(),
      reportType:
          (data['reportType'] ?? '').toString(),
      targetId:
          (data['targetId'] ?? '').toString(),
      targetName:
          (data['targetName'] ?? '').toString(),
      fromDate:
          _date(data['fromDate']),
      toDate:
          _date(data['toDate']),
      hour: data['hour'] is num
          ? (data['hour'] as num).toInt()
          : int.tryParse(
                data['hour']?.toString() ?? '',
              ) ??
              -1,
      notes:
          (data['notes'] ?? '').toString(),
      createdByUid:
          (data['createdByUid'] ?? '').toString(),
      createdByCode:
          (data['createdByCode'] ?? '').toString(),
      createdAt:
          _date(data['createdAt']),
      updatedAt:
          _date(data['updatedAt']),
    );
  }

  DateTime _date(dynamic value) {
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

extension _SavedReportStreamStart<T> on Stream<T> {
  Stream<T> startWith(
    Future<T> first,
  ) async* {
    yield await first;
    yield* this;
  }
}
