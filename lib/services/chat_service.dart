import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_model.dart';
import 'supabase_service.dart';

/// Ringkasan satu percakapan untuk ditampilkan pada halaman Chat Inbox.
///
/// Tabel public.users saat ini belum memiliki kolom foto profil, sehingga
/// identitas pengguna sementara menggunakan nama lengkap.
class ChatConversationSummary {
  final int otherUserId;
  final String otherUserName;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int lastMessageSenderId;
  final int unreadCount;
  final int? lastBookId;

  const ChatConversationSummary({
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessage,
    required this.lastMessageSenderId,
    required this.unreadCount,
    this.lastMessageAt,
    this.lastBookId,
  });

  ChatConversationSummary copyWith({int? unreadCount}) {
    return ChatConversationSummary(
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      lastMessageSenderId: lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      lastBookId: lastBookId,
    );
  }
}

/// Data sementara untuk menggabungkan pesan berdasarkan lawan bicara.
class _ConversationAccumulator {
  final int otherUserId;
  final String otherUserName;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int lastMessageSenderId;
  final int? lastBookId;
  int unreadCount = 0;

  _ConversationAccumulator({
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastMessageSenderId,
    required this.lastBookId,
  });

  ChatConversationSummary toSummary() {
    return ChatConversationSummary(
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      lastMessageSenderId: lastMessageSenderId,
      unreadCount: unreadCount,
      lastBookId: lastBookId,
    );
  }
}

class ChatService {
  final SupabaseClient _client = SupabaseService.client;

  /// Mengubah UUID Supabase Auth menjadi user_id integer pada public.users.
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

