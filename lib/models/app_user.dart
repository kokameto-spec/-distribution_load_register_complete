import 'user_role.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.code,
    required this.displayName,
    required this.role,
    required this.active,
    this.distributorId,
    this.distributorName,
  });

  final String uid;
  final String code;
  final String displayName;
  final UserRole role;
  final bool active;
  final String? distributorId;
  final String? distributorName;

  factory AppUser.fromMap({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    return AppUser(
      uid: uid,
      code: (data['code'] ?? '').toString(),
      displayName: (data['name'] ?? '').toString(),
      role: _roleFromString((data['role'] ?? '').toString()),
      active: data['active'] == true,
      distributorId: _nullableString(data['distributorId']),
      distributorName: _nullableString(data['distributorName']),
    );
  }

  static UserRole _roleFromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'president':
        return UserRole.president;

      case 'manager':
        return UserRole.manager;

      case 'data_entry':
      case 'dataentry':
        return UserRole.dataEntry;

      default:
        throw FormatException('صلاحية المستخدم غير صحيحة: $value');
    }
  }

  static String? _nullableString(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }

  bool get isPresident => role == UserRole.president;
  bool get isManager => role == UserRole.manager;
  bool get isDataEntry => role == UserRole.dataEntry;
}