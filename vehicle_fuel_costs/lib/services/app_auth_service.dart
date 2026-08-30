import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import 'firebase_service.dart';

class AppAuthService {
  AppAuthService._();
  static final instance = AppAuthService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();

  Future<AppUser?> login(String username, String password) async {
    final name = username.trim().toLowerCase();
    final passHash = _hash(password);
    if (name.isEmpty || password.isEmpty) return null;

    try {
      await FirebaseService.instance.ensureAnonymousAuth();
      final ref = _db.collection('app_users').doc(name);
      var doc = await ref.get();

      // Bootstrap manager so the first installation is never locked out.
      if (!doc.exists && name == 'admin' && password == '2600') {
        await ref.set({
          'username': 'admin',
          'displayName': 'المدير',
          'role': 'manager',
          'vehicleCode': '',
          'active': true,
          'passwordHash': passHash,
          'createdAt': FieldValue.serverTimestamp(),
        });
        doc = await ref.get();
      }

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['active'] == false) return null;
        if ((data['passwordHash'] ?? '').toString() != passHash) return null;
        final user = AppUser.fromMap(data, fallbackUsername: name);
        await _cache(user, passHash);
        return user;
      }
    } catch (_) {
      // Fall through to the cached credential for true offline login.
    }

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('cached_username') == name &&
        prefs.getString('cached_password_hash') == passHash) {
      final raw = prefs.getString('cached_user_json');
      if (raw != null && raw.isNotEmpty) {
        final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        return AppUser.fromMap(map, fallbackUsername: name);
      }
    }
    return null;
  }

  Future<void> _cache(AppUser user, String passHash) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_username', user.username);
    await prefs.setString('cached_password_hash', passHash);
    await prefs.setString('cached_user_json', jsonEncode(user.toMap()));
  }

  Future<void> saveUser({
    required AppUser user,
    String? newPassword,
  }) async {
    await FirebaseService.instance.ensureAnonymousAuth();
    final ref = _db.collection('app_users').doc(user.username.trim().toLowerCase());
    String passwordHash = '';
    final old = await ref.get();
    if (old.exists) passwordHash = (old.data()?['passwordHash'] ?? '').toString();
    if (newPassword != null && newPassword.isNotEmpty) {
      passwordHash = _hash(newPassword);
    }
    if (passwordHash.isEmpty) {
      throw StateError('يجب إدخال كلمة مرور للمستخدم الجديد.');
    }
    await ref.set({
      ...user.toMap(),
      'username': user.username.trim().toLowerCase(),
      'passwordHash': passwordHash,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<AppUser>> usersStream() {
    return _db.collection('app_users').snapshots().map((snap) {
      final users = snap.docs
          .map((d) => AppUser.fromMap(d.data(), fallbackUsername: d.id))
          .toList();
      users.sort((a, b) => a.displayName.compareTo(b.displayName));
      return users;
    });
  }
}
