// ignore_for_file: prefer_const_constructors

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  static Future<Uint8List> buildPdf({
    required List<LoadRecord> records,
    String title = 'تقرير الأحمال',
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final document = pw.Document();
    final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final sortedRecords = List<LoadRecord>.from(records)
      ..sort(
        (first, second) =>
            second.recordedAt.compareTo(first.recordedAt),
      );

    final groupedRecords = _groupByDistributor(sortedRecords);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.all(22),
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
        ),
        header: (context) => _buildHeader(
          title: title,
          fromDate: fromDate,
          toDate: toDate,
          pageNumber: context.pageNumber,
          pagesCount: context.pagesCount,
        ),
        footer: (context) => _buildFooter(),
        build: (context) {
          if (sortedRecords.isEmpty) {
            return <pw.Widget>[
              pw.SizedBox(height: 80),
              pw.Center(
                child: pw.Text(
                  'لا توجد بيانات متاحة للتقرير.',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
              ),
            ];
          }

          final widgets = <pw.Widget>[
            _buildGeneralSummary(sortedRecords),
            pw.SizedBox(height: 14),
          ];

          for (final entry in groupedRecords.entries) {
            widgets.add(
              _buildDistributorReport(
                distributorRecords: entry.value,
              ),
            );
            widgets.add(pw.SizedBox(height: 18));
          }

          return widgets;
        },
      ),
    );

    return document.save();
  }

  static Future<void> printReport({
    required List<LoadRecord> records,
    String title = 'تقرير الأحمال',
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final bytes = await buildPdf(
      records: records,
      title: title,
      fromDate: fromDate,
      toDate: toDate,
    );

    await Printing.layoutPdf(
      name: _createFileName(),
      format: PdfPageFormat.a4.landscape,
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> shareReport({
    required List<LoadRecord> records,
    String title = 'تقرير الأحمال',
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final bytes = await buildPdf(
      records: records,
      title: title,
      fromDate: fromDate,
      toDate: toDate,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: _createFileName(),
    );
  }

  static Map<String, List<LoadRecord>> _groupByDistributor(
    List<LoadRecord> records,
  ) {
    final result = <String, List<LoadRecord>>{};

    for (final record in records) {
      final key = record.distributorId.trim().isEmpty
          ? record.distributorName
          : record.distributorId;

      result.putIfAbsent(key, () => <LoadRecord>[]);
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

  static pw.Widget _buildHeader({
    required String title,
    required DateTime? fromDate,
    required DateTime? toDate,
    required int pageNumber,
    required int pagesCount,
  }) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        padding: pw.EdgeInsets.only(bottom: 8),
        margin: pw.EdgeInsets.only(bottom: 12),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(width: 1),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  _periodText(fromDate, toDate),
                  style: pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.Text(
              'صفحة $pageNumber من $pagesCount',
              style: pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        margin: pw.EdgeInsets.only(top: 8),
        padding: pw.EdgeInsets.only(top: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(width: 0.5),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'برنامج تسجيل أحمال الموزعات',
              style: pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              'تم إنشاء التقرير: ${_formatDateTime(DateTime.now())}',
              style: pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildGeneralSummary(List<LoadRecord> records) {
    final distributorIds = records
        .map(
          (record) => record.distributorId.trim().isEmpty
              ? record.distributorName
              : record.distributorId,
        )
        .toSet();

    LoadRecord maximumRecord = records.first;
    LoadRecord minimumRecord = records.first;
    double total = 0;

    for (final record in records) {
      total += record.totalLoad;

      if (record.totalLoad > maximumRecord.totalLoad) {
        maximumRecord = record;
      }

      if (record.totalLoad < minimumRecord.totalLoad) {
        minimumRecord = record;
      }
    }

    final average = total / records.length;

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        padding: pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 0.7),
          borderRadius: pw.BorderRadius.all(
            pw.Radius.circular(4),
          ),
        ),
        child: pw.Row(
          children: [
            _summaryItem(
              title: 'عدد الموزعات',
              value: distributorIds.length.toString(),
            ),
            _verticalDivider(),
            _summaryItem(
              title: 'عدد السجلات',
              value: records.length.toString(),
            ),
            _verticalDivider(),
            _summaryItem(
              title: 'أقصى حمل',
              value: '${maximumRecord.totalLoad.toStringAsFixed(2)} A',
            ),
            _verticalDivider(),
            _summaryItem(
              title: 'أقل حمل',
              value: '${minimumRecord.totalLoad.toStringAsFixed(2)} A',
            ),
            _verticalDivider(),
            _summaryItem(
              title: 'متوسط الأحمال',
              value: '${average.toStringAsFixed(2)} A',
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _summaryItem({
    required String title,
    required String value,
  }) {
    return pw.Expanded(
      child: pw.Column(
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _verticalDivider() {
    return pw.Container(
      width: 0.7,
      height: 34,
      color: PdfColors.grey700,
    );
  }

  static pw.Widget _buildDistributorReport({
    required List<LoadRecord> distributorRecords,
  }) {
    final latestRecord = distributorRecords.first;
    final statistics = _calculateCellStatistics(distributorRecords);

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              border: pw.Border(
                left: pw.BorderSide(),
                right: pw.BorderSide(),
                top: pw.BorderSide(),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  latestRecord.distributorName,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'آخر تسجيل: ${_formatDateTime(latestRecord.recordedAt)}',
                  style: pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: pw.EdgeInsets.all(7),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(),
                right: pw.BorderSide(),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'مدخل البيانات: ${latestRecord.operatorName}',
                    style: pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    'كود المستخدم: ${latestRecord.createdByCode}',
                    style: pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    'إجمالي الحمل الحالي: '
                    '${latestRecord.totalLoad.toStringAsFixed(2)} أمبير',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(width: 0.6),
            headerDecoration: pw.BoxDecoration(
              color: PdfColors.grey300,
            ),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.center,
            headerAlignment: pw.Alignment.center,
            headers: const <String>[
              'الخلية',
              'الحمل الحالي',
              'أقل حمل',
              'أقصى حمل',
              'وقت أقل حمل',
              'وقت أقصى حمل',
            ],
            data: cellNumbers.map((cellNumber) {
              final cell = statistics[cellNumber]!;

              return <String>[
                cellNumber.toString(),
                _formatLoad(cell.current),
                _formatLoad(cell.minimum),
                _formatLoad(cell.maximum),
                cell.minimumRecord == null
                    ? '—'
                    : _formatDateTime(cell.minimumRecord!.recordedAt),
                cell.maximumRecord == null
                    ? '—'
                    : _formatDateTime(cell.maximumRecord!.recordedAt),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }

  static Map<int, _PdfCellStatistics> _calculateCellStatistics(
    List<LoadRecord> records,
  ) {
    final result = <int, _PdfCellStatistics>{};
    final latestRecord = records.first;

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

      result[cellNumber] = _PdfCellStatistics(
        current: latestRecord.cellValues[cellNumber],
        minimum: minimum,
        maximum: maximum,
        minimumRecord: minimumRecord,
        maximumRecord: maximumRecord,
      );
    }

    return result;
  }

  static String _formatLoad(double? value) {
    if (value == null) {
      return '—';
    }

    return '${value.toStringAsFixed(2)} A';
  }

  static String _periodText(DateTime? fromDate, DateTime? toDate) {
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

  static String _formatDateTime(DateTime value) {
    return DateFormat('yyyy-MM-dd HH:mm').format(value);
  }

  static String _createFileName() {
    final date = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'distribution_load_report_$date.pdf';
  }
}

class _PdfCellStatistics {
  const _PdfCellStatistics({
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
