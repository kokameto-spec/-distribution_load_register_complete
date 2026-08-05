import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class UserRepository {
  UserRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<AppUser?> login({
    required String code,
    required String password,
  }) async {
    final normalizedCode = code.trim();

    if (normalizedCode.isEmpty || password.isEmpty) {
      return null;
    }

    final email = '$normalizedCode@distribution.local';

    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      await _auth.signOut();
      return null;
    }

    final document =
    await _firestore.collection('users').doc(firebaseUser.uid).get();

    final data = document.data();

    if (!document.exists || data == null) {
      await _auth.signOut();
      return null;
    }

    final appUser = AppUser.fromMap(
      uid: firebaseUser.uid,
      data: data,
    );

    if (!appUser.active || appUser.code != normalizedCode) {
      await _auth.signOut();
      return null;
    }

    return appUser;
  }

  Future<AppUser?> restoreSession() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      return null;
    }

    final document =
    await _firestore.collection('users').doc(firebaseUser.uid).get();

    final data = document.data();

    if (!document.exists || data == null) {
      await _auth.signOut();
      return null;
    }

    final appUser = AppUser.fromMap(
      uid: firebaseUser.uid,
      data: data,
    );

    if (!appUser.active) {
      await _auth.signOut();
      return null;
    }

    return appUser;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}