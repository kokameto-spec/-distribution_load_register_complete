import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';

import '../../models/station_load_report.dart';

class StationReportExcelService {
  StationReportExcelService._();

  static Future<void> exportReport(StationLoadReportResult report) async {
    final excel = Excel.createExcel();
    final summary = excel['ملخص المحطة'];
    final details = excel['تفاصيل الأحمال'];

    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null &&
        defaultSheet != 'ملخص المحطة' &&
        defaultSheet != 'تفاصيل الأحمال') {
      excel.delete(defaultSheet);
    }

    summary.isRTL = true;
    details.isRTL = true;

    summary.appendRow(<CellValue>[
      TextCellValue('تقرير أحمال المحطة'),
      TextCellValue(report.station.name),
    ]);
    summary.appendRow(<CellValue>[
      TextCellValue('الفترة'),
      TextCellValue(_period(report.fromDate, report.toDate)),
    ]);
    summary.appendRow(const <CellValue>[]);
    summary.appendRow(<CellValue>[
      TextCellValue('البيان'),
      TextCellValue('الحالي'),
      TextCellValue('أقل حمل'),
      TextCellValue('وقت الأقل'),
      TextCellValue('أعلى حمل'),
      TextCellValue('وقت الأعلى'),
      TextCellValue('المتوسط'),
      TextCellValue('عدد القراءات'),
    ]);

    final stationStats = report.stationStatistics;
    summary.appendRow(<CellValue>[
      TextCellValue(report.station.name),
      DoubleCellValue(report.currentStationSnapshot?.totalLoad ?? 0),
      DoubleCellValue(stationStats.minimum ?? 0),
      TextCellValue(_dateTime(stationStats.minimumPoint?.recordedAt)),
      DoubleCellValue(stationStats.maximum ?? 0),
      TextCellValue(_dateTime(stationStats.maximumPoint?.recordedAt)),
      DoubleCellValue(stationStats.average),
      IntCellValue(stationStats.count),
    ]);

    for (final item in report.transformerSummaries) {
      final stats = item.statistics;
      summary.appendRow(<CellValue>[
        TextCellValue(item.transformer.name),
        DoubleCellValue(item.currentReading?.load ?? 0),
        DoubleCellValue(stats.minimum ?? 0),
        TextCellValue(_dateTime(stats.minimumPoint?.recordedAt)),
        DoubleCellValue(stats.maximum ?? 0),
        TextCellValue(_dateTime(stats.maximumPoint?.recordedAt)),
        DoubleCellValue(stats.average),
        IntCellValue(stats.count),
      ]);
    }

    details.appendRow(<CellValue>[
      TextCellValue('التاريخ'),
      TextCellValue('الوقت'),
      ...report.station.transformers.map((item) => TextCellValue(item.name)),
      TextCellValue('إجمالي المحطة'),
    ]);

    for (final snapshot in report.stationSnapshots) {
      details.appendRow(<CellValue>[
        TextCellValue(DateFormat('yyyy/MM/dd').format(snapshot.recordedAt)),
        TextCellValue(DateFormat('HH:mm').format(snapshot.recordedAt)),
        ...report.station.transformers.map(
          (item) => DoubleCellValue(snapshot.transformerLoads[item.id] ?? 0),
        ),
        DoubleCellValue(snapshot.totalLoad),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('تعذر إنشاء ملف Excel.');
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    await FileSaver.instance.saveFile(
      name: 'station_load_report_$timestamp',
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  static String _period(DateTime? from, DateTime? to) {
    if (from == null && to == null) return 'جميع الفترات';
    if (from != null && to != null) return '${_dateTime(from)} - ${_dateTime(to)}';
    if (from != null) return 'من ${_dateTime(from)}';
    return 'حتى ${_dateTime(to)}';
  }

  static String _dateTime(DateTime? value) => value == null
      ? ''
      : DateFormat('yyyy/MM/dd HH:mm').format(value);
}
