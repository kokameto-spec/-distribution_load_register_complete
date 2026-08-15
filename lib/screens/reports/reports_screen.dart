import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/distributor_controller.dart';
import '../../controllers/load_records_controller.dart';
import '../../core/services/report_excel_service.dart';
import '../../core/services/report_file_name_service.dart';
import '../../core/services/report_pdf_service.dart';
import '../../models/distributor_model.dart';
import '../../models/load_record.dart';
import '../../models/user_role.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _SaveReportType { pdf, excel }

class _ReportsScreenState extends State<ReportsScreen> {
  static const List<int> _cells = <int>[
    0, 1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 15,
  ];

  String? _selectedDistributorId;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  int _selectedHour = DateTime.now().hour;
  bool _searched = false;
  bool _fileBusy = false;

  bool get _allDistributors => _selectedDistributorId == null;

  DateTime get _queryFrom => _allDistributors
      ? DateTime(
          _fromDate.year,
          _fromDate.month,
          _fromDate.day,
          _selectedHour,
        )
      : DateTime(_fromDate.year, _fromDate.month, _fromDate.day);

  DateTime get _queryTo => _allDistributors
      ? DateTime(
          _toDate.year,
          _toDate.month,
          _toDate.day,
          _selectedHour,
          59,
          59,
          999,
        )
      : DateTime(
          _toDate.year,
          _toDate.month,
          _toDate.day,
          23,
          59,
          59,
          999,
        );

  Future<void> _selectDate({required bool from}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: from ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selected == null || !mounted) return;

