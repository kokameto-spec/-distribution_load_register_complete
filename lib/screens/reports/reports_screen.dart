import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/distributor_controller.dart';
import '../../controllers/load_records_controller.dart';
import '../../core/services/report_excel_service.dart';
import '../../core/services/report_pdf_service.dart';
import '../../models/distributor_model.dart';
import '../../models/load_record.dart';
import '../../models/user_role.dart';
import '../../repositories/saved_report_repository.dart';
import 'saved_reports_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
  });

  @override
  State<ReportsScreen> createState() =>
      _ReportsScreenState();
}

class _ReportsScreenState
    extends State<ReportsScreen> {
  static const List<int> _allCellNumbers =
      <int>[
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

  /*
   * بدل بناء تقرير شهر أو سنة كامل
   * مرة واحدة، نعرض 7 أيام فقط.
   */
  static const int _daysPerPage = 7;

  String? _selectedDistributorId;

  DateTime _fromDate =
      DateTime.now();

  DateTime _toDate =
      DateTime.now();

  int _selectedHour =
      DateTime.now().hour;

  bool _searched = false;

  int _visibleDaysCount =
      _daysPerPage;

  bool get _allDistributors =>
      _selectedDistributorId == null;

  DateTime get _queryFrom {
    if (_allDistributors) {
      return DateTime(
        _fromDate.year,
        _fromDate.month,
        _fromDate.day,
        _selectedHour,
      );
    }

    return DateTime(
      _fromDate.year,
      _fromDate.month,
      _fromDate.day,
    );
  }

  DateTime get _queryTo {
    if (_allDistributors) {
      return DateTime(
        _toDate.year,
        _toDate.month,
        _toDate.day,
        _selectedHour,
        59,
        59,
        999,
      );
    }

    return DateTime(
      _toDate.year,
      _toDate.month,
      _toDate.day,
      23,
      59,
      59,
      999,
    );
  }

  // =========================================================
  // DATE PICKERS
  // =========================================================

  Future<void> _selectFromDate() async {
    final selected =
        await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(
        const Duration(
          days: 365,
        ),
      ),
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    setState(() {
      _fromDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
      );

      if (_toDate.isBefore(
        _fromDate,
      )) {
        _toDate = _fromDate;
      }

      _searched = false;
    });
  }

  Future<void> _selectToDate() async {
    final selected =
        await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime.now().add(
        const Duration(
          days: 365,
        ),
      ),
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    setState(() {
      _toDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
      );

      _searched = false;
    });
  }

  // =========================================================
  // SEARCH
  // =========================================================

  Future<void> _search() async {
    if (_fromDate.isAfter(
      _toDate,
    )) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'تاريخ البداية يجب أن يكون قبل تاريخ النهاية.',
          ),
        ),
      );

      return;
    }

    final controller =
        context.read<
            LoadRecordsController>();

    /*
     * جميع الموزعات:
     *
     * لا نطلب فترة متصلة تشمل 24 ساعة.
     * نطلب فقط الساعة المختارة
     * لكل يوم.
     */
    if (_allDistributors) {
      await controller
          .searchAllDistributorsByHour(
        fromDate:
            _fromDate,
        toDate:
            _toDate,
        hour:
            _selectedHour,
      );
    } else {
      /*
       * موزع واحد:
       * نريد كل ساعات الفترة.
       */
      await controller.search(
        distributorId:
            _selectedDistributorId,
        fromDate: DateTime(
          _fromDate.year,
          _fromDate.month,
          _fromDate.day,
        ),
        toDate: DateTime(
          _toDate.year,
          _toDate.month,
          _toDate.day,
          23,
          59,
          59,
          999,
        ),

        /*
         * حماية من بناء آلاف
         * العناصر في واجهة واحدة.
         */
        limit: 500,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _searched = true;

      _visibleDaysCount =
          _daysPerPage;
    });
  }

  // =========================================================
  // CLEAR
  // =========================================================

  Future<void> _clearSearch() async {
    context
        .read<LoadRecordsController>()
        .clearRecords();

    setState(() {
      _selectedDistributorId =
          null;

      _fromDate =
          DateTime.now();

      _toDate =
          DateTime.now();

      _selectedHour =
          DateTime.now().hour;

      _searched = false;

      _visibleDaysCount =
          _daysPerPage;
    });
  }

  // =========================================================
  // FORMAT
  // =========================================================

  String _formatDate(
    DateTime value,
  ) {
    return DateFormat(
      'yyyy/MM/dd',
    ).format(value);
  }

  String _formatDateTime(
    DateTime value,
  ) {
    return DateFormat(
      'yyyy/MM/dd - HH:mm',
    ).format(value);
  }

  String _dayName(
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

  String _formatHourRange(
    int hour,
  ) {
    final value =
        hour
            .toString()
            .padLeft(
              2,
              '0',
            );

    return 'الساعة $hour '
        '($value:00 - $value:59)';
  }

  // =========================================================
  // DAYS
  // =========================================================

  List<DateTime> _selectedDays() {
    final result =
        <DateTime>[];

    var current =
        DateTime(
      _fromDate.year,
      _fromDate.month,
      _fromDate.day,
    );

    final end =
        DateTime(
      _toDate.year,
      _toDate.month,
      _toDate.day,
    );

    while (!current.isAfter(
      end,
    )) {
      result.add(
        current,
      );

      current = current.add(
        const Duration(
          days: 1,
        ),
      );
    }

    return result;
  }

  // =========================================================
  // MAX / MIN
  // =========================================================

  LoadRecord? _maximumRecord(
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
        result = record;
      }
    }

    return result;
  }

  LoadRecord? _minimumRecord(
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
        result = record;
      }
    }

    return result;
  }

  // =========================================================
  // PDF
  // =========================================================

  Future<void> _printPdf({
    required List<LoadRecord> records,
    required List<Distributor>
        distributors,
  }) async {
    await ReportPdfService.printReport(
      records: records,
      distributors:
          distributors,
      selectedDistributorId:
          _selectedDistributorId,
      selectedDateTime:
          DateTime(
        _fromDate.year,
        _fromDate.month,
        _fromDate.day,
        _selectedHour,
      ),
      fromDate:
          _queryFrom,
      toDate:
          _queryTo,
      allDistributorsHourly:
          _allDistributors,
    );
  }

  Future<void> _sharePdf({
    required List<LoadRecord> records,
    required List<Distributor>
        distributors,
  }) async {
    await ReportPdfService.shareReport(
      records:
          records,
      distributors:
          distributors,
      selectedDistributorId:
          _selectedDistributorId,
      selectedDateTime:
          DateTime(
        _fromDate.year,
        _fromDate.month,
        _fromDate.day,
        _selectedHour,
      ),
      fromDate:
          _queryFrom,
      toDate:
          _queryTo,
      allDistributorsHourly:
          _allDistributors,
    );
  }

  // =========================================================
  // EXCEL
  // =========================================================

  Future<void> _exportExcel({
    required List<LoadRecord> records,
    required List<Distributor>
        distributors,
  }) async {
    try {
      if (records.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'لا توجد بيانات لتصديرها إلى Excel.',
            ),
          ),
        );

        return;
      }

      await ReportExcelService
          .exportReport(
        records:
            records,
        distributors:
            distributors,
        selectedDistributorId:
            _selectedDistributorId,
        selectedDateTime:
            DateTime(
          _fromDate.year,
          _fromDate.month,
          _fromDate.day,
          _selectedHour,
        ),
        fromDate:
            _queryFrom,
        toDate:
            _queryTo,
        allDistributorsHourly:
            _allDistributors,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'تم إنشاء ملف Excel بنجاح.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'تعذر تصدير Excel:\n$error',
          ),
        ),
      );
    }
  }

  // =========================================================
  // SAVE REPORT
  // =========================================================

  Future<void> _saveCurrentReport({
    required List<Distributor>
        distributors,
  }) async {
    final user =
        context
            .read<AuthController>()
            .currentUser;

    if (user == null ||
        user.role !=
            UserRole.president) {
      return;
    }

    final titleController =
        TextEditingController(
      text: _allDistributors
          ? 'تقرير جميع الموزعات '
              '${_formatDate(_fromDate)}'
          : 'تقرير موزع '
              '${_formatDate(_fromDate)}',
    );

    final notesController =
        TextEditingController();

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) {
        return AlertDialog(
          title: const Text(
            'حفظ التقرير',
          ),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                TextField(
                  controller:
                      titleController,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'اسم التقرير',
                    border:
                        OutlineInputBorder(),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                TextField(
                  controller:
                      notesController,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'ملاحظات',
                    border:
                        OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child:
                  const Text(
                'إلغاء',
              ),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              icon:
                  const Icon(
                Icons.save,
              ),
              label:
                  const Text(
                'حفظ',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      titleController.dispose();
      notesController.dispose();

      return;
    }

    String targetId = '';
    String targetName = '';

    if (!_allDistributors &&
        _selectedDistributorId !=
            null) {
      targetId =
          _selectedDistributorId!;

      for (final distributor
          in distributors) {
        if (distributor.id ==
            targetId) {
          targetName =
              distributor.name;

          break;
        }
      }
    }

    try {
      await SavedReportRepository()
          .create(
        title:
            titleController.text,
        reportType:
            _allDistributors
                ? 'all_distributors_hourly'
                : 'single_distributor',
        targetId:
            targetId,
        targetName:
            targetName,
        fromDate:
            _queryFrom,
        toDate:
            _queryTo,
        hour:
            _allDistributors
                ? _selectedHour
                : -1,
        notes:
            notesController.text,
        performedByUid:
            user.uid,
        performedByCode:
            user.code,
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'تم حفظ التقرير بنجاح.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'تعذر حفظ التقرير: '
              '$error',
            ),
          ),
        );
      }
    } finally {
      titleController.dispose();
      notesController.dispose();
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final distributorController =
        context.watch<
            DistributorController>();

    final recordsController =
        context.watch<
            LoadRecordsController>();

    final authController =
        context.watch<
            AuthController>();

    final isPresident =
        authController
                .currentUser
                ?.role ==
            UserRole.president;

    final records =
        recordsController.records;

    final activeDistributors =
        distributorController
            .distributors
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

    /*
     * أهم تحسين أداء:
     *
     * بناء Index مرة واحدة فقط.
     * بدل البحث داخل records
     * لكل خلية × موزع × يوم.
     */
    final index =
        _ReportIndex.build(
      records:
          records,
      hour:
          _selectedHour,
    );

    final selectedDays =
        _selectedDays();

    final visibleCount =
        _visibleDaysCount >
                selectedDays.length
            ? selectedDays.length
            : _visibleDaysCount;

    final visibleDays =
        selectedDays
            .take(
              visibleCount,
            )
            .toList(
              growable: false,
            );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تقارير أحمال الموزعات',
        ),
        actions: [
          if (isPresident)
            IconButton(
              tooltip:
                  'التقارير المحفوظة',
              onPressed: () {
                Navigator.of(context)
                    .push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const SavedReportsScreen(),
                  ),
                );
              },
              icon:
                  const Icon(
                Icons
                    .folder_copy_outlined,
              ),
            ),
          if (isPresident &&
              _searched)
            IconButton(
              tooltip:
                  'حفظ التقرير',
              onPressed: () =>
                  _saveCurrentReport(
                distributors:
                    distributorController
                        .distributors,
              ),
              icon:
                  const Icon(
                Icons.save_outlined,
              ),
            ),
          IconButton(
            tooltip:
                'مشاركة PDF',
            onPressed:
                !_searched ||
                        recordsController
                            .isLoading
                    ? null
                    : () =>
                        _sharePdf(
                          records:
                              records,
                          distributors:
                              distributorController
                                  .distributors,
                        ),
            icon:
                const Icon(
              Icons
                  .picture_as_pdf_outlined,
            ),
          ),
          IconButton(
            tooltip:
                'Excel',
            onPressed:
                !_searched ||
                        recordsController
                            .isLoading
                    ? null
                    : () =>
                        _exportExcel(
                          records:
                              records,
                          distributors:
                              distributorController
                                  .distributors,
                        ),
            icon:
                const Icon(
              Icons
                  .table_view_outlined,
            ),
          ),
          IconButton(
            tooltip:
                'طباعة',
            onPressed:
                !_searched ||
                        recordsController
                            .isLoading
                    ? null
                    : () =>
                        _printPdf(
                          records:
                              records,
                          distributors:
                              distributorController
                                  .distributors,
                        ),
            icon:
                const Icon(
              Icons.print_outlined,
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh:
            _search,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.all(
            14,
          ),
          children: [
            _buildSearchCard(
              distributorController,
              recordsController,
            ),

            const SizedBox(
              height: 14,
            ),

            if (recordsController
                .isLoading)
              const Padding(
                padding:
                    EdgeInsets.all(
                  40,
                ),
                child: Center(
                  child:
                      CircularProgressIndicator(),
                ),
              )
            else if (recordsController
                    .errorMessage !=
                null)
              Card(
                color: Theme.of(context)
                    .colorScheme
                    .errorContainer,
                child: Padding(
                  padding:
                      const EdgeInsets
                          .all(
                    14,
                  ),
                  child: Text(
                    recordsController
                        .errorMessage!,
                  ),
                ),
              )
            else if (!_searched)
              const Card(
                child: Padding(
                  padding:
                      EdgeInsets.all(
                    35,
                  ),
                  child: Text(
                    'اختر بيانات البحث '
                    'ثم اضغط بحث.',
                    textAlign:
                        TextAlign.center,
                  ),
                ),
              )
            else if (_allDistributors)
              ...[
                if (records.isEmpty)
                  const Card(
                    child: Padding(
                      padding:
                          EdgeInsets.all(
                        35,
                      ),
                      child: Text(
                        'لا توجد سجلات '
                        'مطابقة للبحث.',
                        textAlign:
                            TextAlign
                                .center,
                      ),
                    ),
                  )
                else ...[
                  /*
                   * عرض الأيام تدريجيًا
                   * بدل بناء شهر كامل.
                   */
                  for (final day
                      in visibleDays)
                    _buildAllDistributorsReport(
                      day:
                          day,
                      index:
                          index,
                      distributors:
                          activeDistributors,
                    ),

                  if (visibleCount <
                      selectedDays.length)
                    Padding(
                      padding:
                          const EdgeInsets
                              .only(
                        bottom: 20,
                      ),
                      child:
                          FilledButton.icon(
                        onPressed: () {
                          setState(
                            () {
                              _visibleDaysCount +=
                                  _daysPerPage;
                            },
                          );
                        },
                        icon:
                            const Icon(
                          Icons
                              .expand_more,
                        ),
                        label: Text(
                          'عرض أيام إضافية '
                          '(${selectedDays.length - visibleCount} متبقي)',
                        ),
                      ),
                    ),
                ],
              ]
            else
              _buildSingleDistributorReport(
                records:
                    records,
                distributors:
                    distributorController
                        .distributors,
                index:
                    index,
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // SEARCH CARD
  // =========================================================

  Widget _buildSearchCard(
    DistributorController
        distributors,
    LoadRecordsController
        records,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          14,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .stretch,
          children: [
            Text(
              'البحث والتصفية',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
            ),

            const SizedBox(
              height: 14,
            ),

            DropdownButtonFormField<
                String>(
              value:
                  _selectedDistributorId,
              decoration:
                  const InputDecoration(
                labelText:
                    'الموزع',
                prefixIcon:
                    Icon(
                  Icons.account_tree,
                ),
                border:
                    OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<
                    String>(
                  value: null,
                  child: Text(
                    'جميع الموزعات',
                  ),
                ),
                ...distributors
                    .distributors
                    .map(
                  (distributor) {
                    return DropdownMenuItem<
                        String>(
                      value:
                          distributor.id,
                      child: Text(
                        '${distributor.name} - '
                        '${distributor.code}',
                      ),
                    );
                  },
                ),
              ],
              onChanged:
                  records.isLoading
                      ? null
                      : (value) {
                          setState(
                            () {
                              _selectedDistributorId =
                                  value;

                              _searched =
                                  false;

                              _visibleDaysCount =
                                  _daysPerPage;
                            },
                          );
                        },
            ),

            const SizedBox(
              height: 14,
            ),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DateSelector(
                  title:
                      'من يوم',
                  value:
                      _formatDate(
                    _fromDate,
                  ),
                  onPressed:
                      records
                              .isLoading
                          ? null
                          : _selectFromDate,
                ),
                _DateSelector(
                  title:
                      'إلى يوم',
                  value:
                      _formatDate(
                    _toDate,
                  ),
                  onPressed:
                      records
                              .isLoading
                          ? null
                          : _selectToDate,
                ),
                if (_allDistributors)
                  SizedBox(
                    width: 240,
                    child:
                        DropdownButtonFormField<
                            int>(
                      value:
                          _selectedHour,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'الساعة الكاملة',
                        prefixIcon:
                            Icon(
                          Icons
                              .schedule,
                        ),
                        border:
                            OutlineInputBorder(),
                      ),
                      items:
                          List.generate(
                        24,
                        (hour) {
                          return DropdownMenuItem<
                              int>(
                            value:
                                hour,
                            child:
                                Text(
                              _formatHourRange(
                                hour,
                              ),
                            ),
                          );
                        },
                      ),
                      onChanged:
                          records
                                  .isLoading
                              ? null
                              : (value) {
                                  setState(
                                    () {
                                      _selectedHour =
                                          value ??
                                              0;

                                      _searched =
                                          false;

                                      _visibleDaysCount =
                                          _daysPerPage;
                                    },
                                  );
                                },
                    ),
                  ),
              ],
            ),

            if (_allDistributors)
              ...[
                const SizedBox(
                  height: 10,
                ),
                Text(
                  'سيتم تحميل '
                  '${_formatHourRange(_selectedHour)} '
                  'فقط لكل يوم، '
                  'وليس جميع ساعات الفترة.',
                  textAlign:
                      TextAlign.center,
                ),
              ],

            const SizedBox(
              height: 14,
            ),

            Wrap(
              spacing: 10,
              alignment:
                  WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      records.isLoading
                          ? null
                          : _clearSearch,
                  icon:
                      const Icon(
                    Icons.clear,
                  ),
                  label:
                      const Text(
                    'مسح البحث',
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      records.isLoading
                          ? null
                          : _search,
                  icon:
                      const Icon(
                    Icons.search,
                  ),
                  label:
                      const Text(
                    'بحث',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // ALL DISTRIBUTORS REPORT
  // =========================================================

  Widget _buildAllDistributorsReport({
    required DateTime day,
    required _ReportIndex index,
    required List<Distributor>
        distributors,
  }) {
    final groups =
        <List<Distributor>>[];

    for (var i = 0;
        i < distributors.length;
        i += 6) {
      final end =
          i + 6 <
                  distributors.length
              ? i + 6
              : distributors.length;

      groups.add(
        distributors.sublist(
          i,
          end,
        ),
      );
    }

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 18,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          10,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .stretch,
          children: [
            Text(
              'أحمال خلايا الموزعات',
              textAlign:
                  TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
            ),

            const SizedBox(
              height: 5,
            ),

            Text(
              'اليوم: '
              '${_dayName(day)}    '
              'التاريخ: '
              '${_formatDate(day)}    '
              'الفترة: '
              '${_formatHourRange(_selectedHour)}',
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(
              height: 12,
            ),

            if (groups.isEmpty)
              const Padding(
                padding:
                    EdgeInsets.all(
                  25,
                ),
                child: Text(
                  'لا توجد موزعات نشطة.',
                  textAlign:
                      TextAlign.center,
                ),
              )
            else
              for (final group
                  in groups)
                Padding(
                  padding:
                      const EdgeInsets
                          .only(
                    bottom: 14,
                  ),
                  child:
                      _buildDistributorGrid(
                    day:
                        day,
                    index:
                        index,
                    distributors:
                        group,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // GRID
  // =========================================================

  Widget _buildDistributorGrid({
    required DateTime day,
    required _ReportIndex index,
    required List<Distributor>
        distributors,
  }) {
    final tableWidth =
        90.0 +
            distributors.length *
                210.0;

    return SingleChildScrollView(
      scrollDirection:
          Axis.horizontal,
      reverse:
          true,
      child: SizedBox(
        width:
            tableWidth,
        child: Table(
          border:
              TableBorder.all(
            color:
                Colors.black54,
            width:
                .7,
          ),
          columnWidths: {
            0:
                const FixedColumnWidth(
              90,
            ),
            for (var i = 0;
                i <
                    distributors.length *
                        3;
                i++)
              i + 1:
                  const FixedColumnWidth(
                70,
              ),
          },
          children: [
            TableRow(
              children: [
                _tableHeader(
                  'الخلايا',
                ),
                for (final distributor
                    in distributors)
                  ...[
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

            TableRow(
              children: [
                _tableHeader(
                  'رقم الخلية',
                ),
                for (final _
                    in distributors)
                  ...[
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

            for (final cell
                in _allCellNumbers)
              TableRow(
                children: [
                  _tableValue(
                    '$cell',
                    bold:
                        true,
                  ),

                  for (final distributor
                      in distributors)
                    ...[
                      _tableValue(
                        index
                            .currentCellValue(
                          day:
                              day,
                          distributorId:
                              distributor.id,
                          cellNumber:
                              cell,
                        ),
                      ),
                      _tableValue(
                        index
                            .minimumCellValue(
                          distributorId:
                              distributor.id,
                          cellNumber:
                              cell,
                        ),
                      ),
                      _tableValue(
                        index
                            .maximumCellValue(
                          distributorId:
                              distributor.id,
                          cellNumber:
                              cell,
                        ),
                      ),
                    ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(
    String text,
  ) {
    return Padding(
      padding:
          const EdgeInsets.all(
        5,
      ),
      child: Text(
        text,
        textAlign:
            TextAlign.center,
        style:
            const TextStyle(
          fontSize:
              11,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }

  Widget _tableValue(
    String text, {
    bool bold = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets
              .symmetric(
        vertical:
            5,
        horizontal:
            2,
      ),
      child: Text(
        text,
        textAlign:
            TextAlign.center,
        style: TextStyle(
          fontWeight:
              bold
                  ? FontWeight.bold
                  : FontWeight.normal,
        ),
      ),
    );
  }

  // =========================================================
  // SINGLE DISTRIBUTOR
  // =========================================================

  Widget _buildSingleDistributorReport({
    required List<LoadRecord> records,
    required List<Distributor>
        distributors,
    required _ReportIndex index,
  }) {
    Distributor? distributor;

    for (final item
        in distributors) {
      if (item.id ==
          _selectedDistributorId) {
        distributor =
            item;

        break;
      }
    }

    if (records.isEmpty) {
      return const Card(
        child: Padding(
          padding:
              EdgeInsets.all(
            35,
          ),
          child: Text(
            'لا توجد سجلات مطابقة للبحث.',
            textAlign:
                TextAlign.center,
          ),
        ),
      );
    }

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

    final maximum =
        _maximumRecord(
      sorted,
    );

    final minimum =
        _minimumRecord(
      sorted,
    );

    final distributorId =
        _selectedDistributorId ??
            '';

    /*
     * لا نبني مئات ExpansionTile
     * دفعة واحدة على جهاز قديم.
     */
    final visibleRecords =
        sorted.length > 100
            ? sorted
                .take(100)
                .toList()
            : sorted;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment
              .stretch,
      children: [
        Card(
          child: Padding(
            padding:
                const EdgeInsets
                    .all(
              14,
            ),
            child: Column(
              children: [
                Text(
                  distributor
                          ?.name ??
                      sorted
                          .first
                          .distributorName,
                  style:
                      Theme.of(
                    context,
                  )
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  'نوع الموزع: '
                  '${distributor == null || distributor.type.trim().isEmpty ? 'غير محدد' : distributor.type}',
                ),

                const SizedBox(
                  height: 12,
                ),

                if (maximum !=
                    null)
                  Text(
                    'أقصى حمل: '
                    '${maximum.totalLoad.toStringAsFixed(2)} أمبير'
                    ' — '
                    '${_formatDateTime(maximum.recordedAt)}',
                  ),

                if (minimum !=
                    null)
                  Text(
                    'أقل حمل: '
                    '${minimum.totalLoad.toStringAsFixed(2)} أمبير'
                    ' — '
                    '${_formatDateTime(minimum.recordedAt)}',
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        Card(
          child: Padding(
            padding:
                const EdgeInsets
                    .all(
              12,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: [
                Text(
                  'أقصى وأقل حمل '
                  'لكل خلية خلال فترة البحث',
                  textAlign:
                      TextAlign.center,
                  style:
                      Theme.of(
                    context,
                  )
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
                ),

                const SizedBox(
                  height: 10,
                ),

                SingleChildScrollView(
                  scrollDirection:
                      Axis.horizontal,
                  reverse:
                      true,
                  child: Table(
                    defaultColumnWidth:
                        const FixedColumnWidth(
                      110,
                    ),
                    border:
                        TableBorder.all(
                      color:
                          Colors.black54,
                      width:
                          .7,
                    ),
                    children: [
                      TableRow(
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
                          in _allCellNumbers)
                        TableRow(
                          children: [
                            _tableValue(
                              '$cell',
                              bold:
                                  true,
                            ),
                            _tableValue(
                              index
                                  .minimumCellValue(
                                distributorId:
                                    distributorId,
                                cellNumber:
                                    cell,
                              ),
                            ),
                            _tableValue(
                              index
                                  .maximumCellValue(
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
              ],
            ),
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        if (sorted.length >
            visibleRecords.length)
          Padding(
            padding:
                const EdgeInsets
                    .only(
              bottom: 8,
            ),
            child: Text(
              'يتم عرض أحدث '
              '${visibleRecords.length} سجل '
              'على الشاشة لحماية الأداء. '
              'الطباعة وExcel يستخدمان نتائج البحث المحملة.',
              textAlign:
                  TextAlign.center,
            ),
          ),

        for (final record
            in visibleRecords)
          Card(
            child:
                ExpansionTile(
              title:
                  Text(
                '${record.totalLoad.toStringAsFixed(2)} أمبير',
              ),
              subtitle:
                  Text(
                _formatDateTime(
                  record.recordedAt,
                ),
              ),
              children: [
                Padding(
                  padding:
                      const EdgeInsets
                          .all(
                    12,
                  ),
                  child: Wrap(
                    spacing:
                        8,
                    runSpacing:
                        8,
                    children:
                        _allCellNumbers
                            .map(
                      (cell) {
                        return Chip(
                          label:
                              Text(
                            'خلية $cell: '
                            '${(record.cellValues[cell] ?? 0).toStringAsFixed(1)}',
                          ),
                        );
                      },
                    ).toList(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ===========================================================
// REPORT INDEX
// ===========================================================

class _ReportIndex {
  _ReportIndex({
    required this.latestByDayAndDistributor,
    required this.cellRanges,
  });

  final Map<String, LoadRecord>
      latestByDayAndDistributor;

  final Map<String, _CellRange>
      cellRanges;

  static _ReportIndex build({
    required List<LoadRecord> records,
    required int hour,
  }) {
    final latest =
        <String, LoadRecord>{};

    final ranges =
        <String, _MutableCellRange>{};

    /*
     * دورة واحدة فقط على البيانات.
     */
    for (final record
        in records) {
      final day =
          record.recordedAt;

      final dayKey =
          '${day.year}-'
          '${day.month}-'
          '${day.day}-'
          '${record.distributorId}';

      /*
       * السجل الحالي لليوم/الموزع.
       */
      if (record.recordedAt.hour ==
          hour) {
        final old =
            latest[dayKey];

        if (old == null ||
            record.recordedAt
                .isAfter(
              old.recordedAt,
            )) {
          latest[dayKey] =
              record;
        }
      }

      /*
       * Min / Max لكل خلية
       * ولكل موزع خلال كامل فترة البحث.
       */
      for (final entry
          in record
              .cellValues
              .entries) {
        final rangeKey =
            '${record.distributorId}'
            '-${entry.key}';

        final range =
            ranges.putIfAbsent(
          rangeKey,
          () =>
              _MutableCellRange(),
        );

        range.add(
          entry.value,
        );
      }
    }

    final immutableRanges =
        <String, _CellRange>{};

    for (final entry
        in ranges.entries) {
      immutableRanges[
          entry.key] =
          _CellRange(
        minimum:
            entry.value.minimum,
        maximum:
            entry.value.maximum,
      );
    }

    return _ReportIndex(
      latestByDayAndDistributor:
          latest,
      cellRanges:
          immutableRanges,
    );
  }

  String currentCellValue({
    required DateTime day,
    required String distributorId,
    required int cellNumber,
  }) {
    final key =
        '${day.year}-'
        '${day.month}-'
        '${day.day}-'
        '$distributorId';

    final record =
        latestByDayAndDistributor[
            key];

    if (record == null) {
      return 'لم يسجل';
    }

    return (record
                .cellValues[
            cellNumber] ??
            0)
        .toStringAsFixed(
      1,
    );
  }

  String minimumCellValue({
    required String distributorId,
    required int cellNumber,
  }) {
    final range =
        cellRanges[
            '$distributorId-$cellNumber'];

    if (range?.minimum ==
        null) {
      return '—';
    }

    return range!.minimum!
        .toStringAsFixed(
      1,
    );
  }

  String maximumCellValue({
    required String distributorId,
    required int cellNumber,
  }) {
    final range =
        cellRanges[
            '$distributorId-$cellNumber'];

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

class _MutableCellRange {
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

class _CellRange {
  const _CellRange({
    required this.minimum,
    required this.maximum,
  });

  final double? minimum;
  final double? maximum;
}

// ===========================================================
// DATE SELECTOR
// ===========================================================

class _DateSelector
    extends StatelessWidget {
  const _DateSelector({
    required this.title,
    required this.value,
    required this.onPressed,
  });

  final String title;
  final String value;

  final VoidCallback?
      onPressed;

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      width: 220,
      child:
          OutlinedButton(
        onPressed:
            onPressed,
        style:
            OutlinedButton
                .styleFrom(
          padding:
              const EdgeInsets.all(
            15,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.date_range,
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Text(
                '$title\n$value',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
