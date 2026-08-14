import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/services/firebase_rest_service.dart';
import '../models/audit_log.dart';

class AuditLogRepository {
  AuditLogRepository({
    FirebaseFirestore? firestore,
  }) : _firestore =
            firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  bool get _windows {
    return !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows;
  }

  CollectionReference<Map<String, dynamic>>
      get _collection {
    return _firestore.collection('audit_logs');
  }

  Stream<List<AuditLog>> watchAll() {
    if (_windows) {
      return Stream<List<AuditLog>>.periodic(
        const Duration(seconds: 15),
      ).asyncMap((_) => search()).startWith(search());
    }

    return _collection.snapshots().map(
      (snapshot) {
        final logs = snapshot.docs
            .map(AuditLog.fromFirestore)
            .toList();

        logs.sort(
          (a, b) =>
              b.createdAt.compareTo(a.createdAt),
        );

        return logs;
      },
    );
  }

  Future<List<AuditLog>> search({
    String? action,
    String? targetCode,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (_windows) {
      final docs =
          await FirebaseRestService.getCollection(
        collection: 'audit_logs',
      );

      final logs = docs.map((doc) {
        final data =
            FirebaseRestService.documentData(doc);

        return AuditLog(
          id: FirebaseRestService.documentId(doc),
          action:
              (data['action'] ?? '').toString(),
          performedByUid:
              (data['performedByUid'] ?? '')
                  .toString(),
          targetUid:
              (data['targetUid'] ?? '').toString(),
          targetCode:
              (data['targetCode'] ?? '').toString(),
          createdAt: DateTime.tryParse(
                (data['createdAt'] ?? '').toString(),
              ) ??
              DateTime.now(),
          details: Map<String, dynamic>.from(
            data['details'] as Map? ?? {},
          ),
        );
      }).toList();

      return _filter(
        logs,
        action: action,
        targetCode: targetCode,
        fromDate: fromDate,
        toDate: toDate,
      );
    }

    final snapshot = await _collection.get();

    return _filter(
      snapshot.docs
          .map(AuditLog.fromFirestore)
          .toList(),
      action: action,
      targetCode: targetCode,
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  List<AuditLog> _filter(
    List<AuditLog> logs, {
    String? action,
    String? targetCode,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    final normalizedAction =
        action?.trim() ?? '';

    final normalizedCode =
        targetCode?.trim().toLowerCase() ?? '';

    final result = logs.where((log) {
      if (normalizedAction.isNotEmpty &&
          log.action != normalizedAction) {
        return false;
      }

      if (normalizedCode.isNotEmpty &&
          !log.targetCode
              .toLowerCase()
              .contains(normalizedCode)) {
        return false;
      }

      if (fromDate != null &&
          log.createdAt.isBefore(fromDate)) {
        return false;
      }

      if (toDate != null &&
          log.createdAt.isAfter(toDate)) {
        return false;
      }

      return true;
    }).toList();

    result.sort(
      (a, b) =>
          b.createdAt.compareTo(a.createdAt),
    );

    return result;
  }
}

extension _AuditStreamStart<T> on Stream<T> {
  Stream<T> startWith(Future<T> first) async* {
    yield await first;
    yield* this;
  }
}
