import 'dart:typed_data';

import 'package:flutter/services.dart'
    show rootBundle;
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
  ];

  // =========================================================
  // BUILD PDF
  // =========================================================

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

    final theme =
        pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    );

    /*
     * نبني Index مرة واحدة فقط.
     * ده يمنع إعادة البحث في records
     * آلاف المرات أثناء إنشاء الـPDF.
     */
    final index =
        _ReportPdfIndex.build(
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
              (a, b) =>
                  a.name.compareTo(
                b.name,
              ),
            );

      final days =
          _daysBetween(
        start,
        end,
      );

      for (final day in days) {
        document.addPage(
          pw.MultiPage(
            pageFormat:
                PdfPageFormat.a4.landscape,
            margin:
                const pw.EdgeInsets.all(
              14,
            ),
            theme:
                theme,
            header:
                (_) => _buildHeader(
              logoBytes,
            ),
            footer:
                (_) => _buildFooter(),
            build:
                (_) => <pw.Widget>[
              _buildPeriodRow(
                day:
                    day,
                hour:
                    hour,
              ),

              pw.SizedBox(
                height: 7,
              ),

              ..._buildDistributorTables(
                day:
                    day,
                hour:
                    hour,
                index:
                    index,
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
              const pw.EdgeInsets.all(
            16,
          ),
          theme:
              theme,
          header:
              (_) => _buildHeader(
            logoBytes,
          ),
          footer:
              (_) => _buildFooter(),
          build:
              (_) =>
                  _buildSingleDistributor(
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
          ),
        ),
      );
    }

    return document.save();
  }

  // =========================================================
  // PRINT
  // =========================================================

  static Future<void> printReport({
    required List<LoadRecord> records,
    required List<Distributor> distributors,
    String? selectedDistributorId,
    DateTime? selectedDateTime,
    DateTime? fromDate,
    DateTime? toDate,
    bool allDistributorsHourly = false,
  }) async {
    final bytes =
        await buildPdf(
      records:
          records,
      distributors:
          distributors,
      selectedDistributorId:
          selectedDistributorId,
      selectedDateTime:
          selectedDateTime,
      fromDate:
          fromDate,
      toDate:
          toDate,
      allDistributorsHourly:
          allDistributorsHourly,
    );

    await Printing.layoutPdf(
      name:
          _createFileName(),
      format:
          PdfPageFormat.a4.landscape,
      onLayout:
          (_) async => bytes,
    );
  }

  // =========================================================
  // SHARE
  // =========================================================

  static Future<void> shareReport({
    required List<LoadRecord> records,
    required List<Distributor> distributors,
    String? selectedDistributorId,
    DateTime? selectedDateTime,
    DateTime? fromDate,
    DateTime? toDate,
    bool allDistributorsHourly = false,
  }) async {
    final bytes =
        await buildPdf(
      records:
          records,
      distributors:
          distributors,
      selectedDistributorId:
          selectedDistributorId,
      selectedDateTime:
          selectedDateTime,
      fromDate:
          fromDate,
      toDate:
          toDate,
      allDistributorsHourly:
          allDistributorsHourly,
    );

    await Printing.sharePdf(
      bytes:
          bytes,
      filename:
          _createFileName(),
    );
  }

  // =========================================================
  // LOGO
  // =========================================================

  static Future<Uint8List?>
      _loadLogoBytes() async {
    try {
      final data =
          await rootBundle.load(
        'assets/images/company_logo.png',
      );

      return data.buffer
          .asUint8List();
    } catch (_) {
      return null;
    }
  }

  // =========================================================
  // HEADER
  // =========================================================

  static pw.Widget _buildHeader(
    Uint8List? logoBytes,
  ) {
    return pw.Directionality(
      textDirection:
          pw.TextDirection.rtl,
      child: pw.Row(
        crossAxisAlignment:
            pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width:
                130,
            child:
                pw.Column(
              crossAxisAlignment:
                  pw.CrossAxisAlignment
                      .start,
              children: [
                pw.Text(
                  'شركة جنوب القاهرة لتوزيع الكهرباء',
                  style:
                      pw.TextStyle(
                    fontSize:
                        8,
                    fontWeight:
                        pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'قطاع التحكمات والوقاية',
                  style:
                      const pw.TextStyle(
                    fontSize:
                        7,
                  ),
                ),
                pw.Text(
                  'تحكم 26 يوليو',
                  style:
                      const pw.TextStyle(
                    fontSize:
                        7,
                  ),
                ),
              ],
            ),
          ),

          pw.Expanded(
            child:
                pw.Text(
              'أحمال خلايا الموزعات',
              textAlign:
                  pw.TextAlign.center,
              style:
                  pw.TextStyle(
                fontSize:
                    17,
                fontWeight:
                    pw.FontWeight.bold,
              ),
            ),
          ),

          pw.SizedBox(
            width:
                130,
            child:
                logoBytes == null
                    ? pw.SizedBox()
                    : pw.Align(
                        alignment:
                            pw.Alignment
                                .centerLeft,
                        child:
                            pw.Image(
                          pw.MemoryImage(
                            logoBytes,
                          ),
                          width:
                              72,
                          height:
                              48,
                          fit:
                              pw.BoxFit
                                  .contain,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // FOOTER
  // =========================================================

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
            _signature(
              'إعداد',
            ),
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
            fontSize:
                6.5,
          ),
        ),
        pw.Text(
          '............................',
          style:
              const pw.TextStyle(
            fontSize:
                6,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // PERIOD
  // =========================================================

  static pw.Widget _buildPeriodRow({
    required DateTime day,
    required int hour,
  }) {
    return pw.Directionality(
      textDirection:
          pw.TextDirection.rtl,
      child: pw.Container(
        padding:
            const pw.EdgeInsets
                .symmetric(
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

            pw.SizedBox(
              width: 28,
            ),

            pw.Text(
              'التاريخ: ${_formatDate(day)}',
              style:
                  _periodTextStyle(),
            ),

            pw.SizedBox(
              width: 28,
            ),

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
      fontSize:
          8,
      fontWeight:
          pw.FontWeight.bold,
    );
  }

  // =========================================================
  // ALL DISTRIBUTORS TABLES
  // =========================================================

  static List<pw.Widget>
      _buildDistributorTables({
    required DateTime day,
    required int hour,
    required _ReportPdfIndex index,
    required List<Distributor>
        distributors,
  }) {
    final result =
        <pw.Widget>[];

    for (var start = 0;
        start < distributors.length;
        start += 6) {
      final end =
          (start + 6) <
                  distributors.length
              ? start + 6
              : distributors.length;

      result.add(
        _buildDistributorGrid(
          day:
              day,
          hour:
              hour,
          index:
              index,
          distributors:
              distributors.sublist(
            start,
            end,
          ),
        ),
      );

      result.add(
        pw.SizedBox(
          height: 8,
        ),
      );
    }

    if (distributors.isEmpty) {
      result.add(
        pw.Center(
          child:
              pw.Text(
            'لا توجد موزعات نشطة.',
          ),
        ),
      );
    }

    return result;
  }

  // =========================================================
  // DISTRIBUTOR GRID
  // =========================================================

  static pw.Widget
      _buildDistributorGrid({
    required DateTime day,
    required int hour,
    required _ReportPdfIndex index,
    required List<Distributor>
        distributors,
  }) {
    final rows =
        <pw.TableRow>[];

    rows.add(
      pw.TableRow(
        children: [
          _tableHeader(
            'الخلايا',
          ),

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
            _tableHeader(
              'الحمل',
            ),
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
              bold:
                  true,
            ),

            for (final distributor
                in distributors) ...[
              _tableValue(
                index.currentValue(
                  distributorId:
                      distributor.id,
                  day:
                      day,
                  hour:
                      hour,
                  cellNumber:
                      cellNumber,
                ),
                red:
                    true,
              ),

              _tableValue(
                index.minimumValue(
                  distributorId:
                      distributor.id,
                  cellNumber:
                      cellNumber,
                ),
              ),

              _tableValue(
                index.maximumValue(
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
          width:
              .45,
        ),
        columnWidths:
            <int, pw.TableColumnWidth>{
          0:
              const pw.FlexColumnWidth(
            1.05,
          ),

          for (var index = 0;
              index <
                  distributors.length *
                      3;
              index++)
            index + 1:
                const pw.FlexColumnWidth(
              .85,
            ),
        },
        children:
            rows,
      ),
    );
  }

  static pw.Widget _tableHeader(
    String text,
  ) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets
              .symmetric(
        vertical: 3,
        horizontal: 1,
      ),
      child: pw.Text(
        text,
        textAlign:
            pw.TextAlign.center,
        style:
            pw.TextStyle(
          fontSize:
              5.5,
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
          const pw.EdgeInsets
              .symmetric(
        vertical: 2.5,
        horizontal: 1,
      ),
      child: pw.Text(
        text,
        textAlign:
            pw.TextAlign.center,
        style:
            pw.TextStyle(
          fontSize:
              5.6,
          fontWeight:
              bold
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
          color:
              red
                  ? PdfColors.red700
                  : PdfColors.black,
        ),
      ),
    );
  }

  // =========================================================
  // SINGLE DISTRIBUTOR
  // =========================================================

  static List<pw.Widget>
      _buildSingleDistributor({
    required List<LoadRecord> records,
    required Distributor? distributor,
    required _ReportPdfIndex index,
    required DateTime? fromDate,
    required DateTime? toDate,
  }) {
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

    final widgets =
        <pw.Widget>[];

    widgets.add(
      pw.Directionality(
        textDirection:
            pw.TextDirection.rtl,
        child: pw.Column(
          crossAxisAlignment:
              pw.CrossAxisAlignment
                  .stretch,
          children: [
            pw.Text(
              distributor?.name ??
                  (sorted.isEmpty
                      ? 'الموزع'
                      : sorted.first
                          .distributorName),
              textAlign:
                  pw.TextAlign.center,
              style:
                  pw.TextStyle(
                fontSize:
                    15,
                fontWeight:
                    pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(
              height: 4,
            ),

            pw.Text(
              'نوع الموزع: '
              '${_distributorType(distributor)}',
              textAlign:
                  pw.TextAlign.center,
              style:
                  const pw.TextStyle(
                fontSize:
                    8,
              ),
            ),

            if (fromDate != null &&
                toDate != null) ...[
              pw.SizedBox(
                height: 4,
              ),
              pw.Text(
                'الفترة: '
                '${_formatDate(fromDate)}'
                ' إلى '
                '${_formatDate(toDate)}',
                textAlign:
                    pw.TextAlign.center,
                style:
                    const pw.TextStyle(
                  fontSize:
                      8,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    widgets.add(
      pw.SizedBox(
        height: 10,
      ),
    );

    if (sorted.isEmpty) {
      widgets.add(
        pw.Center(
          child:
              pw.Text(
            'لا توجد سجلات مطابقة.',
          ),
        ),
      );

      return widgets;
    }

    final maximum =
        _maximumRecord(
      sorted,
    );

    final minimum =
        _minimumRecord(
      sorted,
    );

    widgets.add(
      pw.Directionality(
        textDirection:
            pw.TextDirection.rtl,
        child: pw.Row(
          mainAxisAlignment:
              pw.MainAxisAlignment
                  .spaceEvenly,
          children: [
            pw.Text(
              'أقصى حمل: '
              '${maximum?.totalLoad.toStringAsFixed(2) ?? '—'} أمبير',
              style:
                  pw.TextStyle(
                fontSize:
                    8,
                fontWeight:
                    pw.FontWeight.bold,
              ),
            ),

            pw.Text(
              'أقل حمل: '
              '${minimum?.totalLoad.toStringAsFixed(2) ?? '—'} أمبير',
              style:
                  pw.TextStyle(
                fontSize:
                    8,
                fontWeight:
                    pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    widgets.add(
      pw.SizedBox(
        height: 10,
      ),
    );

    final distributorId =
        distributor?.id ??
        sorted.first.distributorId;

    widgets.add(
      pw.Directionality(
        textDirection:
            pw.TextDirection.rtl,
        child: pw.Table(
          border:
              pw.TableBorder.all(
            width:
                .5,
          ),
          children: [
            pw.TableRow(
              children: [
                _tableHeader(
                  'الخلية',
                ),
                _tableHeader(
                  'أقل حمل',
                ),
                _tableHeader(
                  'أقصى حمل',
                ),
              ],
            ),

            for (final cell
                in cellNumbers)
              pw.TableRow(
                children: [
                  _tableValue(
                    '$cell',
                    bold:
                        true,
                  ),
                  _tableValue(
                    index.minimumValue(
                      distributorId:
                          distributorId,
                      cellNumber:
                          cell,
                    ),
                  ),
                  _tableValue(
                    index.maximumValue(
                      distributorId:
                          distributorId,
                      cellNumber:
                          cell,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );

    widgets.add(
      pw.SizedBox(
        height: 12,
      ),
    );

    widgets.add(
      pw.Text(
        'تفاصيل التسجيلات',
        textAlign:
            pw.TextAlign.center,
        style:
            pw.TextStyle(
          fontSize:
              10,
          fontWeight:
              pw.FontWeight.bold,
        ),
      ),
    );

    widgets.add(
      pw.SizedBox(
        height: 6,
      ),
    );

    widgets.add(
      pw.Directionality(
        textDirection:
            pw.TextDirection.rtl,
        child: pw.Table(
          border:
              pw.TableBorder.all(
            width:
                .4,
          ),
          children: [
            pw.TableRow(
              children: [
                _tableHeader(
                  'التاريخ',
                ),
                _tableHeader(
                  'الوقت',
                ),
                _tableHeader(
                  'مدخل البيانات',
                ),
                _tableHeader(
                  'إجمالي الحمل',
                ),

                for (final cell
                    in cellNumbers)
                  _tableHeader(
                    '$cell',
                  ),
              ],
            ),

            for (final record
                in sorted)
              pw.TableRow(
                children: [
                  _tableValue(
                    _formatDate(
                      record.recordedAt,
                    ),
                  ),

                  _tableValue(
                    DateFormat(
                      'HH:mm',
                    ).format(
                      record.recordedAt,
                    ),
                  ),

                  _tableValue(
                    record.operatorName,
                  ),

                  _tableValue(
                    record.totalLoad
                        .toStringAsFixed(
                      1,
                    ),
                  ),

                  for (final cell
                      in cellNumbers)
                    _tableValue(
                      (record.cellValues[
                                  cell] ??
                              0)
                          .toStringAsFixed(
                        1,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );

    return widgets;
  }

  // =========================================================
  // MAX / MIN RECORD
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
        result =
            record;
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

    var result =
        records.first;

    for (final record
        in records.skip(1)) {
      if (record.totalLoad <
          result.totalLoad) {
        result =
            record;
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

  // =========================================================
  // FILE NAME
  // =========================================================

  static String _createFileName() {
    return 'distribution_load_report_'
        '${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}'
        '.pdf';
  }
}

// ===========================================================
// FAST PDF INDEX
// ===========================================================

class _ReportPdfIndex {
  _ReportPdfIndex({
    required this.latest,
    required this.ranges,
  });

  final Map<String, LoadRecord>
      latest;

  final Map<String, _PdfCellRange>
      ranges;

  factory _ReportPdfIndex.build(
    List<LoadRecord> records,
  ) {
    final latest =
        <String, LoadRecord>{};

    final mutableRanges =
        <String, _MutablePdfCellRange>{};

    /*
     * دورة واحدة فقط على records.
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
            mutableRanges
                .putIfAbsent(
          rangeKey,
          () =>
              _MutablePdfCellRange(),
        );

        range.add(
          entry.value,
        );
      }
    }

    final ranges =
        <String, _PdfCellRange>{};

    for (final entry
        in mutableRanges.entries) {
      ranges[entry.key] =
          _PdfCellRange(
        minimum:
            entry.value.minimum,
        maximum:
            entry.value.maximum,
      );
    }

    return _ReportPdfIndex(
      latest:
          latest,
      ranges:
          ranges,
    );
  }

  String currentValue({
    required String distributorId,
    required DateTime day,
    required int hour,
    required int cellNumber,
  }) {
    final key =
        '$distributorId|'
        '${day.year}|'
        '${day.month}|'
        '${day.day}|'
        '$hour';

    final record =
        latest[key];

    if (record == null) {
      return '—';
    }

    return (record.cellValues[
                cellNumber] ??
            0)
        .toStringAsFixed(
      1,
    );
  }

  String minimumValue({
    required String distributorId,
    required int cellNumber,
  }) {
    final range =
        ranges[
            '$distributorId|$cellNumber'];

    if (range?.minimum ==
        null) {
      return '—';
    }

    return range!.minimum!
        .toStringAsFixed(
      1,
    );
  }

  String maximumValue({
    required String distributorId,
    required int cellNumber,
  }) {
    final range =
        ranges[
            '$distributorId|$cellNumber'];

    if (range?.maximum ==
        null) {
      return '—';
    }

    return range!.maximum!
        .toStringAsFixed(
      1,
    );
  }
}

class _MutablePdfCellRange {
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

class _PdfCellRange {
  const _PdfCellRange({
    required this.minimum,
    required this.maximum,
  });

  final double? minimum;
  final double? maximum;
}
