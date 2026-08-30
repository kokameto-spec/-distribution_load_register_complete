import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../models/vehicle.dart';
import '../services/firebase_service.dart';
import '../services/report_pdf_service.dart';
import '../widgets/fueling_report_page.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});
  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _vehicleFilter = 'الكل';

  String get _monthKey => DateFormat('yyyy-MM').format(_month);

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(context: context, initialDate: _month, firstDate: DateTime(2024), lastDate: DateTime(2035), helpText: 'اختر أي يوم من الشهر المطلوب');
    if (picked != null) setState(() => _month = DateTime(picked.year, picked.month));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('صفحة المدير'),
          bottom: const TabBar(tabs: [Tab(text: 'تقارير التموين', icon: Icon(Icons.description)), Tab(text: 'كشف الاستهلاك', icon: Icon(Icons.table_chart)), Tab(text: 'السيارات', icon: Icon(Icons.directions_car))]),
        ),
        body: TabBarView(children: [_reports(), _consumption(), const _VehiclesAdmin()]),
      ),
    );
  }

  Widget _monthBar({Widget? trailing}) => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(children: [
      OutlinedButton.icon(onPressed: _pickMonth, icon: const Icon(Icons.calendar_month), label: Text(DateFormat('MMMM yyyy', 'ar').format(_month))),
      const SizedBox(width: 12),
      if (trailing != null) Expanded(child: trailing),
    ]),
  );

  Widget _reports() {
    return Column(children: [
      StreamBuilder<List<Vehicle>>(
        stream: FirebaseService.instance.vehiclesStream(),
        builder: (_, snap) {
          final numbers = ['الكل', ...?snap.data?.map((v) => v.number)];
          if (!numbers.contains(_vehicleFilter)) _vehicleFilter = 'الكل';
          return _monthBar(
            trailing: DropdownButtonFormField<String>(
              initialValue: _vehicleFilter,
              decoration: const InputDecoration(labelText: 'السيارة'),
              items: numbers.toSet().map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
              onChanged: (v) => setState(() => _vehicleFilter = v ?? 'الكل'),
            ),
          );
        },
      ),
      Expanded(
        child: StreamBuilder(
          stream: FirebaseService.instance.monthlyFuelings(_monthKey),
          builder: (_, snap) {
            if (snap.hasError) return Center(child: Text('خطأ: ${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final all = snap.data!;
            final records = _vehicleFilter == 'الكل' ? all : all.where((r) => r.vehicleNumber == _vehicleFilter).toList();
            if (records.isEmpty) return const Center(child: Text('لا توجد تموينات في الشهر المحدد.'));
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  Text('${records.length} صفحة تموين', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  FilledButton.icon(onPressed: () => Printing.layoutPdf(onLayout: (_) => ReportPdfService.fuelingPages(records), name: 'تقارير_تموين_${_vehicleFilter}_$_monthKey.pdf'), icon: const Icon(Icons.print), label: const Text('طباعة / PDF')),
                ]),
              ),
              const SizedBox(height: 8),
              Expanded(child: PageView.builder(itemCount: records.length, itemBuilder: (_, i) => Padding(padding: const EdgeInsets.all(12), child: Center(child: FuelingReportPage(record: records[i]))))),
            ]);
          },
        ),
      ),
    ]);
  }

  Widget _consumption() {
    return Column(children: [
      _monthBar(),
      Expanded(child: StreamBuilder(
        stream: FirebaseService.instance.monthlyConsumption(_monthKey),
        builder: (_, snap) {
          if (snap.hasError) return Center(child: Text('خطأ: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data!;
          if (rows.isEmpty) return const Center(child: Text('لا توجد قراءات في الشهر المحدد.'));
          return Column(children: [
            Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: FilledButton.icon(onPressed: () => Printing.layoutPdf(onLayout: (_) => ReportPdfService.consumptionTable(rows, _monthKey), name: 'كشف_الاستهلاك_$_monthKey.pdf'), icon: const Icon(Icons.print), label: const Text('طباعة / PDF')))),
            const SizedBox(height: 8),
            Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child: DataTable(columns: const [
              DataColumn(label: Text('التاريخ')), DataColumn(label: Text('رقم السيارة')), DataColumn(label: Text('العداد السابق')), DataColumn(label: Text('العداد الحالي')), DataColumn(label: Text('المسافة')), DataColumn(label: Text('توقيع السائق')), DataColumn(label: Text('توقيع مسئول النقل')),
            ], rows: rows.map((r) => DataRow(cells: [DataCell(Text(DateFormat('yyyy/MM/dd').format(r.date))), DataCell(Text(r.vehicleNumber)), DataCell(Text(r.previousOdometer?.toString() ?? '-')), DataCell(Text(r.currentOdometer.toString())), DataCell(Text(r.distance?.toString() ?? '-')), DataCell(Text(r.driverName)), const DataCell(Text('................'))])).toList())))),
          ]);
        },
      )),
    ]);
  }
}

class _VehiclesAdmin extends StatefulWidget {
  const _VehiclesAdmin();
  @override
  State<_VehiclesAdmin> createState() => _VehiclesAdminState();
}

class _VehiclesAdminState extends State<_VehiclesAdmin> {
  Future<void> _add() async {
    final code = TextEditingController(); final number = TextEditingController(); final model = TextEditingController(); final fuel = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('إضافة / تحديث سيارة'), content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: code, decoration: const InputDecoration(labelText: 'كود السيارة')), const SizedBox(height: 8),
      TextField(controller: number, decoration: const InputDecoration(labelText: 'رقم السيارة')), const SizedBox(height: 8),
      TextField(controller: fuel, decoration: const InputDecoration(labelText: 'نوع الوقود')), const SizedBox(height: 8),
      TextField(controller: model, decoration: const InputDecoration(labelText: 'موديل / ماركة السيارة')),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ'))]));
    if (ok == true && code.text.trim().isNotEmpty && number.text.trim().isNotEmpty) {
      await FirebaseService.instance.saveVehicle(Vehicle(code: code.text.trim(), number: number.text.trim(), fuelType: fuel.text.trim(), model: model.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('إضافة سيارة')))),
    Expanded(child: StreamBuilder<List<Vehicle>>(stream: FirebaseService.instance.vehiclesStream(), builder: (_, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      return ListView.separated(itemCount: snap.data!.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) { final v = snap.data![i]; return ListTile(leading: const CircleAvatar(child: Icon(Icons.directions_car)), title: Text(v.number), subtitle: Text('الكود: ${v.code} | ${v.fuelType} | ${v.model}')); });
    })),
  ]);
}
