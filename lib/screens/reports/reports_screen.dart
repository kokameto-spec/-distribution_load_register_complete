import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/distributor_controller.dart';
import '../../controllers/load_records_controller.dart';
import '../../core/services/report_excel_service.dart';
import '../../core/services/report_pdf_service.dart';
import '../../models/distributor_model.dart';
import '../../models/load_record.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const List<int> _allCellNumbers = <int>[
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

  String? _selectedDistributorId;
  DateTime? _fromDate;
  DateTime? _toDate;

  bool _searched = false;

  Future<void> _selectFromDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _fromDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
      );
    });
  }

  Future<void> _selectToDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _toDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
        23,
        59,
        59,
        999,
      );
    });
  }

  Future<void> _search() async {
    if (_fromDate != null &&
        _toDate != null &&
        _fromDate!.isAfter(_toDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تاريخ البداية يجب أن يكون قبل تاريخ النهاية.',
          ),
        ),
      );
      return;
    }

    await context.read<LoadRecordsController>().search(
      distributorId: _selectedDistributorId,
      fromDate: _fromDate,
      toDate: _toDate,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _searched = true;
    });
  }

  Future<void> _clearSearch() async {
    setState(() {
      _selectedDistributorId = null;
      _fromDate = null;
      _toDate = null;
      _searched = false;
    });

    await context.read<LoadRecordsController>().search();
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'غير محدد';
    }

    return DateFormat(
      'yyyy/MM/dd',
      'ar',
    ).format(value);
  }

  String _formatDateTime(DateTime value) {
    return DateFormat(
      'yyyy/MM/dd - hh:mm a',
      'ar',
    ).format(value);
  }

  LoadRecord? _maximumRecord(
      List<LoadRecord> records,
      ) {
    if (records.isEmpty) {
      return null;
    }

    LoadRecord result = records.first;

    for (final record in records.skip(1)) {
      if (record.totalLoad > result.totalLoad) {
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

    LoadRecord result = records.first;

    for (final record in records.skip(1)) {
      if (record.totalLoad < result.totalLoad) {
        result = record;
      }
    }

    return result;
  }

  double _averageLoad(
      List<LoadRecord> records,
      ) {
    if (records.isEmpty) {
      return 0;
    }

    double total = 0;

    for (final record in records) {
      total += record.totalLoad;
    }

    return total / records.length;
  }

  Map<int, _CellStatistics> _calculateCellStatistics(
      List<LoadRecord> records,
      ) {
    final result = <int, _CellStatistics>{};

    for (final cellNumber in _allCellNumbers) {
      double? current;
      double? minimum;
      double? maximum;
      LoadRecord? currentRecord;
      LoadRecord? minimumRecord;
      LoadRecord? maximumRecord;

      for (final record in records) {
        final value = record.cellValues[cellNumber];

        if (value == null) {
          continue;
        }

        if (currentRecord == null ||
            record.recordedAt.isAfter(currentRecord.recordedAt)) {
          current = value;
          currentRecord = record;
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

      result[cellNumber] = _CellStatistics(
        current: current,
        minimum: minimum,
        maximum: maximum,
        currentRecord: currentRecord,
        minimumRecord: minimumRecord,
        maximumRecord: maximumRecord,
      );
    }

    return result;
  }

  List<Distributor> _missingDistributors(
      List<Distributor> distributors,
      ) {
    final now = DateTime.now();

    return distributors.where((distributor) {
      if (!distributor.active) {
        return false;
      }

      final lastRecordAt = distributor.lastRecordAt;

      if (lastRecordAt == null) {
        return true;
      }

      return now.difference(lastRecordAt) >=
          const Duration(hours: 1);
    }).toList(growable: false);
  }

  Future<void> _printPdf(List<LoadRecord> records) async {
    try {
      await ReportPdfService.printReport(
        records: records,
        fromDate: _fromDate,
        toDate: _toDate,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر إنشاء أو طباعة تقرير PDF.'),
        ),
      );
    }
  }

  Future<void> _sharePdf(List<LoadRecord> records) async {
    try {
      await ReportPdfService.shareReport(
        records: records,
        fromDate: _fromDate,
        toDate: _toDate,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر مشاركة تقرير PDF.'),
        ),
      );
    }
  }


  Future<void> _exportExcel(
    List<LoadRecord> records,
  ) async {
    try {
      await ReportExcelService.exportReport(
        records: records,
        fromDate: _fromDate,
        toDate: _toDate,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إنشاء ملف Excel بنجاح.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر إنشاء ملف Excel.',
          ),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final distributorController =
    context.watch<DistributorController>();

    final recordsController =
    context.watch<LoadRecordsController>();

    final records = recordsController.records;

    final maximumRecord = _maximumRecord(records);
    final minimumRecord = _minimumRecord(records);
    final averageLoad = _averageLoad(records);

    final cellStatistics = _calculateCellStatistics(
      records,
    );

    final missingDistributors = _missingDistributors(
      distributorController.distributors,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير الأحمال'),
        actions: [
          IconButton(
            tooltip: 'تصدير أو حفظ PDF',
            onPressed: records.isEmpty
                ? null
                : () => _sharePdf(records),
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
            ),
          ),
          IconButton(
            tooltip: 'تصدير Excel',
            onPressed: records.isEmpty
                ? null
                : () => _exportExcel(records),
            icon: const Icon(
              Icons.table_view_outlined,
            ),
          ),
          IconButton(
            tooltip: 'طباعة',
            onPressed: records.isEmpty
                ? null
                : () => _printPdf(records),
            icon: const Icon(
              Icons.print_outlined,
            ),
          ),
          IconButton(
            tooltip: 'مشاركة PDF',
            onPressed: records.isEmpty
                ? null
                : () => _sharePdf(records),
            icon: const Icon(
              Icons.share_outlined,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _search,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1200,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.stretch,
                children: [
                  _buildSearchCard(
                    distributorController,
                    recordsController,
                  ),

                  const SizedBox(height: 18),

                  _buildMissingDistributorsCard(
                    missingDistributors,
                  ),

                  const SizedBox(height: 18),

                  if (recordsController.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(35),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    if (recordsController.errorMessage != null)
                      _buildErrorMessage(
                        recordsController.errorMessage!,
                      ),

                    if (records.isEmpty)
                      _buildEmptyState()
                    else ...[
                      _buildOverallSummary(
                        recordsCount: records.length,
                        maximumRecord: maximumRecord,
                        minimumRecord: minimumRecord,
                        averageLoad: averageLoad,
                      ),

                      const SizedBox(height: 20),

                      _buildCellStatisticsSection(
                        cellStatistics,
                      ),

                      const SizedBox(height: 20),

                      _buildRecordsSection(records),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchCard(
      DistributorController distributors,
      LoadRecordsController records,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.stretch,
          children: [
            Text(
              'البحث والتصفية',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _selectedDistributorId,
              decoration: const InputDecoration(
                labelText: 'الموزع',
                prefixIcon: Icon(
                  Icons.account_tree,
                ),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    'جميع الموزعات',
                  ),
                ),
                ...distributors.distributors.map(
                      (distributor) {
                    return DropdownMenuItem<String>(
                      value: distributor.id,
                      child: Text(
                        '${distributor.name} - '
                            '${distributor.code}',
                      ),
                    );
                  },
                ),
              ],
              onChanged: records.isLoading
                  ? null
                  : (value) {
                setState(() {
                  _selectedDistributorId = value;
                });
              },
            ),

            const SizedBox(height: 14),

            LayoutBuilder(
              builder: (context, constraints) {
                final width =
                constraints.maxWidth >= 600
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: _DateSelector(
                        title: 'من تاريخ',
                        value: _formatDate(_fromDate),
                        icon: Icons.date_range,
                        onPressed: records.isLoading
                            ? null
                            : _selectFromDate,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _DateSelector(
                        title: 'إلى تاريخ',
                        value: _formatDate(_toDate),
                        icon: Icons.event_available,
                        onPressed: records.isLoading
                            ? null
                            : _selectToDate,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: records.isLoading
                      ? null
                      : _clearSearch,
                  icon: const Icon(Icons.clear),
                  label: const Text('مسح البحث'),
                ),
                FilledButton.icon(
                  onPressed:
                  records.isLoading ? null : _search,
                  icon: const Icon(Icons.search),
                  label: const Text('بحث'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingDistributorsCard(
      List<Distributor> distributors,
      ) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: distributors.isNotEmpty,
        leading: const Icon(
          Icons.warning_amber_rounded,
        ),
        title: Text(
          'الموزعات التي لم تسجل خلال الساعة '
              '(${distributors.length})',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          distributors.isEmpty
              ? 'جميع الموزعات سجلت الأحمال.'
              : 'اضغط لعرض أسماء الموزعات المتأخرة.',
        ),
        children: distributors.map((distributor) {
          final lastRecordText =
          distributor.lastRecordAt == null
              ? 'لم يسجل من قبل'
              : _formatDateTime(
            distributor.lastRecordAt!,
          );

          return ListTile(
            leading: const CircleAvatar(
              child: Icon(
                Icons.electrical_services,
              ),
            ),
            title: Text(distributor.name),
            subtitle: Text(
              'الكود: ${distributor.code}\n'
                  'آخر تسجيل: $lastRecordText',
            ),
            isThreeLine: true,
            trailing: const Chip(
              label: Text('متأخر'),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOverallSummary({
    required int recordsCount,
    required LoadRecord? maximumRecord,
    required LoadRecord? minimumRecord,
    required double averageLoad,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.stretch,
      children: [
        Text(
          'الملخص العام',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        LayoutBuilder(
          builder: (context, constraints) {
            final width =
            constraints.maxWidth >= 900
                ? (constraints.maxWidth - 36) / 4
                : constraints.maxWidth >= 550
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: _SummaryCard(
                    title: 'عدد السجلات',
                    value: recordsCount.toString(),
                    subtitle: 'سجل',
                    icon: Icons.receipt_long,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _SummaryCard(
                    title: 'أقصى حمل',
                    value: maximumRecord == null
                        ? '—'
                        : maximumRecord.totalLoad
                        .toStringAsFixed(2),
                    subtitle: maximumRecord == null
                        ? 'لا توجد بيانات'
                        : maximumRecord.distributorName,
                    icon: Icons.trending_up,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _SummaryCard(
                    title: 'أقل حمل',
                    value: minimumRecord == null
                        ? '—'
                        : minimumRecord.totalLoad
                        .toStringAsFixed(2),
                    subtitle: minimumRecord == null
                        ? 'لا توجد بيانات'
                        : minimumRecord.distributorName,
                    icon: Icons.trending_down,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _SummaryCard(
                    title: 'متوسط الحمل',
                    value: averageLoad.toStringAsFixed(2),
                    subtitle: 'أمبير',
                    icon: Icons.show_chart,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCellStatisticsSection(
      Map<int, _CellStatistics> statistics,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.stretch,
      children: [
        Text(
          'الحمل الحالي وأقل وأقصى حمل لكل خلية',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        LayoutBuilder(
          builder: (context, constraints) {
            final width =
            constraints.maxWidth >= 900
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth >= 550
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _allCellNumbers.map((cellNumber) {
                final cell = statistics[cellNumber]!;

                return SizedBox(
                  width: width,
                  child: _CellStatisticsCard(
                    cellNumber: cellNumber,
                    statistics: cell,
                    formatDateTime: _formatDateTime,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecordsSection(
      List<LoadRecord> records,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.stretch,
      children: [
        Text(
          'تفاصيل السجلات',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        ...records.map(
              (record) => Padding(
            padding: const EdgeInsets.only(
              bottom: 10,
            ),
            child: Card(
              child: ExpansionTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.bolt),
                ),
                title: Text(
                  record.distributorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${record.totalLoad.toStringAsFixed(2)} أمبير'
                      ' — ${_formatDateTime(record.recordedAt)}',
                ),
                childrenPadding:
                const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16,
                ),
                children: [
                  _InformationRow(
                    title: 'مدخل البيانات',
                    value: record.operatorName,
                  ),
                  _InformationRow(
                    title: 'كود المستخدم',
                    value: record.createdByCode,
                  ),
                  _InformationRow(
                    title: 'التاريخ والوقت',
                    value: _formatDateTime(
                      record.recordedAt,
                    ),
                  ),
                  const Divider(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allCellNumbers.map(
                          (cellNumber) {
                        final value =
                            record.cellValues[cellNumber] ??
                                0;

                        return Chip(
                          label: Text(
                            'خلية $cellNumber: '
                                '${value.toStringAsFixed(2)}',
                          ),
                        );
                      },
                    ).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 45,
        ),
        child: Column(
          children: [
            const Icon(
              Icons.assessment_outlined,
              size: 70,
            ),
            const SizedBox(height: 16),
            Text(
              _searched
                  ? 'لا توجد سجلات مطابقة للبحث.'
                  : 'اختر بيانات البحث ثم اضغط بحث.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage(
      String message,
      ) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context)
              .colorScheme
              .onErrorContainer,
        ),
      ),
    );
  }
}

class _CellStatistics {
  const _CellStatistics({
    required this.current,
    required this.minimum,
    required this.maximum,
    required this.currentRecord,
    required this.minimumRecord,
    required this.maximumRecord,
  });

  final double? current;
  final double? minimum;
  final double? maximum;
  final LoadRecord? currentRecord;
  final LoadRecord? minimumRecord;
  final LoadRecord? maximumRecord;
}

class _CellStatisticsCard extends StatelessWidget {
  const _CellStatisticsCard({
    required this.cellNumber,
    required this.statistics,
    required this.formatDateTime,
  });

  final int cellNumber;
  final _CellStatistics statistics;
  final String Function(DateTime value) formatDateTime;

  @override
  Widget build(BuildContext context) {
    final currentRecord = statistics.currentRecord;
    final maximumRecord = statistics.maximumRecord;
    final minimumRecord = statistics.minimumRecord;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.stretch,
          children: [
            Text(
              'خلية $cellNumber',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const Divider(),

            _StatisticLine(
              title: 'الحمل الحالي',
              value: statistics.current == null
                  ? 'لا توجد بيانات'
                  : '${statistics.current!.toStringAsFixed(2)} أمبير',
            ),

            if (currentRecord != null)
              Text(
                '${currentRecord.distributorName} — '
                    '${formatDateTime(currentRecord.recordedAt)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),

            const SizedBox(height: 12),

            _StatisticLine(
              title: 'أقصى حمل',
              value: statistics.maximum == null
                  ? 'لا توجد بيانات'
                  : '${statistics.maximum!.toStringAsFixed(2)} أمبير',
            ),

            if (maximumRecord != null)
              Text(
                '${maximumRecord.distributorName} — '
                    '${formatDateTime(maximumRecord.recordedAt)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),

            const SizedBox(height: 12),

            _StatisticLine(
              title: 'أقل حمل',
              value: statistics.minimum == null
                  ? 'لا توجد بيانات'
                  : '${statistics.minimum!.toStringAsFixed(2)} أمبير',
            ),

            if (minimumRecord != null)
              Text(
                '${minimumRecord.distributorName} — '
                    '${formatDateTime(minimumRecord.recordedAt)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatisticLine extends StatelessWidget {
  const _StatisticLine({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.title,
    required this.value,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.centerRight,
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
                const SizedBox(height: 3),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'غير متوفر' : value,
            ),
          ),
        ],
      ),
    );
  }
}