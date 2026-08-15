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

  // =========================================================
  // FIRESTORE
  // =========================================================

  factory AuditLog.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>>
        document,
  ) {
    final data =
        document.data();

    if (data == null) {
      throw StateError(
        'بيانات سجل العملية غير موجودة: '
        '${document.id}',
      );
    }

    return AuditLog(
      id:
          document.id,

      action:
          (data['action'] ?? '')
              .toString(),

      performedByUid:
          (data['performedByUid'] ?? '')
              .toString(),

      targetUid:
          (data['targetUid'] ?? '')
              .toString(),

      targetCode:
          (data['targetCode'] ?? '')
              .toString(),

      createdAt:
          _dateTimeFromValue(
                data['createdAt'],
              ) ??
              DateTime.now(),

      details:
          Map<String, dynamic>.from(
        data['details']
                as Map? ??
            <String, dynamic>{},
      ),
    );
  }

  // =========================================================
  // ACTION NAME
  // =========================================================

  String get actionName {
    switch (action) {
      // USERS

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

      // REPORTS

      case 'save_report':
        return 'حفظ تقرير';

      case 'update_report':
        return 'تعديل تقرير';

      case 'delete_report':
        return 'حذف تقرير';

      case 'print_report':
        return 'طباعة تقرير';

      case 'share_report':
        return 'مشاركة تقرير';

      case 'export_excel':
        return 'تصدير Excel';

      // DISTRIBUTORS

      case 'create_distributor':
        return 'إنشاء موزع';

      case 'update_distributor':
        return 'تعديل موزع';

      case 'delete_distributor':
        return 'حذف موزع';

      case 'activate_distributor':
        return 'تفعيل موزع';

      case 'deactivate_distributor':
        return 'إيقاف موزع';

      // STATIONS

      case 'create_station':
        return 'إنشاء محطة';

      case 'update_station':
        return 'تعديل محطة';

      case 'delete_station':
        return 'حذف محطة';

      // LOADS

      case 'create_load_record':
      case 'save_load_record':
        return 'تسجيل أحمال';

      case 'update_load_record':
        return 'تعديل سجل أحمال';

      case 'delete_load_record':
        return 'حذف سجل أحمال';

      // LOGIN

      case 'login':
        return 'تسجيل دخول';

      case 'logout':
        return 'تسجيل خروج';

      default:
        final trimmed =
            action.trim();

        return trimmed.isEmpty
            ? 'عملية غير محددة'
            : trimmed;
    }
  }

  // =========================================================
  // DATE
  // =========================================================

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
      return DateTime.tryParse(
        value,
      )?.toLocal();
    }

    return null;
  }
}
