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

  /*
   * 6 موزعات في كل جدول.
   * جدولان داخل الصفحة = 12 موزع في الصفحة.
   *
   * بهذه الطريقة نستغل ارتفاع ورقة A4 Landscape
   * بدون تصغير الأعمدة لدرجة تجعلها غير مقروءة.
   */
  static const int _distributorsPerTable = 6;
  static const int _tablesPerPage = 2;
  static const int _distributorsPerPage =
      _distributorsPerTable * _tablesPerPage;

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

    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    );

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
          toDate ??
          start;

      final activeDistributors =
          distributors
              .where(
                (item) =>
                    item.active,
              )
              .toList()
            ..sort(
              (a, b) =>
                  a.name.compareTo(
                b.name,
              ),
            );

      final pageGroups =
          _splitDistributorsForPages(
        activeDistributors,
      );

      /*
       * لو مفيش موزعات نشطة،
       * نطبع صفحة واحدة توضح ذلك.
       */
      if (pageGroups.isEmpty) {
        pageGroups.add(
          <Distributor>[],
        );
      }

      for (final day
          in _daysBetween(
        start,
        end,
      )) {
        for (final pageDistributors
            in pageGroups) {
          document.addPage(
            pw.Page(
              pageFormat:
                  PdfPageFormat.a4.landscape,

              /*
               * هوامش صغيرة للاستفادة من الورقة.
               */
              margin:
                  const pw.EdgeInsets.fromLTRB(
                9,
                7,
                9,
                7,
              ),

              theme:
                  theme,

              build:
                  (_) {
                return _buildAllDistributorsPage(
                  day:
                      day,
                  hour:
                      hour,
                  index:
                      index,
                  distributors:
                      pageDistributors,
                  logoBytes:
                      logoBytes,
                );
              },
            ),
          );
        }
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
              const pw.EdgeInsets.fromLTRB(
            12,
            9,
            12,
            9,
          ),

          theme:
              theme,

          header:
              (_) =>
                  _buildCompactHeader(
            logoBytes,
            title:
                'أحمال الموزع',
          ),

          footer:
              (_) =>
                  _buildCompactFooter(),

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
    String? fileName,
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
          '${_effectiveFileName(fileName)}.pdf',
      format:
          PdfPageFormat.a4.landscape,
      onLayout:
          (_) async =>
              bytes,
    );
  }

  // =========================================================
  // SAVE
  // =========================================================

  static Future<void> saveReport({
    required List<LoadRecord> records,
    required List<Distributor> distributors,
    String? fileName,
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

    await FileSaver.instance.saveAs(
      name:
          _effectiveFileName(
        fileName,
      ),
      bytes:
          bytes,
      fileExtension:
          'pdf',
      mimeType:
          MimeType.pdf,
    );
  }

  // =========================================================
  // SHARE
  // =========================================================

  static Future<void> shareReport({
    required List<LoadRecord> records,
    required List<Distributor> distributors,
    String? fileName,
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
          '${_effectiveFileName(fileName)}.pdf',
    );
  }

  // =========================================================
  // ALL DISTRIBUTORS PAGE
  // =========================================================

  static pw.Widget _buildAllDistributorsPage({
    required DateTime day,
    required int hour,
    required _ReportPdfIndex index,
    required List<Distributor> distributors,
    required Uint8List? logoBytes,
  }) {
    /*
     * الصفحة الواحدة تحتوي بحد أقصى على 12 موزع:
     *
     * الجدول الأول: حتى 6 موزعات.
     * الجدول الثاني: حتى 6 موزعات.
     */
    final firstEnd =
        distributors.length >
                _distributorsPerTable
            ? _distributorsPerTable
            : distributors.length;

    final firstGroup =
        distributors.sublist(
      0,
      firstEnd,
    );

    final secondGroup =
        distributors.length >
                _distributorsPerTable
            ? distributors.sublist(
                _distributorsPerTable,
              )
            : <Distributor>[];

    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.stretch,
      children: [
        _buildCompactHeader(
          logoBytes,
          title:
              'أحمال خلايا الموزعات',
        ),

        pw.SizedBox(
          height:
              2,
        ),

        _buildPeriodRow(
          day:
              day,
          hour:
              hour,
        ),

        pw.SizedBox(
          height:
              4,
        ),

        if (firstGroup.isEmpty)
          pw.Expanded(
            child:
                pw.Center(
              child:
                  pw.Text(
                'لا توجد موزعات نشطة.',
              ),
            ),
          )
        else if (secondGroup.isEmpty)
          /*
           * من 1 إلى 6 موزعات:
           * جدول واحد يملأ المساحة المتاحة بالكامل رأسيًا.
           */
          pw.Expanded(
            child: _buildDistributorGrid(
              day: day,
              index: index,
              distributors: firstGroup,
              fillHeight: true,
            ),
          )
        else ...[
          /*
           * من 7 إلى 12 موزع:
           * جدولان متساويان تقريبًا في الارتفاع.
           */
          pw.Expanded(
            child: _buildDistributorGrid(
              day: day,
              index: index,
              distributors: firstGroup,
              fillHeight: true,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Expanded(
            child: _buildDistributorGrid(
              day: day,
              index: index,
              distributors: secondGroup,
              fillHeight: true,
            ),
          ),
        ],

        pw.SizedBox(
          height:
              2,
        ),

        _buildCompactFooter(),
      ],
    );
  }

  // =========================================================
  // DISTRIBUTOR GRID
  // =========================================================

  static pw.Widget _buildDistributorGrid({
    required DateTime day,
    required _ReportPdfIndex index,
    required List<Distributor> distributors,
    bool fillHeight = false,
  }) {
    final rows =
        <pw.TableRow>[
      pw.TableRow(
        children: [
          _tableHeader(
            'الخلايا',
          ),

          for (final distributor
              in distributors) ...[
            _tableHeader(
              '${distributor.name}\n'
              '${distributor.type.trim().isEmpty ? 'غير محدد' : distributor.type}',
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
              'أقل',
            ),
            _tableHeader(
              'أقصى',
            ),
          ],
        ],
      ),
    ];

    for (final cell
        in cellNumbers) {
      rows.add(
        pw.TableRow(
          children: [
            _tableValue(
              '$cell',
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
                  cellNumber:
                      cell,
                ),
                bold:
                    true,
              ),

              _tableValue(
                index.minimumValue(
                  distributorId:
                      distributor.id,
                  cellNumber:
                      cell,
                ),
              ),

              _tableValue(
                index.maximumValue(
                  distributorId:
                      distributor.id,
                  cellNumber:
                      cell,
                ),
              ),
            ],
          ],
        ),
      );
    }

    /*
     * الجدول نفسه لا يُقسم لأننا نستخدم pw.Page
     * وليس MultiPage في تقرير جميع الموزعات.
     */
    final table = pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Table(
        border: pw.TableBorder.all(
          width: .42,
          color: PdfColors.grey700,
        ),
        columnWidths: <int, pw.TableColumnWidth>{
          0: const pw.FlexColumnWidth(1.0),
          for (var i = 0; i < distributors.length * 3; i++)
            i + 1: const pw.FlexColumnWidth(.82),
        },
        children: rows,
      ),
    );

    if (!fillHeight) {
      return table;
    }

    /*
     * ملء المساحة المتاحة رأسيًا بدون تغيير عرض الأعمدة.
     * FittedBox يحافظ على الجدول كوحدة واحدة داخل الصفحة.
     */
    return pw.Container(
      alignment: pw.Alignment.center,
      child: pw.FittedBox(
        fit: pw.BoxFit.fill,
        child: table,
      ),
    );
  }

  // =========================================================
  // SINGLE DISTRIBUTOR
  // =========================================================

  static List<pw.Widget> _buildSingleDistributor({
    required List<LoadRecord> records,
    required Distributor? distributor,
    required _ReportPdfIndex index,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    final sorted =
        List<LoadRecord>.from(
      records,
    )
          ..sort(
            (a, b) =>
                b.recordedAt
                    .compareTo(
              a.recordedAt,
            ),
          );

    if (sorted.isEmpty) {
      return <pw.Widget>[
        pw.Center(
          child:
              pw.Text(
            'لا توجد سجلات مطابقة.',
          ),
        ),
      ];
    }

    final distributorId =
        distributor?.id ??
        sorted.first.distributorId;

    final maxRecord =
        sorted.reduce(
      (a, b) =>
          a.totalLoad >=
                  b.totalLoad
              ? a
              : b,
    );

    final minRecord =
        sorted.reduce(
      (a, b) =>
          a.totalLoad <=
                  b.totalLoad
              ? a
              : b,
    );

    return <pw.Widget>[
      pw.Directionality(
        textDirection:
            pw.TextDirection.rtl,
        child:
            pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(
            vertical:
                3,
          ),
          child:
              pw.Row(
            mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                distributor?.name ??
                    sorted.first.distributorName,
                style:
                    pw.TextStyle(
                  fontSize:
                      12,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),

              if (fromDate != null &&
                  toDate != null)
                pw.Text(
                  'من ${_formatDate(fromDate)} إلى ${_formatDate(toDate)}',
                  style:
                      const pw.TextStyle(
                    fontSize:
                        7,
                  ),
                ),

              pw.Text(
                'أقصى: ${maxRecord.totalLoad.toStringAsFixed(2)} A'
                '   |   '
                'أقل: ${minRecord.totalLoad.toStringAsFixed(2)} A',
                style:
                    pw.TextStyle(
                  fontSize:
                      7,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),

      pw.SizedBox(
        height:
            4,
      ),

      /*
       * ملخص أقل/أقصى حمل لكل خلية.
       */
      pw.Directionality(
        textDirection:
            pw.TextDirection.rtl,
        child:
            pw.Table(
          border:
              pw.TableBorder.all(
            width:
                .4,
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

      pw.SizedBox(
        height:
            5,
      ),

      pw.Text(
        'تفاصيل التسجيلات',
        style:
            pw.TextStyle(
          fontSize:
              8,
          fontWeight:
              pw.FontWeight.bold,
        ),
      ),

      pw.SizedBox(
        height:
            3,
      ),

      pw.Directionality(
        textDirection:
            pw.TextDirection.rtl,
        child:
            pw.Table(
          border:
              pw.TableBorder.all(
            width:
                .35,
          ),

          children: [
            pw.TableRow(
              children: [
                _smallHeader(
                  'التاريخ',
                ),
                _smallHeader(
                  'الوقت',
                ),
                _smallHeader(
                  'المدخل',
                ),
                _smallHeader(
                  'الإجمالي',
                ),

                for (final cell
                    in cellNumbers)
                  _smallHeader(
                    '$cell',
                  ),
              ],
            ),

            for (final record
                in sorted)
              pw.TableRow(
                children: [
                  _smallValue(
                    _formatDate(
                      record.recordedAt,
                    ),
                  ),

                  _smallValue(
                    DateFormat(
                      'HH:mm',
                    ).format(
                      record.recordedAt,
                    ),
                  ),

                  _smallValue(
                    record.operatorName,
                  ),

                  _smallValue(
                    record.totalLoad
                        .toStringAsFixed(
                      1,
                    ),
                  ),

                  for (final cell
                      in cellNumbers)
                    _smallValue(
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
    ];
  }

  // =========================================================
  // COMPACT HEADER
  // =========================================================

  static pw.Widget _buildCompactHeader(
    Uint8List? logoBytes, {
    required String title,
  }) {
    /*
     * هيدر أفقي رفيع جدًا:
     *
     * الشركة | عنوان التقرير | اللوجو
     *
     * بدل الهيدر القديم الكبير.
     */
    return pw.Directionality(
      textDirection:
          pw.TextDirection.rtl,
      child:
          pw.Container(
        height:
            29,
        child:
            pw.Row(
          crossAxisAlignment:
              pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(
              width:
                  180,
              child:
                  pw.Text(
                'شركة جنوب القاهرة لتوزيع الكهرباء'
                '  -  قطاع التحكمات والوقاية'
                '  -  تحكم 26 يوليو',
                maxLines:
                    2,
                style:
                    pw.TextStyle(
                  fontSize:
                      5.6,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),
            ),

            pw.Expanded(
              child:
                  pw.Text(
                title,
                textAlign:
                    pw.TextAlign.center,
                style:
                    pw.TextStyle(
                  fontSize:
                      12,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),
            ),

            pw.SizedBox(
              width:
                  70,
              child:
                  logoBytes == null
                      ? pw.SizedBox()
                      : pw.Align(
                          alignment:
                              pw.Alignment.centerLeft,
                          child:
                              pw.Image(
                            pw.MemoryImage(
                              logoBytes,
                            ),
                            width:
                                45,
                            height:
                                25,
                            fit:
                                pw.BoxFit.contain,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // COMPACT FOOTER
  // =========================================================

  static pw.Widget _buildCompactFooter() {
    return pw.Directionality(
      textDirection:
          pw.TextDirection.rtl,
      child:
          pw.Container(
        height:
            22,
        child:
            pw.Row(
          mainAxisAlignment:
              pw.MainAxisAlignment.spaceAround,
          children: [
            _compactSignature(
              'مدخل البيانات',
            ),
            _compactSignature(
              'إعداد',
            ),
            _compactSignature(
              'مدير التشغيل',
            ),
            _compactSignature(
              'اعتماد المدير العام',
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _compactSignature(
    String title,
  ) {
    return pw.Row(
      children: [
        pw.Text(
          '$title: ',
          style:
              const pw.TextStyle(
            fontSize:
                5.3,
          ),
        ),

        pw.Text(
          '................',
          style:
              const pw.TextStyle(
            fontSize:
                5,
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
    final h =
        hour
            .toString()
            .padLeft(
              2,
              '0',
            );

    return pw.Directionality(
      textDirection:
          pw.TextDirection.rtl,
      child:
          pw.Text(
        '${_dayName(day)}'
        '  |  '
        '${_formatDate(day)}'
        '  |  '
        'الساعة $h:00 - $h:59',
        textAlign:
            pw.TextAlign.center,
        style:
            pw.TextStyle(
          fontSize:
              6.7,
          fontWeight:
              pw.FontWeight.bold,
        ),
      ),
    );
  }

  // =========================================================
  // TABLE CELLS
  // =========================================================

  static pw.Widget _tableHeader(
    String text,
  ) {
    return pw.Container(
      alignment:
          pw.Alignment.center,
      padding:
          const pw.EdgeInsets.symmetric(
        vertical:
            1.5,
        horizontal:
            1,
      ),
      child:
          pw.Text(
        text,
        maxLines:
            2,
        textAlign:
            pw.TextAlign.center,
        style:
            pw.TextStyle(
          fontSize:
              5.2,
          fontWeight:
              pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _tableValue(
    String text, {
    bool bold = false,
  }) {
    return pw.Container(
      alignment:
          pw.Alignment.center,
      padding:
          const pw.EdgeInsets.symmetric(
        vertical:
            1.6,
        horizontal:
            .7,
      ),
      child:
          pw.Text(
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
        ),
      ),
    );
  }

  static pw.Widget _smallHeader(
    String text,
  ) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.all(
        1.2,
      ),
      child:
          pw.Text(
        text,
        textAlign:
            pw.TextAlign.center,
        style:
            pw.TextStyle(
          fontSize:
              4.6,
          fontWeight:
              pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _smallValue(
    String text,
  ) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.all(
        1,
      ),
      child:
          pw.Text(
        text,
        textAlign:
            pw.TextAlign.center,
        style:
            const pw.TextStyle(
          fontSize:
              4.5,
        ),
      ),
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================

  static Future<Uint8List?> _loadLogoBytes() async {
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

  static List<List<Distributor>>
      _splitDistributorsForPages(
    List<Distributor> distributors,
  ) {
    final result =
        <List<Distributor>>[];

    for (var start = 0;
        start < distributors.length;
        start += _distributorsPerPage) {
      final end =
          start + _distributorsPerPage <
                  distributors.length
              ? start +
                  _distributorsPerPage
              : distributors.length;

      result.add(
        distributors.sublist(
          start,
          end,
        ),
      );
    }

    return result;
  }

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
          days:
              1,
        ),
      );
    }

    return result;
  }

  static Distributor? _findDistributor(
    List<Distributor> distributors,
    String? id,
  ) {
    if (id == null ||
        id.isEmpty) {
      return null;
    }

    for (final distributor
        in distributors) {
      if (distributor.id ==
          id) {
        return distributor;
      }
    }

    return null;
  }

  static String _effectiveFileName(
    String? value,
  ) {
    final name =
        value?.trim() ??
        '';

    return name.isEmpty
        ? 'A7mal_ElMoz3at'
        : name;
  }

  static String _formatDate(
    DateTime value,
  ) {
    return DateFormat(
      'dd-MM-yyyy',
    ).format(
      value,
    );
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

    return names[
            value.weekday] ??
        '';
  }
}

// ===========================================================
// PDF INDEX
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

    final mutable =
        <String, _MutablePdfCellRange>{};

    for (final record
        in records) {
      final d =
          record.recordedAt;

      /*
       * مهم جدًا:
       *
       * نتائج البحث للساعة المطلوبة وصلت بالفعل.
       * لذلك لا نضيف d.hour للمفتاح.
       *
       * هذا يحل حالة:
       * أقل/أقصى يظهران لكن الحمل الحالي يظهر "لم يسجل"
       * بسبب اختلاف TimeZone على Windows.
       */
      final latestKey =
          '${record.distributorId}|'
          '${d.year}|'
          '${d.month}|'
          '${d.day}';

      final old =
          latest[
              latestKey];

      if (old == null ||
          record.recordedAt
              .isAfter(
            old.recordedAt,
          )) {
        latest[
            latestKey] =
            record;
      }

      for (final entry
          in record.cellValues.entries) {
        final key =
            '${record.distributorId}|'
            '${entry.key}';

        mutable
            .putIfAbsent(
              key,
              _MutablePdfCellRange.new,
            )
            .add(
              entry.value,
            );
      }
    }

    return _ReportPdfIndex(
      latest:
          latest,

      ranges: {
        for (final entry
            in mutable.entries)
          entry.key:
              _PdfCellRange(
            minimum:
                entry.value.minimum,
            maximum:
                entry.value.maximum,
          ),
      },
    );
  }

  String currentValue({
    required String distributorId,
    required DateTime day,
    required int cellNumber,
  }) {
    final key =
        '$distributorId|'
        '${day.year}|'
        '${day.month}|'
        '${day.day}';

    final record =
        latest[
            key];

    if (record == null) {
      return 'لم يسجل';
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
    final value =
        ranges[
                '$distributorId|$cellNumber']
            ?.minimum;

    return value == null
        ? '—'
        : value.toStringAsFixed(
            1,
          );
  }

  String maximumValue({
    required String distributorId,
    required int cellNumber,
  }) {
    final value =
        ranges[
                '$distributorId|$cellNumber']
            ?.maximum;

    return value == null
        ? '—'
        : value.toStringAsFixed(
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
    this.minimum,
    this.maximum,
  });

  final double? minimum;
  final double? maximum;
}
