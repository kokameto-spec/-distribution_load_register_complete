import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/services/firebase_rest_service.dart';
import '../models/app_user.dart';

class UserRepository {
  UserRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) {
    if (!_useRestOnWindows) {
      _auth = auth ?? FirebaseAuth.instance;
      _firestore = firestore ?? FirebaseFirestore.instance;
    }
  }

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  bool get _useRestOnWindows {
    return !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows;
  }

  Future<AppUser?> login({
    required String code,
    required String password,
  }) async {
    final normalizedCode = code.trim();

    if (normalizedCode.isEmpty || password.isEmpty) {
      return null;
    }

    if (_useRestOnWindows) {
      return _loginWindowsRest(
        code: normalizedCode,
        password: password,
      );
    }

    return _loginFirebase(
      code: normalizedCode,
      password: password,
    );
  }

  Future<AppUser?> _loginWindowsRest({
    required String code,
    required String password,
  }) async {
    final email = '$code@distribution.local';

    final session = await FirebaseRestService.signIn(
      email: email,
      password: password,
    );

    if (session == null) {
      return null;
    }

    final document =
        await FirebaseRestService.getDocument(
      collection: 'users',
      documentId: session.localId,
    );

    if (document == null) {
      FirebaseRestService.signOut();
      return null;
    }

    final data =
        FirebaseRestService.documentData(
      document,
    );

    final appUser = AppUser.fromMap(
      uid: session.localId,
      data: data,
    );

    if (!appUser.active ||
        appUser.code.trim() != code.trim()) {
      FirebaseRestService.signOut();
      return null;
    }

    return appUser;
  }

  Future<AppUser?> _loginFirebase({
    required String code,
    required String password,
  }) async {
    final auth = _auth;
    final firestore = _firestore;

    if (auth == null || firestore == null) {
      return null;
    }

    final email = '$code@distribution.local';

    final credential =
        await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      await auth.signOut();
      return null;
    }

    final document = await firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    final data = document.data();

    if (!document.exists || data == null) {
      await auth.signOut();
      return null;
    }

    final appUser = AppUser.fromMap(
      uid: firebaseUser.uid,
      data: data,
    );

    if (!appUser.active ||
        appUser.code.trim() != code.trim()) {
      await auth.signOut();
      return null;
    }

    return appUser;
  }

  Future<AppUser?> restoreSession() async {
    if (_useRestOnWindows) {
      return null;
    }

    final auth = _auth;
    final firestore = _firestore;

    if (auth == null || firestore == null) {
      return null;
    }

    final firebaseUser = auth.currentUser;

    if (firebaseUser == null) {
      return null;
    }

    final document = await firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    final data = document.data();

    if (!document.exists || data == null) {
      await auth.signOut();
      return null;
    }

    final appUser = AppUser.fromMap(
      uid: firebaseUser.uid,
      data: data,
    );

    if (!appUser.active) {
      await auth.signOut();
      return null;
    }

    return appUser;
  }

  Future<void> logout() async {
    if (_useRestOnWindows) {
      FirebaseRestService.signOut();
      return;
    }

    final auth = _auth;

    if (auth != null) {
      await auth.signOut();
    }
  }
}      uid: session.localId,
      data: data,
    );

    if (!appUser.active ||
        appUser.code != code) {
      FirebaseRestService.signOut();
      return null;
    }

    return appUser;
  }

  Future<AppUser?> _loginFirebase({
    required String code,
    required String password,
  }) async {
    final email = '$code@distribution.local';

    final credential =
        await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      await _auth.signOut();
      return null;
    }

    final document = await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    final data = document.data();

    if (!document.exists || data == null) {
      await _auth.signOut();
      return null;
    }

    final appUser = AppUser.fromMap(
      uid: firebaseUser.uid,
      data: data,
    );

    if (!appUser.active ||
        appUser.code != code) {
      await _auth.signOut();
      return null;
    }

    return appUser;
  }

  Future<AppUser?> restoreSession() async {
    if (_useRestOnWindows) {
      return null;
    }

    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      return null;
    }

    final document = await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

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
    if (_useRestOnWindows) {
      FirebaseRestService.signOut();
      return;
    }

    await _auth.signOut();
  }
}
