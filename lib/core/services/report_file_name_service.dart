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
        name =
            'A7mal_ElMoz3at_day_${from}_hour_${hour.toString().padLeft(2, '0')}';
      } else if (sameDay) {
        name = 'A7mal_ElMoz3at_$from';
      } else if (hour != null) {
        name =
            'A7mal_ElMoz3at_from_${from}_to_${to}_hour_${hour.toString().padLeft(2, '0')}';
      } else {
        name = 'A7mal_ElMoz3at_from_${from}_to_$to';
      }
    } else {
      final safeDistributor = _toAsciiName(
        (distributorName ?? 'Moz3').trim(),
      );

      if (sameDay) {
        name = 'A7mal_Moz3_${safeDistributor}_day_$from';
      } else {
        name =
            'A7mal_Moz3_${safeDistributor}_from_${from}_to_$to';
      }
    }

    return _sanitize(name);
  }

  static String _date(DateTime value) {
    return DateFormat('dd-MM-yyyy').format(value);
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  static String _toAsciiName(String value) {
    const map = <String, String>{
      'ا': 'a',
      'أ': 'a',
      'إ': 'e',
      'آ': 'a',
      'ب': 'b',
      'ت': 't',
      'ث': 'th',
      'ج': 'g',
      'ح': '7',
      'خ': 'kh',
      'د': 'd',
      'ذ': 'z',
      'ر': 'r',
      'ز': 'z',
      'س': 's',
      'ش': 'sh',
      'ص': 's',
      'ض': 'd',
      'ط': 't',
      'ظ': 'z',
      'ع': '3',
      'غ': 'gh',
      'ف': 'f',
      'ق': 'q',
      'ك': 'k',
      'ل': 'l',
      'م': 'm',
      'ن': 'n',
      'ه': 'h',
      'ة': 'a',
      'و': 'w',
      'ؤ': 'w',
      'ي': 'y',
      'ى': 'a',
      'ئ': 'y',
      'ء': '',
      'ـ': '',
    };

    final buffer = StringBuffer();

    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);

      if (RegExp(r'[A-Za-z0-9]').hasMatch(char)) {
        buffer.write(char);
      } else if (char == ' ' || char == '-' || char == '_') {
        buffer.write('_');
      } else {
        buffer.write(map[char] ?? '');
      }
    }

    final result = buffer
        .toString()
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return result.isEmpty ? 'Moz3' : result;
  }

  static String _sanitize(String value) {
    return value
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .trim();
  }
}
