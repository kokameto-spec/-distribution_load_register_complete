import 'package:flutter_test/flutter_test.dart';

import 'package:distribution_load_register_final/core/services/load_calculation_engine.dart';

void main() {
  test('توزيع المجموعة الأولى بالتساوي على 5 و6', () {
    final result = LoadCalculationEngine.calculate(
      inputValues: <int, double?>{
        0: 10,
        1: 10,
        2: 10,
        3: 10,
        4: 10,
        11: 0,
        12: 0,
        13: 0,
        14: 0,
        15: 0,
      },
      cell5Running: true,
      cell6Running: true,
      cell9Running: true,
      cell10Running: true,
    );

    expect(result.cell5, 25);
    expect(result.cell6, 25);
    expect(result.isValid, true);
  });

  test('الخلية الوحيدة العاملة تحصل على إجمالي الحمل', () {
    final result = LoadCalculationEngine.calculate(
      inputValues: <int, double?>{
        0: 10,
        1: 10,
        2: 10,
        3: 10,
        4: 10,
        11: 10,
        12: 10,
        13: 10,
        14: 10,
        15: 10,
      },
      cell5Running: true,
      cell6Running: false,
      cell9Running: false,
      cell10Running: false,
    );

    expect(result.cell5, 100);
    expect(result.cell6, 0);
    expect(result.cell9, 0);
    expect(result.cell10, 0);
  });

  test('فصل الخلايا الأربع يمنع الحفظ', () {
    final result = LoadCalculationEngine.calculate(
      inputValues: const <int, double?>{},
      cell5Running: false,
      cell6Running: false,
      cell9Running: false,
      cell10Running: false,
    );

    expect(result.isValid, false);
    expect(result.errorMessage, isNotNull);
  });
}