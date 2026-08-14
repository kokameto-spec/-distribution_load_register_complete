import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/distributor_controller.dart';
import '../../controllers/load_records_controller.dart';
import '../../core/services/report_pdf_service.dart';
import '../../models/saved_report.dart';
import '../../models/user_role.dart';
import '../../repositories/saved_report_repository.dart';

class SavedReportsScreen extends StatefulWidget {
  const SavedReportsScreen({super.key});

  @override
  State<SavedReportsScreen> createState() =>
      _SavedReportsScreenState();
}

class _SavedReportsScreenState extends State<SavedReportsScreen> {
  final SavedReportRepository _repository =
      SavedReportRepository();

  bool _busy = false;

  // =========================================================
  // تنسيق التاريخ
  // =========================================================

  String _formatDate(DateTime value) {
    return DateFormat('yyyy/MM/dd').format(value);
  }

  String _formatDateTime(DateTime value) {
    return DateFormat(
      'yyyy/MM/dd - HH:mm',
    ).format(value);
  }

  // =========================================================
  // اسم نوع التقرير
  // =========================================================

  String _reportTypeName(SavedReport report) {
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
  // التأكد أن المستخدم رئيس
  // =========================================================

  bool _isPresident() {
    final user =
        context.read<AuthController>().currentUser;

    return user != null &&
        user.role == UserRole.president;
  }

  // =========================================================
  // تعديل التقرير
  // =========================================================

  Future<void> _editReport(
    SavedReport report,
  ) async {
    if (!_isPresident()) {
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
        await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'تعديل التقرير المحفوظ',
          ),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'اسم التقرير',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    border: OutlineInputBorder(),
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
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () {
                final title =
                    titleController.text.trim();

                if (title.isEmpty) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(
                    const SnackBar(
                      content: Text(
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
                        titleController.text.trim(),
                    'notes':
                        notesController.text.trim(),
                  },
                );
              },
              icon: const Icon(Icons.save),
              label: const Text(
                'حفظ التعديل',
              ),
            ),
          ],
        );
      },
    );

    if (result == null || !mounted) {
      titleController.dispose();
      notesController.dispose();
      return;
    }

    final user =
        context.read<AuthController>().currentUser;

    if (user == null ||
        user.role != UserRole.president) {
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
        title: result['title'] ?? '',
        notes: result['notes'] ?? '',
        performedByUid: user.uid,
        performedByCode: user.code,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تعديل التقرير بنجاح.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
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
  // حذف التقرير
  // =========================================================

  Future<void> _deleteReport(
    SavedReport report,
  ) async {
    if (!_isPresident()) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'حذف التقرير',
          ),
          content: Text(
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
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(
                Icons.delete_forever,
              ),
              label: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final user =
        context.read<AuthController>().currentUser;

    if (user == null ||
        user.role != UserRole.president) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await _repository.delete(
        report: report,
        performedByUid: user.uid,
        performedByCode: user.code,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حذف التقرير بنجاح.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
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
  // تحميل بيانات التقرير
  // =========================================================

  Future<List<dynamic>> _loadReportData(
    SavedReport report,
  ) async {
    final recordsController =
        context.read<LoadRecordsController>();

    final distributorController =
        context.read<DistributorController>();

    await recordsController.search(
      distributorId:
          report.isSingleDistributor
              ? report.targetId
              : null,
      fromDate: report.fromDate,
      toDate: report.toDate,
    );

    return <dynamic>[
      recordsController.records,
      distributorController.distributors,
    ];
  }

  // =========================================================
  // طباعة التقرير
  // =========================================================

  Future<void> _printReport(
    SavedReport report,
  ) async {
    if (!_isPresident()) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final data =
          await _loadReportData(report);

      await ReportPdfService.printReport(
        records: data[0],
        distributors: data[1],

        selectedDistributorId:
            report.isSingleDistributor
                ? report.targetId
                : null,

        selectedDateTime:
            report.hour >= 0
                ? DateTime(
                    report.fromDate.year,
                    report.fromDate.month,
                    report.fromDate.day,
                    report.hour,
                  )
                : null,

        fromDate: report.fromDate,
        toDate: report.toDate,

        allDistributorsHourly:
            report.isAllDistributorsHourly,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
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
  // مشاركة التقرير
  // =========================================================

  Future<void> _shareReport(
    SavedReport report,
  ) async {
    if (!_isPresident()) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final data =
          await _loadReportData(report);

      await ReportPdfService.shareReport(
        records: data[0],
        distributors: data[1],

        selectedDistributorId:
            report.isSingleDistributor
                ? report.targetId
                : null,

        selectedDateTime:
            report.hour >= 0
                ? DateTime(
                    report.fromDate.year,
                    report.fromDate.month,
                    report.fromDate.day,
                    report.hour,
                  )
                : null,

        fromDate: report.fromDate,
        toDate: report.toDate,

        allDistributorsHourly:
            report.isAllDistributorsHourly,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
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
  // بطاقة معلومات
  // =========================================================

  Widget _infoRow({
    required IconData icon,
    required String title,
  }) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
    );
  }

  // =========================================================
  // الشاشة
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final auth =
        context.watch<AuthController>();

    // الرئيس فقط
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
        title: const Text(
          'التقارير المحفوظة',
        ),
      ),

      body: Stack(
        children: [
          StreamBuilder<List<SavedReport>>(
            stream: _repository.watchAll(),

            builder: (context, snapshot) {
              // =============================================
              // خطأ
              // =============================================

              if (snapshot.hasError) {
                return Center(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'تعذر تحميل التقارير المحفوظة',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          '${snapshot.error}',
                          textAlign:
                              TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // =============================================
              // تحميل
              // =============================================

              if (!snapshot.hasData) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              final reports =
                  snapshot.data!;

              // =============================================
              // لا توجد تقارير
              // =============================================

              if (reports.isEmpty) {
                return const Center(
                  child: Padding(
                    padding:
                        EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons
                              .folder_copy_outlined,
                          size: 72,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'لا توجد تقارير محفوظة حتى الآن.',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // =============================================
              // قائمة التقارير
              // =============================================

              return RefreshIndicator(
                onRefresh: () async {
                  await Future<void>.delayed(
                    const Duration(
                      milliseconds: 300,
                    ),
                  );
                },
                child: ListView.separated(
                  physics:
                      const AlwaysScrollableScrollPhysics(),

                  padding:
                      const EdgeInsets.all(16),

                  itemCount:
                      reports.length,

                  separatorBuilder:
                      (_, __) =>
                          const SizedBox(
                    height: 10,
                  ),

                  itemBuilder:
                      (context, index) {
                    final report =
                        reports[index];

                    return Card(
                      clipBehavior:
                          Clip.antiAlias,

                      child: ExpansionTile(
                        leading:
                            const CircleAvatar(
                          child: Icon(
                            Icons
                                .description_outlined,
                          ),
                        ),

                        title: Text(
                          report.title,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        subtitle: Text(
                          '${_reportTypeName(report)}'
                          '${report.targetName.isEmpty ? '' : ' — ${report.targetName}'}',
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
                          const Divider(),

                          _infoRow(
                            icon:
                                Icons.date_range,
                            title:
                                'من: ${_formatDate(report.fromDate)}',
                          ),

                          _infoRow(
                            icon:
                                Icons.event,
                            title:
                                'إلى: ${_formatDate(report.toDate)}',
                          ),

                          if (report.hour >=
                              0)
                            _infoRow(
                              icon:
                                  Icons.schedule,
                              title:
                                  'الساعة ${report.hour} (${report.hour.toString().padLeft(2, '0')}:00 - ${report.hour.toString().padLeft(2, '0')}:59)',
                            ),

                          if (report
                              .targetName
                              .isNotEmpty)
                            _infoRow(
                              icon: Icons
                                  .account_tree_outlined,
                              title:
                                  'الموزع/الجهة: ${report.targetName}',
                            ),

                          if (report
                              .notes
                              .isNotEmpty)
                            _infoRow(
                              icon:
                                  Icons.notes,
                              title:
                                  'ملاحظات: ${report.notes}',
                            ),

                          _infoRow(
                            icon: Icons
                                .calendar_today_outlined,
                            title:
                                'تاريخ الحفظ: ${_formatDateTime(report.createdAt)}',
                          ),

                          _infoRow(
                            icon:
                                Icons.history,
                            title:
                                'آخر تعديل: ${_formatDateTime(report.updatedAt)}',
                          ),

                          const Divider(),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment:
                                WrapAlignment
                                    .center,
                            children: [
                              // =============================
                              // تعديل
                              // =============================

                              OutlinedButton
                                  .icon(
                                onPressed:
                                    _busy
                                        ? null
                                        : () {
                                            _editReport(
                                              report,
                                            );
                                          },
                                icon:
                                    const Icon(
                                  Icons.edit,
                                ),
                                label:
                                    const Text(
                                  'تعديل',
                                ),
                              ),

                              // =============================
                              // طباعة
                              // =============================

                              OutlinedButton
                                  .icon(
                                onPressed:
                                    _busy
                                        ? null
                                        : () {
                                            _printReport(
                                              report,
                                            );
                                          },
                                icon:
                                    const Icon(
                                  Icons.print,
                                ),
                                label:
                                    const Text(
                                  'طباعة',
                                ),
                              ),

                              // =============================
                              // مشاركة
                              // =============================

                              OutlinedButton
                                  .icon(
                                onPressed:
                                    _busy
                                        ? null
                                        : () {
                                            _shareReport(
                                              report,
                                            );
                                          },
                                icon:
                                    const Icon(
                                  Icons.share,
                                ),
                                label:
                                    const Text(
                                  'مشاركة',
                                ),
                              ),

                              // =============================
                              // حذف
                              // =============================

                              FilledButton
                                  .icon(
                                onPressed:
                                    _busy
                                        ? null
                                        : () {
                                            _deleteReport(
                                              report,
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
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),

          // =============================================
          // انتظار
          // =============================================

          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color:
                    Color(0x22000000),
                child: Center(
                  child:
                      CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}