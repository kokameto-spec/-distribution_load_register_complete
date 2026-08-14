import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/station_model.dart';
import '../repositories/station_repository.dart';

class StationController extends ChangeNotifier {
  StationController({StationRepository? repository})
      : _repository = repository ?? StationRepository();

  final StationRepository _repository;
  StreamSubscription<List<Station>>? _subscription;

  List<Station> _stations = <Station>[];
  bool _isLoading = false;
  String? _errorMessage;

  List<Station> get stations => List<Station>.unmodifiable(_stations);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isListening => _subscription != null;

  void startListening() {
    _subscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _repository.watchAll().listen(
      (items) {
        _stations = items;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = error is FirebaseException
            ? 'تعذر تحميل المحطات من Firebase.\n${error.code}: ${error.message ?? ''}'
            : 'تعذر تحميل محطات المحولات.\n$error';
        debugPrint('Station stream error: $error');
        notifyListeners();
      },
    );
  }

  Future<bool> createStation({
    required String name,
    required List<StationTransformer> transformers,
  }) {
    return _run(() async {
      final id = await _repository.create(
        name: name,
        transformers: transformers,
      );
      debugPrint('Station created successfully: $id');
    });
  }

  Future<bool> updateStation({
    required Station station,
    required String name,
    required bool active,
    required List<StationTransformer> transformers,
  }) {
    return _run(() async {
      await _repository.update(
        id: station.id,
        name: name,
        active: active,
        transformers: transformers,
      );
    });
  }

  Future<bool> deleteStation(String id) {
    return _run(() => _repository.delete(id));
  }

  Future<bool> _run(Future<void> Function() operation) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await operation();
      return true;
    } on ArgumentError catch (error) {
      _errorMessage = error.message?.toString() ?? 'بيانات غير صحيحة.';
      return false;
    } on FirebaseException catch (error) {
      debugPrint(
        'Station FirebaseException: code=${error.code}, message=${error.message}',
      );
      if (error.code == 'permission-denied') {
        _errorMessage = 'لا توجد صلاحية لحفظ بيانات المحطة.';
      } else if (error.code == 'unavailable') {
        _errorMessage = 'تعذر الاتصال بـ Firebase. تحقق من الإنترنت.';
      } else {
        _errorMessage = 'خطأ Firebase: ${error.code}\n${error.message ?? ''}';
      }
      return false;
    } catch (error, stackTrace) {
      debugPrint('Station unexpected error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _errorMessage = 'تعذر حفظ بيانات المحطة.\n$error';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
