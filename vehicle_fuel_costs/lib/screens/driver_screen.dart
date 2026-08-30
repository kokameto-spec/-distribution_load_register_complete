import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/vehicle.dart';
import '../services/firebase_service.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});
  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _odometer = TextEditingController();
  final _picker = ImagePicker();
  bool _busy = false;

  static const _photoTitles = [
    'صورة مؤشر الوقود قبل التموين',
    'صورة مضخة الوقود',
    'صورة مؤشر الوقود بعد التموين',
    'صورة إيصال المحطة',
  ];

  Future<void> _start() async {
    final name = _name.text.trim();
    final odo = int.tryParse(_odometer.text.replaceAll(',', '').trim());
    if (_code.text.trim().isEmpty || name.isEmpty || odo == null) {
      _msg('أدخل كود السيارة واسم السائق وقراءة العداد.');
      return;
    }
    setState(() => _busy = true);
    try {
      final vehicle = await FirebaseService.instance.vehicleByCode(_code.text.trim());
      if (vehicle == null) {
        _msg('كود السيارة غير صحيح أو السيارة غير مفعلة.');
        return;
      }
      final images = <File>[];
      for (var i = 0; i < 4; i++) {
        if (!mounted) return;
        final file = await Navigator.push<XFile?>(context, MaterialPageRoute(builder: (_) => _CaptureStep(title: _photoTitles[i], step: i + 1, picker: _picker)));
        if (file == null) {
          _msg('تم إلغاء العملية قبل اكتمال الصور الأربع.');
          return;
        }
        images.add(File(file.path));
      }
      if (!mounted) return;
      final ok = await _confirm(vehicle, images);
      if (!ok) return;
      await FirebaseService.instance.submitFueling(vehicle: vehicle, driverName: name, odometer: odo, images: images);
      _code.clear(); _name.clear(); _odometer.clear();
      if (mounted) {
        await showDialog(context: context, builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 52),
          title: const Text('تم الإرسال بنجاح'),
          content: const Text('تم حفظ الصور وبيانات التموينة وإضافة قراءة العداد لكشف الاستهلاك.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('تم'))],
        ));
      }
    } catch (e) {
      _msg('تعذر الإرسال: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(Vehicle vehicle, List<File> images) async {
    return await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('مراجعة قبل الإرسال'),
      content: SizedBox(width: 430, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('السيارة: ${vehicle.number} — ${vehicle.model} — ${vehicle.fuelType}'),
        const SizedBox(height: 10),
        GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 6, mainAxisSpacing: 6), itemCount: 4, itemBuilder: (_, i) => Image.file(images[i], fit: BoxFit.cover)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إرسال'))],
    )) ?? false;
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل تموينة جديدة')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const Icon(Icons.local_gas_station, size: 60, color: Color(0xFF0B4A8B)),
                  const SizedBox(height: 8),
                  const Text('بيانات السائق', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 18),
                  TextField(controller: _code, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'كود السيارة', prefixIcon: Icon(Icons.key))),
                  const SizedBox(height: 12),
                  TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم السائق', prefixIcon: Icon(Icons.person))),
                  const SizedBox(height: 12),
                  TextField(controller: _odometer, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عداد السيارة عند التموين', suffixText: 'كم', prefixIcon: Icon(Icons.speed))),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(onPressed: _busy ? null : _start, icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.camera_alt), label: const Text('بدء التصوير'))),
                  const SizedBox(height: 10),
                  const Text('سيتم فتح الكاميرا تلقائيًا لأربع صور بالترتيب المحدد.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptureStep extends StatelessWidget {
  final String title;
  final int step;
  final ImagePicker picker;
  const _CaptureStep({required this.title, required this.step, required this.picker});

  Future<void> _capture(BuildContext context) async {
    final image = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.rear, imageQuality: 88);
    if (context.mounted) Navigator.pop(context, image);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('$step من 4')),
    body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.camera_alt_outlined, size: 88, color: Color(0xFF0B4A8B)),
      const SizedBox(height: 20),
      Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      const SizedBox(height: 30),
      SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(onPressed: () => _capture(context), icon: const Icon(Icons.camera), label: const Text('فتح الكاميرا والتقاط الصورة'))),
      const SizedBox(height: 12),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء العملية')),
    ]))),
  );
}
