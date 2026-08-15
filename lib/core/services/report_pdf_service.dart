import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
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
    0, 1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 15,
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
    final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();
    final logoBytes = await _loadLogoBytes();

    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    );

    final index = _ReportPdfIndex.build(records);

    if (allDistributorsHourly) {
      final hour = selectedDateTime?.hour ?? 0;
      final start = fromDate ?? selectedDateTime ?? DateTime.now();
      final end = toDate ?? start;

      final activeDistributors = distributors
          .where((item) => item.active)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      for (final day in _daysBetween(start, end)) {
        document.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(14),
            theme: theme,
            header: (_) => _buildHeader(logoBytes),
            footer: (_) => _buildFooter(),
            build: (_) => <pw.Widget>[
              _buildPeriodRow(day: day, hour: hour),
              pw.SizedBox(height: 7),
              ..._buildDistributorTables(
                day: day,
                hour: hour,
                index: index,
                distributors: activeDistributors,
              ),
            ],
          ),
        );
      }
    } else {
      final distributor = _findDistributor(
        distributors,
        selectedDistributorId,
      );

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(16),
          theme: theme,
          header: (_) => _buildHeader(logoBytes),
          footer: (_) => _buildFooter(),
          build: (_) => _buildSingleDistributor(
            records: records,
            distributor: distributor,
            index: index,
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
    required String fileName,
    String? selectedDistributorId,
    DateTime? selectedDateTime,
    DateTime? fromDate,
    DateTime? toDate,
    bool allDistributorsHourly = false,
  }) async {
    final bytes = await buildPdf(
      records: records,
      distributors: distributors,
      selectedDistributorId: selectedDistributorId,
      selectedDateTime: selectedDateTime,
      fromDate: fromDate,
      toDate: toDate,
      allDistributorsHourly: allDistributorsHourly,
    );

    await Printing.layoutPdf(
      name: '$fileName.pdf',
      format: PdfPageFormat.a4.landscape,
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> saveReport({
    required List<LoadRecord> records,
    required List<Distributor> distributors,
    required String fileName,
    String? selectedDistributorId,
    DateTime? selectedDateTime,
    DateTime? fromDate,
    DateTime? toDate,
    bool allDistributorsHourly = false,
  }) async {
    final bytes = await buildPdf(
      records: records,
      distributors: distributors,
      selectedDistributorId: selectedDistributorId,
      selectedDateTime: selectedDateTime,
      fromDate: fromDate,
      toDate: toDate,
      allDistributorsHourly: allDistributorsHourly,
    );

    await FileSaver.instance.saveAs(
      name: fileName,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static Future<void> shareReport({
    required List<LoadRecord> records,
    required List<Distributor> distributors,
    required String fileName,
    String? selectedDistributorId,
    DateTime? selectedDateTime,
    DateTime? fromDate,
    DateTime? toDate,
    bool allDistributorsHourly = false,
  }) async {
    final bytes = await buildPdf(
      records: records,
      distributors: distributors,
      selectedDistributorId: selectedDistributorId,
      selectedDateTime: selectedDateTime,
      fromDate: fromDate,
      toDate: toDate,
      allDistributorsHourly: allDistributorsHourly,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: '$fileName.pdf',
    );
  }

  static List<pw.Widget> _buildDistributorTables({
    required DateTime day,
    required int hour,
    required _ReportPdfIndex index,
    required List<Distributor> distributors,
  }) {
    final result = <pw.Widget>[];

    for (var start = 0; start < distributors.length; start += 6) {
      final end = (start + 6) < distributors.length
          ? start + 6
          : distributors.length;

      final table = _buildDistributorGrid(
        day: day,
        hour: hour,
        index: index,
        distributors: distributors.sublist(start, end),
      );

      // المجموعة كاملة كوحدة واحدة: لو المساحة المتبقية لا تكفيها
      // تنتقل للصفحة التالية ولا تُقسم بين صفحتين.
      result.add(
        pw.Wrap(
          children: <pw.Widget>[table],
        ),
      );
      result.add(pw.SizedBox(height: 8));
    }

    if (distributors.isEmpty) {
      result.add(pw.Center(child: pw.Text('لا توجد موزعات نشطة.')));
    }

    return result;
  }

  static pw.Widget _buildDistributorGrid({
    required DateTime day,
    required int hour,
    required _ReportPdfIndex index,
    required List<Distributor> distributors,
  }) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        children: [
          _tableHeader('الخلايا'),
          for (final distributor in distributors) ...[
            _tableHeader(
              '${distributor.name}\n'
              '${distributor.type.trim().isEmpty ? 'غير محدد' : distributor.type}',
            ),
            _tableHeader('${distributor.name}\n${distributor.code}'),
            _tableHeader('${distributor.name}\n${distributor.code}'),
          ],
        ],
      ),
      pw.TableRow(
        children: [
          _tableHeader('رقم الخلية'),
          for (final _ in distributors) ...[
            _tableHeader('الحمل'),
            _tableHeader('أقل حمل'),
            _tableHeader('أقصى حمل'),
          ],
        ],
      ),
    ];

    for (final cell in cellNumbers) {
      rows.add(
        pw.TableRow(
          children: [
            _tableValue('$cell', bold: true),
            for (final distributor in distributors) ...[
              _tableValue(
                index.currentValue(
                  distributorId: distributor.id,
                  day: day,
                  hour: hour,
                  cellNumber: cell,
                ),
                red: true,
              ),
              _tableValue(
                index.minimumValue(
                  distributorId: distributor.id,
                  cellNumber: cell,
                ),
              ),
              _tableValue(
                index.maximumValue(
                  distributorId: distributor.id,
                  cellNumber: cell,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Table(
        border: pw.TableBorder.all(width: .45),
        columnWidths: <int, pw.TableColumnWidth>{
          0: const pw.FlexColumnWidth(1.05),
          for (var i = 0; i < distributors.length * 3; i++)
            i + 1: const pw.FlexColumnWidth(.85),
        },
        children: rows,
      ),
    );
  }

  static List<pw.Widget> _buildSingleDistributor({
    required List<LoadRecord> records,
    required Distributor? distributor,
    required _ReportPdfIndex index,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    final sorted = List<LoadRecord>.from(records)
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    if (sorted.isEmpty) {
      return <pw.Widget>[
        pw.Center(child: pw.Text('لا توجد سجلات مطابقة.')),
      ];
    }

    final distributorId = distributor?.id ?? sorted.first.distributorId;
    final maxRecord = sorted.reduce(
      (a, b) => a.totalLoad >= b.totalLoad ? a : b,
    );
    final minRecord = sorted.reduce(
      (a, b) => a.totalLoad <= b.totalLoad ? a : b,
    );

    return <pw.Widget>[
      pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Column(
          children: [
            pw.Text(
              distributor?.name ?? sorted.first.distributorName,
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (fromDate != null && toDate != null)
              pw.Text(
                'الفترة: ${_formatDate(fromDate)} إلى ${_formatDate(toDate)}',
              ),
            pw.SizedBox(height: 6),
            pw.Text(
              'أقصى حمل: ${maxRecord.totalLoad.toStringAsFixed(2)} أمبير'
              '   —   '
              'أقل حمل: ${minRecord.totalLoad.toStringAsFixed(2)} أمبير',
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 10),
      pw.Wrap(
        children: <pw.Widget>[
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Table(
              border: pw.TableBorder.all(width: .5),
              children: [
                pw.TableRow(
                  children: [
                    _tableHeader('الخلية'),
                    _tableHeader('أقل حمل'),
                    _tableHeader('أقصى حمل'),
                  ],
                ),
                for (final cell in cellNumbers)
                  pw.TableRow(
                    children: [
                      _tableValue('$cell', bold: true),
                      _tableValue(
                        index.minimumValue(
                          distributorId: distributorId,
                          cellNumber: cell,
                        ),
                      ),
                      _tableValue(
                        index.maximumValue(
                          distributorId: distributorId,
                          cellNumber: cell,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Text(
        'تفاصيل التسجيلات',
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 5),
      pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Table(
          border: pw.TableBorder.all(width: .4),
          children: [
            pw.TableRow(
              children: [
                _tableHeader('التاريخ'),
                _tableHeader('الوقت'),
                _tableHeader('مدخل البيانات'),
                _tableHeader('الإجمالي'),
                for (final cell in cellNumbers) _tableHeader('$cell'),
              ],
            ),
            for (final record in sorted)
              pw.TableRow(
                children: [
                  _tableValue(_formatDate(record.recordedAt)),
                  _tableValue(DateFormat('HH:mm').format(record.recordedAt)),
                  _tableValue(record.operatorName),
                  _tableValue(record.totalLoad.toStringAsFixed(1)),
                  for (final cell in cellNumbers)
                    _tableValue(
                      (record.cellValues[cell] ?? 0).toStringAsFixed(1),
                    ),
                ],
              ),
          ],
        ),
      ),
    ];
  }

  static Future<Uint8List?> _loadLogoBytes() async {
    try {
      final data = await rootBundle.load('assets/images/company_logo.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _buildHeader(Uint8List? logoBytes) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 145,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'شركة جنوب القاهرة لتوزيع الكهرباء',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('قطاع التحكمات والوقاية',
                    style: const pw.TextStyle(fontSize: 7)),
                pw.Text('تحكم 26 يوليو',
                    style: const pw.TextStyle(fontSize: 7)),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              'أحمال خلايا الموزعات',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 17,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(
            width: 145,
            child: logoBytes == null
                ? pw.SizedBox()
                : pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Image(
                      pw.MemoryImage(logoBytes),
                      width: 72,
                      height: 48,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _signature('اسم مدخل البيانات'),
          _signature('إعداد'),
          _signature('مدير التشغيل'),
          _signature('اعتماد المدير العام'),
        ],
      ),
    );
  }

  static pw.Widget _signature(String title) {
    return pw.Column(
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 6.5)),
        pw.Text('............................',
            style: const pw.TextStyle(fontSize: 6)),
      ],
    );
  }

  static pw.Widget _buildPeriodRow({
    required DateTime day,
    required int hour,
  }) {
    final h = hour.toString().padLeft(2, '0');
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Text(
        'اليوم: ${_dayName(day)}    '
        'التاريخ: ${_formatDate(day)}    '
        'الفترة: $h:00 - $h:59',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(2.5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 5.5,
          fontWeight: pw.FontWeight.bold,
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
      padding: const pw.EdgeInsets.all(2),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 5.6,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: red ? PdfColors.red700 : PdfColors.black,
        ),
      ),
    );
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

  static String _formatDate(DateTime value) {
    return DateFormat('dd-MM-yyyy').format(value);
  }

  static String _dayName(DateTime value) {
    const names = <int, String>{
      DateTime.monday: 'الاثنين',
      DateTime.tuesday: 'الثلاثاء',
      DateTime.wednesday: 'الأربعاء',
      DateTime.thursday: 'الخميس',
      DateTime.friday: 'الجمعة',
      DateTime.saturday: 'السبت',
      DateTime.sunday: 'الأحد',
    };
    return names[value.weekday] ?? '';
  }
}

class _ReportPdfIndex {
  _ReportPdfIndex({
    required this.latest,
    required this.ranges,
  });

  final Map<String, LoadRecord> latest;
  final Map<String, _PdfCellRange> ranges;

  factory _ReportPdfIndex.build(List<LoadRecord> records) {
    final latest = <String, LoadRecord>{};
    final mutable = <String, _MutablePdfCellRange>{};

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
        mutable.putIfAbsent(key, _MutablePdfCellRange.new).add(entry.value);
      }
    }

    return _ReportPdfIndex(
      latest: latest,
      ranges: {
        for (final e in mutable.entries)
          e.key: _PdfCellRange(
            minimum: e.value.minimum,
            maximum: e.value.maximum,
          ),
      },
    );
  }

  String currentValue({
    required String distributorId,
    required DateTime day,
    required int hour,
    required int cellNumber,
  }) {
    final key =
        '$distributorId|${day.year}|${day.month}|${day.day}|$hour';
    final record = latest[key];
    if (record == null) return 'لم يسجل';
    return (record.cellValues[cellNumber] ?? 0).toStringAsFixed(1);
  }

  String minimumValue({
    required String distributorId,
    required int cellNumber,
  }) {
    final value = ranges['$distributorId|$cellNumber']?.minimum;
    return value == null ? '—' : value.toStringAsFixed(1);
  }

  String maximumValue({
    required String distributorId,
    required int cellNumber,
  }) {
    final value = ranges['$distributorId|$cellNumber']?.maximum;
    return value == null ? '—' : value.toStringAsFixed(1);
  }
}

class _MutablePdfCellRange {
  double? minimum;
  double? maximum;

  void add(double value) {
    if (minimum == null || value < minimum!) minimum = value;
    if (maximum == null || value > maximum!) maximum = value;
  }
}

class _PdfCellRange {
  const _PdfCellRange({
    this.minimum,
    this.maximum,
  });

  final double? minimum;
  final double? maximum;
}
