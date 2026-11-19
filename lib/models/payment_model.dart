
class PaymentModel {
  final int? pembayaranId;
  final int? transaksiId;
  final String metodePembayaran;
  final String statusPembayaran;
  final String? buktiPembayaran;
  final DateTime? tanggalBayar;

  const PaymentModel({
    this.pembayaranId,
    this.transaksiId,
    required this.metodePembayaran,
    this.statusPembayaran = 'Belum_Bayar',
    this.buktiPembayaran,
    this.tanggalBayar,
  });

  // ==================== FROM JSON ====================
  factory PaymentModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PaymentModel(
      pembayaranId:
          (json['pembayaran_id'] as num?)?.toInt(),
      transaksiId:
          (json['transaksi_id'] as num?)?.toInt(),
      metodePembayaran:
          json['metode_pembayaran'] as String,
      statusPembayaran:
          json['status_pembayaran'] as String? ??
              'Belum_Bayar',
      buktiPembayaran:
          json['bukti_pembayaran'] as String?,
      tanggalBayar:
          json['tanggal_bayar'] != null
              ? DateTime.parse(
                  json['tanggal_bayar'] as String,
                )
              : null,
    );
  }

  // ==================== TO JSON ====================
  Map<String, dynamic> toJson() {
    return {
      if (transaksiId != null)
        'transaksi_id': transaksiId,
      'metode_pembayaran': metodePembayaran,
      'status_pembayaran': statusPembayaran,
      'bukti_pembayaran': buktiPembayaran,
      if (tanggalBayar != null)
        'tanggal_bayar':
            tanggalBayar!.toIso8601String(),
    };
  }

  // ==================== COPY WITH ====================
  PaymentModel copyWith({
    int? pembayaranId,
    int? transaksiId,
    String? metodePembayaran,
    String? statusPembayaran,
    String? buktiPembayaran,
    DateTime? tanggalBayar,
  }) {
    return PaymentModel(
      pembayaranId:
          pembayaranId ?? this.pembayaranId,
      transaksiId:
          transaksiId ?? this.transaksiId,
      metodePembayaran:
          metodePembayaran ?? this.metodePembayaran,
      statusPembayaran:
          statusPembayaran ?? this.statusPembayaran,
      buktiPembayaran:
          buktiPembayaran ?? this.buktiPembayaran,
      tanggalBayar:
          tanggalBayar ?? this.tanggalBayar,
    );
  }
}
