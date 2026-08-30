import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../config/app_config.dart';
import '../models/consumption_entry.dart';
import '../models/fueling_record.dart';

class ReportPdfService {
  static Future<Uint8List> fuelingPages(List<FuelingRecord> records) async {
    final doc = pw.Document();
    final regular = await PdfGoogleFonts.cairoRegular();
    final bold = await PdfGoogleFonts.cairoBold();
    final logo = pw.MemoryImage((await rootBundle.load('assets/company_logo.png')).buffer.asUint8List());

    for (final record in records) {
      final images = <pw.MemoryImage>[];
      for (final url in record.imageUrls.take(4)) {
        final response = await http.get(Uri.parse(url));
        images.add(pw.MemoryImage(response.bodyBytes));
      }
      while (images.length < 4) {
        images.add(pw.MemoryImage(Uint8List.fromList(_transparentPng)));
      }

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          theme: pw.ThemeData.withFont(base: regular, bold: bold),
          build: (_) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Image(logo, width: 62, height: 62, fit: pw.BoxFit.contain),
                    pw.Column(children: [
                      pw.Text(AppConfig.companyName, style: pw.TextStyle(font: bold, fontSize: 15)),
                      pw.SizedBox(height: 3),
                      pw.Text(AppConfig.departmentName, style: pw.TextStyle(font: bold, fontSize: 14)),
                      pw.Text(AppConfig.reportTitle, style: const pw.TextStyle(fontSize: 12)),
                    ]),
                    pw.SizedBox(width: 62),
                  ],
                ),
                pw.SizedBox(height: 8),
                _infoGrid(record, bold),
                pw.SizedBox(height: 10),
                pw.Expanded(
                  child: pw.GridView(
                    crossAxisCount: 2,
                    childAspectRatio: 0.94,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: [
                      _photo('مؤشر الوقود قبل التموين', images[0], bold),
                      _photo('مضخة الوقود', images[1], bold),
                      _photo('مؤشر الوقود بعد التموين', images[2], bold),
                      _photo('إيصال المحطة', images[3], bold),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('اسم السائق: ${record.driverName}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('عداد السيارة: ${NumberFormat.decimalPattern().format(record.odometer)} كم', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('${AppConfig.approvalTitle}: ........................', style: const pw.TextStyle(fontSize: 10)),
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
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: .7)),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 10)), pw.Text(value, style: const pw.TextStyle(fontSize: 10))],
          ),
        );
    return pw.Column(children: [
      pw.Row(children: [
        pw.Expanded(child: cell('التاريخ', DateFormat('yyyy/MM/dd  HH:mm').format(r.createdAt))),
        pw.Expanded(child: cell('رقم السيارة', r.vehicleNumber)),
      ]),
      pw.Row(children: [
        pw.Expanded(child: cell('نوع الوقود', r.fuelType)),
        pw.Expanded(child: cell('موديل السيارة', r.vehicleModel)),
      ]),
    ]);
  }

  static pw.Widget _photo(String label, pw.MemoryImage image, pw.Font bold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: .8), borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Column(children: [
        pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Expanded(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ]),
    );
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
              pw.Text('${AppConfig.companyName} - ${AppConfig.departmentName}', style: pw.TextStyle(font: bold, fontSize: 16)),
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
