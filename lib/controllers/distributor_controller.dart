import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/distributor_model.dart';
import '../repositories/distributor_repository.dart';

class DistributorController extends ChangeNotifier {
  DistributorController({
    DistributorRepository? repository,
  }) : _repository = repository ?? DistributorRepository();

  final DistributorRepository _repository;

  StreamSubscription<List<Distributor>>? _subscription;

  List<Distributor> _distributors = <Distributor>[];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isListening = false;

  List<Distributor> get distributors {
    return List<Distributor>.unmodifiable(_distributors);
  }

  List<Distributor> get activeDistributors {
    return _distributors
        .where((distributor) => distributor.active)
        .toList(growable: false);
  }

  bool get isLoading => _isLoading;
  bool get isListening => _isListening;
  String? get errorMessage => _errorMessage;

  Future<void> startListening() async {
    await _subscription?.cancel();

    _isLoading = true;
    _isListening = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _repository.watchAll().listen(
          (List<Distributor> items) {
        _distributors = items;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        _isLoading = false;
        _errorMessage = 'تعذر تحميل الموزعات.';
        notifyListeners();
      },
      onDone: () {
        _isListening = false;
        notifyListeners();
      },
    );
  }

  Future<void> stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    notifyListeners();
  }

  Future<bool> create({
    required String code,
    required String name,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _repository.create(
        code: code,
        name: name,
      );

      return true;
    } on ArgumentError catch (error) {
      _errorMessage = error.message?.toString();
      return false;
    } on StateError catch (error) {
      _errorMessage = error.message.toString();
      return false;
    } catch (_) {
      _errorMessage = 'تعذر إضافة الموزع.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> update({
    required String id,
    required String code,
    required String name,
    required bool active,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _repository.update(
        id: id,
        code: code,
        name: name,
        active: active,
      );

      return true;
    } on ArgumentError catch (error) {
      _errorMessage = error.message?.toString();
      return false;
    } on StateError catch (error) {
      _errorMessage = error.message.toString();
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تعديل الموزع.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> delete(String id) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _repository.delete(id);
      return true;
    } on ArgumentError catch (error) {
      _errorMessage = error.message?.toString();
      return false;
    } catch (_) {
      _errorMessage = 'تعذر حذف الموزع.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Distributor? findById(String id) {
    final normalizedId = id.trim();

    for (final distributor in _distributors) {
      if (distributor.id == normalizedId) {
        return distributor;
      }
    }

    return null;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}