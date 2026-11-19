
class ChatModel {
  final int? chatId;
  final int pengirimId;
  final int penerimaId;
  final int? bukuId;
  final String pesan;
  final bool sudahDibaca;
  final DateTime? tanggalDikirim;

  const ChatModel({
    this.chatId,
    required this.pengirimId,
    required this.penerimaId,
    this.bukuId,
    required this.pesan,
    this.sudahDibaca = false,
    this.tanggalDikirim,
  });

  // ==================== FROM JSON ====================
  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      chatId: (json['chat_id'] as num?)?.toInt(),
      pengirimId: (json['pengirim_id'] as num).toInt(),
      penerimaId: (json['penerima_id'] as num).toInt(),
      bukuId: (json['buku_id'] as num?)?.toInt(),
      pesan: json['pesan'] as String,
      sudahDibaca: json['sudah_dibaca'] as bool? ?? false,
      tanggalDikirim: json['tanggal_dikirim'] != null
          ? DateTime.parse(json['tanggal_dikirim'] as String)
          : null,
    );
  }

  // ==================== TO JSON ====================
  Map<String, dynamic> toJson() {
    return {
      'pengirim_id': pengirimId,
      'penerima_id': penerimaId,
      if (bukuId != null) 'buku_id': bukuId,
      'pesan': pesan,
    };
  }

  // ==================== COPY WITH ====================
  ChatModel copyWith({
    int? chatId,
    int? pengirimId,
    int? penerimaId,
    int? bukuId,
    String? pesan,
    bool? sudahDibaca,
    DateTime? tanggalDikirim,
  }) {
    return ChatModel(
      chatId: chatId ?? this.chatId,
      pengirimId: pengirimId ?? this.pengirimId,
      penerimaId: penerimaId ?? this.penerimaId,
      bukuId: bukuId ?? this.bukuId,
      pesan: pesan ?? this.pesan,
      sudahDibaca: sudahDibaca ?? this.sudahDibaca,
      tanggalDikirim: tanggalDikirim ?? this.tanggalDikirim,
    );
  }
}
