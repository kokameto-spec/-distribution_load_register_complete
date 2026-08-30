import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/consumption_entry.dart';
import '../models/fueling_record.dart';
import '../models/vehicle.dart';

class FirebaseService {
  FirebaseService._();
  static final instance = FirebaseService._();

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
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
    await _db.collection('vehicles').doc(vehicle.code).set(vehicle.toMap());
  }

  Stream<List<Vehicle>> vehiclesStream() {
    return _db.collection('vehicles').snapshots().map((snapshot) {
      final items = snapshot.docs.map((d) => Vehicle.fromMap(d.data(), fallbackCode: d.id)).toList();
      items.sort((a, b) => a.number.compareTo(b.number));
      return items;
    });
  }

  Future<void> submitFueling({
    required Vehicle vehicle,
    required String driverName,
    required int odometer,
    required List<File> images,
  }) async {
    if (images.length != 4) throw StateError('يجب إرسال أربع صور بالترتيب.');
    await ensureAnonymousAuth();

    final now = DateTime.now();
    final monthKey = DateFormat('yyyy-MM').format(now);
    final id = _uuid.v4();

    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      final ref = _storage.ref().child('fuelings/${vehicle.code}/$monthKey/$id/${i + 1}.jpg');
      await ref.putFile(images[i], SettableMetadata(contentType: 'image/jpeg'));
      urls.add(await ref.getDownloadURL());
    }

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
      'createdAt': Timestamp.fromDate(now),
      'monthKey': monthKey,
      'imageUrls': urls,
    });

    final consumptionRef = _db.collection('consumption').doc(id);
    batch.set(consumptionRef, {
      'vehicleCode': vehicle.code,
      'vehicleNumber': vehicle.number,
      'driverName': driverName.trim(),
      'previousOdometer': previous,
      'currentOdometer': odometer,
      'distance': distance,
      'createdAt': Timestamp.fromDate(now),
      'monthKey': monthKey,
      'fuelingId': id,
    });
    await batch.commit();
  }

  Future<int?> _lastOdometer(String vehicleCode) async {
    final snapshot = await _db
        .collection('consumption')
        .where('vehicleCode', isEqualTo: vehicleCode)
        .get();
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
