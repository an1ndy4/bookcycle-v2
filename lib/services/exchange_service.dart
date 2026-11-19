
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exchange_model.dart';
import 'supabase_service.dart';

class ExchangeService {
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
        throw Exception('Profil pengguna tidak ditemukan');
      }

      return (response['user_id'] as num).toInt();
    } catch (e) {
      throw Exception('Gagal mengambil ID pengguna: $e');
    }
  }

  // ==================== GET MY EXCHANGES ====================
  // Mengambil permintaan tukar yang diajukan pengguna.
  Future<List<ExchangeModel>> getMyExchanges() async {
    try {
      final userId = await getCurrentUserId();

      final response = await _client
          .from('tukar_buku')
          .select()
          .eq('user_id', userId)
          .order('tanggal_tukar', ascending: false);

      return response
          .map((json) => ExchangeModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal mengambil permintaan tukar: $e');
    }
  }

  // ==================== GET INCOMING EXCHANGES ====================
  // Mengambil permintaan tukar untuk buku milik pengguna.
  Future<List<ExchangeModel>> getIncomingExchanges() async {
    try {
      final userId = await getCurrentUserId();

      final myBooks = await _client
          .from('buku')
          .select('buku_id')
          .eq('user_id', userId);

      if (myBooks.isEmpty) {
        return [];
      }

      final bookIds = myBooks
          .map((book) => (book['buku_id'] as num).toInt())
          .toList();

      final response = await _client
          .from('tukar_buku')
          .select()
          .inFilter('buku_id', bookIds)
          .order('tanggal_tukar', ascending: false);

      return response
          .map((json) => ExchangeModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal mengambil permintaan tukar masuk: $e');
    }
  }

  // ==================== GET EXCHANGE BY ID ====================
  Future<ExchangeModel?> getExchangeById(int tukarId) async {
    try {
      final response = await _client
          .from('tukar_buku')
          .select()
          .eq('tukar_id', tukarId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return ExchangeModel.fromJson(response);
    } catch (e) {
      throw Exception('Gagal mengambil detail pertukaran: $e');
    }
  }

  // ==================== CREATE EXCHANGE ====================
  Future<ExchangeModel> createExchange(
    ExchangeModel exchange,
  ) async {
    try {
      final userId = await getCurrentUserId();

      if (exchange.bukuId == null) {
        throw Exception('Buku yang ingin ditukar harus dipilih');
      }

      final book = await _client
          .from('buku')
          .select('user_id, jenis_transaksi, status_buku')
          .eq('buku_id', exchange.bukuId!)
          .maybeSingle();

      if (book == null) {
        throw Exception('Buku tidak ditemukan');
      }

      final ownerId = (book['user_id'] as num?)?.toInt();

      if (ownerId == userId) {
        throw Exception('Tidak dapat menukar buku milik sendiri');
      }

      final jenisTransaksi = book['jenis_transaksi'] as String;

      if (jenisTransaksi != 'Tukar' &&
          jenisTransaksi != 'Jual_Tukar') {
        throw Exception('Buku ini tidak tersedia untuk ditukar');
      }

      if (book['status_buku'] != 'Tersedia') {
        throw Exception('Buku sudah tidak tersedia');
      }

      final data = <String, dynamic>{
        ...exchange.toJson(),
        'user_id': userId,
        'status_tukar': 'Menunggu',
      };

      final response = await _client
          .from('tukar_buku')
          .insert(data)
          .select()
          .single();

      return ExchangeModel.fromJson(response);
    } catch (e) {
      throw Exception('Gagal mengajukan pertukaran: $e');
    }
  }

  // ==================== UPDATE EXCHANGE NOTES ====================
  // Pemohon dapat mengubah catatan saat masih menunggu.
  Future<ExchangeModel> updateExchangeNotes({
    required int tukarId,
    String? bukuDicari,
    String? catatanTukar,
  }) async {
    try {
      final userId = await getCurrentUserId();

      final response = await _client
          .from('tukar_buku')
          .update({
            'buku_dicari': bukuDicari,
            'catatan_tukar': catatanTukar,
          })
          .eq('tukar_id', tukarId)
          .eq('user_id', userId)
          .eq('status_tukar', 'Menunggu')
          .select()
          .maybeSingle();

      if (response == null) {
        throw Exception(
          'Permintaan tidak ditemukan atau tidak dapat diubah',
        );
      }

      return ExchangeModel.fromJson(response);
    } catch (e) {
      throw Exception('Gagal mengubah permintaan tukar: $e');
    }
  }

  // ==================== UPDATE EXCHANGE STATUS ====================
  // Hanya pemilik buku yang boleh memproses permintaan.
  Future<ExchangeModel> updateExchangeStatus({
    required int tukarId,
    required String status,
  }) async {
    try {
      final userId = await getCurrentUserId();

      final exchange = await _client
          .from('tukar_buku')
          .select('buku_id, status_tukar')
          .eq('tukar_id', tukarId)
          .maybeSingle();

      if (exchange == null) {
        throw Exception('Permintaan tukar tidak ditemukan');
      }

      final bukuId = (exchange['buku_id'] as num?)?.toInt();

      if (bukuId == null) {
        throw Exception('Buku pertukaran tidak ditemukan');
      }

      final book = await _client
          .from('buku')
          .select('user_id')
          .eq('buku_id', bukuId)
          .maybeSingle();

      if (book == null ||
          (book['user_id'] as num?)?.toInt() != userId) {
        throw Exception(
          'Hanya pemilik buku yang dapat mengubah status',
        );
      }

      if (exchange['status_tukar'] != 'Menunggu') {
        throw Exception(
          'Permintaan ini sudah diproses',
        );
      }

      final response = await _client
          .from('tukar_buku')
          .update({'status_tukar': status})
          .eq('tukar_id', tukarId)
          .eq('status_tukar', 'Menunggu')
          .select()
          .maybeSingle();

      if (response == null) {
        throw Exception('Status permintaan gagal diperbarui');
      }

      return ExchangeModel.fromJson(response);
    } catch (e) {
      throw Exception('Gagal mengubah status pertukaran: $e');
    }
  }

  // ==================== CANCEL EXCHANGE ====================
  // Pemohon hanya dapat membatalkan permintaan
  // yang masih berstatus Menunggu.
  Future<bool> cancelExchange(int tukarId) async {
    try {
      final userId = await getCurrentUserId();

      final response = await _client
          .from('tukar_buku')
          .delete()
          .eq('tukar_id', tukarId)
          .eq('user_id', userId)
          .eq('status_tukar', 'Menunggu')
          .select('tukar_id');

      if (response.isEmpty) {
        throw Exception(
          'Permintaan tidak ditemukan atau tidak dapat dibatalkan',
        );
      }

      return true;
    } catch (e) {
      throw Exception('Gagal membatalkan pertukaran: $e');
    }
  }
}
