import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLog {
  const AuditLog({
    required this.id,
    required this.action,
    required this.performedByUid,
    required this.targetUid,
    required this.targetCode,
    required this.createdAt,
    required this.details,
  });

  final String id;
  final String action;
  final String performedByUid;
  final String targetUid;
  final String targetCode;
  final DateTime createdAt;
  final Map<String, dynamic> details;

  factory AuditLog.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'بيانات سجل العملية غير موجودة: ${document.id}',
      );
    }

    return AuditLog(
      id: document.id,
      action: (data['action'] ?? '').toString(),
      performedByUid:
      (data['performedByUid'] ?? '').toString(),
      targetUid: (data['targetUid'] ?? '').toString(),
      targetCode: (data['targetCode'] ?? '').toString(),
      createdAt:
      _dateTimeFromValue(data['createdAt']) ??
          DateTime.now(),
      details: Map<String, dynamic>.from(
        data['details'] as Map? ??
            <String, dynamic>{},
      ),
    );
  }

  String get actionName {
    switch (action) {
      case 'create_user':
        return 'إنشاء مستخدم';

      case 'update_user':
        return 'تعديل مستخدم';

      case 'change_user_password':
        return 'تغيير كلمة المرور';

      case 'activate_user':
        return 'تفعيل مستخدم';

      case 'deactivate_user':
        return 'إيقاف مستخدم';

      case 'delete_user':
        return 'حذف مستخدم';

      default:
        return 'عملية غير معروفة';
    }
  }

  static DateTime? _dateTimeFromValue(
      dynamic value,
      ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}