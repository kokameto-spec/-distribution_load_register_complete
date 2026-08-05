import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/audit_log.dart';

class AuditLogRepository {
  AuditLogRepository({
    FirebaseFirestore? firestore,
  }) : _firestore =
      firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>>
  get _collection {
    return _firestore.collection('audit_logs');
  }

  Stream<List<AuditLog>> watchAll() {
    return _collection.snapshots().map(
          (snapshot) {
        final logs = snapshot.docs
            .map(AuditLog.fromFirestore)
            .toList();

        logs.sort(
              (first, second) =>
              second.createdAt.compareTo(
                first.createdAt,
              ),
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
    final snapshot = await _collection.get();

    final normalizedAction =
        action?.trim() ?? '';

    final normalizedCode =
        targetCode?.trim().toLowerCase() ?? '';

    final logs = snapshot.docs
        .map(AuditLog.fromFirestore)
        .where(
          (log) {
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
      },
    )
        .toList();

    logs.sort(
          (first, second) =>
          second.createdAt.compareTo(
            first.createdAt,
          ),
    );

    return logs;
  }
}