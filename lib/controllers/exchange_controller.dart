
import 'package:flutter/material.dart';
import '../models/exchange_model.dart';
import '../services/exchange_service.dart';

class ExchangeController extends ChangeNotifier {
  final ExchangeService _exchangeService = ExchangeService();

  // ==================== STATE ====================
  List<ExchangeModel> _myExchanges = [];
  List<ExchangeModel> _incomingExchanges = [];

  ExchangeModel? _selectedExchange;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // ==================== GETTERS ====================
  List<ExchangeModel> get myExchanges =>
      List.unmodifiable(_myExchanges);

  List<ExchangeModel> get incomingExchanges =>
      List.unmodifiable(_incomingExchanges);

  ExchangeModel? get selectedExchange => _selectedExchange;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  // ==================== GET CURRENT USER ID ====================
  Future<int> getCurrentUserId() async {
    return await _exchangeService.getCurrentUserId();
  }

  // ==================== GET MY EXCHANGES ====================
  Future<void> loadMyExchanges() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _myExchanges = await _exchangeService.getMyExchanges();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== GET INCOMING EXCHANGES ====================
  Future<void> loadIncomingExchanges() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _incomingExchanges =
          await _exchangeService.getIncomingExchanges();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== GET EXCHANGE BY ID ====================
  Future<ExchangeModel?> getExchangeById(int tukarId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final exchange =
          await _exchangeService.getExchangeById(tukarId);

      _selectedExchange = exchange;
      return exchange;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== CREATE EXCHANGE ====================
  Future<bool> createExchange(ExchangeModel exchange) async {
    if (_isSubmitting) return false;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newExchange =
          await _exchangeService.createExchange(exchange);

      _myExchanges.insert(0, newExchange);
      _selectedExchange = newExchange;

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // ==================== UPDATE EXCHANGE NOTES ====================
  Future<bool> updateExchangeNotes({
    required int tukarId,
    String? bukuDicari,
    String? catatanTukar,
  }) async {
    if (_isSubmitting) return false;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedExchange =
          await _exchangeService.updateExchangeNotes(
        tukarId: tukarId,
        bukuDicari: bukuDicari,
        catatanTukar: catatanTukar,
      );

      final index = _myExchanges.indexWhere(
        (exchange) => exchange.tukarId == tukarId,
      );

      if (index != -1) {
        _myExchanges[index] = updatedExchange;
      }

      if (_selectedExchange?.tukarId == tukarId) {
        _selectedExchange = updatedExchange;
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // ==================== UPDATE EXCHANGE STATUS ====================
  Future<bool> updateExchangeStatus({
    required int tukarId,
    required String status,
  }) async {
    if (_isSubmitting) return false;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedExchange =
          await _exchangeService.updateExchangeStatus(
        tukarId: tukarId,
        status: status,
      );

      final incomingIndex = _incomingExchanges.indexWhere(
        (exchange) => exchange.tukarId == tukarId,
      );

      if (incomingIndex != -1) {
        _incomingExchanges[incomingIndex] = updatedExchange;
      }

      final myIndex = _myExchanges.indexWhere(
        (exchange) => exchange.tukarId == tukarId,
      );

      if (myIndex != -1) {
        _myExchanges[myIndex] = updatedExchange;
      }

      if (_selectedExchange?.tukarId == tukarId) {
        _selectedExchange = updatedExchange;
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // ==================== CANCEL EXCHANGE ====================
  Future<bool> cancelExchange(int tukarId) async {
    if (_isSubmitting) return false;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success =
          await _exchangeService.cancelExchange(tukarId);

      if (success) {
        _myExchanges.removeWhere(
          (exchange) => exchange.tukarId == tukarId,
        );

        if (_selectedExchange?.tukarId == tukarId) {
          _selectedExchange = null;
        }
      }

      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // ==================== CLEAR SELECTED EXCHANGE ====================
  void clearSelectedExchange() {
    _selectedExchange = null;
    notifyListeners();
  }

  // ==================== CLEAR ERROR ====================
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ==================== RESET DATA ====================
  void reset() {
    _myExchanges = [];
    _incomingExchanges = [];
    _selectedExchange = null;
    _isLoading = false;
    _isSubmitting = false;
    _errorMessage = null;
    notifyListeners();
  }
}
