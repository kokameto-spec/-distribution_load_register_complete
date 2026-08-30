import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:public_file_saver/public_file_saver.dart';

import '../config/app_config.dart';
import '../models/consumption_entry.dart';
import '../models/fueling_record.dart';
import 'firebase_service.dart';

class ReportPdfService {
  static Future<Uint8List> fuelingPages(List<FuelingRecord> records) async {
    final doc = pw.Document();
    final regular = await PdfGoogleFonts.cairoRegular();
    final bold = await PdfGoogleFonts.cairoBold();
    final logo = pw.MemoryImage((await rootBundle.load('assets/company_logo.png')).buffer.asUint8List());

    for (final record in records) {
      final rawImages = await FirebaseService.instance.fuelingImages(record.id);
      final images = <pw.MemoryImage>[for (final bytes in rawImages.take(4)) pw.MemoryImage(bytes)];
      while (images.length < 4) {
        images.add(pw.MemoryImage(Uint8List.fromList(_transparentPng)));
      }

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(15),
          theme: pw.ThemeData.withFont(base: regular, bold: bold),
          build: (_) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Image(logo, width: 62, height: 62, fit: pw.BoxFit.contain),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(AppConfig.ministryName, style: pw.TextStyle(font: bold, fontSize: 10)),
                        pw.Text(AppConfig.companyName, style: pw.TextStyle(font: bold, fontSize: 10)),
                        pw.Text(AppConfig.controlName, style: pw.TextStyle(font: bold, fontSize: 10)),
                        pw.Text(AppConfig.departmentName, style: pw.TextStyle(font: bold, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                pw.Text(AppConfig.reportTitle, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: bold, fontSize: 11)),
                pw.SizedBox(height: 4),
                _infoGrid(record, bold),
                pw.SizedBox(height: 5),
                pw.Expanded(
                  child: pw.GridView(
                    crossAxisCount: 2,
                    childAspectRatio: .92,
                    crossAxisSpacing: 5,
                    mainAxisSpacing: 5,
                    children: [for (final image in images.take(4)) _photo(image)],
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Row(children: [
                  pw.Expanded(child: pw.Text('السائق: ${record.driverName}', style: const pw.TextStyle(fontSize: 8))),
                  pw.Expanded(child: pw.Text('العداد: ${NumberFormat.decimalPattern().format(record.odometer)} كم', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
                ]),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _signature(AppConfig.driverSignature, bold),
                    _signature(AppConfig.transportHeadSignature, bold),
                    _signature(AppConfig.generalManagerSignature, bold),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return doc.save();
  }

  static pw.Widget _infoGrid(FuelingRecord r, pw.Font bold) {
    pw.Widget cell(String label, String value) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: .55)),
          child: pw.Row(children: [
            pw.Text('$label: ', style: pw.TextStyle(font: bold, fontSize: 8)),
            pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 8))),
          ]),
        );
    return pw.Column(children: [
      pw.Row(children: [
        pw.Expanded(child: cell('التاريخ', DateFormat('yyyy/MM/dd HH:mm').format(r.createdAt))),
        pw.Expanded(child: cell('رقم السيارة', r.vehicleNumber)),
      ]),
      pw.Row(children: [
        pw.Expanded(child: cell('نوع الوقود', r.fuelType)),
        pw.Expanded(child: cell('الموديل', r.vehicleModel)),
      ]),
    ]);
  }

  static pw.Widget _photo(pw.MemoryImage image) => pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(width: .65)),
        child: pw.Image(image, fit: pw.BoxFit.cover),
      );

  static pw.Widget _signature(String label, pw.Font bold) => pw.SizedBox(
        width: 150,
        child: pw.Column(children: [
          pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 8)),
          pw.SizedBox(height: 12),
          pw.Text('........................', style: const pw.TextStyle(fontSize: 8)),
        ]),
      );

  static Future<String> savePdf(Uint8List bytes, String fileName) async {
    final safeName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
    final result = await PublicFileSaver().saveBytes(
      bytes: bytes,
      fileName: safeName,
      mimeType: 'application/pdf',
      subDir: 'تحكم_26_وسائل_النقل',
    );
    if (result == null) return 'تم إلغاء الحفظ';
    return result.path ?? result.uri ?? result.fileName;
  }

  static Future<void> sharePdf(Uint8List bytes, String fileName) {
    return Printing.sharePdf(bytes: bytes, filename: fileName.endsWith('.pdf') ? fileName : '$fileName.pdf');
  }

  static Future<Uint8List> consumptionTable(List<ConsumptionEntry> rows, String monthKey) async {
    final doc = pw.Document();
    final regular = await PdfGoogleFonts.cairoRegular();
    final bold = await PdfGoogleFonts.cairoBold();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (_) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(children: [
              pw.Text('${AppConfig.companyName} - ${AppConfig.controlName} - ${AppConfig.departmentName}', style: pw.TextStyle(font: bold, fontSize: 16)),
              pw.SizedBox(height: 4),
              pw.Text('كشف الاستهلاك الشهري - $monthKey', style: pw.TextStyle(font: bold, fontSize: 14)),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: const ['التاريخ', 'رقم السيارة', 'العداد السابق', 'العداد الحالي', 'المسافة', 'توقيع السائق', 'توقيع مسئول النقل'],
                data: rows.map((r) => [
                  DateFormat('yyyy/MM/dd').format(r.date),
                  r.vehicleNumber,
                  r.previousOdometer?.toString() ?? '-',
                  r.currentOdometer.toString(),
                  r.distance?.toString() ?? '-',
                  r.driverName,
                  '................',
                ]).toList(),
                headerStyle: pw.TextStyle(font: bold, fontSize: 9),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.center,
              ),
            ]),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static const List<int> _transparentPng = [
    137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,1,0,0,0,1,8,6,0,0,0,31,21,196,137,
    0,0,0,13,73,68,65,84,8,29,99,96,96,96,0,0,0,5,0,1,13,10,45,180,0,0,0,0,73,69,78,68,174,66,96,130
  ];
}