  /// Mengambil satu riwayat percakapan untuk pasangan pengguna.
  ///
  /// buku_id tetap menjadi konteks pesan, bukan pemisah thread. Satu pembeli
  /// dan satu penjual hanya memiliki satu percakapan.
  Future<List<ChatModel>> getConversation({
    required int otherUserId,
  }) async {
    try {
      final currentUserId = await getCurrentUserId();

      if (currentUserId == otherUserId) {
        throw Exception('Tidak dapat membuka chat dengan diri sendiri');
      }

      final participantsFilter =
          'and(pengirim_id.eq.$currentUserId,'
          'penerima_id.eq.$otherUserId),'
          'and(pengirim_id.eq.$otherUserId,'
          'penerima_id.eq.$currentUserId)';

      final response = await _client
          .from('chat')
          .select()
          .or(participantsFilter)
          .order('tanggal_dikirim', ascending: true);

      return response.map((json) => ChatModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Gagal mengambil percakapan: $e');
    }
  }

  /// Mengambil daftar percakapan untuk halaman Chat Inbox.
  ///
  /// Pesan diambil dari yang terbaru, kemudian dikelompokkan berdasarkan
  /// pengguna lain. Pesan terakhir menjadi preview, sedangkan unreadCount
  /// menghitung pesan masuk yang belum dibaca oleh pengguna saat ini.
  ///
  /// Batas maksimum 1.000 pesan mengikuti batas hasil REST API yang umum
  /// digunakan Supabase. Untuk skala pesan yang jauh lebih besar, agregasi
  /// sebaiknya dipindahkan ke database view atau RPC dengan pagination.
  Future<List<ChatConversationSummary>> getInboxConversations({
    int limit = 1000,
  }) async {
    try {
      final currentUserId = await getCurrentUserId();
      final safeLimit = limit.clamp(1, 1000).toInt();

      final response = await _client
          .from('chat')
          .select(
            'chat_id,'
            'pengirim_id,'
            'penerima_id,'
            'buku_id,'
            'pesan,'
            'sudah_dibaca,'
            'tanggal_dikirim,'
            'pengirim:users!chat_pengirim_id_fkey(user_id,nama_lengkap),'
            'penerima:users!chat_penerima_id_fkey(user_id,nama_lengkap)',
          )
          .or(
            'pengirim_id.eq.$currentUserId,penerima_id.eq.$currentUserId',
          )
          .order('tanggal_dikirim', ascending: false)
          .limit(safeLimit);

      final conversations = <int, _ConversationAccumulator>{};

      for (final item in response) {
        final row = Map<String, dynamic>.from(item as Map);
        final senderId = (row['pengirim_id'] as num).toInt();
        final receiverId = (row['penerima_id'] as num).toInt();

        // Abaikan baris yang tidak melibatkan pengguna saat ini.
        if (senderId != currentUserId && receiverId != currentUserId) {
          continue;
        }

        final otherUserId =
            senderId == currentUserId ? receiverId : senderId;
        if (otherUserId == currentUserId) {
          continue;
        }

        final partnerProfile = _asJsonMap(
          senderId == currentUserId ? row['penerima'] : row['pengirim'],
        );

        final profileName =
            partnerProfile?['nama_lengkap']?.toString().trim() ?? '';
        final partnerName =
            profileName.isNotEmpty ? profileName : 'Pengguna BookCycle';

        // Query sudah diurutkan descending, jadi baris pertama untuk setiap
        // lawan bicara adalah pesan terakhirnya.
        final conversation = conversations.putIfAbsent(
          otherUserId,
          () => _ConversationAccumulator(
            otherUserId: otherUserId,
            otherUserName: partnerName,
            lastMessage: row['pesan']?.toString() ?? '',
            lastMessageAt: DateTime.tryParse(
              row['tanggal_dikirim']?.toString() ?? '',
            ),
            lastMessageSenderId: senderId,
            lastBookId: (row['buku_id'] as num?)?.toInt(),
          ),
        );

        // Hanya pesan yang diterima oleh pengguna saat ini yang dihitung
        // sebagai pesan belum dibaca.
        if (receiverId == currentUserId && row['sudah_dibaca'] != true) {
          conversation.unreadCount++;
        }
      }

      final result = conversations.values
          .map((conversation) => conversation.toSummary())
          .toList();

      result.sort((a, b) {
        final aTime =
            a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return result;
    } catch (e) {
      throw Exception('Gagal mengambil daftar percakapan: $e');
    }
  }

  /// Berlangganan perubahan pesan untuk Chat Inbox pengguna saat ini.
  ///
  /// Listener pengirim menangkap pesan keluar dan perubahan status baca.
  /// Listener penerima menangkap pesan masuk dan perubahan status baca.
  /// RLS pada tabel chat tetap menjadi lapisan otorisasi di sisi database.
  RealtimeChannel subscribeToInboxChanges({
    required int currentUserId,
    required void Function() onChanged,
  }) {
    final channel = _client.channel('bookcycle_inbox_$currentUserId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'pengirim_id',
            value: currentUserId,
          ),
          callback: (_) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'penerima_id',
            value: currentUserId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();

    return channel;
  }

  /// Menyimpan pesan baru. chat_id dan tanggal_dikirim dibuat oleh database.
  Future<ChatModel> sendMessage({
    required int penerimaId,
    required String pesan,
    int? bukuId,
  }) async {
    try {
      final currentUserId = await getCurrentUserId();
      final messageText = pesan.trim();

      if (messageText.isEmpty) {
        throw Exception('Pesan tidak boleh kosong');
      }
      if (currentUserId == penerimaId) {
        throw Exception('Tidak dapat mengirim pesan ke diri sendiri');
      }

      final data = <String, dynamic>{
        'pengirim_id': currentUserId,
        'penerima_id': penerimaId,
        'pesan': messageText,
      };

      // Informasi buku menjadi konteks pesan, bukan pemisah percakapan.
      if (bukuId != null) {
        data['buku_id'] = bukuId;
      }

      final response = await _client
          .from('chat')
          .insert(data)
          .select()
          .single();

      return ChatModel.fromJson(response);
    } catch (e) {
      throw Exception('Gagal mengirim pesan: $e');
    }
  }

  /// Menandai seluruh pesan masuk dari lawan bicara sebagai sudah dibaca.
  /// Tidak dibatasi buku_id karena thread hanya satu untuk setiap pasangan.
  Future<void> markMessagesAsRead({
    required int otherUserId,
  }) async {
    try {
      final currentUserId = await getCurrentUserId();

      await _client
          .from('chat')
          .update({'sudah_dibaca': true})
          .eq('pengirim_id', otherUserId)
          .eq('penerima_id', currentUserId)
          .eq('sudah_dibaca', false);
    } catch (e) {
      throw Exception('Gagal memperbarui status pesan: $e');
    }
  }

  Map<String, dynamic>? _asJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }
}
