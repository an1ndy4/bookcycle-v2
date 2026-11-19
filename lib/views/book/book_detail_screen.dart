import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/cart_service.dart';
import '../widgets/chat_screen.dart';
import '../widgets/cart_screen.dart';
import '../widgets/checkout_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final int bookId;

  const BookDetailScreen({Key? key, required this.bookId}) : super(key: key);

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final _supabase = Supabase.instance.client;
  final CartService _cartService = CartService();
  Map<String, dynamic>? _book;
  Map<String, dynamic>? _seller;
  bool _isLoading = true;
  bool _isAddingToCart = false;
  bool _isBuyingNow = false;

  @override
  void initState() {
    super.initState();
    _fetchBookData();
  }


  Future<void> _fetchBookData() async {
    try {
      // 1. Ambil detail buku dari tabel public.buku
      final bookResponse = await _supabase
          .from('buku')
          .select()
          .eq('buku_id', widget.bookId)
          .maybeSingle();

      if (bookResponse == null) {
        if (!mounted) return;

        setState(() {
          _book = null;
          _isLoading = false;
        });
        return;
      }

      // 2. Ambil data penjual dari tabel public.users
      Map<String, dynamic>? sellerResponse;

      final sellerId = bookResponse['user_id'];

      if (sellerId != null) {
        try {
          sellerResponse = await _supabase
              .from('users')
              .select('nama_lengkap, nomor_hp')
              .eq('user_id', sellerId)
              .maybeSingle();
        } catch (e) {
          debugPrint('Gagal mengambil data penjual: $e');
        }
      }

      // 3. Ambil nama kategori
      String categoryName = '-';

      final kategoriId = bookResponse['kategori_id'];

      if (kategoriId != null) {
        try {
          final categoryResponse = await _supabase
              .from('kategori')
              .select('nama_kategori')
              .eq('kategori_id', kategoriId)
              .maybeSingle();

          categoryName =
              categoryResponse?['nama_kategori']?.toString() ?? '-';
        } catch (e) {
          debugPrint('Gagal mengambil kategori: $e');
        }
      }

      // 4. Sesuaikan nama kolom database
      // dengan nama field yang digunakan tampilan lama.
      final jenisTransaksi =
          bookResponse['jenis_transaksi']?.toString() ?? '';

      final mappedBook = <String, dynamic>{
        ...bookResponse,
        'title': bookResponse['judul_buku'] ?? '-',
        'author': bookResponse['penulis'] ?? '-',
        'image_url': bookResponse['foto_buku'],
        'price': bookResponse['harga'] ?? 0,
        'description': bookResponse['deskripsi'],
        'category': categoryName,
        'condition': bookResponse['kondisi_buku']
                ?.toString()
                .replaceAll('_', ' ') ??
            '-',
        'created_at': null,
        'is_for_sale':
            jenisTransaksi == 'Jual' ||
            jenisTransaksi == 'Jual_Tukar',
        'is_for_exchange':
            jenisTransaksi == 'Tukar' ||
            jenisTransaksi == 'Jual_Tukar',
      };

      // 5. Sesuaikan nama field penjual
      final mappedSeller = <String, dynamic>{
        'full_name':
            sellerResponse?['nama_lengkap'] ?? 'Penjual',
        'phone_number':
            sellerResponse?['nomor_hp'] ?? '-',
      };

      // 6. Tampilkan data buku
      if (!mounted) return;

      setState(() {
        _book = mappedBook;
        _seller = mappedSeller;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Gagal mengambil detail buku: $e');

      if (!mounted) return;

      setState(() {
        _book = null;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat detail buku: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  bool get _canPurchase {
    final transactionType = _book?['jenis_transaksi']?.toString();
    return _book?['status_buku'] == 'Tersedia' &&
        (transactionType == 'Jual' || transactionType == 'Jual_Tukar');
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF2E7D32),
      ),
    );
  }

  // ==================== ADD TO CART ====================

  Future<void> _addToCart() async {
    if (_isAddingToCart || !_canPurchase) return;

    setState(() => _isAddingToCart = true);

    try {
      final currentUserId = await _cartService.getCurrentUserId();
      final sellerId = (_book!['user_id'] as num).toInt();

      if (currentUserId == sellerId) {
        throw Exception('Kamu tidak dapat memasukkan buku milik sendiri');
      }

      await _cartService.addToCart(
        userId: currentUserId,
        bukuId: widget.bookId,
        jumlah: 1,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Buku berhasil ditambahkan ke keranjang'),
          backgroundColor: const Color(0xFF2E7D32),
          action: SnackBarAction(
            label: 'Lihat Keranjang',
            textColor: Colors.white,
            onPressed: _openCart,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  // ==================== BUY NOW ====================
  // Pembelian langsung menuju checkout dan tidak membuat record keranjang.

  Future<void> _buyNow() async {
    if (_isBuyingNow || !_canPurchase) return;

    setState(() => _isBuyingNow = true);

    try {
      final currentUserId = await _cartService.getCurrentUserId();
      final sellerId = (_book!['user_id'] as num).toInt();

      if (currentUserId == sellerId) {
        throw Exception('Kamu tidak dapat membeli buku milik sendiri');
      }

      final price = (_book!['price'] as num).toDouble();
      final checkoutBook = <String, dynamic>{
        'id': widget.bookId,
        'buku_id': widget.bookId,
        'title': _book!['title'],
        'author': _book!['author'],
        'price': price,
        'image_url': _book!['image_url'],
        'user_id': sellerId,
        'status_buku': _book!['status_buku'],
        'jenis_transaksi': _book!['jenis_transaksi'],
      };

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckoutScreen(
            cartItems: [
              {
                'id': null,
                'keranjang_id': null,
                'buku_id': widget.bookId,
                'quantity': 1,
                'books': checkoutBook,
              },
            ],
            totalPrice: price,
            isBuyNow: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isBuyingNow = false);
    }
  }

  // ==================== CHAT SELLER ====================

  Future<void> _chatSeller() async {
    try {
      final sellerId = (_book!['user_id'] as num).toInt();
      final currentUserId = await _cartService.getCurrentUserId();

      if (currentUserId == sellerId) {
        _showMessage('Ini buku yang kamu unggah sendiri.');
        return;
      }

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            sellerId: sellerId,
            sellerName: _seller?['full_name']?.toString() ?? 'Penjual',
            bookId: widget.bookId,
            bookTitle: _book?['title']?.toString(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF2E7D32);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_book == null) {
      return Scaffold(body: Center(child: Text('Buku tidak ditemukan')));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Keranjang',
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black87),
            onPressed: _openCart,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.black87),
            onPressed: () {
              // Share functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Gambar Buku + Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gambar Buku
                Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _book!['image_url'] != null
                        ? Image.network(
                            _book!['image_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.book, size: 50),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.book, size: 50),
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                // Info Buku
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _book!['title'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _book!['author'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Rating (bisa ditambahkan nanti)
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          const Text(
                            '4.8',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(120 ulasan)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Harga & Status
                      Row(
                        children: [
                          Text(
                            'Rp${NumberFormat('#,##0').format(_book!['price'])}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _book!['is_for_sale'] == true
                                  ? 'Tersedia'
                                  : 'Ditukar',
                              style: const TextStyle(
                                fontSize: 12,
                                color: primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Deskripsi
            const Text(
              'Deskripsi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _book!['description'] ?? 'Tidak ada deskripsi',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 24),

            // Info Detail Buku
            _buildInfoRow('Kategori', _book!['category'] ?? '-'),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Tipe',
              _book!['is_for_exchange'] == true ? 'Tukar' : 'Jual',
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Penulis', _book!['author'] ?? '-'),
            const SizedBox(height: 12),
            _buildInfoRow('Kondisi', _book!['condition'] ?? '-'),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Diposting',
              _book!['created_at'] != null
                  ? DateFormat('dd MMM yyyy')
                        .format(DateTime.parse(_book!['created_at']))
                  : '-',
            ),

            const SizedBox(height: 24),

            // Info Penjual
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informasi Penjual',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: primaryGreen,
                        radius: 20,
                        child: Text(
                          _seller?['full_name']?[0] ?? 'P',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _seller?['full_name'] ?? 'Penjual',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),

      // Bottom action buttons
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _chatSeller,
                      icon: const Icon(Icons.chat_outlined, size: 17),
                      label: const Text('Chat Penjual'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryGreen,
                        side: const BorderSide(color: primaryGreen),
                        minimumSize: const Size(0, 46),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: !_canPurchase || _isAddingToCart
                          ? null
                          : _addToCart,
                      icon: _isAddingToCart
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_shopping_cart, size: 17),
                      label: const Text(
                        'Tambah ke Keranjang',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryGreen,
                        side: const BorderSide(color: primaryGreen),
                        disabledForegroundColor: Colors.grey,
                        minimumSize: const Size(0, 46),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: !_canPurchase || _isBuyingNow ? null : _buyNow,
                  icon: _isBuyingNow
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.flash_on, size: 18),
                  label: Text(
                    _canPurchase ? 'Beli Sekarang' : 'Buku Tidak Tersedia',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
        const Text(': ', style: TextStyle(color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
