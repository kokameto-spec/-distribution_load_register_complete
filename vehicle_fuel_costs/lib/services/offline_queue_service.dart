import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/vehicle.dart';
import 'firebase_service.dart';

class OfflineQueueService {
  OfflineQueueService._();
  static final instance = OfflineQueueService._();
  final _uuid = const Uuid();

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<void> cacheVehicle(Vehicle vehicle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vehicle_${vehicle.code}', jsonEncode(vehicle.toMap()));
  }

  Future<Vehicle?> cachedVehicle(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('vehicle_$code');
    if (raw == null || raw.isEmpty) return null;
    return Vehicle.fromMap(Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }

  Future<String> queueFueling({
    required Vehicle vehicle,
    required String driverName,
    required int odometer,
    required List<File> images,
    DateTime? createdAt,
  }) async {
    final id = _uuid.v4();
    final when = createdAt ?? DateTime.now();
    final base = await getApplicationSupportDirectory();
    final folder = Directory('${base.path}/pending_fuelings/$id');
    await folder.create(recursive: true);

    final paths = <String>[];
    for (var i = 0; i < images.length; i++) {
      final target = File('${folder.path}/${i + 1}.jpg');
      await images[i].copy(target.path);
      paths.add(target.path);
    }

    final list = await _readQueue();
    list.add({
      'id': id,
      'createdAt': when.toIso8601String(),
      'vehicle': vehicle.toMap(),
      'driverName': driverName,
      'odometer': odometer,
      'images': paths,
    });
    await _writeQueue(list);
    return id;
  }

  Future<int> pendingCount() async => (await _readQueue()).length;

  Future<int> syncPending() async {
    if (!await isOnline()) return 0;
    final list = await _readQueue();
    list.sort((a, b) => (a['createdAt'] ?? '').toString().compareTo((b['createdAt'] ?? '').toString()));
    var sent = 0;
    final remaining = <Map<String, dynamic>>[];

    for (final item in list) {
      try {
        final vehicle = Vehicle.fromMap(Map<String, dynamic>.from(item['vehicle'] as Map));
        final paths = List<String>.from(item['images'] as List);
        final files = paths.map(File.new).toList();
        await FirebaseService.instance.submitFuelingWithId(
          id: item['id'].toString(),
          createdAt: DateTime.parse(item['createdAt'].toString()),
          vehicle: vehicle,
          driverName: item['driverName'].toString(),
          odometer: (item['odometer'] as num).toInt(),
          images: files,
        );
        for (final file in files) {
          if (await file.exists()) await file.delete();
        }
        final folder = Directory(File(paths.first).parent.path);
        if (await folder.exists()) await folder.delete(recursive: true);
        sent++;
      } catch (_) {
        remaining.add(item);
      }
    }

    await _writeQueue(remaining);
    return sent;
  }

  Future<File> _queueFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/pending_fuelings.json');
  }

  Future<List<Map<String, dynamic>>> _readQueue() async {
    final file = await _queueFile();
    if (!await file.exists()) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(await file.readAsString()) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _writeQueue(List<Map<String, dynamic>> items) async {
    final file = await _queueFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(items), flush: true);
  }
}
