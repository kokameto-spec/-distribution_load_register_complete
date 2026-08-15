import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';

import '../../models/distributor_model.dart';
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

  // =========================================================
  // EXPORT
  // =========================================================

  static Future<void> exportReport({
    required List<LoadRecord> records,
    required List<Distributor> distributors,
    String? selectedDistributorId,
    DateTime? selectedDateTime,
    DateTime? fromDate,
    DateTime? toDate,
    bool allDistributorsHourly = false,
  }) async {
    final excel = Excel.createExcel();

    final index =
        _ReportExcelIndex.build(
      records,
    );

    if (allDistributorsHourly) {
      final hour =
          selectedDateTime?.hour ?? 0;

      final start =
          fromDate ??
          selectedDateTime ??
          DateTime.now();

      final end =
          toDate ?? start;

      final activeDistributors =
          distributors
              .where(
                (item) => item.active,
              )
              .toList()
            ..sort(
              (a, b) => a.name.compareTo(
                b.name,
              ),
            );

      for (final day
          in _daysBetween(
        start,
        end,
      )) {
        final sheetName =
            DateFormat(
          'MM-dd',
        ).format(day);

        _buildDaySheet(
          sheet:
              excel[sheetName],
          day:
              day,
          hour:
              hour,
          index:
              index,
          distributors:
              activeDistributors,
        );
      }
    } else {
      final distributor =
          _findDistributor(
        distributors,
        selectedDistributorId,
      );

      _buildSingleDistributorSheet(
        sheet:
            excel['تفاصيل الموزع'],
        records:
            records,
        distributor:
            distributor,
        index:
            index,
        fromDate:
            fromDate,
        toDate:
            toDate,
      );
    }

    final defaultSheetName =
        excel.getDefaultSheet();

    if (defaultSheetName != null &&
        excel.sheets.length > 1) {
      excel.delete(
        defaultSheetName,
      );
    }

    final bytes =
        excel.save();

    if (bytes == null ||
        bytes.isEmpty) {
      throw StateError(
        'تعذر إنشاء ملف Excel.',
      );
    }

    await FileSaver.instance.saveFile(
      name:
          'distribution_load_report_'
          '${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}',
      bytes:
          Uint8List.fromList(
        bytes,
      ),
      fileExtension:
          'xlsx',
      mimeType:
          MimeType.microsoftExcel,
    );
  }

  // =========================================================
  // ALL DISTRIBUTORS DAY SHEET
  // =========================================================

  static void _buildDaySheet({
    required Sheet sheet,
    required DateTime day,
    required int hour,
    required _ReportExcelIndex index,
    required List<Distributor>
        distributors,
  }) {
    sheet.isRTL = true;

    sheet.appendRow(
      <CellValue>[
        TextCellValue(
          'أحمال خلايا الموزعات',
        ),
      ],
    );

    sheet.appendRow(
      <CellValue>[
        TextCellValue(
          'اليوم: ${_dayName(day)} - '
          'التاريخ: ${_formatDate(day)} - '
          'الفترة: ${_formatHourRange(hour)}',
        ),
      ],
    );

    sheet.appendRow(
      const <CellValue>[],
    );

    final headers =
        <CellValue>[
      TextCellValue(
        'اسم الموزع',
      ),
      TextCellValue(
        'نوع الموزع',
      ),
      TextCellValue(
        'كود الموزع',
      ),
      TextCellValue(
        'الحالة',
      ),

      ...cellNumbers.expand(
        (cell) => <CellValue>[
          TextCellValue(
            'خلية $cell - الحمل',
          ),
          TextCellValue(
            'خلية $cell - أقل',
          ),
          TextCellValue(
            'خلية $cell - أقصى',
          ),
        ],
      ),
    ];

    sheet.appendRow(
      headers,
    );

    for (final distributor
        in distributors) {
      final currentRecord =
          index.latestRecord(
        distributorId:
            distributor.id,
        day:
            day,
        hour:
            hour,
      );

      final row =
          <CellValue>[
        TextCellValue(
          distributor.name,
        ),
        TextCellValue(
          _distributorType(
            distributor,
          ),
        ),
        TextCellValue(
          distributor.code,
        ),
        TextCellValue(
          currentRecord == null
              ? 'لم يسجل'
              : 'مسجل',
        ),
      ];

      for (final cell
          in cellNumbers) {
        final range =
            index.range(
          distributorId:
              distributor.id,
          cellNumber:
              cell,
        );

        row.add(
          currentRecord == null
              ? TextCellValue('')
              : DoubleCellValue(
                  currentRecord
                          .cellValues[cell] ??
                      0,
                ),
        );

        row.add(
          range.minimum == null
              ? TextCellValue('')
              : DoubleCellValue(
                  range.minimum!,
                ),
        );

        row.add(
          range.maximum == null
              ? TextCellValue('')
              : DoubleCellValue(
                  range.maximum!,
                ),
        );
      }

      sheet.appendRow(
        row,
      );
    }

    for (var index = 0;
        index < headers.length;
        index++) {
      final cell =
          sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex:
              index,
          rowIndex:
              3,
        ),
      );

      cell.cellStyle =
          CellStyle(
        bold:
            true,
        horizontalAlign:
            HorizontalAlign.Center,
        verticalAlign:
            VerticalAlign.Center,
        textWrapping:
            TextWrapping.WrapText,
      );

      sheet.setColumnWidth(
        index,
        index < 4
            ? 16
            : 12,
      );
    }
  }

  // =========================================================
  // SINGLE DISTRIBUTOR SHEET
  // =========================================================

  static void _buildSingleDistributorSheet({
    required Sheet sheet,
    required List<LoadRecord> records,
    required Distributor? distributor,
    required _ReportExcelIndex index,
    required DateTime? fromDate,
    required DateTime? toDate,
  }) {
    sheet.isRTL = true;

    final sorted =
        List<LoadRecord>.from(
      records,
    )
          ..sort(
            (a, b) =>
                b.recordedAt.compareTo(
              a.recordedAt,
            ),
          );

    sheet.appendRow(
      <CellValue>[
        TextCellValue(
          'تفاصيل أحمال الموزع',
        ),
      ],
    );

    sheet.appendRow(
      <CellValue>[
        TextCellValue(
          '${distributor?.name ?? (sorted.isEmpty ? '' : sorted.first.distributorName)}'
          ' - النوع: ${_distributorType(distributor)}',
        ),
      ],
    );

    if (fromDate != null &&
        toDate != null) {
      sheet.appendRow(
        <CellValue>[
          TextCellValue(
            'من ${_formatDate(fromDate)} '
            'إلى ${_formatDate(toDate)}',
          ),
        ],
      );
    }

    if (sorted.isNotEmpty) {
      final maximum =
          _maximumRecord(
        sorted,
      )!;

      final minimum =
          _minimumRecord(
        sorted,
      )!;

      sheet.appendRow(
        <CellValue>[
          TextCellValue(
            'أقصى حمل للموزع: '
            '${maximum.totalLoad.toStringAsFixed(2)} أمبير'
            ' - ${_formatDateTime(maximum.recordedAt)}',
          ),
        ],
      );

      sheet.appendRow(
        <CellValue>[
          TextCellValue(
            'أقل حمل للموزع: '
            '${minimum.totalLoad.toStringAsFixed(2)} أمبير'
            ' - ${_formatDateTime(minimum.recordedAt)}',
          ),
        ],
      );

      sheet.appendRow(
        const <CellValue>[],
      );

      sheet.appendRow(
        <CellValue>[
          TextCellValue(
            'الخلية',
          ),
          TextCellValue(
            'أقل حمل',
          ),
          TextCellValue(
            'أقصى حمل',
          ),
        ],
      );

      final distributorId =
          distributor?.id ??
          sorted.first.distributorId;

      for (final cell
          in cellNumbers) {
        final range =
            index.range(
          distributorId:
              distributorId,
          cellNumber:
              cell,
        );

        sheet.appendRow(
          <CellValue>[
            IntCellValue(
              cell,
            ),
            range.minimum == null
                ? TextCellValue('')
                : DoubleCellValue(
                    range.minimum!,
                  ),
            range.maximum == null
                ? TextCellValue('')
                : DoubleCellValue(
                    range.maximum!,
                  ),
          ],
        );
      }

      sheet.appendRow(
        const <CellValue>[],
      );
    } else {
      sheet.appendRow(
        const <CellValue>[],
      );
    }

    final headers =
        <CellValue>[
      TextCellValue(
        'التاريخ',
      ),
      TextCellValue(
        'الوقت',
      ),
      TextCellValue(
        'مدخل البيانات',
      ),
      TextCellValue(
        'إجمالي الحمل',
      ),

      ...cellNumbers.map(
        (cell) => TextCellValue(
          'خلية $cell',
        ),
      ),
    ];

    sheet.appendRow(
      headers,
    );

    for (final record
        in sorted) {
      final row =
          <CellValue>[
        TextCellValue(
          _formatDate(
            record.recordedAt,
          ),
        ),
        TextCellValue(
          DateFormat(
            'HH:mm',
          ).format(
            record.recordedAt,
          ),
        ),
        TextCellValue(
          record.operatorName,
        ),
        DoubleCellValue(
          record.totalLoad,
        ),
      ];

      for (final cell
          in cellNumbers) {
        row.add(
          DoubleCellValue(
            record.cellValues[
                    cell] ??
                0,
          ),
        );
      }

      sheet.appendRow(
        row,
      );
    }

    final headerRowIndex =
        sheet.maxRows -
        sorted.length -
        1;

    for (var index = 0;
        index < headers.length;
        index++) {
      final cell =
          sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex:
              index,
          rowIndex:
              headerRowIndex,
        ),
      );

      cell.cellStyle =
          CellStyle(
        bold:
            true,
        horizontalAlign:
            HorizontalAlign.Center,
        verticalAlign:
            VerticalAlign.Center,
        textWrapping:
            TextWrapping.WrapText,
      );

      sheet.setColumnWidth(
        index,
        index == 2
            ? 22
            : 13,
      );
    }
  }

  // =========================================================
  // MAX RECORD
  // =========================================================

  static LoadRecord? _maximumRecord(
    List<LoadRecord> records,
  ) {
    if (records.isEmpty) {
      return null;
    }

    var result =
        records.first;

    for (final record
        in records.skip(1)) {
      if (record.totalLoad >
          result.totalLoad) {
        result = record;
      }
    }

    return result;
  }

  // =========================================================
  // MIN RECORD
  // =========================================================

  static LoadRecord? _minimumRecord(
    List<LoadRecord> records,
  ) {
    if (records.isEmpty) {
      return null;
    }

    var result =
        records.first;

    for (final record
        in records.skip(1)) {
      if (record.totalLoad <
          result.totalLoad) {
        result = record;
      }
    }

    return result;
  }

  // =========================================================
  // DAYS
  // =========================================================

  static List<DateTime> _daysBetween(
    DateTime from,
    DateTime to,
  ) {
    final result =
        <DateTime>[];

    var current =
        DateTime(
      from.year,
      from.month,
      from.day,
    );

    final end =
        DateTime(
      to.year,
      to.month,
      to.day,
    );

    while (!current.isAfter(
      end,
    )) {
      result.add(
        current,
      );

      current =
          current.add(
        const Duration(
          days: 1,
        ),
      );
    }

    return result;
  }

  // =========================================================
  // DISTRIBUTOR
  // =========================================================

  static Distributor? _findDistributor(
    List<Distributor> distributors,
    String? id,
  ) {
    if (id == null ||
        id.trim().isEmpty) {
      return null;
    }

    for (final distributor
        in distributors) {
      if (distributor.id == id) {
        return distributor;
      }
    }

    return null;
  }

  static String _distributorType(
    Distributor? distributor,
  ) {
    final type =
        distributor?.type.trim() ??
            '';

    return type.isEmpty
        ? 'غير محدد'
        : type;
  }

  // =========================================================
  // FORMAT
  // =========================================================

  static String _formatDate(
    DateTime value,
  ) {
    return DateFormat(
      'yyyy/MM/dd',
    ).format(
      value,
    );
  }

  static String _formatDateTime(
    DateTime value,
  ) {
    return DateFormat(
      'yyyy/MM/dd - HH:mm',
    ).format(
      value,
    );
  }

  static String _formatHourRange(
    int hour,
  ) {
    final value =
        hour
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$value:00 - $value:59';
  }

  static String _dayName(
    DateTime value,
  ) {
    const names =
        <int, String>{
      DateTime.monday:
          'الاثنين',
      DateTime.tuesday:
          'الثلاثاء',
      DateTime.wednesday:
          'الأربعاء',
      DateTime.thursday:
          'الخميس',
      DateTime.friday:
          'الجمعة',
      DateTime.saturday:
          'السبت',
      DateTime.sunday:
          'الأحد',
    };

    return names[value.weekday] ??
        '';
  }
}

