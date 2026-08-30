import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../models/app_user.dart';
import '../models/consumption_entry.dart';
import '../models/fueling_record.dart';
import '../models/vehicle.dart';
import '../services/app_auth_service.dart';
import '../services/firebase_service.dart';
import '../services/report_pdf_service.dart';
import '../widgets/fueling_report_page.dart';

class ManagerScreen extends StatefulWidget {
  final AppUser user;
  const ManagerScreen({super.key, required this.user});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _vehicleFilter = 'الكل';
  final _picker = ImagePicker();

  String get _monthKey => DateFormat('yyyy-MM').format(_month);

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: 'اختر أي يوم من الشهر المطلوب',
    );
    if (picked != null) setState(() => _month = DateTime(picked.year, picked.month));
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('صفحة المدير'),
            actions: [IconButton(onPressed: () => Navigator.pop(context), tooltip: 'تسجيل الخروج', icon: const Icon(Icons.logout))],
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'تقارير التموين', icon: Icon(Icons.description)),
                Tab(text: 'كشف الاستهلاك', icon: Icon(Icons.table_chart)),
                Tab(text: 'السيارات', icon: Icon(Icons.directions_car)),
                Tab(text: 'المستخدمون', icon: Icon(Icons.manage_accounts)),
              ],
            ),
          ),
          body: TabBarView(children: [_reports(), _consumption(), const _VehiclesAdmin(), const _UsersAdmin()]),
        ),
      );

  Widget _monthBar({Widget? trailing}) => Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          OutlinedButton.icon(
            onPressed: _pickMonth,
            icon: const Icon(Icons.calendar_month),
            label: Text(DateFormat('MMMM yyyy', 'ar').format(_month)),
          ),
          const SizedBox(width: 12),
          if (trailing != null) Expanded(child: trailing),
        ]),
      );

  Future<void> _savePdf(List<FuelingRecord> records) async {
    try {
      final bytes = await ReportPdfService.fuelingPages(records);
      final path = await ReportPdfService.savePdf(bytes, 'تقارير_تموين_${_vehicleFilter}_$_monthKey.pdf');
      _msg('تم الحفظ: $path');
    } catch (e) {
      _msg('تعذر الحفظ: $e');
    }
  }

  Future<void> _printPdf(List<FuelingRecord> records) async {
    try {
      await Printing.layoutPdf(onLayout: (_) => ReportPdfService.fuelingPages(records), name: 'تقارير_تموين_${_vehicleFilter}_$_monthKey.pdf');
    } catch (e) {
      _msg('تعذرت الطباعة: $e');
    }
  }

  Future<void> _sharePdf(List<FuelingRecord> records) async {
    try {
      final bytes = await ReportPdfService.fuelingPages(records);
      await ReportPdfService.sharePdf(bytes, 'تقارير_تموين_${_vehicleFilter}_$_monthKey.pdf');
    } catch (e) {
      _msg('تعذرت المشاركة: $e');
    }
  }

  Future<void> _editFueling(FuelingRecord record) async {
    final name = TextEditingController(text: record.driverName);
    final odo = TextEditingController(text: record.odometer.toString());
    final replacements = <int, File>{};
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('تعديل التموينة'),
              content: SizedBox(
                width: 470,
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('السيارة: ${record.vehicleNumber} — ${record.vehicleModel}'),
                    const SizedBox(height: 10),
                    TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم السائق')),
                    const SizedBox(height: 10),
                    TextField(controller: odo, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'قراءة العداد', suffixText: 'كم')),
                    const SizedBox(height: 12),
                    const Text('استبدال الصور (اختياري)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(4, (i) {
                        final order = i + 1;
                        return OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 70);
                            if (picked != null) setDialogState(() => replacements[order] = File(picked.path));
                          },
                          icon: Icon(replacements.containsKey(order) ? Icons.check_circle : Icons.image),
                          label: Text('الصورة $order'),
                        );
                      }),
                    ),
                  ]),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ التعديل')),
              ],
            ),
          ),
        ) ??
        false;
    if (!ok) return;
    final newOdo = int.tryParse(odo.text.replaceAll(',', '').trim());
    if (newOdo == null || name.text.trim().isEmpty) return;
    try {
      await FirebaseService.instance.updateFueling(
        record: record,
        driverName: name.text.trim(),
        odometer: newOdo,
        replacementImages: replacements,
      );
      _msg('تم تعديل التموينة.');
    } catch (e) {
      _msg('تعذر التعديل: $e');
    }
  }

  Future<void> _deleteFueling(FuelingRecord record) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('حذف التموينة'),
            content: const Text('سيتم حذف التموينة والصور وقراءة العداد المرتبطة بها.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await FirebaseService.instance.deleteFueling(record.id, record.vehicleCode);
      _msg('تم الحذف.');
    } catch (e) {
      _msg('تعذر الحذف: $e');
    }
  }

  Widget _reports() => Column(children: [
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
          child: StreamBuilder<List<FuelingRecord>>(
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
                    IconButton(onPressed: () => _savePdf(records), tooltip: 'حفظ PDF', icon: const Icon(Icons.save_alt)),
                    IconButton(onPressed: () => _printPdf(records), tooltip: 'طباعة', icon: const Icon(Icons.print)),
                    IconButton(onPressed: () => _sharePdf(records), tooltip: 'مشاركة', icon: const Icon(Icons.share)),
                  ]),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 20),
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) {
                      final record = records[i];
                      return Column(children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            child: Row(children: [
                              Text('تموينة ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              IconButton(onPressed: () => _editFueling(record), tooltip: 'تعديل', icon: const Icon(Icons.edit)),
                              IconButton(onPressed: () => _savePdf([record]), tooltip: 'حفظ', icon: const Icon(Icons.save_alt)),
                              IconButton(onPressed: () => _printPdf([record]), tooltip: 'طباعة', icon: const Icon(Icons.print)),
                              IconButton(onPressed: () => _sharePdf([record]), tooltip: 'مشاركة', icon: const Icon(Icons.share)),
                              IconButton(onPressed: () => _deleteFueling(record), tooltip: 'حذف', icon: const Icon(Icons.delete_outline, color: Colors.red)),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: FuelingReportPage(record: record),
                          ),
                        ),
                      ]);
                    },
                  ),
                ),
              ]);
            },
          ),
        ),
      ]);

  Future<void> _editConsumption(ConsumptionEntry entry) async {
    final controller = TextEditingController(text: entry.currentOdometer.toString());
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('تعديل قراءة العداد'),
            content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'العداد الحالي', suffixText: 'كم')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    final value = int.tryParse(controller.text.replaceAll(',', '').trim());
    if (value == null) return;
    try {
      await FirebaseService.instance.updateConsumptionReading(entry, value);
      _msg('تم تعديل القراءة.');
    } catch (e) {
      _msg('تعذر تعديل القراءة: $e');
    }
  }

  Widget _consumption() => Column(children: [
        _monthBar(),
        Expanded(
          child: StreamBuilder<List<ConsumptionEntry>>(
            stream: FirebaseService.instance.monthlyConsumption(_monthKey),
            builder: (_, snap) {
              if (snap.hasError) return Center(child: Text('خطأ: ${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final rows = snap.data!;
              if (rows.isEmpty) return const Center(child: Text('لا توجد قراءات في الشهر المحدد.'));
              return Column(children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(spacing: 6, children: [
                      IconButton(
                        tooltip: 'حفظ PDF',
                        onPressed: () async {
                          try {
                            final bytes = await ReportPdfService.consumptionTable(rows, _monthKey);
                            final path = await ReportPdfService.savePdf(bytes, 'كشف_الاستهلاك_$_monthKey.pdf');
                            _msg('تم الحفظ: $path');
                          } catch (e) {
                            _msg('تعذر الحفظ: $e');
                          }
                        },
                        icon: const Icon(Icons.save_alt),
                      ),
                      IconButton(
                        tooltip: 'طباعة',
                        onPressed: () async {
                          try {
                            await Printing.layoutPdf(onLayout: (_) => ReportPdfService.consumptionTable(rows, _monthKey), name: 'كشف_الاستهلاك_$_monthKey.pdf');
                          } catch (e) {
                            _msg('تعذرت الطباعة: $e');
                          }
                        },
                        icon: const Icon(Icons.print),
                      ),
                      IconButton(
                        tooltip: 'مشاركة',
                        onPressed: () async {
                          try {
                            final bytes = await ReportPdfService.consumptionTable(rows, _monthKey);
                            await ReportPdfService.sharePdf(bytes, 'كشف_الاستهلاك_$_monthKey.pdf');
                          } catch (e) {
                            _msg('تعذرت المشاركة: $e');
                          }
                        },
                        icon: const Icon(Icons.share),
                      ),
                    ]),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('التاريخ')),
                          DataColumn(label: Text('رقم السيارة')),
                          DataColumn(label: Text('العداد السابق')),
                          DataColumn(label: Text('العداد الحالي')),
                          DataColumn(label: Text('المسافة')),
                          DataColumn(label: Text('توقيع السائق')),
                          DataColumn(label: Text('توقيع مسئول النقل')),
                          DataColumn(label: Text('إجراء')),
                        ],
                        rows: rows.map((r) => DataRow(cells: [
                          DataCell(Text(DateFormat('yyyy/MM/dd').format(r.date))),
                          DataCell(Text(r.vehicleNumber)),
                          DataCell(Text(r.previousOdometer?.toString() ?? '-')),
                          DataCell(Text(r.currentOdometer.toString())),
                          DataCell(Text(r.distance?.toString() ?? '-')),
                          DataCell(Text(r.driverName)),
                          const DataCell(Text('................')),
                          DataCell(Row(children: [
                            IconButton(onPressed: () => _editConsumption(r), icon: const Icon(Icons.edit, size: 20)),
                            IconButton(
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('حذف القراءة والتموينة'),
                                        content: const Text('الحذف سيشمل تقرير التموينة والصور المرتبطة بهذه القراءة.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
                                        ],
                                      ),
                                    ) ??
                                    false;
                                if (ok) await FirebaseService.instance.deleteFueling(r.id, r.vehicleCode);
                              },
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            ),
                          ])),
                        ])).toList(),
                      ),
                    ),
                  ),
                ),
              ]);
            },
          ),
        ),
      ]);
}

