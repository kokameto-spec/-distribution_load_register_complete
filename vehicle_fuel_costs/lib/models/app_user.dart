class AppUser {
  final String username;
  final String displayName;
  final String role;
  final String vehicleCode;
  final bool active;

  const AppUser({
    required this.username,
    required this.displayName,
    required this.role,
    this.vehicleCode = '',
    this.active = true,
  });

  bool get isManager => role == 'manager';
  bool get isDriver => role == 'driver';

  factory AppUser.fromMap(Map<String, dynamic> map, {String? fallbackUsername}) {
    return AppUser(
      username: (map['username'] ?? fallbackUsername ?? '').toString(),
      displayName: (map['displayName'] ?? '').toString(),
      role: (map['role'] ?? 'driver').toString(),
      vehicleCode: (map['vehicleCode'] ?? '').toString(),
      active: map['active'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
        'username': username,
        'displayName': displayName,
        'role': role,
        'vehicleCode': vehicleCode,
        'active': active,
      };
}
