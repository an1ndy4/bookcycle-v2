
class ExchangeModel {
  final int? tukarId;
  final int? userId;
  final int? bukuId;
  final String? bukuDicari;
  final String? catatanTukar;
  final String statusTukar;
  final DateTime? tanggalTukar;

  const ExchangeModel({
    this.tukarId,
    this.userId,
    this.bukuId,
    this.bukuDicari,
    this.catatanTukar,
    this.statusTukar = 'Menunggu',
    this.tanggalTukar,
  });

  // ==================== FROM JSON ====================
  factory ExchangeModel.fromJson(Map<String, dynamic> json) {
    return ExchangeModel(
      tukarId: (json['tukar_id'] as num?)?.toInt(),
      userId: (json['user_id'] as num?)?.toInt(),
      bukuId: (json['buku_id'] as num?)?.toInt(),
      bukuDicari: json['buku_dicari'] as String?,
      catatanTukar: json['catatan_tukar'] as String?,
      statusTukar: json['status_tukar'] as String? ?? 'Menunggu',
      tanggalTukar: json['tanggal_tukar'] != null
          ? DateTime.parse(json['tanggal_tukar'] as String)
          : null,
    );
  }

  // ==================== TO JSON ====================
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'buku_id': bukuId,
      'buku_dicari': bukuDicari,
      'catatan_tukar': catatanTukar,
      'status_tukar': statusTukar,
    };
  }

  // ==================== COPY WITH ====================
  ExchangeModel copyWith({
    int? tukarId,
    int? userId,
    int? bukuId,
    String? bukuDicari,
    String? catatanTukar,
    String? statusTukar,
    DateTime? tanggalTukar,
  }) {
    return ExchangeModel(
      tukarId: tukarId ?? this.tukarId,
      userId: userId ?? this.userId,
      bukuId: bukuId ?? this.bukuId,
      bukuDicari: bukuDicari ?? this.bukuDicari,
      catatanTukar: catatanTukar ?? this.catatanTukar,
      statusTukar: statusTukar ?? this.statusTukar,
      tanggalTukar: tanggalTukar ?? this.tanggalTukar,
    );
  }
}
