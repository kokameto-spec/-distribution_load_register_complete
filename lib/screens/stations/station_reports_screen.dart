import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/station_controller.dart';
import '../../controllers/station_report_controller.dart';
import '../../core/services/station_report_excel_service.dart';
import '../../core/services/station_report_pdf_service.dart';
import '../../models/station_load_report.dart';
import '../../models/station_model.dart';
import '../../widgets/load_line_chart.dart';

class StationReportsScreen extends StatefulWidget {
  const StationReportsScreen({super.key});

  @override
  State<StationReportsScreen> createState() => _StationReportsScreenState();
}

class _StationReportsScreenState extends State<StationReportsScreen> {
  String? _selectedStationId;
  String? _selectedTransformerId;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  TimeOfDay _fromTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _toTime = const TimeOfDay(hour: 23, minute: 59);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final stations = context.read<StationController>();
      if (!stations.isListening) stations.startListening();
    });
  }

  Station? _selectedStation(List<Station> stations) {
    if (_selectedStationId == null) return null;
    for (final station in stations) {
      if (station.id == _selectedStationId) return station;
    }
    return null;
  }

  DateTime get _fromDateTime => DateTime(
        _fromDate.year,
        _fromDate.month,
        _fromDate.day,
        _fromTime.hour,
        _fromTime.minute,
      );

  DateTime get _toDateTime => DateTime(
        _toDate.year,
        _toDate.month,
        _toDate.day,
        _toTime.hour,
        _toTime.minute,
        59,
        999,
      );

  Future<void> _pickFromDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value != null && mounted) setState(() => _fromDate = value);
  }

  Future<void> _pickToDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value != null && mounted) setState(() => _toDate = value);
  }

  Future<void> _pickFromTime() async {
    final value = await showTimePicker(context: context, initialTime: _fromTime);
    if (value != null && mounted) setState(() => _fromTime = value);
  }

  Future<void> _pickToTime() async {
    final value = await showTimePicker(context: context, initialTime: _toTime);
    if (value != null && mounted) setState(() => _toTime = value);
  }

  void _setQuickRange(int days) {
    final now = DateTime.now();
    setState(() {
      _toDate = DateTime(now.year, now.month, now.day);
      _toTime = const TimeOfDay(hour: 23, minute: 59);
      final start = now.subtract(Duration(days: days - 1));
      _fromDate = DateTime(start.year, start.month, start.day);
      _fromTime = const TimeOfDay(hour: 0, minute: 0);
    });
    context.read<StationReportController>().clear();
  }

  Future<void> _search() async {
    final stations = context.read<StationController>().stations;
    final station = _selectedStation(stations);
    if (station == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر محطة أولًا.')),
      );
      return;
    }

    if (_fromDateTime.isAfter(_toDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بداية الفترة يجب أن تسبق نهايتها.')),
      );
      return;
    }

    await context.read<StationReportController>().search(
          station: station,
          transformerId: _selectedTransformerId,
          fromDate: _fromDateTime,
          toDate: _toDateTime,
        );
  }

  Future<void> _print() async {
    final report = context.read<StationReportController>().result;
    if (report == null) return;
    try {
      await StationReportPdfService.printReport(report);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر طباعة التقرير.')),
      );
    }
  }

  Future<void> _share() async {
    final report = context.read<StationReportController>().result;
    if (report == null) return;
    try {
      await StationReportPdfService.shareReport(report);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر مشاركة التقرير.')),
      );
    }
  }

  Future<void> _exportExcel() async {
    final report = context.read<StationReportController>().result;
    if (report == null) return;
    try {
      await StationReportExcelService.exportReport(report);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تصدير ملف Excel.')),
      );
    }
  }

  String _date(DateTime value) => DateFormat('yyyy/MM/dd').format(value);
  String _time(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  String _dateTime(DateTime? value) => value == null
      ? 'لا توجد بيانات'
      : DateFormat('yyyy/MM/dd - HH:mm').format(value);

  @override
  Widget build(BuildContext context) {
    final stationsController = context.watch<StationController>();
    final reportController = context.watch<StationReportController>();
    final stations = stationsController.stations.where((item) => item.active).toList();
    final selectedStation = _selectedStation(stations);

    return Scaffold(
      appBar: AppBar(title: const Text('تقارير أحمال المحطات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFilters(stations, selectedStation, reportController.isLoading),
          const SizedBox(height: 14),
          if (reportController.errorMessage != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  reportController.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          if (reportController.isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (reportController.result != null)
            _buildReport(reportController.result!),
        ],
      ),
    );
  }

  Widget _buildFilters(
    List<Station> stations,
    Station? selectedStation,
    bool loading,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedStationId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'المحطة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_tree_outlined),
              ),
              items: stations
                  .map((station) => DropdownMenuItem(
                        value: station.id,
                        child: Text(station.name),
                      ))
                  .toList(),
              onChanged: loading
                  ? null
                  : (value) {
                      setState(() {
                        _selectedStationId = value;
                        _selectedTransformerId = null;
                      });
                      context.read<StationReportController>().clear();
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedTransformerId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'المحول - اختياري',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.transform_outlined),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('كل محولات المحطة'),
                ),
                ...?selectedStation?.transformers.map(
                  (item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text('${item.name} - ${item.linksSummary}'),
                  ),
                ),
              ],
              onChanged: selectedStation == null || loading
                  ? null
                  : (value) => setState(() => _selectedTransformerId = value),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('اليوم'),
                    onPressed: loading ? null : () => _setQuickRange(1),
                  ),
                  ActionChip(
                    label: const Text('3 أيام'),
                    onPressed: loading ? null : () => _setQuickRange(3),
                  ),
                  ActionChip(
                    label: const Text('7 أيام'),
                    onPressed: loading ? null : () => _setQuickRange(7),
                  ),
                  ActionChip(
                    label: const Text('30 يوم'),
                    onPressed: loading ? null : () => _setQuickRange(30),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: loading ? null : _pickFromDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text('من تاريخ: ${_date(_fromDate)}'),
                ),
                OutlinedButton.icon(
                  onPressed: loading ? null : _pickFromTime,
                  icon: const Icon(Icons.schedule),
                  label: Text('من وقت: ${_time(_fromTime)}'),
                ),
                OutlinedButton.icon(
                  onPressed: loading ? null : _pickToDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text('إلى تاريخ: ${_date(_toDate)}'),
                ),
                OutlinedButton.icon(
                  onPressed: loading ? null : _pickToTime,
                  icon: const Icon(Icons.schedule),
                  label: Text('إلى وقت: ${_time(_toTime)}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: loading ? null : _search,
                icon: const Icon(Icons.search),
                label: const Text('بحث وعرض التقرير'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReport(StationLoadReportResult report) {
    final stats = report.stationStatistics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  report.station.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _stat('الحمل الحالي', report.currentStationSnapshot?.totalLoad, report.currentStationSnapshot?.recordedAt),
                    _stat('أقل حمل', stats.minimum, stats.minimumPoint?.recordedAt),
                    _stat('أعلى حمل', stats.maximum, stats.maximumPoint?.recordedAt),
                    _stat('متوسط الحمل', stats.count == 0 ? null : stats.average, null),
                  ],
                ),
                const SizedBox(height: 10),
                Text('عدد القراءات الكاملة للمحطة: ${stats.count}'),
                if (stats.count == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'لا يتم احتساب إجمالي المحطة إلا للساعة التي تتوفر فيها قراءة لكل الموزعات المرتبطة بمحولات المحطة.',
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (report.stationSnapshots.isNotEmpty) ...[
          const SizedBox(height: 10),
          LoadLineChart(
            title: 'منحنى إجمالي حمل المحطة',
            points: report.stationSnapshots
                .map(
                  (item) => LoadChartPoint(
                    time: item.recordedAt,
                    value: item.totalLoad,
                  ),
                )
                .toList(growable: false),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _print,
              icon: const Icon(Icons.print_outlined),
              label: const Text('طباعة PDF'),
            ),
            OutlinedButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.share_outlined),
              label: const Text('مشاركة PDF'),
            ),
            OutlinedButton.icon(
              onPressed: _exportExcel,
              icon: const Icon(Icons.table_view_outlined),
              label: const Text('تصدير Excel'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...report.transformerSummaries.map(_transformerCard),
        if (report.stationSnapshots.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'قراءات إجمالي المحطة حسب الساعة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ...report.stationSnapshots.take(100).map(
                    (item) => ListTile(
                      dense: true,
                      title: Text(_dateTime(item.recordedAt)),
                      trailing: Text(
                        '${item.totalLoad.toStringAsFixed(1)} A',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _transformerCard(TransformerReportSummary summary) {
    final stats = summary.statistics;
    return Card(
      child: ExpansionTile(
        title: Text(summary.transformer.name),
        subtitle: Text(
          summary.transformer.linksSummary,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _stat('الحالي', summary.currentReading?.load, summary.currentReading?.recordedAt),
              _stat('الأقل', stats.minimum, stats.minimumPoint?.recordedAt),
              _stat('الأعلى', stats.maximum, stats.maximumPoint?.recordedAt),
              _stat('المتوسط', stats.count == 0 ? null : stats.average, null),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text('عدد القراءات: ${stats.count}'),
          ),
          if (summary.readings.isNotEmpty) ...[
            const SizedBox(height: 8),
            LoadLineChart(
              title: 'منحنى حمل ${summary.transformer.name}',
              points: summary.readings
                  .map(
                    (item) => LoadChartPoint(
                      time: item.recordedAt,
                      value: item.load,
                    ),
                  )
                  .toList(growable: false),
              height: 190,
            ),
          ],
          const Divider(),
          ...summary.readings.take(100).map(
                (reading) => ListTile(
                  dense: true,
                  leading: Icon(
                    reading.running ? Icons.check_circle_outline : Icons.pause_circle_outline,
                  ),
                  title: Text(_dateTime(reading.recordedAt)),
                  trailing: Text(
                    '${reading.load.toStringAsFixed(1)} A',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _stat(String title, double? value, DateTime? time) {
    return SizedBox(
      width: 230,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              const SizedBox(height: 3),
              Text(
                value == null ? 'لا توجد بيانات' : '${value.toStringAsFixed(1)} A',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              if (time != null) ...[
                const SizedBox(height: 3),
                Text(_dateTime(time), style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
