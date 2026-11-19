import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction_model.dart';
import '../models/transaction_detail_model.dart';
import 'supabase_service.dart';

class TransactionService {
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

      if (response == null || response['user_id'] == null) {
        throw Exception('Profil pengguna tidak ditemukan');
      }

      return (response['user_id'] as num).toInt();
    } catch (e) {
      throw Exception('Gagal mengambil ID pengguna: $e');
    }
  }

  // ==================== VALIDATE BOOKS BEFORE CHECKOUT ====================

  Future<void> validatePurchasableBooks({
    required List<int> bookIds,
  }) async {
    try {
      if (bookIds.isEmpty) {
        throw Exception('Tidak ada buku untuk dibeli');
      }

      final buyerId = await getCurrentUserId();
      final uniqueBookIds = bookIds.toSet().toList();

      for (final bookId in uniqueBookIds) {
        final book = await _client
            .from('buku')
            .select('buku_id, user_id, status_buku, jenis_transaksi')
            .eq('buku_id', bookId)
            .maybeSingle();

        if (book == null) {
          throw Exception('Salah satu buku tidak lagi ditemukan');
        }

        final sellerId = (book['user_id'] as num).toInt();
        if (sellerId == buyerId) {
          throw Exception('Kamu tidak dapat membeli buku milik sendiri');
        }

        if (book['status_buku'] != 'Tersedia') {
          throw Exception('Salah satu buku sudah tidak tersedia');
        }

        final type = book['jenis_transaksi']?.toString();
        if (type != 'Jual' && type != 'Jual_Tukar') {
          throw Exception('Salah satu buku tidak tersedia untuk dibeli');
        }
      }
    } catch (e) {
      throw Exception('Validasi buku gagal: $e');
    }
  }

  // ==================== GET MY TRANSACTIONS ====================

  Future<List<TransactionModel>> getMyTransactions() async {
    try {
      final userId = await getCurrentUserId();
      final response = await _client
          .from('transaksi')
          .select()
          .eq('user_id', userId)
          .order('tanggal_dibuat', ascending: false);

      return response
          .map<TransactionModel>((json) => TransactionModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal mengambil riwayat transaksi: $e');
    }
  }

  // ==================== GET TRANSACTION BY ID ====================

  Future<TransactionModel?> getTransactionById(int transaksiId) async {
    try {
      final userId = await getCurrentUserId();
      final response = await _client
          .from('transaksi')
          .select()
          .eq('transaksi_id', transaksiId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return TransactionModel.fromJson(response);
    } catch (e) {
      throw Exception('Gagal mengambil detail transaksi: $e');
    }
  }

  // ==================== GET TRANSACTION DETAILS ====================

  Future<List<TransactionDetailModel>> getTransactionDetails(
    int transaksiId,
  ) async {
    try {
      final transaction = await getTransactionById(transaksiId);
      if (transaction == null) {
        throw Exception('Transaksi tidak ditemukan atau tidak dapat diakses');
      }

      final response = await _client
          .from('detail_transaksi')
          .select()
          .eq('transaksi_id', transaksiId)
          .order('detail_id', ascending: true);

      return response
          .map<TransactionDetailModel>(
            (json) => TransactionDetailModel.fromJson(json),
          )
          .toList();
    } catch (e) {
      throw Exception('Gagal mengambil rincian buku transaksi: $e');
    }
  }

  // ==================== CREATE TRANSACTION ====================

  Future<TransactionModel> createTransaction(
    TransactionModel transaction,
  ) async {
    try {
      final userId = await getCurrentUserId();

      if (transaction.totalHarga <= 0) {
        throw Exception('Total harga transaksi harus lebih dari nol');
      }

      final alamat = transaction.alamatPengiriman?.trim();
      if (alamat == null || alamat.isEmpty) {
        throw Exception('Alamat pengiriman harus diisi');
      }

      const allowedMethods = {'Transfer_Bank', 'E-Wallet', 'COD'};
      final metode = transaction.metodePembayaran?.trim();
      if (metode == null || !allowedMethods.contains(metode)) {
        throw Exception('Metode pembayaran tidak valid');
      }

      final response = await _client
          .from('transaksi')
          .insert({
            'user_id': userId,
            'total_harga': transaction.totalHarga,
            'status': 'Menunggu',
            'alamat_pengiriman': alamat,
            'metode_pembayaran': metode,
          })
          .select()
          .single();

      return TransactionModel.fromJson(response);
    } catch (e) {
      throw Exception('Gagal membuat transaksi: $e');
    }
  }

  // ==================== CREATE TRANSACTION DETAILS ====================

  Future<List<TransactionDetailModel>> createTransactionDetails({
    required int transaksiId,
    required List<TransactionDetailModel> details,
  }) async {
    try {
      if (details.isEmpty) {
        throw Exception('Rincian transaksi tidak boleh kosong');
      }

      final transaction = await getTransactionById(transaksiId);
      if (transaction == null) {
        throw Exception('Transaksi bukan milik pengguna yang sedang login');
      }

      for (final detail in details) {
        if (detail.transaksiId != transaksiId ||
            detail.bukuId <= 0 ||
            detail.penjualId <= 0 ||
            detail.jumlah <= 0 ||
            detail.harga <= 0) {
          throw Exception('Data rincian transaksi tidak valid');
        }
      }

      final response = await _client
          .from('detail_transaksi')
          .insert(details.map((detail) => detail.toJson()).toList())
          .select();

      return response
          .map<TransactionDetailModel>(
            (json) => TransactionDetailModel.fromJson(json),
          )
          .toList();
    } catch (e) {
      throw Exception('Gagal menyimpan rincian transaksi: $e');
    }
  }

  // ==================== CANCEL TRANSACTION ====================

  Future<void> cancelTransaction(int transaksiId) async {
    try {
      final userId = await getCurrentUserId();
      await _client
          .from('transaksi')
          .update({'status': 'Dibatalkan'})
          .eq('transaksi_id', transaksiId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Gagal membatalkan transaksi: $e');
    }
  }
}
