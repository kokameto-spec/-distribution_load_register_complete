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

  static const List<int> groupACells = <int>[
    0,
    1,
    2,
    3,
    4,
  ];

  static const List<int> groupBCells = <int>[
    11,
    12,
    13,
    14,
    15,
  ];

  static const List<int> calculatedCells = <int>[
    5,
    6,
    9,
    10,
  ];

  static LoadCalculationResult calculate({
    required Map<int, double?> inputValues,
    required bool cell5Running,
    required bool cell6Running,
    required bool cell9Running,
    required bool cell10Running,
  }) {
    final normalizedValues = _normalizeInputValues(
      inputValues,
    );

    final groupA = _sumCells(
      normalizedValues,
      groupACells,
    );

    final groupB = _sumCells(
      normalizedValues,
      groupBCells,
    );

    final totalInputLoad = groupA + groupB;

    final firstPairRunningCount = _countRunning(
      cell5Running,
      cell6Running,
    );

    final secondPairRunningCount = _countRunning(
      cell9Running,
      cell10Running,
    );

    final totalRunningCount =
        firstPairRunningCount + secondPairRunningCount;

    if (totalRunningCount == 0) {
      return LoadCalculationResult(
        cell5: 0,
        cell6: 0,
        cell9: 0,
        cell10: 0,
        groupA: groupA,
        groupB: groupB,
        totalInputLoad: totalInputLoad,
        isValid: false,
        errorMessage:
        'لا يمكن حفظ البيانات لأن الخلايا 5 و6 و9 و10 كلها مفصولة.',
      );
    }

    /*
     * الحالة الأولى:
     * يوجد على الأقل خلية تشغيل في الزوج 5 و6،
     * ويوجد على الأقل خلية تشغيل في الزوج 9 و10.
     *
     * كل مجموعة توزع على الزوج التابع لها.
     */
    if (firstPairRunningCount > 0 &&
        secondPairRunningCount > 0) {
      final firstPairValues = _distributeOnPair(
        totalLoad: groupA,
        firstRunning: cell5Running,
        secondRunning: cell6Running,
      );

      final secondPairValues = _distributeOnPair(
        totalLoad: groupB,
        firstRunning: cell9Running,
        secondRunning: cell10Running,
      );

      return LoadCalculationResult(
        cell5: firstPairValues.first,
        cell6: firstPairValues.second,
        cell9: secondPairValues.first,
        cell10: secondPairValues.second,
        groupA: groupA,
        groupB: groupB,
        totalInputLoad: totalInputLoad,
        isValid: true,
      );
    }

    /*
     * الحالة الثانية:
     * الخليتان 5 و6 مفصولتان.
     *
     * يتم جمع المجموعتين A وB وتوزيعهما على 9 و10
     * وفق حالة تشغيلهما.
     */
    if (firstPairRunningCount == 0) {
      final secondPairValues = _distributeOnPair(
        totalLoad: totalInputLoad,
        firstRunning: cell9Running,
        secondRunning: cell10Running,
      );

      return LoadCalculationResult(
        cell5: 0,
        cell6: 0,
        cell9: secondPairValues.first,
        cell10: secondPairValues.second,
        groupA: groupA,
        groupB: groupB,
        totalInputLoad: totalInputLoad,
        isValid: true,
      );
    }

    /*
     * الحالة الثالثة:
     * الخليتان 9 و10 مفصولتان.
     *
     * يتم جمع المجموعتين A وB وتوزيعهما على 5 و6
     * وفق حالة تشغيلهما.
     */
    final firstPairValues = _distributeOnPair(
      totalLoad: totalInputLoad,
      firstRunning: cell5Running,
      secondRunning: cell6Running,
    );

    return LoadCalculationResult(
      cell5: firstPairValues.first,
      cell6: firstPairValues.second,
      cell9: 0,
      cell10: 0,
      groupA: groupA,
      groupB: groupB,
      totalInputLoad: totalInputLoad,
      isValid: true,
    );
  }

  static Map<int, double> _normalizeInputValues(
      Map<int, double?> inputValues,
      ) {
    final result = <int, double>{};

    for (final cellNumber in inputCells) {
      final value = inputValues[cellNumber] ?? 0;

      if (!value.isFinite) {
        throw ArgumentError(
          'قيمة الخلية $cellNumber غير صحيحة.',
        );
      }

      if (value < 0) {
        throw ArgumentError(
          'لا يمكن إدخال قيمة سالبة في الخلية $cellNumber.',
        );
      }

      result[cellNumber] = value;
    }

    return result;
  }

  static double _sumCells(
      Map<int, double> values,
      List<int> cells,
      ) {
    double total = 0;

    for (final cellNumber in cells) {
      total += values[cellNumber] ?? 0;
    }

    return total;
  }

  static int _countRunning(
      bool firstRunning,
      bool secondRunning,
      ) {
    int count = 0;

    if (firstRunning) {
      count++;
    }

    if (secondRunning) {
      count++;
    }

    return count;
  }

  static _PairValues _distributeOnPair({
    required double totalLoad,
    required bool firstRunning,
    required bool secondRunning,
  }) {
    if (firstRunning && secondRunning) {
      final dividedLoad = totalLoad / 2;

      return _PairValues(
        first: dividedLoad,
        second: dividedLoad,
      );
    }

    if (firstRunning) {
      return _PairValues(
        first: totalLoad,
        second: 0,
      );
    }

    if (secondRunning) {
      return _PairValues(
        first: 0,
        second: totalLoad,
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