class _VehiclesAdmin extends StatefulWidget {
  const _VehiclesAdmin();
  @override
  State<_VehiclesAdmin> createState() => _VehiclesAdminState();
}

class _VehiclesAdminState extends State<_VehiclesAdmin> {
  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('حذف السيارة'),
            content: Text('هل تريد حذف السيارة ${vehicle.number}؟ ستظل التقارير القديمة محفوظة.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await FirebaseService.instance.deleteVehicle(vehicle.code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف السيارة.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف السيارة: $e')));
      }
    }
  }

  Future<void> _edit([Vehicle? existing]) async {
    final code = TextEditingController(text: existing?.code ?? '');
    final number = TextEditingController(text: existing?.number ?? '');
    final model = TextEditingController(text: existing?.model ?? '');
    final fuel = TextEditingController(text: existing?.fuelType ?? '');
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(existing == null ? 'إضافة سيارة' : 'تعديل السيارة'),
            content: SizedBox(
              width: 420,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: code, enabled: existing == null, decoration: const InputDecoration(labelText: 'كود السيارة')),
                const SizedBox(height: 8),
                TextField(controller: number, decoration: const InputDecoration(labelText: 'رقم السيارة')),
                const SizedBox(height: 8),
                TextField(controller: fuel, decoration: const InputDecoration(labelText: 'نوع الوقود')),
                const SizedBox(height: 8),
                TextField(controller: model, decoration: const InputDecoration(labelText: 'موديل / ماركة السيارة')),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
            ],
          ),
        ) ??
        false;
    if (ok && code.text.trim().isNotEmpty && number.text.trim().isNotEmpty) {
      await FirebaseService.instance.saveVehicle(Vehicle(code: code.text.trim(), number: number.text.trim(), fuelType: fuel.text.trim(), model: model.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('إضافة سيارة'))),
        ),
        Expanded(
          child: StreamBuilder<List<Vehicle>>(
            stream: FirebaseService.instance.vehiclesStream(),
            builder: (_, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              return ListView.separated(
                itemCount: snap.data!.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final v = snap.data![i];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.directions_car)),
                    title: Text(v.number),
                    subtitle: Text('الكود: ${v.code} | ${v.fuelType} | ${v.model}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(onPressed: () => _edit(v), tooltip: 'تعديل السيارة', icon: const Icon(Icons.edit)),
                        const SizedBox(width: 6),
                        IconButton(onPressed: () => _deleteVehicle(v), tooltip: 'حذف السيارة', icon: const Icon(Icons.delete_outline, color: Colors.red)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]);
}

class _UsersAdmin extends StatefulWidget {
  const _UsersAdmin();
  @override
  State<_UsersAdmin> createState() => _UsersAdminState();
}

class _UsersAdminState extends State<_UsersAdmin> {
  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _deleteUser(AppUser user) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('حذف المستخدم'),
            content: Text('هل تريد حذف المستخدم ${user.displayName} (${user.username})؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await AppAuthService.instance.deleteUser(user.username);
      _msg('تم حذف المستخدم.');
    } catch (e) {
      _msg('تعذر حذف المستخدم: $e');
    }
  }

  Future<void> _editUser(List<Vehicle> vehicles, [AppUser? existing]) async {
    final username = TextEditingController(text: existing?.username ?? '');
    final displayName = TextEditingController(text: existing?.displayName ?? '');
    final password = TextEditingController();
    var role = existing?.role ?? 'driver';
    var vehicleCode = existing?.vehicleCode ?? '';
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(existing == null ? 'إضافة مستخدم' : 'تعديل المستخدم'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(controller: username, enabled: existing == null, decoration: const InputDecoration(labelText: 'اسم المستخدم')),
                    const SizedBox(height: 8),
                    TextField(controller: displayName, decoration: const InputDecoration(labelText: 'اسم السائق / المستخدم')),
                    const SizedBox(height: 8),
                    TextField(controller: password, obscureText: true, decoration: InputDecoration(labelText: existing == null ? 'كلمة المرور' : 'كلمة مرور جديدة (اختياري)')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(labelText: 'نوع المستخدم'),
                      items: const [
                        DropdownMenuItem(value: 'driver', child: Text('سائق')),
                        DropdownMenuItem(value: 'manager', child: Text('مدير')),
                      ],
                      onChanged: (v) => setDialogState(() {
                        role = v ?? 'driver';
                        if (role == 'manager') vehicleCode = '';
                      }),
                    ),
                    if (role == 'driver') ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: vehicles.any((v) => v.code == vehicleCode) ? vehicleCode : null,
                        decoration: const InputDecoration(labelText: 'السيارة المرتبطة'),
                        items: vehicles.map((v) => DropdownMenuItem(value: v.code, child: Text('${v.number} — ${v.model}'))).toList(),
                        onChanged: (v) => vehicleCode = v ?? '',
                      ),
                    ],
                  ]),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
              ],
            ),
          ),
        ) ??
        false;
    if (!ok) return;
    if (username.text.trim().isEmpty || displayName.text.trim().isEmpty || (role == 'driver' && vehicleCode.isEmpty)) return;
    try {
      await AppAuthService.instance.saveUser(
        user: AppUser(
          username: username.text.trim().toLowerCase(),
          displayName: displayName.text.trim(),
          role: role,
          vehicleCode: vehicleCode,
        ),
        newPassword: password.text,
      );
      _msg('تم حفظ المستخدم.');
    } catch (e) {
      _msg('تعذر حفظ المستخدم: $e');
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Vehicle>>(
        stream: FirebaseService.instance.vehiclesStream(),
        builder: (_, vehicleSnap) {
          final vehicles = vehicleSnap.data ?? const <Vehicle>[];
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(onPressed: () => _editUser(vehicles), icon: const Icon(Icons.person_add), label: const Text('إضافة مستخدم')),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<AppUser>>(
                stream: AppAuthService.instance.usersStream(),
                builder: (_, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  return ListView.separated(
                    itemCount: snap.data!.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final user = snap.data![i];
                      Vehicle? car;
                      for (final v in vehicles) {
                        if (v.code == user.vehicleCode) {
                          car = v;
                          break;
                        }
                      }
                      return ListTile(
                        leading: CircleAvatar(child: Icon(user.isManager ? Icons.admin_panel_settings : Icons.person)),
                        title: Text(user.displayName),
                        subtitle: Text('${user.username} — ${user.isManager ? 'مدير' : 'سائق'}${car == null ? '' : ' — ${car.number}'}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(onPressed: () => _editUser(vehicles, user), tooltip: 'تعديل', icon: const Icon(Icons.edit)),
                            if (user.username.toLowerCase() != 'admin')
                              IconButton(onPressed: () => _deleteUser(user), tooltip: 'حذف', icon: const Icon(Icons.delete_outline, color: Colors.red)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ]);
        },
      );
}
