import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_model.dart';
import '../models/cart_detail_model.dart';
import 'supabase_service.dart';

class CartService {
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

  // ==================== GET USER CART ====================

  Future<List<CartModel>> getUserCart(int userId) async {
    try {
      final response = await _client
          .from('keranjang')
          .select()
          .eq('user_id', userId)
          .order('keranjang_id', ascending: false);

      return response
          .map<CartModel>((json) => CartModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal mengambil keranjang: $e');
    }
  }

  // ==================== GET CART WITH BOOK DATA ====================
  // Menggunakan dua query agar tidak bergantung pada nama foreign key
  // atau relasi PostgREST yang belum dipastikan pada database.

  Future<List<Map<String, dynamic>>> getUserCartWithBooks(
    int userId,
  ) async {
    try {
      final cartResponse = await _client
          .from('keranjang')
          .select()
          .eq('user_id', userId)
          .order('keranjang_id', ascending: false);

      final cartRows = List<Map<String, dynamic>>.from(cartResponse);
      if (cartRows.isEmpty) return [];

      final bookIds = cartRows
          .map((row) => (row['buku_id'] as num).toInt())
          .toSet()
          .toList();

      final bookResponse = await _client
          .from('buku')
          .select()
          .inFilter('buku_id', bookIds);

      final booksById = <int, Map<String, dynamic>>{};
      for (final row in List<Map<String, dynamic>>.from(bookResponse)) {
        final id = (row['buku_id'] as num).toInt();
        booksById[id] = row;
      }

      return cartRows.map((cart) {
        final cartId = (cart['keranjang_id'] as num).toInt();
        final bookId = (cart['buku_id'] as num).toInt();
        final rawBook = booksById[bookId];

        Map<String, dynamic>? book;
        if (rawBook != null) {
          book = {
            ...rawBook,
            'id': rawBook['buku_id'],
            'title': rawBook['judul_buku'] ?? '-',
            'author': rawBook['penulis'] ?? '-',
            'price': rawBook['harga'] ?? 0,
            'image_url': rawBook['foto_buku'],
            'condition': rawBook['kondisi_buku'] ?? '-',
          };
        }

        return {
          ...cart,
          'id': cartId,
          'keranjang_id': cartId,
          'buku_id': bookId,
          'quantity': (cart['jumlah'] as num?)?.toInt() ?? 1,
          'books': book,
        };
      }).toList();
    } catch (e) {
      throw Exception('Gagal mengambil isi keranjang: $e');
    }
  }

  // ==================== GET CART DETAIL ====================

  Future<List<CartDetailModel>> getCartDetails(int keranjangId) async {
    try {
      final response = await _client
          .from('detail_keranjang')
          .select()
          .eq('keranjang_id', keranjangId)
          .order('detail_id', ascending: false);

      return response
          .map<CartDetailModel>((json) => CartDetailModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal mengambil detail keranjang: $e');
    }
  }

  // ==================== ADD TO CART ====================

  Future<CartModel> addToCart({
    required int userId,
    required int bukuId,
    int jumlah = 1,
  }) async {
    try {
      if (jumlah < 1) {
        throw Exception('Jumlah buku minimal 1');
      }

      final currentUserId = await getCurrentUserId();
      if (currentUserId != userId) {
        throw Exception('Akun pengguna tidak sesuai');
      }

      final book = await _client
          .from('buku')
          .select('user_id, status_buku, jenis_transaksi')
          .eq('buku_id', bukuId)
          .maybeSingle();

      if (book == null) {
        throw Exception('Buku tidak ditemukan');
      }

      final sellerId = (book['user_id'] as num).toInt();
      if (sellerId == userId) {
        throw Exception('Kamu tidak dapat memasukkan buku milik sendiri');
      }

      if (book['status_buku'] != 'Tersedia') {
        throw Exception('Buku sudah tidak tersedia');
      }

      final transactionType = book['jenis_transaksi']?.toString();
      if (transactionType != 'Jual' && transactionType != 'Jual_Tukar') {
        throw Exception('Buku ini tidak tersedia untuk dibeli');
      }

      final existing = await _client
          .from('keranjang')
          .select()
          .eq('user_id', userId)
          .eq('buku_id', bukuId)
          .maybeSingle();

      if (existing != null) {
        throw Exception('Buku sudah ada di keranjang');
      }

      final response = await _client
          .from('keranjang')
          .insert({
            'user_id': userId,
            'buku_id': bukuId,
            'jumlah': jumlah,
          })
          .select()
          .single();

      return CartModel.fromJson(response);
    } catch (e) {
      throw Exception('Gagal menambahkan buku ke keranjang: $e');
    }
  }

  // ==================== UPDATE CART QUANTITY ====================

  Future<CartModel> updateCartQuantity({
    required int keranjangId,
    required int jumlah,
  }) async {
    if (jumlah < 1) {
      throw Exception('Jumlah buku minimal 1');
    }

    try {
      final response = await _client
          .from('keranjang')
          .update({'jumlah': jumlah})
          .eq('keranjang_id', keranjangId)
          .select()
          .single();

      return CartModel.fromJson(response);
    } catch (e) {
      throw Exception('Gagal mengubah jumlah buku: $e');
    }
  }

  // ==================== REMOVE FROM CART ====================

  Future<void> removeFromCart(int keranjangId) async {
    try {
      await _client
          .from('keranjang')
          .delete()
          .eq('keranjang_id', keranjangId);
    } catch (e) {
      throw Exception('Gagal menghapus buku dari keranjang: $e');
    }
  }

  // ==================== CLEAR CART ====================

  Future<void> clearCart(int userId) async {
    try {
      await _client.from('keranjang').delete().eq('user_id', userId);
    } catch (e) {
      throw Exception('Gagal mengosongkan keranjang: $e');
    }
  }

  // ==================== ADD CART DETAIL ====================

  Future<CartDetailModel> addCartDetail({
    required int keranjangId,
    required int bukuId,
    required int jumlah,
    required int subtotal,
  }) async {
    try {
      final response = await _client
          .from('detail_keranjang')
          .insert({
            'keranjang_id': keranjangId,
            'buku_id': bukuId,
            'jumlah': jumlah,
            'subtotal': subtotal,
          })
          .select()
          .single();

      return CartDetailModel.fromJson(response);
    } catch (e) {
      throw Exception('Gagal menambahkan detail keranjang: $e');
    }
  }

  // ==================== UPDATE CART DETAIL ====================

  Future<CartDetailModel> updateCartDetail({
    required int detailId,
    required int jumlah,
    required int subtotal,
  }) async {
    if (jumlah < 1) {
      throw Exception('Jumlah buku minimal 1');
    }

    try {
      final response = await _client
          .from('detail_keranjang')
          .update({'jumlah': jumlah, 'subtotal': subtotal})
          .eq('detail_id', detailId)
          .select()
          .single();

      return CartDetailModel.fromJson(response);
    } catch (e) {
      throw Exception('Gagal mengubah detail keranjang: $e');
    }
  }

  // ==================== DELETE CART DETAIL ====================

  Future<void> deleteCartDetail(int detailId) async {
    try {
      await _client
          .from('detail_keranjang')
          .delete()
          .eq('detail_id', detailId);
    } catch (e) {
      throw Exception('Gagal menghapus detail keranjang: $e');
    }
  }
}
