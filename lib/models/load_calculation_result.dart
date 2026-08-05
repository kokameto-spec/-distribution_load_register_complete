class LoadCalculationResult {
  const LoadCalculationResult({
    required this.cell5,
    required this.cell6,
    required this.cell9,
    required this.cell10,
    required this.groupA,
    required this.groupB,
    required this.totalInputLoad,
    required this.isValid,
    this.errorMessage,
  });

  /// ناتج الخلايا 0 إلى 4.
  final double groupA;

  /// ناتج الخلايا 11 إلى 15.
  final double groupB;

  /// إجمالي الأحمال المدخلة.
  final double totalInputLoad;

  /// الأحمال المحسوبة لخلايا الربط.
  final double cell5;
  final double cell6;
  final double cell9;
  final double cell10;

  /// هل حالة التشغيل والفصل تسمح بالحفظ؟
  final bool isValid;

  /// رسالة الخطأ عند عدم صلاحية الحالة.
  final String? errorMessage;

  Map<int, double> get calculatedCells {
    return <int, double>{
      5: cell5,
      6: cell6,
      9: cell9,
      10: cell10,
    };
  }

  double valueForCell(int cellNumber) {
    switch (cellNumber) {
      case 5:
        return cell5;
      case 6:
        return cell6;
      case 9:
        return cell9;
      case 10:
        return cell10;
      default:
        throw ArgumentError(
          'الخلية $cellNumber ليست خلية حسابية.',
        );
    }
  }

  LoadCalculationResult copyWith({
    double? cell5,
    double? cell6,
    double? cell9,
    double? cell10,
    double? groupA,
    double? groupB,
    double? totalInputLoad,
    bool? isValid,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return LoadCalculationResult(
      cell5: cell5 ?? this.cell5,
      cell6: cell6 ?? this.cell6,
      cell9: cell9 ?? this.cell9,
      cell10: cell10 ?? this.cell10,
      groupA: groupA ?? this.groupA,
      groupB: groupB ?? this.groupB,
      totalInputLoad: totalInputLoad ?? this.totalInputLoad,
      isValid: isValid ?? this.isValid,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}