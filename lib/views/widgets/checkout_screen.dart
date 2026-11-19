import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/transaction_detail_model.dart';
import '../../models/transaction_model.dart';
import '../../services/cart_service.dart';
import '../../services/payment_service.dart';
import '../../services/transaction_service.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double totalPrice;
  final bool isBuyNow;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.totalPrice,
    this.isBuyNow = false,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const Color primaryGreen = Color(0xFF2E7D32);

  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _transactionService = TransactionService();
  final _paymentService = PaymentService();
  final _cartService = CartService();

  String _selectedPayment = 'Transfer_Bank';
  bool _isProcessing = false;
  int _currentStep = 0;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'Transfer_Bank',
      'name': 'Transfer Bank',
      'icon': Icons.account_balance,
    },
    {
      'id': 'E-Wallet',
      'name': 'E-Wallet (OVO, DANA, GoPay)',
      'icon': Icons.account_balance_wallet,
    },
    {
      'id': 'COD',
      'name': 'COD (Bayar di Tempat)',
      'icon': Icons.payments_outlined,
    },
  ];

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value, String fieldName) {
    if (value is num) return value.toInt();
    throw Exception('Data $fieldName tidak valid');
  }

  Map<String, dynamic> _getBook(Map<String, dynamic> item) {
    final rawBook = item['books'] ?? item['book'];
    if (rawBook is! Map) {
      throw Exception('Data buku dalam pesanan tidak ditemukan');
    }
    return Map<String, dynamic>.from(rawBook);
  }

  int _getBookId(Map<String, dynamic> book) {
    return _toInt(book['buku_id'] ?? book['id'], 'ID buku');
  }

  int _getSellerId(Map<String, dynamic> book) {
    return _toInt(book['user_id'], 'ID penjual');
  }

  int _getBookPrice(Map<String, dynamic> book) {
    return _toInt(book['price'] ?? book['harga'], 'harga buku');
  }

  int _getQuantity(Map<String, dynamic> item) {
    return _toInt(item['quantity'] ?? item['jumlah'] ?? 1, 'jumlah buku');
  }

  Future<void> _processOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.cartItems.isEmpty) {
      _showError('Tidak ada buku yang akan dibeli');
      return;
    }

    setState(() => _isProcessing = true);

    TransactionModel? createdTransaction;

    try {
      final bookIds = <int>[];
      for (final item in widget.cartItems) {
        bookIds.add(_getBookId(_getBook(item)));
      }

      // Periksa ulang ketersediaan buku sebelum membuat transaksi.
      await _transactionService.validatePurchasableBooks(
        bookIds: bookIds,
      );

      final transaction = await _transactionService.createTransaction(
        TransactionModel(
          totalHarga: widget.totalPrice.round(),
          status: 'Menunggu',
          alamatPengiriman: _addressController.text.trim(),
          metodePembayaran: _selectedPayment,
        ),
      );
      createdTransaction = transaction;

      final transactionId = transaction.transaksiId;
      if (transactionId == null) {
        throw Exception('ID transaksi tidak diterima dari server');
      }

      final details = widget.cartItems.map((item) {
        final book = _getBook(item);
        return TransactionDetailModel(
          transaksiId: transactionId,
          bukuId: _getBookId(book),
          penjualId: _getSellerId(book),
          jumlah: _getQuantity(item),
          harga: _getBookPrice(book),
        );
      }).toList();

      await _transactionService.createTransactionDetails(
        transaksiId: transactionId,
        details: details,
      );

      await _paymentService.createPendingPayment(
        transaksiId: transactionId,
        metodePembayaran: _selectedPayment,
      );

      // Pembelian langsung tidak boleh menghapus isi keranjang.
      // Kegagalan pembersihan keranjang tidak membatalkan pesanan yang
      // sudah berhasil dibuat dan memiliki detail serta data pembayaran.
      if (!widget.isBuyNow) {
        for (final item in widget.cartItems) {
          final cartId = item['keranjang_id'] ?? item['id'];
          if (cartId is num) {
            try {
              await _cartService.removeFromCart(cartId.toInt());
            } catch (cleanupError) {
              debugPrint('Gagal membersihkan item keranjang: $cleanupError');
            }
          }
        }
      }

      if (!mounted) return;
      setState(() => _currentStep = 2);
      await _showSuccessDialog(transactionId);
    } catch (e) {
      // Jika transaksi utama sudah terbentuk tetapi detail/pembayaran gagal,
      // tandai transaksi sebagai dibatalkan agar tidak dianggap pesanan aktif.
      if (createdTransaction?.transaksiId != null) {
        try {
          await _transactionService.cancelTransaction(
            createdTransaction!.transaksiId!,
          );
        } catch (cancelError) {
          debugPrint('Gagal membatalkan transaksi parsial: $cancelError');
        }
      }

      if (mounted) {
        _showError('Gagal memproses pesanan: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showSuccessDialog(int transactionId) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: primaryGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pesanan Berhasil Dibuat!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Nomor transaksi: #$transactionId',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Text(
              'Total: Rp${NumberFormat('#,##0').format(widget.totalPrice)}',
              style: const TextStyle(
                color: primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Status pembayaran: Belum Bayar. Pesanan menunggu proses berikutnya.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context, true);
            },
            child: const Text(
              'Selesai',
              style: TextStyle(
                color: primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
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
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Checkout',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStepIndicator(1, 'Alamat'),
                        const Expanded(child: Divider()),
                        _buildStepIndicator(2, 'Pembayaran'),
                        const Expanded(child: Divider()),
                        _buildStepIndicator(3, 'Selesai'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Alamat Pengiriman',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Masukkan alamat lengkap pengiriman',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: primaryGreen,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Alamat wajib diisi'
                              : null,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Metode Pembayaran',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ..._paymentMethods.map((method) {
                      final isSelected = _selectedPayment == method['id'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? primaryGreen : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: RadioListTile<String>(
                          value: method['id'] as String,
                          groupValue: _selectedPayment,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedPayment = value);
                            }
                          },
                          activeColor: primaryGreen,
                          title: Text(method['name'] as String),
                          secondary: Icon(
                            method['icon'] as IconData,
                            color: primaryGreen,
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    _buildOrderSummary(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _processOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Buat Pesanan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan Pesanan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          ...widget.cartItems.map((item) {
            final book = _getBook(item);
            final quantity = _getQuantity(item);
            final subtotal = _getBookPrice(book) * quantity;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${book['title'] ?? book['judul_buku'] ?? 'Buku'} x$quantity',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rp${NumberFormat('#,##0').format(subtotal)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Rp${NumberFormat('#,##0').format(widget.totalPrice)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step - 1;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? primaryGreen : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? primaryGreen : Colors.grey,
          ),
        ),
      ],
    );
  }
}
