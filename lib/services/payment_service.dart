
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_model.dart';
import 'supabase_service.dart';

class PaymentService {
  final SupabaseClient _client = SupabaseService.client;

  // ==================== GET CURRENT USER ID ====================
  Future<int> getCurrentUserId() async {
    try {
      final authUser = _client.auth.currentUser;

      if (authUser == null) {
        throw Exception('Pengguna belum login');
      }

      final response = await _client
          .from('users')
          .select('user_id')
          .eq('auth_id', authUser.id)
          .maybeSingle();

      if (response == null) {
        throw Exception(
          'Profil pengguna tidak ditemukan',
        );
      }

      return (response['user_id'] as num).toInt();
    } catch (e) {
      throw Exception(
        'Gagal mengambil ID pengguna: $e',
      );
    }
  }

  // ==================== GET PAYMENT BY TRANSACTION ====================
  Future<PaymentModel?> getPaymentByTransactionId(
    int transaksiId,
  ) async {
    try {
      final userId = await getCurrentUserId();

      // Pastikan transaksi milik pengguna login.
      final transaction = await _client
          .from('transaksi')
          .select('transaksi_id')
          .eq('transaksi_id', transaksiId)
          .eq('user_id', userId)
          .maybeSingle();

      if (transaction == null) {
        throw Exception(
          'Transaksi tidak ditemukan atau tidak dapat diakses',
        );
      }

      final response = await _client
          .from('pembayaran')
          .select()
          .eq('transaksi_id', transaksiId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return PaymentModel.fromJson(response);
    } catch (e) {
      throw Exception(
        'Gagal mengambil data pembayaran: $e',
      );
    }
  }

  // ==================== GET MY PAYMENTS ====================
  Future<List<PaymentModel>> getMyPayments() async {
    try {
      final userId = await getCurrentUserId();

      // Ambil ID transaksi milik pengguna login.
      final transactions = await _client
          .from('transaksi')
          .select('transaksi_id')
          .eq('user_id', userId);

      if (transactions.isEmpty) {
        return [];
      }

      final transactionIds = transactions
          .map(
            (item) =>
                (item['transaksi_id'] as num).toInt(),
          )
          .toList();

      final response = await _client
          .from('pembayaran')
          .select()
          .inFilter('transaksi_id', transactionIds)
          .order(
            'pembayaran_id',
            ascending: false,
          );

      return response
          .map(
            (json) => PaymentModel.fromJson(json),
          )
          .toList();
    } catch (e) {
      throw Exception(
        'Gagal mengambil riwayat pembayaran: $e',
      );
    }
  }

  // ==================== CREATE PENDING PAYMENT ====================
  // Hanya membuat catatan pembayaran awal.
  // Tidak memproses uang atau mengonfirmasi pembayaran.
  Future<PaymentModel> createPendingPayment({
    required int transaksiId,
    required String metodePembayaran,
  }) async {
    try {
      final userId = await getCurrentUserId();

      // Nilai harus sesuai metode_pembayaran_enum
      // di database Supabase.
      const allowedMethods = {
        'Transfer_Bank',
        'E-Wallet',
        'COD',
      };

      if (!allowedMethods.contains(metodePembayaran)) {
        throw Exception(
          'Metode pembayaran tidak valid',
        );
      }

      // Pastikan transaksi benar-benar milik pengguna.
      final transaction = await _client
          .from('transaksi')
          .select('transaksi_id, status')
          .eq('transaksi_id', transaksiId)
          .eq('user_id', userId)
          .maybeSingle();

      if (transaction == null) {
        throw Exception(
          'Transaksi tidak ditemukan atau bukan milik pengguna',
        );
      }

      // Pembayaran baru hanya untuk transaksi berstatus Menunggu.
      if (transaction['status'] != 'Menunggu') {
        throw Exception(
          'Pembayaran baru hanya dapat dibuat '
          'untuk transaksi berstatus Menunggu',
        );
      }

      // Satu transaksi hanya boleh memiliki
      // satu record pembayaran.
      final existingPayment = await _client
          .from('pembayaran')
          .select('pembayaran_id')
          .eq('transaksi_id', transaksiId)
          .maybeSingle();

      if (existingPayment != null) {
        throw Exception(
          'Transaksi ini sudah memiliki data pembayaran',
        );
      }

      final data = <String, dynamic>{
        'transaksi_id': transaksiId,
        'metode_pembayaran': metodePembayaran,
        'status_pembayaran': 'Belum_Bayar',
      };

      final response = await _client
          .from('pembayaran')
          .insert(data)
          .select()
          .single();

      return PaymentModel.fromJson(response);
    } catch (e) {
      throw Exception(
        'Gagal membuat pembayaran: $e',
      );
    }
  }
}
