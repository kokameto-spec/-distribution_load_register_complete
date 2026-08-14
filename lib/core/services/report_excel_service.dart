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
    16,
  ];

  static Future<void> exportReport({
    required List<LoadRecord> records,
    required List<Distributor> distributors,
    String? selectedDistributorId,
    DateTime? selectedDateTime,
    DateTime? fromDate,
    DateTime? toDate,
    bool allDistributorsHourly = false,
  }) async {
    final excel =
        Excel.createExcel();

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
              (a, b) =>
                  a.name.compareTo(b.name),
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
          day: day,
          hour: hour,
          records: records,
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
        records: records,
        distributor: distributor,
        fromDate: fromDate,
        toDate: toDate,
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
          Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType:
          MimeType.microsoftExcel,
    );
  }

  static void _buildDaySheet({
    required Sheet sheet,
    required DateTime day,
    required int hour,
    required List<LoadRecord> records,
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

    sheet.appendRow(headers);

    for (final distributor
        in distributors) {
      final currentRecord =
          _latestRecord(
        records: records,
        distributorId:
            distributor.id,
        day: day,
        hour: hour,
      );

      sheet.appendRow(
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
          ...cellNumbers.expand(
            (cell) {
              final range =
                  _cellRange(
                records: records,
                distributorId:
                    distributor.id,
                cellNumber:
                    cell,
              );

              return <CellValue>[
                currentRecord == null
                    ? TextCellValue(
                        '',
                      )
                    : DoubleCellValue(
                        currentRecord
                                .cellValues[
                            cell] ??
                        0,
                      ),
                range.$1 == null
                    ? TextCellValue(
                        '',
                      )
                    : DoubleCellValue(
                        range.$1!,
                      ),
                range.$2 == null
                    ? TextCellValue(
                        '',
                      )
                    : DoubleCellValue(
                        range.$2!,
                      ),
              ];
            },
          ),
        ],
      );
    }

    for (var index = 0;
        index < headers.length;
        index++) {
      final cell =
          sheet.cell(
        CellIndex
            .indexByColumnRow(
          columnIndex: index,
          rowIndex: 3,
        ),
      );

      cell.cellStyle =
          CellStyle(
        bold: true,
        horizontalAlign:
            HorizontalAlign.Center,
        verticalAlign:
            VerticalAlign.Center,
        textWrapping:
            TextWrapping.WrapText,
      );

      sheet.setColumnWidth(
        index,
        index < 4 ? 16 : 12,
      );
    }
  }

  static void
      _buildSingleDistributorSheet({
    required Sheet sheet,
    required List<LoadRecord> records,
    required Distributor?
        distributor,
    required DateTime? fromDate,
    required DateTime? toDate,
  }) {
    sheet.isRTL = true;

    final sorted =
        List<LoadRecord>.from(records)
          ..sort(
            (a, b) => b.recordedAt
                .compareTo(
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
      final maximum = _maximumRecord(sorted)!;
      final minimum = _minimumRecord(sorted)!;

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
          TextCellValue('الخلية'),
          TextCellValue('أقل حمل'),
          TextCellValue('أقصى حمل'),
        ],
      );

      for (final cell in cellNumbers) {
        final range = _cellRange(
          records: sorted,
          distributorId: sorted.first.distributorId,
          cellNumber: cell,
        );

        sheet.appendRow(
          <CellValue>[
            IntCellValue(cell),
            range.$1 == null
                ? TextCellValue('')
                : DoubleCellValue(range.$1!),
            range.$2 == null
                ? TextCellValue('')
                : DoubleCellValue(range.$2!),
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
      TextCellValue('التاريخ'),
      TextCellValue('الوقت'),
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

    sheet.appendRow(headers);

    for (final record
        in sorted) {
      sheet.appendRow(
        <CellValue>[
          TextCellValue(
            _formatDate(
              record.recordedAt,
            ),
          ),
          TextCellValue(
            DateFormat('HH:mm')
                .format(
              record.recordedAt,
            ),
          ),
          TextCellValue(
            record.operatorName,
          ),
          DoubleCellValue(
            record.totalLoad,
          ),
          ...cellNumbers.map<
              CellValue>(
            (cell) =>
                DoubleCellValue(
              record.cellValues[cell] ??
                  0,
            ),
          ),
        ],
      );
    }

    final headerRowIndex =
        sheet.maxRows - sorted.length - 1;

    for (var index = 0;
        index < headers.length;
        index++) {
      final cell =
          sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: index,
          rowIndex: headerRowIndex,
        ),
      );

      cell.cellStyle =
          CellStyle(
        bold: true,
        horizontalAlign:
            HorizontalAlign.Center,
        verticalAlign:
            VerticalAlign.Center,
        textWrapping:
            TextWrapping.WrapText,
      );

      sheet.setColumnWidth(
        index,
        index == 2 ? 22 : 13,
      );
    }
  }

  static LoadRecord? _maximumRecord(
    List<LoadRecord> records,
  ) {
    if (records.isEmpty) {
      return null;
    }

    var result = records.first;

    for (final record in records.skip(1)) {
      if (record.totalLoad > result.totalLoad) {
        result = record;
      }
    }

    return result;
  }

  static LoadRecord? _minimumRecord(
    List<LoadRecord> records,
  ) {
    if (records.isEmpty) {
      return null;
    }

    var result = records.first;

    for (final record in records.skip(1)) {
      if (record.totalLoad < result.totalLoad) {
        result = record;
      }
    }

    return result;
  }

  static String _formatDateTime(
    DateTime value,
  ) {
    return DateFormat(
      'yyyy/MM/dd - HH:mm',
    ).format(value);
  }

  static LoadRecord?
      _latestRecord({
    required List<LoadRecord> records,
    required String distributorId,
    required DateTime day,
    required int hour,
  }) {
    LoadRecord? result;

    for (final record in records) {
      if (record.distributorId !=
              distributorId ||
          record.recordedAt.year !=
              day.year ||
          record.recordedAt.month !=
              day.month ||
          record.recordedAt.day !=
              day.day ||
          record.recordedAt.hour !=
              hour) {
        continue;
      }

      if (result == null ||
          record.recordedAt
              .isAfter(
            result.recordedAt,
          )) {
        result = record;
      }
    }

    return result;
  }

  static (double?, double?)
      _cellRange({
    required List<LoadRecord> records,
    required String distributorId,
    required int cellNumber,
  }) {
    double? minimum;
    double? maximum;

    for (final record in records) {
      if (record.distributorId !=
          distributorId) {
        continue;
      }

      final value =
          record.cellValues[cellNumber];

      if (value == null) {
        continue;
      }

      if (minimum == null ||
          value < minimum) {
        minimum = value;
      }

      if (maximum == null ||
          value > maximum) {
        maximum = value;
      }
    }

    return (
      minimum,
      maximum,
    );
  }

  static List<DateTime> _daysBetween(
    DateTime from,
    DateTime to,
  ) {
    final result =
        <DateTime>[];

    var current = DateTime(
      from.year,
      from.month,
      from.day,
    );

    final end = DateTime(
      to.year,
      to.month,
      to.day,
    );

    while (!current.isAfter(end)) {
      result.add(current);

      current = current.add(
        const Duration(days: 1),
      );
    }

    return result;
  }

  static Distributor?
      _findDistributor(
    List<Distributor> distributors,
    String? id,
  ) {
    if (id == null) {
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
        distributor?.type.trim() ?? '';

    return type.isEmpty
        ? 'غير محدد'
        : type;
  }

  static String _dayName(
    DateTime value,
  ) {
    const names = <int, String>{
      1: 'الاثنين',
      2: 'الثلاثاء',
      3: 'الأربعاء',
      4: 'الخميس',
      5: 'الجمعة',
      6: 'السبت',
      7: 'الأحد',
    };

    return names[value.weekday] ?? '';
  }

  static String _formatDate(
    DateTime value,
  ) {
    return DateFormat(
      'yyyy/MM/dd',
    ).format(value);
  }

  static String _formatHourRange(
    int hour,
  ) {
    final value =
        hour.toString().padLeft(2, '0');

    return 'الساعة $hour '
        '($value:00 - $value:59)';
  }
}