// ===========================================================
// FAST EXCEL INDEX
// ===========================================================

class _ReportExcelIndex {
  _ReportExcelIndex({
    required this.latest,
    required this.ranges,
  });

  final Map<String, LoadRecord>
      latest;

  final Map<String, _ExcelCellRange>
      ranges;

  factory _ReportExcelIndex.build(
    List<LoadRecord> records,
  ) {
    final latest =
        <String, LoadRecord>{};

    final mutableRanges =
        <String, _MutableExcelCellRange>{};

    /*
     * دورة واحدة على كل records.
     */
    for (final record
        in records) {
      final date =
          record.recordedAt;

      final latestKey =
          '${record.distributorId}|'
          '${date.year}|'
          '${date.month}|'
          '${date.day}|'
          '${date.hour}';

      final old =
          latest[latestKey];

      if (old == null ||
          record.recordedAt.isAfter(
            old.recordedAt,
          )) {
        latest[latestKey] =
            record;
      }

      for (final entry
          in record.cellValues.entries) {
        final rangeKey =
            '${record.distributorId}|'
            '${entry.key}';

        final range =
            mutableRanges.putIfAbsent(
          rangeKey,
          () =>
              _MutableExcelCellRange(),
        );

        range.add(
          entry.value,
        );
      }
    }

    final ranges =
        <String, _ExcelCellRange>{};

    for (final entry
        in mutableRanges.entries) {
      ranges[entry.key] =
          _ExcelCellRange(
        minimum:
            entry.value.minimum,
        maximum:
            entry.value.maximum,
      );
    }

    return _ReportExcelIndex(
      latest:
          latest,
      ranges:
          ranges,
    );
  }

  LoadRecord? latestRecord({
    required String distributorId,
    required DateTime day,
    required int hour,
  }) {
    final key =
        '$distributorId|'
        '${day.year}|'
        '${day.month}|'
        '${day.day}|'
        '$hour';

    return latest[key];
  }

  _ExcelCellRange range({
    required String distributorId,
    required int cellNumber,
  }) {
    return ranges[
            '$distributorId|$cellNumber'] ??
        const _ExcelCellRange(
          minimum:
              null,
          maximum:
              null,
        );
  }
}

class _MutableExcelCellRange {
  double? minimum;
  double? maximum;

  void add(
    double value,
  ) {
    if (minimum == null ||
        value < minimum!) {
      minimum =
          value;
    }

    if (maximum == null ||
        value > maximum!) {
      maximum =
          value;
    }
  }
}

class _ExcelCellRange {
  const _ExcelCellRange({
    required this.minimum,
    required this.maximum,
  });

  final double? minimum;
  final double? maximum;
}
