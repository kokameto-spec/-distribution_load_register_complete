import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/distributor_model.dart';
import '../../models/load_record.dart';

class ReportExcelService {
  ReportExcelService._();

  static const List<int> cellNumbers = <int>[
    0, 1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 15,
  ];

  static Future<Uint8List> buildExcel({
    required List<LoadRecord> records,
    required List<Distributor> distributors,
    String? selectedDistributorId,
    DateTime? selectedDateTime,
    DateTime? fromDate,
    DateTime? toDate,
    bool allDistributorsHourly = false,
  }) async {
    final excel = Excel.createExcel();
    final index = _ReportExcelIndex.build(records);

    if (allDistributorsHourly) {
      final hour = selectedDateTime?.hour ?? 0;
      final start = fromDate ?? selectedDateTime ?? DateTime.now();
      final end = toDate ?? start;

      final activeDistributors = distributors
          .where((item) => item.active)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      var dayIndex = 1;
      for (final day in _daysBetween(start, end)) {
        final sheetName = _safeSheetName(
          '${DateFormat('dd-MM').format(day)}-$dayIndex',
        );

        _buildDaySheet(
          sheet: excel[sheetName],
          day: day,
          hour: hour,
          index: index,
          distributors: activeDistributors,
        );
        dayIndex++;
      }
    } else {
      final distributor = _findDistributor(
        distributors,
        selectedDistributorId,
      );

      _buildSingleDistributorSheet(
        sheet: excel['تفاصيل الموزع'],
        records: records,
        distributor: distributor,
        index: index,
        fromDate: fromDate,
        toDate: toDate,
      );
    }

    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && excel.sheets.length > 1) {
      excel.delete(defaultSheet);
    }

