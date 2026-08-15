import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/distributor_model.dart';
import '../repositories/distributor_repository.dart';

class DistributorController extends ChangeNotifier {
  DistributorController({
    DistributorRepository? repository,
  }) : _repository =
            repository ?? DistributorRepository();

  final DistributorRepository _repository;

  Timer? _refreshTimer;

  List<Distributor> _distributors = <Distributor>[];

  bool _isLoading = false;
  bool _isListening = false;

  String? _errorMessage;

  List<Distributor> get distributors =>
      List<Distributor>.unmodifiable(
        _distributors,
      );

  List<Distributor> get activeDistributors =>
      _distributors
          .where(
            (item) => item.active,
          )
          .toList(
            growable: false,
          );

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

    _isListening = true;
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    await _loadDistributors();

    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        _refreshSilently();
      },
    );
  }

  // =========================================================
  // FIRST LOAD
  // =========================================================

  Future<void> _loadDistributors() async {
    try {
      final items = await _repository
          .getAll()
          .timeout(
            const Duration(seconds: 20),
          );

      _distributors = items;

      _errorMessage = null;
    } on TimeoutException {
      _errorMessage =
          'انتهت مهلة تحميل بيانات الموزعات. '
          'تحقق من اتصال الإنترنت ثم حاول مرة أخرى.';
    } catch (error) {
      _errorMessage =
          'تعذر تحميل بيانات الموزعات.\n$error';
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // =========================================================
  // SILENT REFRESH
  // =========================================================

  Future<void> _refreshSilently() async {
    if (!_isListening) {
      return;
    }

    try {
      final items = await _repository
          .getAll()
          .timeout(
            const Duration(seconds: 20),
          );

      _distributors = items;

      _errorMessage = null;

      notifyListeners();
    } catch (_) {
      // لا نمسح البيانات القديمة إذا فشل التحديث الدوري.
    }
  }

  // =========================================================
  // MANUAL REFRESH
  // =========================================================

  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    await _loadDistributors();
  }

  // =========================================================
  // STOP
  // =========================================================

  Future<void> stopListening() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    _isListening = false;

    notifyListeners();
  }

  // =========================================================
  // CREATE
  // =========================================================

  Future<bool> create({
    required String code,
    required String name,
    required String type,
  }) async {
    _setLoading(true);

    _errorMessage = null;

    try {
      await _repository.create(
        code: code,
        name: name,
        type: type,
      );

      await _loadDistributors();

      return true;
    } on ArgumentError catch (error) {
      _errorMessage =
          error.message?.toString();

      return false;
    } on StateError catch (error) {
      _errorMessage =
          error.message.toString();

      return false;
    } catch (error) {
      _errorMessage =
          'تعذر إضافة الموزع.\n$error';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // UPDATE
  // =========================================================

  Future<bool> update({
    required String id,
    required String code,
    required String name,
    required String type,
    required bool active,
  }) async {
    _setLoading(true);

    _errorMessage = null;

    try {
      await _repository.update(
        id: id,
        code: code,
        name: name,
        type: type,
        active: active,
      );

      await _loadDistributors();

      return true;
    } on ArgumentError catch (error) {
      _errorMessage =
          error.message?.toString();

      return false;
    } on StateError catch (error) {
      _errorMessage =
          error.message.toString();

      return false;
    } catch (error) {
      _errorMessage =
          'تعذر تعديل الموزع.\n$error';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // DELETE
  // =========================================================

  Future<bool> delete(
    String id,
  ) async {
    _setLoading(true);

    _errorMessage = null;

    try {
      await _repository.delete(
        id,
      );

      await _loadDistributors();

      return true;
    } on ArgumentError catch (error) {
      _errorMessage =
          error.message?.toString();

      return false;
    } catch (error) {
      _errorMessage =
          'تعذر حذف الموزع.\n$error';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // FIND
  // =========================================================

  Distributor? findById(
    String id,
  ) {
    final normalizedId =
        id.trim();

    for (final distributor
        in _distributors) {
      if (distributor.id ==
          normalizedId) {
        return distributor;
      }
    }

    return null;
  }

  // =========================================================
  // CLEAR ERROR
  // =========================================================

  void clearError() {
    _errorMessage = null;

    notifyListeners();
  }

  // =========================================================
  // LOADING
  // =========================================================

  void _setLoading(
    bool value,
  ) {
    _isLoading = value;

    notifyListeners();
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _refreshTimer?.cancel();

    super.dispose();
  }
}
