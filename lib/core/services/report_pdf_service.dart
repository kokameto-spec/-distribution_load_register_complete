import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/distributor_model.dart';
import '../../models/load_record.dart';

class ReportPdfService {
  ReportPdfService._();

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

  static Future<Uint8List> buildPdf({
    required List<LoadRecord> records,
    required List<Distributor> distributors,
    String? selectedDistributorId,
    DateTime? selectedDateTime,
    DateTime? fromDate,
    DateTime? toDate,
    bool allDistributorsHourly = false,
  }) async {
    final document = pw.Document();

    final regularFont =
        await PdfGoogleFonts.cairoRegular();

    final boldFont =
        await PdfGoogleFonts.cairoBold();

    final logoBytes =
        await _loadLogoBytes();

    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
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
              (a, b) =>
                  a.name.compareTo(b.name),
            );

      for (final day
          in _daysBetween(
        start,
        end,
      )) {
        document.addPage(
          pw.MultiPage(
            pageFormat:
                PdfPageFormat.a4.landscape,
            margin:
                const pw.EdgeInsets.all(
              14,
            ),
            theme: theme,
            header: (_) =>
                _buildHeader(
              logoBytes,
            ),
            footer: (_) =>
                _buildFooter(),
            build: (_) => [
              _buildPeriodRow(
                day: day,
                hour: hour,
              ),
              pw.SizedBox(height: 7),
              ..._buildDistributorTables(
                day: day,
                hour: hour,
                records: records,
                distributors:
                    activeDistributors,
              ),
            ],
          ),
        );
      }
    } else {
      final distributor =
          _findDistributor(
        distributors,
        selectedDistributorId,
      );

      document.addPage(
        pw.MultiPage(
          pageFormat:
              PdfPageFormat.a4.landscape,
          margin:
              const pw.EdgeInsets.all(16),
          theme: theme,
          header: (_) =>
              _buildHeader(
            logoBytes,
          ),
          footer: (_) =>
              _buildFooter(),
          build: (_) =>
              _buildSingleDistributor(
            records: records,
            distributor: distributor,
            fromDate: fromDate,
            toDate: toDate,
          ),
        ),
      );
    }

    return document.save();
  }

  static Future<void> printReport({
    required List<LoadRecord> records,
    required List<Distributor> distributors,
    String? selectedDistributorId,
    DateTime? selectedDateTime,
    DateTime? fromDate,
    DateTime? toDate,
    bool allDistributorsHourly = false,
  }) async {
    final bytes = await buildPdf(
      records: records,
      distributors: distributors,
      selectedDistributorId:
          selectedDistributorId,
      selectedDateTime:
          selectedDateTime,
      fromDate: fromDate,
      toDate: toDate,
      allDistributorsHourly:
          allDistributorsHourly,
    );

    await Printing.layoutPdf(
      name: _createFileName(),
      format:
          PdfPageFormat.a4.landscape,
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> shareReport({
    required List<LoadRecord> records,
    required List<Distributor> distributors,
    String? selectedDistributorId,
    DateTime? selectedDateTime,
    DateTime? fromDate,
    DateTime? toDate,
    bool allDistributorsHourly = false,
  }) async {
    final bytes = await buildPdf(
      records: records,
      distributors: distributors,
      selectedDistributorId:
          selectedDistributorId,
      selectedDateTime:
          selectedDateTime,
      fromDate: fromDate,
      toDate: toDate,
      allDistributorsHourly:
          allDistributorsHourly,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: _createFileName(),
    );
  }

  static Future<Uint8List?>
      _loadLogoBytes() async {
    try {
      final data = await rootBundle.load(
        'assets/images/company_logo.png',
      );

      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _buildHeader(
    Uint8List? logoBytes,
  ) {
    return pw.Directionality(
      textDirection:
          pw.TextDirection.rtl,
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Column(
              crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'شركة جنوب القاهرة لتوزيع الكهرباء',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight:
                        pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'قطاع التحكمات والوقاية',
                  style:
                      const pw.TextStyle(
                    fontSize: 7,
                  ),
                ),
                pw.Text(
                  'تحكم 26 يوليو',
                  style:
                      const pw.TextStyle(
                    fontSize: 7,
                  ),
                ),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              'أحمال خلايا الموزعات',
              textAlign:
                  pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 17,
                fontWeight:
                    pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(
            width: 120,
            child: logoBytes == null
                ? pw.SizedBox()
                : pw.Image(
                    pw.MemoryImage(
                      logoBytes,
                    ),
                    width: 72,
                    height: 48,
                    fit:
                        pw.BoxFit.contain,
                  ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Directionality(
      textDirection:
          pw.TextDirection.rtl,
      child: pw.Padding(
        padding:
            const pw.EdgeInsets.only(
          top: 6,
        ),
        child: pw.Row(
          mainAxisAlignment:
              pw.MainAxisAlignment
                  .spaceBetween,
          children: [
            _signature(
              'اسم مدخل البيانات',
            ),
            _signature('إعداد'),
            _signature(
              'مدير التشغيل',
            ),
            _signature(
              'اعتماد المدير العام',
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _signature(
    String title,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style:
              const pw.TextStyle(
            fontSize: 6.5,
          ),
        ),
        pw.Text(
          '............................',
          style:
              const pw.TextStyle(
            fontSize: 6,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPeriodRow({
    required DateTime day,
    required int hour,
  }) {
    return pw.Directionality(
      textDirection:
          pw.TextDirection.rtl,
      child: pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(
          vertical: 5,
        ),
        child: pw.Row(
          mainAxisAlignment:
              pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'اليوم: ${_dayName(day)}',
              style:
                  _periodTextStyle(),
            ),
            pw.SizedBox(width: 28),
            pw.Text(
              'التاريخ: ${_formatDate(day)}',
              style:
                  _periodTextStyle(),
            ),
            pw.SizedBox(width: 28),
            pw.Text(
              'الفترة: ${_formatHourRange(hour)}',
              style:
                  _periodTextStyle(),
            ),
          ],
        ),
      ),
    );
  }

  static pw.TextStyle
      _periodTextStyle() {
    return pw.TextStyle(
      fontSize: 8,
      fontWeight:
          pw.FontWeight.bold,
    );
  }

  static List<pw.Widget>
      _buildDistributorTables({
    required DateTime day,
    required int hour,
    required List<LoadRecord> records,
    required List<Distributor>
        distributors,
  }) {
    final result = <pw.Widget>[];

    for (var index = 0;
        index < distributors.length;
        index += 6) {
      final end =
          index + 6 <
                  distributors.length
              ? index + 6
              : distributors.length;

      result.add(
        _buildDistributorGrid(
          day: day,
          hour: hour,
          records: records,
          distributors:
              distributors.sublist(
            index,
            end,
          ),
        ),
      );

      result.add(
        pw.SizedBox(height: 8),
      );
    }

    if (distributors.isEmpty) {
      result.add(
        pw.Center(
          child: pw.Text(
            'لا توجد موزعات نشطة.',
          ),
        ),
      );
    }

    return result;
  }

  static pw.Widget
      _buildDistributorGrid({
    required DateTime day,
    required int hour,
    required List<LoadRecord> records,
    required List<Distributor>
        distributors,
  }) {
    final rows = <pw.TableRow>[];

    rows.add(
      pw.TableRow(
        children: [
          _tableHeader('الخلايا'),
          for (final distributor
              in distributors) ...[
            _tableHeader(
              '${distributor.name}\n'
              '${_distributorType(distributor)}',
            ),
            _tableHeader(
              '${distributor.name}\n'
              '${distributor.code}',
            ),
            _tableHeader(
              '${distributor.name}\n'
              '${distributor.code}',
            ),
          ],
        ],
      ),
    );

    rows.add(
      pw.TableRow(
        children: [
          _tableHeader(
            'رقم الخلية',
          ),
          for (final _
              in distributors) ...[
            _tableHeader('الحمل'),
            _tableHeader(
              'أقل حمل',
            ),
            _tableHeader(
              'أقصى حمل',
            ),
          ],
        ],
      ),
    );

    for (final cellNumber
        in cellNumbers) {
      rows.add(
        pw.TableRow(
          children: [
            _tableValue(
              '$cellNumber',
              bold: true,
            ),
            for (final distributor
                in distributors) ...[
              _tableValue(
                _currentCellValue(
                  records: records,
                  distributorId:
                      distributor.id,
                  day: day,
                  hour: hour,
                  cellNumber:
                      cellNumber,
                ),
                red: true,
              ),
              _tableValue(
                _minimumCellValue(
                  records: records,
                  distributorId:
                      distributor.id,
                  cellNumber:
                      cellNumber,
                ),
              ),
              _tableValue(
                _maximumCellValue(
                  records: records,
                  distributorId:
                      distributor.id,
                  cellNumber:
                      cellNumber,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return pw.Directionality(
      textDirection:
          pw.TextDirection.rtl,
      child: pw.Table(
        border:
            pw.TableBorder.all(
          width: .45,
        ),
        columnWidths: {
          0: const pw.FlexColumnWidth(
            1.05,
          ),
          for (var index = 0;
              index <
                  distributors.length * 3;
              index++)
            index + 1:
                const pw.FlexColumnWidth(
              .85,
            ),
        },
        children: rows,
      ),
    );
  }

  static pw.Widget _tableHeader(
    String text,
  ) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(
        vertical: 3,
        horizontal: 1,
      ),
      child: pw.Text(
        text,
        textAlign:
            pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 5.5,
          fontWeight:
              pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _tableValue(
    String text, {
    bool bold = false,
    bool red = false,
  }) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(
        vertical: 2.5,
        horizontal: 1,
      ),
      child: pw.Text(
        text,
        textAlign:
            pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 5.6,
          fontWeight: bold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: red
              ? PdfColors.red700
              : PdfColors.black,
        ),
      ),
    );
  }

  static String _currentCellValue({
    required List<LoadRecord> records,
    required String distributorId,
    required DateTime day,
    required int hour,
    required int cellNumber,
  }) {
    LoadRecord? latest;

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

      if (latest == null ||
          record.recordedAt
              .isAfter(
            latest.recordedAt,
          )) {
        latest = record;
      }
    }

    if (latest == null) {
      return '—';
    }

    return (latest.cellValues[cellNumber] ??
            0)
        .toStringAsFixed(1);
  }

  static String _minimumCellValue({
    required List<LoadRecord> records,
    required String distributorId,
    required int cellNumber,
  }) {
    double? minimum;

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
    }

    return minimum == null
        ? '—'
        : minimum.toStringAsFixed(1);
  }

  static String _maximumCellValue({
    required List<LoadRecord> records,
    required String distributorId,
    required int cellNumber,
  }) {
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

      if (maximum == null ||
          value > maximum) {
        maximum = value;
      }
    }

    return maximum == null
        ? '—'
        : maximum.toStringAsFixed(1);
  }

  static List<pw.Widget>
      _buildSingleDistributor({
    required List<LoadRecord> records,
    required Distributor? distributor,
    required DateTime? fromDate,
    required DateTime? toDate,
  }) {
    final sortedRecords =
        List<LoadRecord>.from(records)
          ..sort(
            (a, b) => b.recordedAt
                .compareTo(
              a.recordedAt,
            ),
          );

    final result = <pw.Widget>[
      pw.Directionality(
        textDirection:
            pw.TextDirection.rtl,
        child: pw.Container(
          padding:
              const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border:
                pw.Border.all(
              width: .6,
            ),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                distributor?.name ??
                    (sortedRecords
                            .isEmpty
                        ? 'الموزع'
                        : sortedRecords
                            .first
                            .distributorName),
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'نوع الموزع: '
                '${_distributorType(distributor)}',
                style:
                    const pw.TextStyle(
                  fontSize: 8,
                ),
              ),
              if (fromDate != null &&
                  toDate != null)
                pw.Text(
                  'من ${_formatDate(fromDate)} '
                  'إلى ${_formatDate(toDate)}',
                  style:
                      const pw.TextStyle(
                    fontSize: 8,
                  ),
                ),
            ],
          ),
        ),
      ),
      pw.SizedBox(height: 8),
    ];

    if (sortedRecords.isEmpty) {
      result.add(
        pw.Center(
          child: pw.Text(
            'لا توجد سجلات مطابقة للبحث.',
          ),
        ),
      );
      return result;
    }

    var maximum =
        sortedRecords.first;
    var minimum =
        sortedRecords.first;

    for (final record
        in sortedRecords) {
      if (record.totalLoad >
          maximum.totalLoad) {
        maximum = record;
      }

      if (record.totalLoad <
          minimum.totalLoad) {
        minimum = record;
      }
    }

    result.add(
      pw.Directionality(
        textDirection:
            pw.TextDirection.rtl,
        child: pw.Table(
          border:
              pw.TableBorder.all(
            width: .5,
          ),
          children: [
            pw.TableRow(
              children: [
                _tableHeader(
                  'أقصى حمل',
                ),
                _tableHeader(
                  '${maximum.totalLoad.toStringAsFixed(2)} A\n'
                  '${_formatDateTime(maximum.recordedAt)}',
                ),
                _tableHeader(
                  'أقل حمل',
                ),
                _tableHeader(
                  '${minimum.totalLoad.toStringAsFixed(2)} A\n'
                  '${_formatDateTime(minimum.recordedAt)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );

    result.add(
      pw.SizedBox(height: 8),
    );

    for (final record
        in sortedRecords) {
      result.add(
        pw.Directionality(
          textDirection:
              pw.TextDirection.rtl,
          child: pw.Column(
            children: [
              pw.Text(
                '${_formatDateTime(record.recordedAt)} — '
                'إجمالي '
                '${record.totalLoad.toStringAsFixed(2)} A',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),
              pw.Table(
                border:
                    pw.TableBorder.all(
                  width: .4,
                ),
                children: [
                  pw.TableRow(
                    children: cellNumbers
                        .map(
                          (cell) =>
                              _tableHeader(
                            'خ $cell',
                          ),
                        )
                        .toList(),
                  ),
                  pw.TableRow(
                    children: cellNumbers
                        .map(
                          (cell) =>
                              _tableValue(
                            (record.cellValues[
                                        cell] ??
                                    0)
                                .toStringAsFixed(
                              1,
                            ),
                            red: true,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              pw.SizedBox(height: 7),
            ],
          ),
        ),
      );
    }

    return result;
  }

  static List<DateTime> _daysBetween(
    DateTime from,
    DateTime to,
  ) {
    final result = <DateTime>[];

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

  static String _formatDateTime(
    DateTime value,
  ) {
    return DateFormat(
      'yyyy/MM/dd HH:mm',
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

  static String _createFileName() {
    return 'distribution_load_report_'
        '${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
  }
}
