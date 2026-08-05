enum UserRole {
  dataEntry,
  manager,
  president,
}

extension UserRoleX on UserRole {
  String get arabicName {
    switch (this) {
      case UserRole.dataEntry:
        return 'مدخل بيانات';
      case UserRole.manager:
        return 'مشغل مدير';
      case UserRole.president:
        return 'الرئيس';
    }
  }
}
