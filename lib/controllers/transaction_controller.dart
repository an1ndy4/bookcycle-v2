
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../models/transaction_detail_model.dart';
import '../services/transaction_service.dart';

class TransactionController extends ChangeNotifier {
  final TransactionService _transactionService =
      TransactionService();

  // ==================== STATE ====================
  List<TransactionModel> _transactions = [];

  // Menyimpan rincian buku dalam transaksi.
  List<TransactionDetailModel> _transactionDetails = [];

  TransactionModel? _selectedTransaction;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // ==================== GETTERS ====================
  List<TransactionModel> get transactions =>
      List.unmodifiable(_transactions);

  // Getter baru untuk rincian transaksi.
  List<TransactionDetailModel> get transactionDetails =>
      List.unmodifiable(_transactionDetails);

  TransactionModel? get selectedTransaction =>
      _selectedTransaction;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  // ==================== GET CURRENT USER ID ====================
  Future<int> getCurrentUserId() async {
    return await _transactionService.getCurrentUserId();
  }

  // ==================== LOAD MY TRANSACTIONS ====================
  Future<void> loadMyTransactions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _transactions =
          await _transactionService.getMyTransactions();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== GET TRANSACTION BY ID ====================
  Future<TransactionModel?> getTransactionById(
    int transaksiId,
  ) async {
    _isLoading = true;
    _errorMessage = null;

    // Hindari menampilkan rincian transaksi sebelumnya.
    _transactionDetails = [];

    notifyListeners();

    try {
      final transaction =
          await _transactionService.getTransactionById(
        transaksiId,
      );

      _selectedTransaction = transaction;

      return transaction;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== LOAD TRANSACTION DETAILS ====================
  // Mengambil daftar buku dalam suatu transaksi.
  Future<void> loadTransactionDetails(
    int transaksiId,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    _transactionDetails = [];

    notifyListeners();

    try {
      final details =
          await _transactionService.getTransactionDetails(
        transaksiId,
      );

      _transactionDetails = details;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== CREATE TRANSACTION ====================
  // Hanya membuat record utama transaksi.
  // Belum merupakan proses checkout lengkap.
  Future<bool> createTransaction(
    TransactionModel transaction,
  ) async {
    if (_isSubmitting) {
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newTransaction =
          await _transactionService.createTransaction(
        transaction,
      );

      _transactions.insert(0, newTransaction);
      _selectedTransaction = newTransaction;

      // Transaksi baru belum mempunyai detail.
      _transactionDetails = [];

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // ==================== CLEAR SELECTED TRANSACTION ====================
  void clearSelectedTransaction() {
    _selectedTransaction = null;
    _transactionDetails = [];
    notifyListeners();
  }

  // ==================== CLEAR ERROR ====================
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ==================== RESET DATA ====================
  void reset() {
    _transactions = [];
    _transactionDetails = [];
    _selectedTransaction = null;

    _isLoading = false;
    _isSubmitting = false;
    _errorMessage = null;

    notifyListeners();
  }
}
