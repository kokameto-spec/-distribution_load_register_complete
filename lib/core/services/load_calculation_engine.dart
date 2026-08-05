import '../../models/load_calculation_result.dart';

class LoadCalculationEngine {
  const LoadCalculationEngine._();

  static const List<int> inputCells = <int>[
    0,
    1,
    2,
    3,
    4,
    11,
    12,
    13,
    14,
    15,
  ];

  static LoadCalculationResult calculate({
    required Map<int, double?> inputValues,
    required bool cell5Running,
    required bool cell6Running,
    required bool cell9Running,
    required bool cell10Running,
  }) {
    final values = <int, double>{};

    for (final cell in inputCells) {
      final value = inputValues[cell] ?? 0;

      if (!value.isFinite || value < 0) {
        throw ArgumentError(
          'قيمة الخلية $cell غير صحيحة.',
        );
      }

      values[cell] = value;
    }

    final groupA =
        (values[0] ?? 0) +
            (values[1] ?? 0) +
            (values[2] ?? 0) +
            (values[3] ?? 0) +
            (values[4] ?? 0);

    final groupB =
        (values[11] ?? 0) +
            (values[12] ?? 0) +
            (values[13] ?? 0) +
            (values[14] ?? 0) +
            (values[15] ?? 0);

    final total = groupA + groupB;

    final firstPairCount =
        (cell5Running ? 1 : 0) +
            (cell6Running ? 1 : 0);

    final secondPairCount =
        (cell9Running ? 1 : 0) +
            (cell10Running ? 1 : 0);

    if (firstPairCount == 0 && secondPairCount == 0) {
      return LoadCalculationResult(
        cell5: 0,
        cell6: 0,
        cell9: 0,
        cell10: 0,
        groupA: groupA,
        groupB: groupB,
        totalInputLoad: total,
        isValid: false,
        errorMessage:
        'لا يمكن الحفظ لأن الخلايا 5 و6 و9 و10 كلها مفصولة.',
      );
    }

    if (firstPairCount == 0) {
      final second = _distribute(
        total,
        cell9Running,
        cell10Running,
      );

      return LoadCalculationResult(
        cell5: 0,
        cell6: 0,
        cell9: second.first,
        cell10: second.second,
        groupA: groupA,
        groupB: groupB,
        totalInputLoad: total,
        isValid: true,
      );
    }

    if (secondPairCount == 0) {
      final first = _distribute(
        total,
        cell5Running,
        cell6Running,
      );

      return LoadCalculationResult(
        cell5: first.first,
        cell6: first.second,
        cell9: 0,
        cell10: 0,
        groupA: groupA,
        groupB: groupB,
        totalInputLoad: total,
        isValid: true,
      );
    }

    final first = _distribute(
      groupA,
      cell5Running,
      cell6Running,
    );

    final second = _distribute(
      groupB,
      cell9Running,
      cell10Running,
    );

    return LoadCalculationResult(
      cell5: first.first,
      cell6: first.second,
      cell9: second.first,
      cell10: second.second,
      groupA: groupA,
      groupB: groupB,
      totalInputLoad: total,
      isValid: true,
    );
  }

  static _PairValues _distribute(
      double load,
      bool firstRunning,
      bool secondRunning,
      ) {
    if (firstRunning && secondRunning) {
      return _PairValues(
        first: load / 2,
        second: load / 2,
      );
    }

    if (firstRunning) {
      return _PairValues(
        first: load,
        second: 0,
      );
    }

    if (secondRunning) {
      return _PairValues(
        first: 0,
        second: load,
      );
    }

    return const _PairValues(
      first: 0,
      second: 0,
    );
  }
}

class _PairValues {
  const _PairValues({
    required this.first,
    required this.second,
  });

  final double first;
  final double second;
}