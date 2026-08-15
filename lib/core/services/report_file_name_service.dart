import 'package:intl/intl.dart';

class ReportFileNameService {
  ReportFileNameService._();

  static String buildBaseName({
    required bool allDistributors,
    required DateTime fromDate,
    required DateTime toDate,
    int? hour,
    String? distributorName,
  }) {
    final from = _date(fromDate);
    final to = _date(toDate);
    final sameDay = _sameDay(fromDate, toDate);

    String name;

    if (allDistributors) {
      if (sameDay && hour != null) {
        name = 'احمال الموزعات يوم $from الساعة ${hour.toString().padLeft(2, '0')}';
      } else if (sameDay) {
        name = 'احمال الموزعات $from';
      } else if (hour != null) {
        name = 'احمال الموزعات من $from الى $to الساعة ${hour.toString().padLeft(2, '0')}';
      } else {
        name = 'احمال الموزعات من $from الى $to';
      }
    } else {
      final distributor = (distributorName ?? 'الموزع').trim();
      if (sameDay) {
        name = 'احمال موزع $distributor يوم $from';
      } else {
        name = 'احمال موزع $distributor من $from الى $to';
      }
    }

    return _sanitize(name);
  }

  static String _date(DateTime value) {
    return DateFormat('dd-MM-yyyy').format(value);
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _sanitize(String value) {
    return value
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
