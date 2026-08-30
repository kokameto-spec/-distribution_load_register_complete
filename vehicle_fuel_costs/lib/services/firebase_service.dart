import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/consumption_entry.dart';
import '../models/fueling_record.dart';
import '../models/vehicle.dart';

class FirebaseService {
  FirebaseService._();
  static final instance = FirebaseService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  Future<void> ensureAnonymousAuth() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  Future<Vehicle?> vehicleByCode(String code) async {
    final normalized = code.trim();
    if (normalized.isEmpty) return null;
    final doc = await _db.collection('vehicles').doc(normalized).get();
    if (!doc.exists || doc.data() == null) return null;
    final vehicle = Vehicle.fromMap(doc.data()!, fallbackCode: normalized);
    return vehicle.active ? vehicle : null;
  }

  Future<void> saveVehicle(Vehicle vehicle) async {
    await ensureAnonymousAuth();
    await _db.collection('vehicles').doc(vehicle.code).set(vehicle.toMap());
  }

  Future<void> deleteVehicle(String code) async {
    await ensureAnonymousAuth();
    await _db.collection('vehicles').doc(code).delete();
  }

  Stream<List<Vehicle>> vehiclesStream() {
    return _db.collection('vehicles').snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((d) => Vehicle.fromMap(d.data(), fallbackCode: d.id))
          .toList();
      items.sort((a, b) => a.number.compareTo(b.number));
      return items;
    });
  }

  Future<void> submitFueling({
    required Vehicle vehicle,
    required String driverName,
    required int odometer,
    required List<File> images,
  }) {
    return submitFuelingWithId(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      vehicle: vehicle,
      driverName: driverName,
      odometer: odometer,
      images: images,
    );
  }

  Future<void> submitFuelingWithId({
    required String id,
    required DateTime createdAt,
    required Vehicle vehicle,
    required String driverName,
    required int odometer,
    required List<File> images,
  }) async {
    if (images.length != 4) {
      throw StateError('يجب إرسال أربع صور بالترتيب.');
    }
    await ensureAnonymousAuth();

    final existing = await _db.collection('fuelings').doc(id).get();
    if (existing.exists) return;

    final imageBytes = await _readAndValidateImages(images);
    final monthKey = DateFormat('yyyy-MM').format(createdAt);
    final previous = await _lastOdometer(vehicle.code);
    final distance = previous == null ? null : odometer - previous;
    if (distance != null && distance < 0) {
      throw StateError('قراءة العداد الحالية أقل من القراءة السابقة.');
    }

    final batch = _db.batch();
    final fuelingRef = _db.collection('fuelings').doc(id);
    batch.set(fuelingRef, {
      'vehicleCode': vehicle.code,
      'vehicleNumber': vehicle.number,
      'fuelType': vehicle.fuelType,
      'vehicleModel': vehicle.model,
      'driverName': driverName.trim(),
      'odometer': odometer,
      'createdAt': Timestamp.fromDate(createdAt),
      'monthKey': monthKey,
      'imageCount': 4,
      'imageStorage': 'firestore',
    });

    for (var i = 0; i < imageBytes.length; i++) {
      final imageRef = _db.collection('fueling_images').doc('${id}_${i + 1}');
      batch.set(imageRef, {
        'fuelingId': id,
        'vehicleCode': vehicle.code,
        'order': i + 1,
        'contentType': 'image/jpeg',
        'data': Blob(imageBytes[i]),
        'createdAt': Timestamp.fromDate(createdAt),
        'monthKey': monthKey,
      });
    }

    final consumptionRef = _db.collection('consumption').doc(id);
    batch.set(consumptionRef, {
      'vehicleCode': vehicle.code,
      'vehicleNumber': vehicle.number,
      'driverName': driverName.trim(),
      'previousOdometer': previous,
      'currentOdometer': odometer,
      'distance': distance,
      'createdAt': Timestamp.fromDate(createdAt),
      'monthKey': monthKey,
      'fuelingId': id,
    });

    await batch.commit();
  }

  Future<List<Uint8List>> _readAndValidateImages(List<File> images) async {
    const maxImageBytes = 900 * 1024;
    final result = <Uint8List>[];
    for (var i = 0; i < images.length; i++) {
      final bytes = await images[i].readAsBytes();
      if (bytes.length > maxImageBytes) {
        throw StateError('الصورة رقم ${i + 1} حجمها كبير. أعد التقاطها ثم حاول مرة أخرى.');
      }
      result.add(bytes);
    }
    return result;
  }

  Future<List<Uint8List>> fuelingImages(String fuelingId) async {
    await ensureAnonymousAuth();
    final images = <Uint8List>[];
    for (var i = 1; i <= 4; i++) {
      final doc = await _db.collection('fueling_images').doc('${fuelingId}_$i').get();
      final data = doc.data()?['data'];
      if (data is Blob) images.add(data.bytes);
    }
    return images;
  }

  Future<void> updateFueling({
    required FuelingRecord record,
    required String driverName,
    required int odometer,
    Map<int, File> replacementImages = const {},
  }) async {
    await ensureAnonymousAuth();
    await _validateOdometerChange(record.vehicleCode, record.id, odometer);

    final batch = _db.batch();
    batch.update(_db.collection('fuelings').doc(record.id), {
      'driverName': driverName.trim(),
      'odometer': odometer,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_db.collection('consumption').doc(record.id), {
      'driverName': driverName.trim(),
      'currentOdometer': odometer,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (final entry in replacementImages.entries) {
      if (entry.key < 1 || entry.key > 4) continue;
      final bytes = await _readAndValidateImages([entry.value]);
      batch.set(
        _db.collection('fueling_images').doc('${record.id}_${entry.key}'),
        {
          'fuelingId': record.id,
          'vehicleCode': record.vehicleCode,
          'order': entry.key,
          'contentType': 'image/jpeg',
          'data': Blob(bytes.first),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    await _recomputeConsumption(record.vehicleCode);
  }

  Future<void> updateConsumptionReading(ConsumptionEntry entry, int newOdometer) async {
    await ensureAnonymousAuth();
    await _validateOdometerChange(entry.vehicleCode, entry.id, newOdometer);
    final batch = _db.batch();
    batch.update(_db.collection('consumption').doc(entry.id), {
      'currentOdometer': newOdometer,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_db.collection('fuelings').doc(entry.id), {
      'odometer': newOdometer,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await _recomputeConsumption(entry.vehicleCode);
  }

  Future<void> deleteFueling(String id, String vehicleCode) async {
    await ensureAnonymousAuth();
    final batch = _db.batch();
    batch.delete(_db.collection('fuelings').doc(id));
    batch.delete(_db.collection('consumption').doc(id));
    for (var i = 1; i <= 4; i++) {
      batch.delete(_db.collection('fueling_images').doc('${id}_$i'));
    }
    await batch.commit();
    await _recomputeConsumption(vehicleCode);
  }

  Future<void> _validateOdometerChange(String vehicleCode, String id, int newValue) async {
    final snap = await _db.collection('consumption').where('vehicleCode', isEqualTo: vehicleCode).get();
    final rows = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    rows.sort((a, b) {
      final at = a['createdAt'] as Timestamp?;
      final bt = b['createdAt'] as Timestamp?;
      return (at?.millisecondsSinceEpoch ?? 0).compareTo(bt?.millisecondsSinceEpoch ?? 0);
    });
    int? previous;
    for (final row in rows) {
      final current = row['id'] == id ? newValue : (row['currentOdometer'] as num?)?.toInt() ?? 0;
      if (previous != null && current < previous) {
        throw StateError('القراءة المعدلة ستجعل ترتيب العدادات غير صحيح لهذه السيارة.');
      }
      previous = current;
    }
  }

  Future<void> _recomputeConsumption(String vehicleCode) async {
    final snap = await _db.collection('consumption').where('vehicleCode', isEqualTo: vehicleCode).get();
    final rows = snap.docs.toList();
    rows.sort((a, b) {
      final at = a.data()['createdAt'] as Timestamp?;
      final bt = b.data()['createdAt'] as Timestamp?;
      return (at?.millisecondsSinceEpoch ?? 0).compareTo(bt?.millisecondsSinceEpoch ?? 0);
    });

    int? previous;
    WriteBatch batch = _db.batch();
    var writes = 0;
    for (final doc in rows) {
      final current = (doc.data()['currentOdometer'] as num?)?.toInt() ?? 0;
      final distance = previous == null ? null : current - previous;
      batch.update(doc.reference, {
        'previousOdometer': previous,
        'distance': distance,
      });
      previous = current;
      writes++;
      if (writes >= 400) {
        await batch.commit();
        batch = _db.batch();
        writes = 0;
      }
    }
    if (writes > 0) await batch.commit();
  }

  Future<int?> _lastOdometer(String vehicleCode) async {
    final snapshot = await _db.collection('consumption').where('vehicleCode', isEqualTo: vehicleCode).get();
    if (snapshot.docs.isEmpty) return null;
    final rows = snapshot.docs.map((d) => d.data()).toList();
    rows.sort((a, b) {
      final at = a['createdAt'] as Timestamp?;
      final bt = b['createdAt'] as Timestamp?;
      return (bt?.millisecondsSinceEpoch ?? 0).compareTo(at?.millisecondsSinceEpoch ?? 0);
    });
    return (rows.first['currentOdometer'] as num?)?.toInt();
  }

  Stream<List<FuelingRecord>> monthlyFuelings(String monthKey) {
    return _db.collection('fuelings').where('monthKey', isEqualTo: monthKey).snapshots().map((snapshot) {
      final items = snapshot.docs.map((d) => FuelingRecord.fromMap(d.id, d.data())).toList();
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return items;
    });
  }

  Stream<List<ConsumptionEntry>> monthlyConsumption(String monthKey) {
    return _db.collection('consumption').where('monthKey', isEqualTo: monthKey).snapshots().map((snapshot) {
      final items = snapshot.docs.map((d) => ConsumptionEntry.fromMap(d.id, d.data())).toList();
      items.sort((a, b) => a.date.compareTo(b.date));
      return items;
    });
  }
}