    final bytes = excel.save();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('تعذر إنشاء ملف Excel.');
    }

    return Uint8List.fromList(bytes);
  }

  // توافق مع الشاشات القديمة التي ما زالت تستدعي exportReport.
  static Future<void> exportReport({
    required List<LoadRecord> records,
    required List<Distributor> distributors,
    String? selectedDistributorId,
    DateTime? selectedDateTime,
    DateTime? fromDate,
    DateTime? toDate,
    bool allDistributorsHourly = false,
  }) async {
    await saveReport(
      records: records,
      distributors: distributors,
      fileName: 'احمال الموزعات',
      selectedDistributorId: selectedDistributorId,
      selectedDateTime: selectedDateTime,
      fromDate: fromDate,
      toDate: toDate,
      allDistributorsHourly: allDistributorsHourly,
    );
  }

  static Future<void> saveReport({
    required List<LoadRecord> records,
    required List<Distributor> distributors,
    String? fileName,
    String? selectedDistributorId,
    DateTime? selectedDateTime,
    DateTime? fromDate,
    DateTime? toDate,
    bool allDistributorsHourly = false,
  }) async {
    final bytes = await buildExcel(
      records: records,
      distributors: distributors,
      selectedDistributorId: selectedDistributorId,
      selectedDateTime: selectedDateTime,
      fromDate: fromDate,
      toDate: toDate,
      allDistributorsHourly: allDistributorsHourly,
    );

    await FileSaver.instance.saveAs(
      name: _effectiveFileName(fileName),
      bytes: bytes,
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  static Future<void> shareReport({
    required List<LoadRecord> records,
    required List<Distributor> distributors,
    String? fileName,
    String? selectedDistributorId,
    DateTime? selectedDateTime,
    DateTime? fromDate,
    DateTime? toDate,
    bool allDistributorsHourly = false,
  }) async {
    final bytes = await buildExcel(
      records: records,
      distributors: distributors,
      selectedDistributorId: selectedDistributorId,
      selectedDateTime: selectedDateTime,
      fromDate: fromDate,
      toDate: toDate,
      allDistributorsHourly: allDistributorsHourly,
    );

    await Share.shareXFiles(
      <XFile>[
        XFile.fromData(
          bytes,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      subject: _effectiveFileName(fileName),
      fileNameOverrides: <String>[
        '${_effectiveFileName(fileName)}.xlsx',
      ],
    );
  }

  static void _buildDaySheet({
    required Sheet sheet,
    required DateTime day,
    required int hour,
    required _ReportExcelIndex index,
    required List<Distributor> distributors,
  }) {
    sheet.isRTL = true;

    sheet.appendRow(<CellValue>[
      TextCellValue('أحمال خلايا الموزعات'),
    ]);

    final h = hour.toString().padLeft(2, '0');
    sheet.appendRow(<CellValue>[
      TextCellValue(
        'التاريخ: ${_formatDate(day)} - الفترة: $h:00 - $h:59',
      ),
    ]);

    sheet.appendRow(const <CellValue>[]);

    final headers = <CellValue>[
      TextCellValue('اسم الموزع'),
      TextCellValue('النوع'),
      TextCellValue('الكود'),
      TextCellValue('الحالة'),
      ...cellNumbers.expand(
        (cell) => <CellValue>[
          TextCellValue('خلية $cell - الحمل'),
          TextCellValue('خلية $cell - أقل'),
          TextCellValue('خلية $cell - أقصى'),
        ],
      ),
    ];

    sheet.appendRow(headers);

    for (final distributor in distributors) {
      final current = index.latestRecord(
        distributorId: distributor.id,
        day: day,
        hour: hour,
      );

      final row = <CellValue>[
        TextCellValue(distributor.name),
        TextCellValue(
          distributor.type.trim().isEmpty ? 'غير محدد' : distributor.type,
        ),
        TextCellValue(distributor.code),
        TextCellValue(current == null ? 'لم يسجل' : 'مسجل'),
      ];

      for (final cell in cellNumbers) {
        final range = index.range(
          distributorId: distributor.id,
          cellNumber: cell,
        );

        row.add(
          current == null
              ? TextCellValue('')
              : DoubleCellValue(current.cellValues[cell] ?? 0),
        );
        row.add(
          range.minimum == null
              ? TextCellValue('')
              : DoubleCellValue(range.minimum!),
        );
        row.add(
          range.maximum == null
              ? TextCellValue('')
              : DoubleCellValue(range.maximum!),
        );
      }

      sheet.appendRow(row);
    }

    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3),
      );

      cell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
      );

      sheet.setColumnWidth(i, i < 4 ? 16 : 12);
    }
  }

  static void _buildSingleDistributorSheet({
    required Sheet sheet,
    required List<LoadRecord> records,
    required Distributor? distributor,
    required _ReportExcelIndex index,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    sheet.isRTL = true;

    final sorted = List<LoadRecord>.from(records)
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    sheet.appendRow(<CellValue>[
      TextCellValue('تفاصيل أحمال الموزع'),
    ]);

    sheet.appendRow(<CellValue>[
      TextCellValue(
        distributor?.name ??
            (sorted.isEmpty ? 'الموزع' : sorted.first.distributorName),
      ),
    ]);

    if (fromDate != null && toDate != null) {
      sheet.appendRow(<CellValue>[
        TextCellValue(
          'من ${_formatDate(fromDate)} إلى ${_formatDate(toDate)}',
        ),
      ]);
    }

    if (sorted.isNotEmpty) {
      final maxRecord = sorted.reduce(
        (a, b) => a.totalLoad >= b.totalLoad ? a : b,
      );
      final minRecord = sorted.reduce(
        (a, b) => a.totalLoad <= b.totalLoad ? a : b,
      );

      sheet.appendRow(<CellValue>[
        TextCellValue(
          'أقصى حمل: ${maxRecord.totalLoad.toStringAsFixed(2)} أمبير',
        ),
      ]);
      sheet.appendRow(<CellValue>[
        TextCellValue(
          'أقل حمل: ${minRecord.totalLoad.toStringAsFixed(2)} أمبير',
        ),
      ]);
    }

    sheet.appendRow(const <CellValue>[]);

    final headers = <CellValue>[
      TextCellValue('التاريخ'),
      TextCellValue('الوقت'),
      TextCellValue('مدخل البيانات'),
      TextCellValue('إجمالي الحمل'),
      ...cellNumbers.map((cell) => TextCellValue('خلية $cell')),
    ];

    sheet.appendRow(headers);

    for (final record in sorted) {
      sheet.appendRow(<CellValue>[
        TextCellValue(_formatDate(record.recordedAt)),
        TextCellValue(DateFormat('HH:mm').format(record.recordedAt)),
        TextCellValue(record.operatorName),
        DoubleCellValue(record.totalLoad),
        ...cellNumbers.map(
          (cell) => DoubleCellValue(record.cellValues[cell] ?? 0),
        ),
      ]);
    }

    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, i == 2 ? 22 : 13);
    }
  }

  static List<DateTime> _daysBetween(DateTime from, DateTime to) {
    final result = <DateTime>[];
    var current = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);

    while (!current.isAfter(end)) {
      result.add(current);
      current = current.add(const Duration(days: 1));
    }
    return result;
  }

  static Distributor? _findDistributor(
    List<Distributor> distributors,
    String? id,
  ) {
    if (id == null || id.isEmpty) return null;
    for (final distributor in distributors) {
      if (distributor.id == id) return distributor;
    }
    return null;
  }

  static String _effectiveFileName(String? value) {
    final name = value?.trim() ?? '';
    return name.isEmpty ? 'احمال الموزعات' : name;
  }

  static String _formatDate(DateTime value) {
    return DateFormat('dd-MM-yyyy').format(value);
  }

  static String _safeSheetName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[:\\/?*\[\]]'), '-');
    return cleaned.length <= 31 ? cleaned : cleaned.substring(0, 31);
  }
}

