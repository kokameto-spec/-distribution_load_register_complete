import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/distributor_controller.dart';
import '../../controllers/load_records_controller.dart';
import '../../core/services/report_pdf_service.dart';
import '../../models/distributor_model.dart';
import '../../models/load_record.dart';
import '../../models/saved_report.dart';
import '../../models/user_role.dart';
import '../../repositories/saved_report_repository.dart';

class SavedReportsScreen
    extends StatefulWidget {
  const SavedReportsScreen({
    super.key,
  });

  @override
  State<SavedReportsScreen>
      createState() =>
          _SavedReportsScreenState();
}

class _SavedReportsScreenState
    extends State<SavedReportsScreen> {
  final SavedReportRepository _repository =
      SavedReportRepository();

  late Stream<List<SavedReport>>
      _reportsStream;

  bool _busy = false;

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();

    _reportsStream =
        _repository.watchAll();
  }

  // =========================================================
  // REFRESH
  // =========================================================

  Future<void> _refresh() async {
    setState(() {
      _reportsStream =
          _repository.watchAll();
    });

    await Future<void>.delayed(
      const Duration(
        milliseconds: 200,
      ),
    );
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

  String _hourText(
    int hour,
  ) {
    if (hour < 0 ||
        hour > 23) {
      return 'كل الساعات';
    }

    final text =
        hour.toString().padLeft(
      2,
      '0',
    );

    return '$text:00 - $text:59';
  }

  // =========================================================
  // TYPE
  // =========================================================

  String _reportTypeName(
    SavedReport report,
  ) {
    switch (report.reportType) {
      case 'all_distributors_hourly':
        return 'جميع الموزعات';

      case 'single_distributor':
        return 'موزع واحد';

      case 'station':
        return 'محطة محولات';

      default:
        return report.reportType;
    }
  }

  // =========================================================
  // PRESIDENT
  // =========================================================

  bool _isPresident() {
    final user =
        context
            .read<AuthController>()
            .currentUser;

    return user != null &&
        user.role ==
            UserRole.president;
  }

  // =========================================================
  // EDIT
  // =========================================================

  Future<void> _editReport(
    SavedReport report,
  ) async {
    if (!_isPresident() ||
        _busy) {
      return;
    }

    final titleController =
        TextEditingController(
      text: report.title,
    );

    final notesController =
        TextEditingController(
      text: report.notes,
    );

    final result =
        await showDialog<
            Map<String, String>>(
      context: context,
      builder:
          (dialogContext) {
        return AlertDialog(
          title:
              const Text(
            'تعديل التقرير المحفوظ',
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
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
                  const Text(
                'إلغاء',
              ),
            ),

            FilledButton.icon(
              onPressed: () {
                final title =
                    titleController
                        .text
                        .trim();

                if (title.isEmpty) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(
                    const SnackBar(
                      content:
                          Text(
                        'اكتب اسم التقرير.',
                      ),
                    ),
                  );

                  return;
                }

                Navigator.pop(
                  dialogContext,
                  <String, String>{
                    'title':
                        title,
                    'notes':
                        notesController
                            .text
                            .trim(),
                  },
                );
              },
              icon:
                  const Icon(
                Icons.save,
              ),
              label:
                  const Text(
                'حفظ التعديل',
              ),
            ),
          ],
        );
      },
    );

    if (result == null ||
        !mounted) {
      titleController.dispose();
      notesController.dispose();

      return;
    }

    final user =
        context
            .read<AuthController>()
            .currentUser;

    if (user == null ||
        user.role !=
            UserRole.president) {
      titleController.dispose();
      notesController.dispose();

      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await _repository.update(
        report: report,
        title:
            result['title'] ?? '',
        notes:
            result['notes'] ?? '',
        performedByUid:
            user.uid,
        performedByCode:
            user.code,
      );

      await _refresh();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text(
            'تم تعديل التقرير بنجاح.',
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
          content:
              Text(
            'تعذر تعديل التقرير:\n$error',
          ),
        ),
      );
    } finally {
      titleController.dispose();
      notesController.dispose();

      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // =========================================================
  // DELETE
  // =========================================================

  Future<void> _deleteReport(
    SavedReport report,
  ) async {
    if (!_isPresident() ||
        _busy) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) {
        return AlertDialog(
          title:
              const Text(
            'حذف التقرير',
          ),
          content:
              Text(
            'هل تريد حذف التقرير؟\n\n'
            '${report.title}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text(
                'إلغاء',
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon:
                  const Icon(
                Icons
                    .delete_forever,
              ),
              label:
                  const Text(
                'حذف',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    final user =
        context
            .read<AuthController>()
            .currentUser;

    if (user == null ||
        user.role !=
            UserRole.president) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await _repository.delete(
        report: report,
        performedByUid:
            user.uid,
        performedByCode:
            user.code,
      );

      await _refresh();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text(
            'تم حذف التقرير بنجاح.',
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
          content:
              Text(
            'تعذر حذف التقرير:\n$error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // =========================================================
  // LOAD REPORT DATA
  // =========================================================

  Future<_SavedReportData>
      _loadReportData(
    SavedReport report,
  ) async {
    final recordsController =
        context.read<
            LoadRecordsController>();

    final distributorController =
        context.read<
            DistributorController>();

    /*
     * أهم تعديل هنا:
     *
     * تقرير جميع الموزعات + ساعة
     * لا يستخدم search العادي.
     *
     * يستخدم البحث اليومي الجديد،
     * وبالتالي لا ينزل كل ساعات الفترة.
     */
    if (report
        .isAllDistributorsHourly) {
      await recordsController
          .searchAllDistributorsByHour(
        fromDate:
            report.fromDate,
        toDate:
            report.toDate,
        hour:
            report.hour,
      );
    } else {
      await recordsController.search(
        distributorId:
            report.isSingleDistributor
                ? report.targetId
                : null,
        fromDate:
            report.fromDate,
        toDate:
            report.toDate,

        /*
         * للموزع الواحد نسمح
         * بعدد أكبر من العرض العادي.
         */
        limit: 2000,
      );
    }

    return _SavedReportData(
      records:
          List<LoadRecord>.from(
        recordsController.records,
      ),
      distributors:
          List<Distributor>.from(
        distributorController
            .distributors,
      ),
    );
  }

  // =========================================================
  // PRINT
  // =========================================================

  Future<void> _printReport(
    SavedReport report,
  ) async {
    if (!_isPresident() ||
        _busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final data =
          await _loadReportData(
        report,
      );

      if (data.records.isEmpty) {
        throw StateError(
          'لا توجد بيانات ضمن فترة التقرير.',
        );
      }

      await ReportPdfService
          .printReport(
        records:
            data.records,
        distributors:
            data.distributors,
        selectedDistributorId:
            report.isSingleDistributor
                ? report.targetId
                : null,
        selectedDateTime:
            report.hour >= 0
                ? DateTime(
                    report
                        .fromDate.year,
                    report
                        .fromDate.month,
                    report
                        .fromDate.day,
                    report.hour,
                  )
                : null,
        fromDate:
            report.fromDate,
        toDate:
            report.toDate,
        allDistributorsHourly:
            report
                .isAllDistributorsHourly,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text(
            'تعذر طباعة التقرير:\n$error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // =========================================================
  // SHARE
  // =========================================================

  Future<void> _shareReport(
    SavedReport report,
  ) async {
    if (!_isPresident() ||
        _busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final data =
          await _loadReportData(
        report,
      );

      if (data.records.isEmpty) {
        throw StateError(
          'لا توجد بيانات ضمن فترة التقرير.',
        );
      }

      await ReportPdfService
          .shareReport(
        records:
            data.records,
        distributors:
            data.distributors,
        selectedDistributorId:
            report.isSingleDistributor
                ? report.targetId
                : null,
        selectedDateTime:
            report.hour >= 0
                ? DateTime(
                    report
                        .fromDate.year,
                    report
                        .fromDate.month,
                    report
                        .fromDate.day,
                    report.hour,
                  )
                : null,
        fromDate:
            report.fromDate,
        toDate:
            report.toDate,
        allDistributorsHourly:
            report
                .isAllDistributorsHourly,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text(
            'تعذر مشاركة التقرير:\n$error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final auth =
        context.watch<
            AuthController>();

    if (auth.currentUser?.role !=
        UserRole.president) {
      return const Scaffold(
        body: Center(
          child: Text(
            'هذه الصفحة متاحة للرئيس فقط.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'التقارير المحفوظة',
        ),
        actions: [
          IconButton(
            tooltip:
                'تحديث',
            onPressed:
                _busy
                    ? null
                    : _refresh,
            icon:
                const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      body: Stack(
        children: [
          StreamBuilder<
              List<SavedReport>>(
            stream:
                _reportsStream,
            builder:
                (
              context,
              snapshot,
            ) {
              if (snapshot.hasError) {
                return Center(
                  child:
                      SingleChildScrollView(
                    padding:
                        const EdgeInsets
                            .all(
                      24,
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        const Icon(
                          Icons
                              .error_outline,
                          size:
                              64,
                        ),

                        const SizedBox(
                          height:
                              16,
                        ),

                        const Text(
                          'تعذر تحميل التقارير المحفوظة',
                          style:
                              TextStyle(
                            fontSize:
                                18,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),

                        const SizedBox(
                          height:
                              12,
                        ),

                        SelectableText(
                          '${snapshot.error}',
                          textAlign:
                              TextAlign
                                  .center,
                        ),

                        const SizedBox(
                          height:
                              16,
                        ),

                        FilledButton.icon(
                          onPressed:
                              _refresh,
                          icon:
                              const Icon(
                            Icons
                                .refresh,
                          ),
                          label:
                              const Text(
                            'إعادة المحاولة',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              final reports =
                  snapshot.data!;

              if (reports.isEmpty) {
                return RefreshIndicator(
                  onRefresh:
                      _refresh,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    children:
                        const [
                      SizedBox(
                        height:
                            150,
                      ),
                      Icon(
                        Icons
                            .folder_copy_outlined,
                        size:
                            72,
                      ),
                      SizedBox(
                        height:
                            16,
                      ),
                      Center(
                        child:
                            Text(
                          'لا توجد تقارير محفوظة حتى الآن.',
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh:
                    _refresh,
                child:
                    ListView.separated(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    16,
                    16,
                    16,
                    30,
                  ),
                  itemCount:
                      reports.length,
                  separatorBuilder:
                      (_, __) =>
                          const SizedBox(
                    height:
                        10,
                  ),
                  itemBuilder:
                      (
                    context,
                    index,
                  ) {
                    return _buildReportCard(
                      reports[index],
                    );
                  },
                ),
              );
            },
          ),

          if (_busy)
            Positioned.fill(
              child:
                  ColoredBox(
                color:
                    Colors.black26,
                child:
                    const Center(
                  child:
                      Card(
                    child:
                        Padding(
                      padding:
                          EdgeInsets
                              .all(
                        24,
                      ),
                      child:
                          Column(
                        mainAxisSize:
                            MainAxisSize
                                .min,
                        children:
                            [
                          CircularProgressIndicator(),
                          SizedBox(
                            height:
                                14,
                          ),
                          Text(
                            'جارٍ تنفيذ العملية...',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // CARD
  // =========================================================

  Widget _buildReportCard(
    SavedReport report,
  ) {
    return Card(
      clipBehavior:
          Clip.antiAlias,
      child:
          ExpansionTile(
        leading:
            const CircleAvatar(
          child:
              Icon(
            Icons
                .description_outlined,
          ),
        ),

        title:
            Text(
          report.title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        subtitle:
            Text(
          '${_reportTypeName(report)}\n'
          '${_formatDate(report.fromDate)}'
          ' إلى '
          '${_formatDate(report.toDate)}',
        ),

        childrenPadding:
            const EdgeInsets
                .fromLTRB(
          16,
          0,
          16,
          16,
        ),

        children: [
          _infoRow(
            icon:
                Icons
                    .category_outlined,
            title:
                'نوع التقرير',
            value:
                _reportTypeName(
              report,
            ),
          ),

          if (report.targetName
              .trim()
              .isNotEmpty)
            _infoRow(
              icon:
                  Icons
                      .account_tree_outlined,
              title:
                  'الجهة',
              value:
                  report.targetName,
            ),

          _infoRow(
            icon:
                Icons
                    .date_range,
            title:
                'الفترة',
            value:
                '${_formatDate(report.fromDate)}'
                ' إلى '
                '${_formatDate(report.toDate)}',
          ),

          if (report.hour >= 0)
            _infoRow(
              icon:
                  Icons.schedule,
              title:
                  'الساعة',
              value:
                  _hourText(
                report.hour,
              ),
            ),

          _infoRow(
            icon:
                Icons
                    .access_time,
            title:
                'آخر تعديل',
            value:
                _formatDateTime(
              report.updatedAt,
            ),
          ),

          if (report.notes
              .trim()
              .isNotEmpty)
            _infoRow(
              icon:
                  Icons.notes,
              title:
                  'ملاحظات',
              value:
                  report.notes,
            ),

          const Divider(),

          Wrap(
            spacing:
                8,
            runSpacing:
                8,
            alignment:
                WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed:
                    _busy
                        ? null
                        : () =>
                            _editReport(
                              report,
                            ),
                icon:
                    const Icon(
                  Icons.edit,
                ),
                label:
                    const Text(
                  'تعديل',
                ),
              ),

              OutlinedButton.icon(
                onPressed:
                    _busy
                        ? null
                        : () =>
                            _printReport(
                              report,
                            ),
                icon:
                    const Icon(
                  Icons.print_outlined,
                ),
                label:
                    const Text(
                  'طباعة',
                ),
              ),

              OutlinedButton.icon(
                onPressed:
                    _busy
                        ? null
                        : () =>
                            _shareReport(
                              report,
                            ),
                icon:
                    const Icon(
                  Icons.share_outlined,
                ),
                label:
                    const Text(
                  'مشاركة',
                ),
              ),

              FilledButton.icon(
                onPressed:
                    _busy
                        ? null
                        : () =>
                            _deleteReport(
                              report,
                            ),
                icon:
                    const Icon(
                  Icons
                      .delete_outline,
                ),
                label:
                    const Text(
                  'حذف',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      dense:
          true,
      contentPadding:
          EdgeInsets.zero,
      leading:
          Icon(
        icon,
      ),
      title:
          Text(
        title,
        style:
            const TextStyle(
          fontWeight:
              FontWeight.bold,
        ),
      ),
      subtitle:
          Text(
        value,
      ),
    );
  }
}

// ===========================================================
// DATA HOLDER
// ===========================================================

class _SavedReportData {
  const _SavedReportData({
    required this.records,
    required this.distributors,
  });

  final List<LoadRecord> records;
  final List<Distributor> distributors;
}
