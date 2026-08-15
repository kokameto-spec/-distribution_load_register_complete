import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/station_model.dart';
import '../repositories/station_repository.dart';

class StationController extends ChangeNotifier {
  StationController({
    StationRepository? repository,
  }) : _repository =
            repository ?? StationRepository();

  final StationRepository _repository;

  StreamSubscription<List<Station>>? _subscription;

  List<Station> _stations = <Station>[];

  bool _isLoading = false;
  bool _isListening = false;

  String? _errorMessage;

  List<Station> get stations =>
      List<Station>.unmodifiable(_stations);

  List<Station> get activeStations =>
      _stations
          .where((station) => station.active)
          .toList(growable: false);

  bool get isLoading => _isLoading;

  bool get isListening => _isListening;

  String? get errorMessage => _errorMessage;

  // =========================================================
  // START
  // =========================================================

  Future<void> startListening() async {
    if (_isListening) {
      return;
    }

    await _subscription?.cancel();
    _subscription = null;

    _isListening = true;
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    final completer = Completer<void>();

    _subscription =
        _repository.watchAll().listen(
      (items) {
        _stations = items;
        _isLoading = false;
        _errorMessage = null;

        notifyListeners();

        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = _errorText(error);

        notifyListeners();

        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      onDone: () {
        _isListening = false;

        if (!completer.isCompleted) {
          completer.complete();
        }

        notifyListeners();
      },
    );

    try {
      await completer.future.timeout(
        const Duration(seconds: 25),
      );
    } on TimeoutException {
      _isLoading = false;

      _errorMessage =
          'انتهت مهلة تحميل بيانات المحطات. '
          'تحقق من الإنترنت ثم أعد المحاولة.';

      notifyListeners();
    }
  }

  // =========================================================
  // REFRESH
  // =========================================================

  Future<void> refresh() async {
    await stopListening();
    await startListening();
  }

  // =========================================================
  // CREATE
  // =========================================================

  Future<bool> createStation({
    required String name,
    required List<StationTransformer> transformers,
  }) async {
    final success = await _run(
      () => _repository.create(
        name: name,
        transformers: transformers,
      ),
    );

    if (success) {
      await refresh();
    }

    return success;
  }

  // =========================================================
  // UPDATE
  // =========================================================

  Future<bool> updateStation({
    required Station station,
    required String name,
    required bool active,
    required List<StationTransformer> transformers,
  }) async {
    final success = await _run(
      () => _repository.update(
        id: station.id,
        name: name,
        active: active,
        transformers: transformers,
      ),
    );

    if (success) {
      await refresh();
    }

    return success;
  }

  // =========================================================
  // DELETE
  // =========================================================

  Future<bool> deleteStation(
    String id,
  ) async {
    final success = await _run(
      () => _repository.delete(id),
    );

    if (success) {
      await refresh();
    }

    return success;
  }

  // =========================================================
  // OPERATION
  // =========================================================

  Future<bool> _run(
    Future<dynamic> Function() operation,
  ) async {
    if (_isLoading) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      await operation().timeout(
        const Duration(seconds: 30),
      );

      return true;
    } on TimeoutException {
      _errorMessage =
          'انتهت مهلة تنفيذ العملية. '
          'تحقق من الاتصال بالإنترنت.';

      return false;
    } on ArgumentError catch (error) {
      _errorMessage =
          error.message?.toString() ??
          'بيانات المحطة غير صحيحة.';

      return false;
    } on StateError catch (error) {
      _errorMessage =
          error.message.toString();

      return false;
    } on FirebaseException catch (error) {
      _errorMessage =
          _firebaseError(error);

      return false;
    } catch (error) {
      _errorMessage =
          'تعذر تنفيذ العملية على المحطة.\n$error';

      return false;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // =========================================================
  // FIND
  // =========================================================

  Station? findById(
    String id,
  ) {
    final normalized =
        id.trim();

    for (final station in _stations) {
      if (station.id == normalized) {
        return station;
      }
    }

    return null;
  }

  // =========================================================
  // STOP
  // =========================================================

  Future<void> stopListening() async {
    await _subscription?.cancel();

    _subscription = null;
    _isListening = false;
    _isLoading = false;

    notifyListeners();
  }

  // =========================================================
  // ERROR
  // =========================================================

  void clearError() {
    _errorMessage = null;

    notifyListeners();
  }

  String _errorText(
    Object error,
  ) {
    if (error is FirebaseException) {
      return _firebaseError(error);
    }

    final text =
        error.toString().trim();

    if (text.startsWith('Bad state:')) {
      return text
          .substring('Bad state:'.length)
          .trim();
    }

    if (text.startsWith('Exception:')) {
      return text
          .substring('Exception:'.length)
          .trim();
    }

    if (text.contains('PERMISSION_DENIED')) {
      return 'لا توجد صلاحية لقراءة بيانات المحطات.';
    }

    if (text.contains('UNAUTHENTICATED')) {
      return 'انتهت جلسة تسجيل الدخول. '
          'سجل الدخول مرة أخرى.';
    }

    return text.isEmpty
        ? 'تعذر تحميل بيانات المحطات.'
        : text;
  }

  String _firebaseError(
    FirebaseException error,
  ) {
    switch (error.code) {
      case 'permission-denied':
        return 'لا توجد صلاحية لتنفيذ العملية على المحطات.';

      case 'unavailable':
        return 'تعذر الاتصال بقاعدة البيانات. '
            'تحقق من الإنترنت.';

      case 'unauthenticated':
        return 'انتهت جلسة تسجيل الدخول. '
            'سجل الدخول مرة أخرى.';

      default:
        return error.message ??
            'حدث خطأ في قاعدة البيانات.';
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();

    super.dispose();
  }
}
