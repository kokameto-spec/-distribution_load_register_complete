import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/saved_report.dart';

class SavedReportRepository {
  SavedReportRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('saved_reports');

  // =========================================================
  // متابعة التقارير المحفوظة
  // =========================================================

  Stream<List<SavedReport>> watchAll() {
    return _reports
        .orderBy(
          'updatedAt',
          descending: true,
        )
        .snapshots()
        .map(
          (snapshot) {
            return snapshot.docs
                .map(
                  SavedReport.fromFirestore,
                )
                .toList(
                  growable: false,
                );
          },
        );
  }

  // =========================================================
  // إنشاء تقرير محفوظ
  // =========================================================

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
    final normalizedTitle =
        title.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError(
        'اسم التقرير مطلوب.',
      );
    }

    final document =
        _reports.doc();

    await document.set(
      <String, dynamic>{
        'title': normalizedTitle,

        'reportType':
            reportType.trim(),

        'targetId':
            targetId.trim(),

        'targetName':
            targetName.trim(),

        'fromDate':
            Timestamp.fromDate(
          fromDate,
        ),

        'toDate':
            Timestamp.fromDate(
          toDate,
        ),

        'hour': hour,

        'notes':
            notes.trim(),

        'createdByUid':
            performedByUid,

        'createdByCode':
            performedByCode,

        'createdAt':
            FieldValue.serverTimestamp(),

        'updatedAt':
            FieldValue.serverTimestamp(),
      },
    );

    // التأكد من إرسال البيانات إلى Firebase
    await _firestore
        .waitForPendingWrites();

    // التأكد أن التقرير موجود على السيرفر
    final savedDocument =
        await document.get(
      const GetOptions(
        source: Source.server,
      ),
    );

    if (!savedDocument.exists) {
      throw StateError(
        'تم إرسال التقرير ولكن لم يتم العثور عليه على Firebase.',
      );
    }

    return document.id;
  }

  // =========================================================
  // تعديل تقرير محفوظ
  // =========================================================

  Future<void> update({
    required SavedReport report,
    required String title,
    required String notes,
    required String performedByUid,
    required String performedByCode,
  }) async {
    final normalizedTitle =
        title.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError(
        'اسم التقرير مطلوب.',
      );
    }

    final document =
        _reports.doc(
      report.id,
    );

    await document.update(
      <String, dynamic>{
        'title':
            normalizedTitle,

        'notes':
            notes.trim(),

        'updatedAt':
            FieldValue.serverTimestamp(),
      },
    );

    await _firestore
        .waitForPendingWrites();

    final savedDocument =
        await document.get(
      const GetOptions(
        source: Source.server,
      ),
    );

    if (!savedDocument.exists) {
      throw StateError(
        'تعذر التأكد من تعديل التقرير على Firebase.',
      );
    }
  }

  // =========================================================
  // حذف تقرير محفوظ
  // =========================================================

  Future<void> delete({
    required SavedReport report,
    required String performedByUid,
    required String performedByCode,
  }) async {
    final document =
        _reports.doc(
      report.id,
    );

    await document.delete();

    await _firestore
        .waitForPendingWrites();

    final deletedDocument =
        await document.get(
      const GetOptions(
        source: Source.server,
      ),
    );

    if (deletedDocument.exists) {
      throw StateError(
        'تعذر حذف التقرير من Firebase.',
      );
    }
  }

  // =========================================================
  // قراءة تقرير واحد
  // =========================================================

  Future<SavedReport?> getById(
    String id,
  ) async {
    final reportId =
        id.trim();

    if (reportId.isEmpty) {
      return null;
    }

    final document =
        await _reports
            .doc(reportId)
            .get(
      const GetOptions(
        source: Source.server,
      ),
    );

    if (!document.exists) {
      return null;
    }

    return SavedReport
        .fromFirestore(
      document,
    );
  }
}