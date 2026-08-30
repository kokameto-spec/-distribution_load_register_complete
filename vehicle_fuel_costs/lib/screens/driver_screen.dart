import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user.dart';
import '../models/vehicle.dart';
import '../services/firebase_service.dart';
import '../services/offline_queue_service.dart';

class DriverScreen extends StatefulWidget {
  final AppUser user;
  const DriverScreen({super.key, required this.user});
  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final _name = TextEditingController();
  final _odometer = TextEditingController();
  final _picker = ImagePicker();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _busy = false;
  int _pending = 0;
  Vehicle? _vehicle;

  static const _photoTitles = [
    'صورة مؤشر الوقود قبل التموين',
    'صورة مضخة الوقود',
    'صورة مؤشر الوقود بعد التموين',
    'صورة إيصال المحطة',
  ];

  @override
  void initState() {
    super.initState();
    _name.text = widget.user.displayName;
    _loadVehicleAndSync();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) _syncPending();
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _name.dispose();
    _odometer.dispose();
    super.dispose();
  }

  Future<void> _loadVehicleAndSync() async {
    final code = widget.user.vehicleCode;
    if (code.isNotEmpty) {
      try {
        final onlineVehicle = await FirebaseService.instance.vehicleByCode(code);
        if (onlineVehicle != null) {
          _vehicle = onlineVehicle;
          await OfflineQueueService.instance.cacheVehicle(onlineVehicle);
        }
      } catch (_) {
        _vehicle = await OfflineQueueService.instance.cachedVehicle(code);
      }
      _vehicle ??= await OfflineQueueService.instance.cachedVehicle(code);
    }
    await _refreshPending();
    await _syncPending();
    if (mounted) setState(() {});
  }

  Future<void> _refreshPending() async {
    final count = await OfflineQueueService.instance.pendingCount();
    if (mounted) setState(() => _pending = count);
  }

  Future<void> _syncPending() async {
    final sent = await OfflineQueueService.instance.syncPending();
    await _refreshPending();
    if (sent > 0 && mounted) _msg('تم إرسال $sent عملية محفوظة أوفلاين.');
  }

  Future<void> _start() async {
    final name = _name.text.trim();
    final odo = int.tryParse(_odometer.text.replaceAll(',', '').trim());
    if (name.isEmpty || odo == null) {
      _msg('أدخل اسم السائق وقراءة العداد.');
      return;
    }
    if (_vehicle == null) {
      _msg('بيانات السيارة المرتبطة بالحساب غير متاحة. افتح التطبيق مرة واحدة أثناء وجود الإنترنت.');
      return;
    }

    setState(() => _busy = true);
    try {
      final images = <File>[];
      for (var i = 0; i < 4; i++) {
        if (!mounted) return;
        final file = await Navigator.push<XFile?>(
          context,
          MaterialPageRoute(builder: (_) => _CaptureStep(title: _photoTitles[i], step: i + 1, picker: _picker)),
        );
        if (file == null) {
          _msg('تم إلغاء العملية قبل اكتمال الصور الأربع.');
          return;
        }
        images.add(File(file.path));
      }
      if (!mounted) return;
      if (!await _confirm(_vehicle!, images)) return;

      var queued = false;
      if (await OfflineQueueService.instance.isOnline()) {
        try {
          await FirebaseService.instance.submitFueling(
            vehicle: _vehicle!,
            driverName: name,
            odometer: odo,
            images: images,
          );
        } on StateError {
          rethrow;
        } catch (_) {
          queued = true;
        }
      } else {
        queued = true;
      }

      if (queued) {
        await OfflineQueueService.instance.queueFueling(
          vehicle: _vehicle!,
          driverName: name,
          odometer: odo,
          images: images,
        );
      }

      _odometer.clear();
      await _refreshPending();
      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            icon: Icon(queued ? Icons.cloud_upload_outlined : Icons.check_circle, color: queued ? Colors.orange : Colors.green, size: 52),
            title: Text(queued ? 'تم الحفظ أوفلاين' : 'تم الإرسال بنجاح'),
            content: Text(queued
                ? 'تم حفظ التموينة والصور على الجهاز، وسيتم إرسالها تلقائيًا عند عودة الإنترنت.'
                : 'تم حفظ الصور وبيانات التموينة وإضافة قراءة العداد لكشف الاستهلاك.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('تم'))],
          ),
        );
      }
    } catch (e) {
      _msg('تعذر الحفظ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(Vehicle vehicle, List<File> images) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('مراجعة قبل الحفظ'),
            content: SizedBox(
              width: 430,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('السيارة: ${vehicle.number} — ${vehicle.model} — ${vehicle.fuelType}'),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 6, mainAxisSpacing: 6),
                  itemCount: 4,
                  itemBuilder: (_, i) => Image.file(images[i], fit: BoxFit.cover),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ وإرسال')),
            ],
          ),
        ) ??
        false;
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل تموينة جديدة'),
        actions: [
          if (_pending > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: Text('معلق: $_pending')),
            ),
          IconButton(onPressed: _syncPending, tooltip: 'مزامنة الآن', icon: const Icon(Icons.sync)),
          IconButton(onPressed: () => Navigator.pop(context), tooltip: 'تسجيل الخروج', icon: const Icon(Icons.logout)),
        ],
      ),
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
                  Text(
                    _vehicle == null ? 'بيانات السائق' : 'السيارة ${_vehicle!.number} — ${_vehicle!.model}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  if (_vehicle != null) Text(_vehicle!.fuelType, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 18),
                  TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم السائق', prefixIcon: Icon(Icons.person))),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _odometer,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'عداد السيارة عند التموين', suffixText: 'كم', prefixIcon: Icon(Icons.speed)),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _start,
                      icon: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.camera_alt),
                      label: const Text('بدء التصوير'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('أربع صور بالترتيب المحدد. عند عدم وجود إنترنت يتم الحفظ على الجهاز والإرسال تلقائيًا لاحقًا.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
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
    final image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 55,
    );
    if (context.mounted) Navigator.pop(context, image);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('$step من 4')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.camera_alt_outlined, size: 88, color: Color(0xFF0B4A8B)),
              const SizedBox(height: 20),
              Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(onPressed: () => _capture(context), icon: const Icon(Icons.camera), label: const Text('فتح الكاميرا والتقاط الصورة')),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء العملية')),
            ]),
          ),
        ),
      );
}
