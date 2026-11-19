
import 'package:flutter/material.dart';
import '../models/payment_model.dart';
import '../services/payment_service.dart';

class PaymentController extends ChangeNotifier {
  final PaymentService _paymentService = PaymentService();

  // ==================== STATE ====================
  List<PaymentModel> _payments = [];
  PaymentModel? _selectedPayment;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // ==================== GETTERS ====================
  List<PaymentModel> get payments =>
      List.unmodifiable(_payments);

  PaymentModel? get selectedPayment => _selectedPayment;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  // ==================== GET CURRENT USER ID ====================
  Future<int> getCurrentUserId() async {
    return await _paymentService.getCurrentUserId();
  }

  // ==================== LOAD MY PAYMENTS ====================
  // Mengambil riwayat pembayaran pengguna login.
  Future<void> loadMyPayments() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _paymentService.getMyPayments();

      _payments = result;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== GET PAYMENT BY TRANSACTION ====================
  // Mengambil pembayaran berdasarkan ID transaksi.
  Future<PaymentModel?> getPaymentByTransactionId(
    int transaksiId,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    _selectedPayment = null;
    notifyListeners();

    try {
      final payment =
          await _paymentService.getPaymentByTransactionId(
        transaksiId,
      );

      _selectedPayment = payment;

      return payment;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== CREATE PENDING PAYMENT ====================
  // Hanya membuat catatan pembayaran awal.
  // Status awal pembayaran adalah Belum_Bayar.
  Future<bool> createPendingPayment({
    required int transaksiId,
    required String metodePembayaran,
  }) async {
    if (_isSubmitting) {
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newPayment =
          await _paymentService.createPendingPayment(
        transaksiId: transaksiId,
        metodePembayaran: metodePembayaran,
      );

      // Menambahkan pembayaran baru ke daftar lokal.
      final existingIndex = _payments.indexWhere(
        (payment) =>
            payment.pembayaranId == newPayment.pembayaranId,
      );

      if (existingIndex == -1) {
        _payments.insert(0, newPayment);
      } else {
        _payments[existingIndex] = newPayment;
      }

      // Menyimpan pembayaran yang baru dibuat.
      _selectedPayment = newPayment;

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // ==================== CLEAR SELECTED PAYMENT ====================
  void clearSelectedPayment() {
    _selectedPayment = null;
    notifyListeners();
  }

  // ==================== CLEAR ERROR ====================
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ==================== RESET DATA ====================
  // Digunakan saat logout atau ingin
  // membersihkan data pembayaran lokal.
  void reset() {
    _payments = [];
    _selectedPayment = null;

    _isLoading = false;
    _isSubmitting = false;
    _errorMessage = null;

    notifyListeners();
  }
}
