
class TransactionModel {
  final int? transaksiId;
  final int? userId;
  final int totalHarga;
  final String status;
  final String? alamatPengiriman;
  final String? metodePembayaran;
  final DateTime? tanggalDibuat;

  const TransactionModel({
    this.transaksiId,
    this.userId,
    required this.totalHarga,
    this.status = 'Menunggu',
    this.alamatPengiriman,
    this.metodePembayaran,
    this.tanggalDibuat,
  });

  // ==================== FROM JSON ====================
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      transaksiId: (json['transaksi_id'] as num?)?.toInt(),
      userId: (json['user_id'] as num?)?.toInt(),
      totalHarga: (json['total_harga'] as num).toInt(),
      status: json['status'] as String? ?? 'Menunggu',
      alamatPengiriman: json['alamat_pengiriman'] as String?,
      metodePembayaran: json['metode_pembayaran'] as String?,
      tanggalDibuat: json['tanggal_dibuat'] != null
          ? DateTime.parse(json['tanggal_dibuat'] as String)
          : null,
    );
  }

  // ==================== TO JSON ====================
  Map<String, dynamic> toJson() {
    return {
      if (userId != null) 'user_id': userId,
      'total_harga': totalHarga,
      'status': status,
      'alamat_pengiriman': alamatPengiriman,
      'metode_pembayaran': metodePembayaran,
    };
  }

  // ==================== COPY WITH ====================
  TransactionModel copyWith({
    int? transaksiId,
    int? userId,
    int? totalHarga,
    String? status,
    String? alamatPengiriman,
    String? metodePembayaran,
    DateTime? tanggalDibuat,
  }) {
    return TransactionModel(
      transaksiId: transaksiId ?? this.transaksiId,
      userId: userId ?? this.userId,
      totalHarga: totalHarga ?? this.totalHarga,
      status: status ?? this.status,
      alamatPengiriman:
          alamatPengiriman ?? this.alamatPengiriman,
      metodePembayaran:
          metodePembayaran ?? this.metodePembayaran,
      tanggalDibuat: tanggalDibuat ?? this.tanggalDibuat,
    );
  }
}
