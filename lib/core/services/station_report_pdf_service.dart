import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/station_load_report.dart';

class StationReportPdfService {
  StationReportPdfService._();

  static Future<Uint8List> buildPdf({
    required StationLoadReportResult report,
  }) async {
    final document = pw.Document();
    final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        header: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'تقرير أحمال المحطة - ${report.station.name}',
                    style: pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'صفحة ${context.pageNumber} من ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                _periodText(report.fromDate, report.toDate),
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Divider(),
            ],
          ),
        ),
        build: (_) {
          final widgets = <pw.Widget>[
            _stationSummary(report),
            pw.SizedBox(height: 14),
          ];

          for (final summary in report.transformerSummaries) {
            widgets.add(_transformerSummary(summary));
            widgets.add(pw.SizedBox(height: 10));
          }

          if (report.stationSnapshots.isNotEmpty) {
            widgets.add(
              pw.Text(
                'إجمالي حمل المحطة حسب الساعة',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(_stationHistoryTable(report));
          }

          return widgets;
        },
      ),
    );

    return document.save();
  }

  static Future<void> printReport(StationLoadReportResult report) async {
    final bytes = await buildPdf(report: report);
    await Printing.layoutPdf(
      name: _fileName(),
      format: PdfPageFormat.a4.landscape,
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> shareReport(StationLoadReportResult report) async {
    final bytes = await buildPdf(report: report);
    await Printing.sharePdf(bytes: bytes, filename: _fileName());
  }

  static pw.Widget _stationSummary(StationLoadReportResult report) {
    final stats = report.stationStatistics;
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Table(
        border: pw.TableBorder.all(width: 0.6),
        children: [
          pw.TableRow(
            children: [
              _cell('عدد القراءات الكاملة', bold: true),
              _cell('أقل حمل', bold: true),
              _cell('وقت أقل حمل', bold: true),
              _cell('أعلى حمل', bold: true),
              _cell('وقت أعلى حمل', bold: true),
              _cell('المتوسط', bold: true),
            ],
          ),
          pw.TableRow(
            children: [
              _cell('${stats.count}'),
              _cell(_load(stats.minimum)),
              _cell(_dateTime(stats.minimumPoint?.recordedAt)),
              _cell(_load(stats.maximum)),
              _cell(_dateTime(stats.maximumPoint?.recordedAt)),
              _cell('${stats.average.toStringAsFixed(1)} A'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _transformerSummary(TransformerReportSummary summary) {
    final stats = summary.statistics;
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            '${summary.transformer.name} - ${summary.transformer.linksSummary}',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            children: [
              pw.TableRow(
                children: [
                  _cell('الحالي', bold: true),
                  _cell('أقل حمل', bold: true),
                  _cell('وقت الأقل', bold: true),
                  _cell('أعلى حمل', bold: true),
                  _cell('وقت الأعلى', bold: true),
                  _cell('المتوسط', bold: true),
                ],
              ),
              pw.TableRow(
                children: [
                  _cell(_load(summary.currentReading?.load)),
                  _cell(_load(stats.minimum)),
                  _cell(_dateTime(stats.minimumPoint?.recordedAt)),
                  _cell(_load(stats.maximum)),
                  _cell(_dateTime(stats.maximumPoint?.recordedAt)),
                  _cell('${stats.average.toStringAsFixed(1)} A'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _stationHistoryTable(StationLoadReportResult report) {
    final rows = report.stationSnapshots.take(200).toList();
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Table(
        border: pw.TableBorder.all(width: 0.4),
        children: [
          pw.TableRow(
            children: [
              _cell('التاريخ والوقت', bold: true),
              ...report.station.transformers.map(
                (item) => _cell(item.name, bold: true),
              ),
              _cell('إجمالي المحطة', bold: true),
            ],
          ),
          ...rows.map(
            (snapshot) => pw.TableRow(
              children: [
                _cell(_dateTime(snapshot.recordedAt)),
                ...report.station.transformers.map(
                  (item) => _cell(
                    '${(snapshot.transformerLoads[item.id] ?? 0).toStringAsFixed(1)} A',
                  ),
                ),
                _cell('${snapshot.totalLoad.toStringAsFixed(1)} A'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static String _load(double? value) =>
      value == null ? 'لا توجد بيانات' : '${value.toStringAsFixed(1)} A';

  static String _dateTime(DateTime? value) => value == null
      ? 'لا توجد بيانات'
      : DateFormat('yyyy/MM/dd - HH:mm').format(value);

  static String _periodText(DateTime? from, DateTime? to) {
    if (from == null && to == null) return 'جميع الفترات';
    if (from != null && to != null) {
      return 'من ${_dateTime(from)} إلى ${_dateTime(to)}';
    }
    if (from != null) return 'من ${_dateTime(from)}';
    return 'حتى ${_dateTime(to)}';
  }

  static String _fileName() {
    final time = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'station_load_report_$time.pdf';
  }
}
