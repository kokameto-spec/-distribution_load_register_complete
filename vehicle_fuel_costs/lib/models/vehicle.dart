class Vehicle {
  final String code;
  final String number;
  final String fuelType;
  final String model;
  final bool active;

  const Vehicle({
    required this.code,
    required this.number,
    required this.fuelType,
    required this.model,
    this.active = true,
  });

  factory Vehicle.fromMap(Map<String, dynamic> map, {String? fallbackCode}) => Vehicle(
        code: (map['code'] ?? fallbackCode ?? '').toString(),
        number: (map['number'] ?? '').toString(),
        fuelType: (map['fuelType'] ?? '').toString(),
        model: (map['model'] ?? '').toString(),
        active: map['active'] != false,
      );

  Map<String, dynamic> toMap() => {
        'code': code,
        'number': number,
        'fuelType': fuelType,
        'model': model,
        'active': active,
      };
}
