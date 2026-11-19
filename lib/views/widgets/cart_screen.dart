import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/cart_service.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const Color primaryGreen = Color(0xFF2E7D32);

  final CartService _cartService = CartService();
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  bool _isCheckingOut = false;
  double _totalPrice = 0;
  String? _errorMessage;

  bool get _hasUnavailableItems {
    return _cartItems.any((item) {
      final book = item['books'] as Map<String, dynamic>?;
      return book == null || book['status_buku'] != 'Tersedia';
    });
  }

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final userId = await _cartService.getCurrentUserId();
      final items = await _cartService.getUserCartWithBooks(userId);

      double total = 0;
      for (final item in items) {
        final book = item['books'] as Map<String, dynamic>?;
        if (book == null || book['status_buku'] != 'Tersedia') continue;

        final price = (book['price'] as num?)?.toDouble() ?? 0;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
        total += price * quantity;
      }

      if (!mounted) return;
      setState(() {
        _cartItems = items;
        _totalPrice = total;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFromCart(Map<String, dynamic> item) async {
    final cartId = item['keranjang_id'] as num?;
    if (cartId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus dari Keranjang?'),
        content: const Text(
          'Buku ini akan dihapus dari keranjang belanja.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _cartService.removeFromCart(cartId.toInt());
      await _loadCart();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus buku: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _goToCheckout() async {
    if (_cartItems.isEmpty || _isCheckingOut) return;

    if (_hasUnavailableItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ada buku yang sudah tidak tersedia. Hapus buku tersebut sebelum checkout.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCheckingOut = true);
    try {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CheckoutScreen(
            cartItems: _cartItems,
            totalPrice: _totalPrice,
          ),
        ),
      );
      if (mounted) await _loadCart();
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Keranjang',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _isLoading ? null : _loadCart,
            icon: const Icon(Icons.refresh, color: Colors.black87),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _cartItems.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _cartItems.length,
                            itemBuilder: (context, index) {
                              return _buildCartItem(_cartItems[index]);
                            },
                          ),
                        ),
                        _buildCheckoutBar(),
                      ],
                    ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 52),
            const SizedBox(height: 12),
            const Text(
              'Keranjang gagal dimuat',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Terjadi kesalahan',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadCart,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'Keranjang Kosong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Buku yang kamu tambahkan akan muncul di sini.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    final book = item['books'] as Map<String, dynamic>?;
    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final isAvailable = book != null && book['status_buku'] == 'Tersedia';
    final price = (book?['price'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 76,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: book?['image_url'] != null
                  ? Image.network(
                      book!['image_url'].toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.book, size: 38),
                    )
                  : const Icon(Icons.book, size: 38),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book?['title']?.toString() ?? 'Buku tidak ditemukan',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  book?['author']?.toString() ?? '-',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 6),
                Text(
                  'Rp${NumberFormat('#,##0').format(price)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Jumlah: $quantity',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 8),
                    if (!isAvailable)
                      const Expanded(
                        child: Text(
                          'Tidak tersedia',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hapus dari keranjang',
            onPressed: () => _removeFromCart(item),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Rp${NumberFormat('#,##0').format(_totalPrice)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
            ],
          ),
          if (_hasUnavailableItems) ...[
            const SizedBox(height: 8),
            const Text(
              'Hapus buku yang tidak tersedia sebelum melanjutkan.',
              style: TextStyle(color: Colors.red, fontSize: 11),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _hasUnavailableItems || _isCheckingOut
                  ? null
                  : _goToCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: _isCheckingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Checkout'),
            ),
          ),
        ],
      ),
    );
  }
}
