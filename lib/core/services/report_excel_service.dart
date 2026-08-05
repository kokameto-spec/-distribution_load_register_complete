import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';

import '../../models/load_record.dart';

class ReportExcelService {
  ReportExcelService._();

  static const List<int> cellNumbers = <int>[
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
  ];

  static Future<void> exportReport({
    required List<LoadRecord> records,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (records.isEmpty) {
      throw StateError('لا توجد بيانات لتصديرها.');
    }

    final sortedRecords = List<LoadRecord>.from(records)
      ..sort(
        (first, second) =>
            second.recordedAt.compareTo(first.recordedAt),
      );

    final excel = Excel.createExcel();

    final detailsSheet = excel['تفاصيل السجلات'];
    final summarySheet = excel['ملخص الخلايا'];

    final defaultSheetName = excel.getDefaultSheet();

    if (defaultSheetName != null &&
        defaultSheetName != 'تفاصيل السجلات' &&
        defaultSheetName != 'ملخص الخلايا') {
      excel.delete(defaultSheetName);
    }

    _buildDetailsSheet(
      sheet: detailsSheet,
      records: sortedRecords,
      fromDate: fromDate,
      toDate: toDate,
    );

    _buildSummarySheet(
      sheet: summarySheet,
      records: sortedRecords,
      fromDate: fromDate,
      toDate: toDate,
    );

    final bytes = excel.save();

    if (bytes == null || bytes.isEmpty) {
      throw StateError('تعذر إنشاء ملف Excel.');
    }

    await FileSaver.instance.saveFile(
      name: _createFileNameWithoutExtension(),
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  static void _buildDetailsSheet({
    required Sheet sheet,
    required List<LoadRecord> records,
    required DateTime? fromDate,
    required DateTime? toDate,
  }) {
    sheet.isRTL = true;

    sheet.appendRow(
      <CellValue>[
        TextCellValue('تقرير أحمال الموزعات'),
      ],
    );

    sheet.appendRow(
      <CellValue>[
        TextCellValue(_periodText(fromDate, toDate)),
      ],
    );

    sheet.appendRow(const <CellValue>[]);

    final headers = <CellValue>[
      TextCellValue('اسم الموزع'),
      TextCellValue('التاريخ'),
      TextCellValue('الوقت'),
      TextCellValue('اسم مدخل البيانات'),
      TextCellValue('كود المستخدم'),
      TextCellValue('إجمالي الحمل'),
      ...cellNumbers.map(
        (cellNumber) => TextCellValue('خلية $cellNumber'),
      ),
    ];

    sheet.appendRow(headers);

    for (final record in records) {
      sheet.appendRow(
        <CellValue>[
          TextCellValue(record.distributorName),
          TextCellValue(_formatDate(record.recordedAt)),
          TextCellValue(_formatTime(record.recordedAt)),
          TextCellValue(record.operatorName),
          TextCellValue(record.createdByCode),
          DoubleCellValue(record.totalLoad),
          ...cellNumbers.map(
            (cellNumber) => DoubleCellValue(
              record.cellValues[cellNumber] ?? 0,
            ),
          ),
        ],
      );
    }

    _applyHeaderStyle(
      sheet: sheet,
      rowIndex: 3,
      columnsCount: headers.length,
    );

    _setDetailsColumnWidths(sheet);
  }

  static void _buildSummarySheet({
    required Sheet sheet,
    required List<LoadRecord> records,
    required DateTime? fromDate,
    required DateTime? toDate,
  }) {
    sheet.isRTL = true;

    sheet.appendRow(
      <CellValue>[
        TextCellValue(
          'ملخص الحمل الحالي وأقل وأقصى حمل لكل خلية',
        ),
      ],
    );

    sheet.appendRow(
      <CellValue>[
        TextCellValue(_periodText(fromDate, toDate)),
      ],
    );

    sheet.appendRow(const <CellValue>[]);

    final headers = <CellValue>[
      TextCellValue('اسم الموزع'),
      TextCellValue('الخلية'),
      TextCellValue('الحمل الحالي'),
      TextCellValue('أقل حمل'),
      TextCellValue('أقصى حمل'),
      TextCellValue('وقت الحمل الحالي'),
      TextCellValue('وقت أقل حمل'),
      TextCellValue('وقت أقصى حمل'),
      TextCellValue('مدخل آخر قراءة'),
    ];

    sheet.appendRow(headers);

    final grouped = _groupByDistributor(records);

    for (final distributorRecords in grouped.values) {
      final latest = distributorRecords.first;
      final statistics = _calculateStatistics(
        distributorRecords,
      );

      for (final cellNumber in cellNumbers) {
        final cell = statistics[cellNumber]!;

        sheet.appendRow(
          <CellValue>[
            TextCellValue(latest.distributorName),
            IntCellValue(cellNumber),
            DoubleCellValue(cell.current ?? 0),
            DoubleCellValue(cell.minimum ?? 0),
            DoubleCellValue(cell.maximum ?? 0),
            TextCellValue(
              _formatDateTime(latest.recordedAt),
            ),
            TextCellValue(
              cell.minimumRecord == null
                  ? ''
                  : _formatDateTime(
                      cell.minimumRecord!.recordedAt,
                    ),
            ),
            TextCellValue(
              cell.maximumRecord == null
                  ? ''
                  : _formatDateTime(
                      cell.maximumRecord!.recordedAt,
                    ),
            ),
            TextCellValue(latest.operatorName),
          ],
        );
      }
    }

    _applyHeaderStyle(
      sheet: sheet,
      rowIndex: 3,
      columnsCount: headers.length,
    );

    _setSummaryColumnWidths(sheet);
  }

  static Map<String, List<LoadRecord>> _groupByDistributor(
    List<LoadRecord> records,
  ) {
    final result = <String, List<LoadRecord>>{};

    for (final record in records) {
      final key = record.distributorId.trim().isNotEmpty
          ? record.distributorId.trim()
          : record.distributorName.trim();

      result.putIfAbsent(
        key,
        () => <LoadRecord>[],
      );

      result[key]!.add(record);
    }

    for (final distributorRecords in result.values) {
      distributorRecords.sort(
        (first, second) =>
            second.recordedAt.compareTo(first.recordedAt),
      );
    }

    return result;
  }

  static Map<int, _ExcelCellStatistics> _calculateStatistics(
    List<LoadRecord> records,
  ) {
    final result = <int, _ExcelCellStatistics>{};
    final latest = records.first;

    for (final cellNumber in cellNumbers) {
      double? minimum;
      double? maximum;

      LoadRecord? minimumRecord;
      LoadRecord? maximumRecord;

      for (final record in records) {
        final value = record.cellValues[cellNumber];

        if (value == null) {
          continue;
        }

        if (minimum == null || value < minimum) {
          minimum = value;
          minimumRecord = record;
        }

        if (maximum == null || value > maximum) {
          maximum = value;
          maximumRecord = record;
        }
      }

      result[cellNumber] = _ExcelCellStatistics(
        current: latest.cellValues[cellNumber],
        minimum: minimum,
        maximum: maximum,
        minimumRecord: minimumRecord,
        maximumRecord: maximumRecord,
      );
    }

    return result;
  }

  static void _applyHeaderStyle({
    required Sheet sheet,
    required int rowIndex,
    required int columnsCount,
  }) {
    for (var columnIndex = 0;
        columnIndex < columnsCount;
        columnIndex++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
      );

      cell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
      );
    }
  }

  static void _setDetailsColumnWidths(Sheet sheet) {
    sheet.setColumnWidth(0, 24);
    sheet.setColumnWidth(1, 13);
    sheet.setColumnWidth(2, 11);
    sheet.setColumnWidth(3, 24);
    sheet.setColumnWidth(4, 14);
    sheet.setColumnWidth(5, 14);

    for (var index = 6;
        index < 6 + cellNumbers.length;
        index++) {
      sheet.setColumnWidth(index, 12);
    }
  }

  static void _setSummaryColumnWidths(Sheet sheet) {
    sheet.setColumnWidth(0, 24);
    sheet.setColumnWidth(1, 10);
    sheet.setColumnWidth(2, 15);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 15);
    sheet.setColumnWidth(5, 20);
    sheet.setColumnWidth(6, 20);
    sheet.setColumnWidth(7, 20);
    sheet.setColumnWidth(8, 24);
  }