    setState(() {
      final value = DateTime(selected.year, selected.month, selected.day);
      if (from) {
        _fromDate = value;
        if (_toDate.isBefore(_fromDate)) _toDate = _fromDate;
      } else {
        _toDate = value;
      }
      _searched = false;
    });
  }

  Future<void> _search() async {
    if (_fromDate.isAfter(_toDate)) {
      _message('تاريخ البداية يجب أن يكون قبل تاريخ النهاية.');
      return;
    }

    final controller = context.read<LoadRecordsController>();

    if (_allDistributors) {
      await controller.searchAllDistributorsByHour(
        fromDate: _fromDate,
        toDate: _toDate,
        hour: _selectedHour,
      );
    } else {
      await controller.search(
        distributorId: _selectedDistributorId,
        fromDate: _queryFrom,
        toDate: _queryTo,
        limit: 500,
      );
    }

    if (!mounted) return;
    setState(() => _searched = true);
  }

  void _clear() {
    context.read<LoadRecordsController>().clearRecords();
    setState(() {
      _selectedDistributorId = null;
      _fromDate = DateTime.now();
      _toDate = DateTime.now();
      _selectedHour = DateTime.now().hour;
      _searched = false;
    });
  }

  Distributor? _selectedDistributor(List<Distributor> distributors) {
    final id = _selectedDistributorId;
    if (id == null) return null;
    for (final item in distributors) {
      if (item.id == id) return item;
    }
    return null;
  }

  String _fileName(List<Distributor> distributors) {
    final selected = _selectedDistributor(distributors);

    return ReportFileNameService.buildBaseName(
      allDistributors: _allDistributors,
      fromDate: _fromDate,
      toDate: _toDate,
      hour: _allDistributors ? _selectedHour : null,
      distributorName: selected?.name,
    );
  }

  Future<void> _saveReport(
    List<LoadRecord> records,
    List<Distributor> distributors,
  ) async {
    if (records.isEmpty || _fileBusy) return;

    final type = await showDialog<_SaveReportType>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حفظ التقرير'),
        content: const Text('اختر نوع الملف الذي تريد حفظه على الجهاز.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(
              dialogContext,
              _SaveReportType.excel,
            ),
            icon: const Icon(Icons.table_view),
            label: const Text('Excel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(
              dialogContext,
              _SaveReportType.pdf,
            ),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('PDF'),
          ),
        ],
      ),
    );

    if (type == null || !mounted) return;

    await _runFileOperation(() async {
      final name = _fileName(distributors);
      if (type == _SaveReportType.pdf) {
        await ReportPdfService.saveReport(
          records: records,
          distributors: distributors,
          fileName: name,
          selectedDistributorId: _selectedDistributorId,
          selectedDateTime: DateTime(
            _fromDate.year,
            _fromDate.month,
            _fromDate.day,
            _selectedHour,
          ),
          fromDate: _queryFrom,
          toDate: _queryTo,
          allDistributorsHourly: _allDistributors,
        );
      } else {
        await ReportExcelService.saveReport(
          records: records,
          distributors: distributors,
          fileName: name,
          selectedDistributorId: _selectedDistributorId,
          selectedDateTime: DateTime(
            _fromDate.year,
            _fromDate.month,
            _fromDate.day,
            _selectedHour,
          ),
          fromDate: _queryFrom,
          toDate: _queryTo,
          allDistributorsHourly: _allDistributors,
        );
      }
    });
  }

  Future<void> _sharePdf(
    List<LoadRecord> records,
    List<Distributor> distributors,
  ) async {
    await _runFileOperation(() {
      return ReportPdfService.shareReport(
        records: records,
        distributors: distributors,
        fileName: _fileName(distributors),
        selectedDistributorId: _selectedDistributorId,
        selectedDateTime: DateTime(
          _fromDate.year,
          _fromDate.month,
          _fromDate.day,
          _selectedHour,
        ),
        fromDate: _queryFrom,
        toDate: _queryTo,
        allDistributorsHourly: _allDistributors,
      );
    });
  }

  Future<void> _shareExcel(
    List<LoadRecord> records,
    List<Distributor> distributors,
  ) async {
    await _runFileOperation(() {
      return ReportExcelService.shareReport(
        records: records,
        distributors: distributors,
        fileName: _fileName(distributors),
        selectedDistributorId: _selectedDistributorId,
        selectedDateTime: DateTime(
          _fromDate.year,
          _fromDate.month,
          _fromDate.day,
          _selectedHour,
        ),
        fromDate: _queryFrom,
        toDate: _queryTo,
        allDistributorsHourly: _allDistributors,
      );
    });
  }

  Future<void> _print(
    List<LoadRecord> records,
    List<Distributor> distributors,
  ) async {
    await _runFileOperation(() {
      return ReportPdfService.printReport(
        records: records,
        distributors: distributors,
        fileName: _fileName(distributors),
        selectedDistributorId: _selectedDistributorId,
        selectedDateTime: DateTime(
          _fromDate.year,
          _fromDate.month,
          _fromDate.day,
          _selectedHour,
        ),
        fromDate: _queryFrom,
        toDate: _queryTo,
        allDistributorsHourly: _allDistributors,
      );
    });
  }

  Future<void> _runFileOperation(Future<void> Function() action) async {
    if (_fileBusy) return;
    setState(() => _fileBusy = true);

    try {
      await action();
    } catch (error) {
      if (mounted) _message('تعذر تنفيذ العملية:\n$error');
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distributorsController = context.watch<DistributorController>();
    final recordsController = context.watch<LoadRecordsController>();
    final auth = context.watch<AuthController>();

    final distributors = distributorsController.distributors;
    final active = distributors.where((e) => e.active).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final records = recordsController.records;
    final isPresident = auth.currentUser?.role == UserRole.president;
    final index = _ReportScreenIndex.build(records, _selectedHour);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير أحمال الموزعات'),
        actions: [
          if (isPresident && _searched)
            IconButton(
              tooltip: 'حفظ التقرير على الجهاز',
              onPressed: _fileBusy || records.isEmpty
                  ? null
                  : () => _saveReport(records, distributors),
              icon: const Icon(Icons.save_alt),
            ),
          IconButton(
            tooltip: 'مشاركة PDF',
            onPressed: !_searched || _fileBusy || records.isEmpty
                ? null
                : () => _sharePdf(records, distributors),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'مشاركة Excel',
            onPressed: !_searched || _fileBusy || records.isEmpty
                ? null
                : () => _shareExcel(records, distributors),
            icon: const Icon(Icons.table_view_outlined),
          ),
          IconButton(
            tooltip: 'طباعة',
            onPressed: !_searched || _fileBusy || records.isEmpty
                ? null
                : () => _print(records, distributors),
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _search,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14),
          children: [
            _searchCard(distributorsController, recordsController),
            const SizedBox(height: 14),
            if (_fileBusy)
              const LinearProgressIndicator(),
            if (recordsController.isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (recordsController.errorMessage != null)
              _errorCard(recordsController.errorMessage!)
            else if (!_searched)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Text(
                    'اختر بيانات البحث ثم اضغط بحث.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (records.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Text(
                    'لا توجد بيانات مطابقة للبحث.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (_allDistributors)
              _allDistributorsResult(active, index)
            else
              _singleDistributorResult(
                records,
                _selectedDistributor(distributors),
                index,
              ),
          ],
        ),
      ),
    );
  }

  Widget _searchCard(
    DistributorController distributors,
    LoadRecordsController records,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'البحث والتصفية',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _selectedDistributorId,
              decoration: const InputDecoration(
                labelText: 'الموزع',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_tree),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('جميع الموزعات'),
                ),
                ...distributors.distributors.map(
                  (d) => DropdownMenuItem<String>(
                    value: d.id,
                    child: Text('${d.name} - ${d.code}'),
                  ),
                ),
              ],
              onChanged: records.isLoading
                  ? null
                  : (value) => setState(() {
                        _selectedDistributorId = value;
                        _searched = false;
                      }),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DateButton(
                  label: 'من',
                  value: _displayDate(_fromDate),
                  onPressed: records.isLoading
                      ? null
                      : () => _selectDate(from: true),
                ),
                _DateButton(
                  label: 'إلى',
                  value: _displayDate(_toDate),
                  onPressed: records.isLoading
                      ? null
                      : () => _selectDate(from: false),
                ),
                if (_allDistributors)
                  SizedBox(
                    width: 230,
                    child: DropdownButtonFormField<int>(
                      value: _selectedHour,
                      decoration: const InputDecoration(
                        labelText: 'الساعة',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.schedule),
                      ),
                      items: List.generate(
                        24,
                        (hour) => DropdownMenuItem<int>(
                          value: hour,
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00 - '
                            '${hour.toString().padLeft(2, '0')}:59',
                          ),
                        ),
                      ),
                      onChanged: records.isLoading
                          ? null
                          : (value) => setState(() {
                                _selectedHour = value ?? 0;
                                _searched = false;
                              }),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: records.isLoading ? null : _clear,
                  icon: const Icon(Icons.clear),
                  label: const Text('مسح البحث'),
                ),
                FilledButton.icon(
                  onPressed: records.isLoading ? null : _search,
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

  Widget _allDistributorsResult(
    List<Distributor> distributors,
    _ReportScreenIndex index,
  ) {
    final days = _daysBetween(_fromDate, _toDate);
    final groups = <List<Distributor>>[];

    for (var i = 0; i < distributors.length; i += 6) {
      groups.add(
        distributors.sublist(
          i,
          (i + 6) < distributors.length ? i + 6 : distributors.length,
        ),
      );
    }

    return Column(
      children: [
        for (final day in days)
          Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Text(
                    'أحمال الموزعات - ${_displayDate(day)} '
                    'الساعة ${_selectedHour.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  for (final group in groups)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _distributorTable(day, group, index),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _distributorTable(
    DateTime day,
    List<Distributor> distributors,
    _ReportScreenIndex index,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(72),
        border: TableBorder.all(color: Colors.black45, width: .6),
        children: [
          TableRow(
            children: [
              _cell('الخلية', bold: true),
              for (final d in distributors) ...[
                _cell('${d.name}\nالحمل', bold: true),
                _cell('${d.name}\nأقل', bold: true),
                _cell('${d.name}\nأقصى', bold: true),
              ],
            ],
          ),
          for (final cell in _cells)
            TableRow(
              children: [
                _cell('$cell', bold: true),
                for (final d in distributors) ...[
                  _cell(
                    index.current(
                      d.id,
                      day,
                      cell,
                    ),
                  ),
                  _cell(index.minimum(d.id, cell)),
                  _cell(index.maximum(d.id, cell)),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _singleDistributorResult(
    List<LoadRecord> records,
    Distributor? distributor,
    _ReportScreenIndex index,
  ) {
    final sorted = List<LoadRecord>.from(records)
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    final max = sorted.reduce(
      (a, b) => a.totalLoad >= b.totalLoad ? a : b,
    );
    final min = sorted.reduce(
      (a, b) => a.totalLoad <= b.totalLoad ? a : b,
    );

    final id = distributor?.id ?? sorted.first.distributorId;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Text(
                  distributor?.name ?? sorted.first.distributorName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'أقصى حمل: ${max.totalLoad.toStringAsFixed(2)} أمبير - '
                  '${_displayDateTime(max.recordedAt)}',
                ),
                Text(
                  'أقل حمل: ${min.totalLoad.toStringAsFixed(2)} أمبير - '
                  '${_displayDateTime(min.recordedAt)}',
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Table(
              border: TableBorder.all(color: Colors.black45),
              children: [
                TableRow(
                  children: [
                    _cell('الخلية', bold: true),
                    _cell('أقل', bold: true),
                    _cell('أقصى', bold: true),
                  ],
                ),
                for (final cell in _cells)
                  TableRow(
                    children: [
                      _cell('$cell', bold: true),
                      _cell(index.minimum(id, cell)),
                      _cell(index.maximum(id, cell)),
                    ],
                  ),
              ],
            ),
          ),
        ),
        for (final record in sorted.take(100))
          Card(
            child: ExpansionTile(
              title: Text(
                '${record.totalLoad.toStringAsFixed(2)} أمبير',
              ),
              subtitle: Text(_displayDateTime(record.recordedAt)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final cell in _cells)
                        Chip(
                          label: Text(
                            'خلية $cell: '
                            '${(record.cellValues[cell] ?? 0).toStringAsFixed(1)}',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _errorCard(String text) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(text),
      ),
    );
  }

  String _displayDate(DateTime value) {
    return DateFormat('yyyy/MM/dd').format(value);
  }

  String _displayDateTime(DateTime value) {
    return DateFormat('yyyy/MM/dd - HH:mm').format(value);
  }

  List<DateTime> _daysBetween(DateTime from, DateTime to) {
    final result = <DateTime>[];
    var current = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    while (!current.isAfter(end)) {
      result.add(current);
      current = current.add(const Duration(days: 1));
    }
    return result;
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.date_range),
        label: Text('$label\n$value'),
      ),
    );
  }
}

class _ReportScreenIndex {
  _ReportScreenIndex({
    required this.latest,
    required this.ranges,
  });

  final Map<String, LoadRecord> latest;
  final Map<String, _ScreenRange> ranges;

  factory _ReportScreenIndex.build(List<LoadRecord> records, int hour) {
    final latest = <String, LoadRecord>{};
    final mutable = <String, _MutableScreenRange>{};

    for (final record in records) {
      final d = record.recordedAt;
      if (d.hour == hour) {
        final key =
            '${record.distributorId}|${d.year}|${d.month}|${d.day}';
        final old = latest[key];
        if (old == null || record.recordedAt.isAfter(old.recordedAt)) {
          latest[key] = record;
        }
      }

      for (final entry in record.cellValues.entries) {
        final key = '${record.distributorId}|${entry.key}';
        mutable.putIfAbsent(key, _MutableScreenRange.new).add(entry.value);
      }
    }

    return _ReportScreenIndex(
      latest: latest,
      ranges: {
        for (final e in mutable.entries)
          e.key: _ScreenRange(
            minimum: e.value.minimum,
            maximum: e.value.maximum,
          ),
      },
    );
  }

  String current(String distributorId, DateTime day, int cell) {
    final key =
        '$distributorId|${day.year}|${day.month}|${day.day}';
    final record = latest[key];
    if (record == null) return 'لم يسجل';
    return (record.cellValues[cell] ?? 0).toStringAsFixed(1);
  }

  String minimum(String distributorId, int cell) {
    final value = ranges['$distributorId|$cell']?.minimum;
    return value == null ? '—' : value.toStringAsFixed(1);
  }

  String maximum(String distributorId, int cell) {
    final value = ranges['$distributorId|$cell']?.maximum;
    return value == null ? '—' : value.toStringAsFixed(1);
  }
}

class _MutableScreenRange {
  double? minimum;
  double? maximum;

  void add(double value) {
    if (minimum == null || value < minimum!) minimum = value;
    if (maximum == null || value > maximum!) maximum = value;
  }
}

class _ScreenRange {
  const _ScreenRange({
    this.minimum,
    this.maximum,
  });

  final double? minimum;
  final double? maximum;
}