class _ReportExcelIndex {
  _ReportExcelIndex({
    required this.latest,
    required this.ranges,
  });

  final Map<String, LoadRecord> latest;
  final Map<String, _ExcelCellRange> ranges;

  factory _ReportExcelIndex.build(List<LoadRecord> records) {
    final latest = <String, LoadRecord>{};
    final mutable = <String, _MutableExcelCellRange>{};

    for (final record in records) {
      final d = record.recordedAt;
      final latestKey =
          '${record.distributorId}|${d.year}|${d.month}|${d.day}|${d.hour}';

      final old = latest[latestKey];
      if (old == null || record.recordedAt.isAfter(old.recordedAt)) {
        latest[latestKey] = record;
      }

      for (final entry in record.cellValues.entries) {
        final key = '${record.distributorId}|${entry.key}';
        mutable.putIfAbsent(key, _MutableExcelCellRange.new).add(entry.value);
      }
    }

    return _ReportExcelIndex(
      latest: latest,
      ranges: {
        for (final e in mutable.entries)
          e.key: _ExcelCellRange(
            minimum: e.value.minimum,
            maximum: e.value.maximum,
          ),
      },
    );
  }

  LoadRecord? latestRecord({
    required String distributorId,
    required DateTime day,
    required int hour,
  }) {
    return latest[
        '$distributorId|${day.year}|${day.month}|${day.day}|$hour'];
  }

  _ExcelCellRange range({
    required String distributorId,
    required int cellNumber,
  }) {
    return ranges['$distributorId|$cellNumber'] ??
        const _ExcelCellRange();
  }
}

class _MutableExcelCellRange {
  double? minimum;
  double? maximum;

  void add(double value) {
    if (minimum == null || value < minimum!) minimum = value;
    if (maximum == null || value > maximum!) maximum = value;
  }
}

class _ExcelCellRange {
  const _ExcelCellRange({
    this.minimum,
    this.maximum,
  });

  final double? minimum;
  final double? maximum;
}
