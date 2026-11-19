import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_model.dart';
import '../services/chat_service.dart';

class ChatController extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  List<ChatModel> _messages = [];

  // State terpisah untuk halaman Chat Inbox.
  List<ChatConversationSummary> _conversations = [];
  bool _isInboxLoading = false;
  String? _inboxErrorMessage;
  int? _inboxCurrentUserId;
  RealtimeChannel? _inboxChannel;
  Timer? _inboxRefreshTimer;
  bool _isInitializingInbox = false;
  int _inboxGeneration = 0;
  int _inboxFetchGeneration = 0;
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;

  int? _activeOtherUserId;
  int _conversationVersion = 0;

  List<ChatModel> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;

  List<ChatConversationSummary> get conversations =>
      List.unmodifiable(_conversations);
  bool get isInboxLoading => _isInboxLoading;
  String? get inboxErrorMessage => _inboxErrorMessage;
  int? get inboxCurrentUserId => _inboxCurrentUserId;
  int get totalUnreadCount => _conversations.fold<int>(
        0,
        (total, conversation) => total + conversation.unreadCount,
      );

  Future<int> getCurrentUserId() => _chatService.getCurrentUserId();

  /// Memuat Inbox dan memasang satu subscription Realtime untuk pengguna.
  /// Aman dipanggil berulang kali selama HomeScreen masih aktif.
  Future<void> initializeInbox({bool forceRefresh = false}) async {
    if (_isInitializingInbox) return;
    _isInitializingInbox = true;
    final generation = ++_inboxGeneration;

    try {
      final currentUserId = await _chatService.getCurrentUserId();
      if (generation != _inboxGeneration) return;

      if (_inboxCurrentUserId != currentUserId) {
        final oldChannel = _inboxChannel;
        _inboxChannel = null;
        _inboxCurrentUserId = currentUserId;
        _conversations = [];
        if (oldChannel != null) {
          await oldChannel.unsubscribe();
          if (generation != _inboxGeneration) return;
        }
      }

      if (_inboxChannel == null) {
        _inboxChannel = _chatService.subscribeToInboxChanges(
          currentUserId: currentUserId,
          onChanged: _scheduleInboxRefresh,
        );
      }

      await loadInbox(
        showLoading: forceRefresh || _conversations.isEmpty,
      );
    } catch (e) {
      if (generation != _inboxGeneration) return;
      _inboxErrorMessage = e.toString();
      _isInboxLoading = false;
      notifyListeners();
    } finally {
      if (generation == _inboxGeneration) {
        _isInitializingInbox = false;
      }
    }
  }

  /// Mengambil ulang daftar percakapan tanpa mengganggu state chat aktif.
  Future<void> loadInbox({bool showLoading = true}) async {
    final fetchGeneration = ++_inboxFetchGeneration;
    final inboxGeneration = _inboxGeneration;

    if (showLoading) _isInboxLoading = true;
    _inboxErrorMessage = null;
    notifyListeners();

    try {
      final result = await _chatService.getInboxConversations();
      if (fetchGeneration != _inboxFetchGeneration ||
          inboxGeneration != _inboxGeneration) {
        return;
      }
      _conversations = result;
    } catch (e) {
      if (fetchGeneration != _inboxFetchGeneration ||
          inboxGeneration != _inboxGeneration) {
        return;
      }
      _inboxErrorMessage = e.toString();
    } finally {
      if (fetchGeneration == _inboxFetchGeneration &&
          inboxGeneration == _inboxGeneration) {
        _isInboxLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshInbox() => loadInbox(showLoading: false);

  void _scheduleInboxRefresh() {
    if (_inboxChannel == null || _inboxCurrentUserId == null) return;
    _inboxRefreshTimer?.cancel();
    _inboxRefreshTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(loadInbox(showLoading: false));
    });
  }

  /// Menghentikan subscription saat HomeScreen ditutup atau pengguna logout.
  Future<void> stopInboxRealtime() async {
    _inboxGeneration++;
    _inboxFetchGeneration++;
    _isInitializingInbox = false;
    _inboxRefreshTimer?.cancel();
    _inboxRefreshTimer = null;

    final channel = _inboxChannel;
    _inboxChannel = null;
    _inboxCurrentUserId = null;

    if (channel != null) {
      await channel.unsubscribe();
    }
  }

  /// Memuat seluruh riwayat untuk satu pasangan pengguna.
  /// preserveExisting dipakai saat reconnect agar daftar pesan tidak berkedip.
  Future<void> loadConversation({
    required int otherUserId,
    bool preserveExisting = false,
  }) async {
    _activeOtherUserId = otherUserId;
    final version = ++_conversationVersion;

    if (!preserveExisting) {
      _messages = [];
    }
    _isLoading = _messages.isEmpty;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _chatService.getConversation(
        otherUserId: otherUserId,
      );

      if (version != _conversationVersion) return;
      // Gabungkan hasil query dengan event Realtime yang mungkin tiba saat
      // query sedang berjalan, sehingga pesan baru tidak tertimpa snapshot lama.
      _mergeMessages(result);
    } catch (e) {
      if (version != _conversationVersion) return;
      _errorMessage = e.toString();
    } finally {
      if (version == _conversationVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> sendMessage({
    required int penerimaId,
    required String pesan,
    int? bukuId,
  }) async {
    if (_isSending) return false;

    final messageText = pesan.trim();
    if (messageText.isEmpty) {
      _errorMessage = 'Pesan tidak boleh kosong';
      notifyListeners();
      return false;
    }

    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newMessage = await _chatService.sendMessage(
        penerimaId: penerimaId,
        pesan: messageText,
        bukuId: bukuId,
      );

      // Pesan milik pengirim langsung ditambahkan tanpa menunggu event Realtime.
      if (_activeOtherUserId == penerimaId) {
        _insertMessageIfMissing(newMessage);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// Memasukkan pesan INSERT yang diterima melalui Supabase Realtime.
  void addRealtimeMessage(
    ChatModel message, {
    required int currentUserId,
  }) {
    final otherUserId = _activeOtherUserId;
    if (otherUserId == null) return;

    final belongsToConversation =
        (message.pengirimId == currentUserId &&
            message.penerimaId == otherUserId) ||
        (message.pengirimId == otherUserId &&
            message.penerimaId == currentUserId);

    if (!belongsToConversation) return;

    final inserted = _insertMessageIfMissing(message);
    if (inserted) notifyListeners();
  }

  /// Memperbarui indikator baca pada pesan yang menerima event UPDATE.
  void updateRealtimeMessage(
    ChatModel updatedMessage, {
    required int currentUserId,
  }) {
    final otherUserId = _activeOtherUserId;
    if (otherUserId == null || updatedMessage.chatId == null) return;

    final belongsToConversation =
        updatedMessage.pengirimId == currentUserId &&
        updatedMessage.penerimaId == otherUserId;
    if (!belongsToConversation) return;

    final index = _messages.indexWhere(
      (message) => message.chatId == updatedMessage.chatId,
    );
    if (index == -1) {
      // Event UPDATE bisa tiba sebelum respons INSERT selesai ditambahkan.
      if (_insertMessageIfMissing(updatedMessage)) notifyListeners();
      return;
    }

    final currentMessage = _messages[index];
    if (currentMessage.sudahDibaca == updatedMessage.sudahDibaca) return;

    _messages[index] = currentMessage.copyWith(
      sudahDibaca: updatedMessage.sudahDibaca,
    );
    notifyListeners();
  }

  bool _insertMessageIfMissing(ChatModel message) {
    if (message.chatId != null &&
        _messages.any((item) => item.chatId == message.chatId)) {
      return false;
    }

    _messages.add(message);
    _sortMessages();
    return true;
  }

  void _mergeMessages(List<ChatModel> incomingMessages) {
    final merged = <int, ChatModel>{};
    final messagesWithoutId = <ChatModel>[];

    for (final message in incomingMessages) {
      final id = message.chatId;
      if (id == null) {
        messagesWithoutId.add(message);
      } else {
        merged[id] = message;
      }
    }

    // Versi lokal diprioritaskan karena bisa berisi status baca yang lebih baru
    // dari event Realtime ketika query awal masih berjalan.
    for (final message in _messages) {
      final id = message.chatId;
      if (id == null) {
        if (!messagesWithoutId.contains(message)) {
          messagesWithoutId.add(message);
        }
      } else {
        final databaseMessage = merged[id];
        if (databaseMessage == null) {
          merged[id] = message;
        } else {
          merged[id] = message.copyWith(
            sudahDibaca: message.sudahDibaca || databaseMessage.sudahDibaca,
          );
        }
      }
    }

    _messages = [...merged.values, ...messagesWithoutId];
    _sortMessages();
  }

  void _sortMessages() {
    _messages.sort((a, b) {
      final aTime = a.tanggalDikirim ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.tanggalDikirim ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });
  }

  Future<bool> markMessagesAsRead({
    required int otherUserId,
  }) async {
    try {
      await _chatService.markMessagesAsRead(otherUserId: otherUserId);

      var inboxChanged = false;
      _conversations = _conversations.map((conversation) {
        if (conversation.otherUserId == otherUserId &&
            conversation.unreadCount > 0) {
          inboxChanged = true;
          return conversation.copyWith(unreadCount: 0);
        }
        return conversation;
      }).toList();
      if (inboxChanged) notifyListeners();

      if (_activeOtherUserId == otherUserId) {
        final currentUserId = await _chatService.getCurrentUserId();
        var changed = false;

        _messages = _messages.map((message) {
          if (message.pengirimId == otherUserId &&
              message.penerimaId == currentUserId &&
              !message.sudahDibaca) {
            changed = true;
            return message.copyWith(sudahDibaca: true);
          }
          return message;
        }).toList();

        if (changed) notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearConversation() {
    _conversationVersion++;
    _activeOtherUserId = null;
    _messages = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _inboxRefreshTimer?.cancel();
    final channel = _inboxChannel;
    _inboxChannel = null;
    if (channel != null) {
      unawaited(channel.unsubscribe().then<void>((_) {}));
    }
    super.dispose();
  }
}