  static String _periodText(
    DateTime? fromDate,
    DateTime? toDate,
  ) {
    if (fromDate == null && toDate == null) {
      return 'جميع الفترات المتاحة';
    }

    if (fromDate != null && toDate != null) {
      return 'الفترة من ${_formatDate(fromDate)} '
          'إلى ${_formatDate(toDate)}';
    }

    if (fromDate != null) {
      return 'من تاريخ ${_formatDate(fromDate)}';
    }

    return 'حتى تاريخ ${_formatDate(toDate!)}';
  }

  static String _formatDate(DateTime value) {
    return DateFormat('yyyy-MM-dd').format(value);
  }

  static String _formatTime(DateTime value) {
    return DateFormat('HH:mm').format(value);
  }

  static String _formatDateTime(DateTime value) {
    return DateFormat('yyyy-MM-dd HH:mm').format(value);
  }

  static String _createFileNameWithoutExtension() {
    final timestamp = DateFormat(
      'yyyyMMdd_HHmmss',
    ).format(DateTime.now());

    return 'distribution_load_report_$timestamp';
  }
}

class _ExcelCellStatistics {
  const _ExcelCellStatistics({
    required this.current,
    required this.minimum,
    required this.maximum,
    required this.minimumRecord,
    required this.maximumRecord,
  });

  final double? current;
  final double? minimum;
  final double? maximum;
  final LoadRecord? minimumRecord;
  final LoadRecord? maximumRecord;
}
