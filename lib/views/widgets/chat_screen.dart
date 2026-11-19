import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../controllers/chat_controller.dart';
import '../../models/chat_model.dart';
import '../../services/supabase_service.dart';

class ChatScreen extends StatefulWidget {
  final int sellerId;
  final String sellerName;
  final int? bookId;
  final String? bookTitle;

  const ChatScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
    this.bookId,
    this.bookTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Color primaryGreen = Color(0xFF2E7D32);

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  late final ChatController _chatController;
  RealtimeChannel? _channel;
  int? _currentUserId;
  bool _initializing = true;
  bool _initialLoadComplete = false;
  String _realtimeStatus = 'Menghubungkan...';
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    _chatController = context.read<ChatController>();
    _chatController.addListener(_onChatChanged);
    unawaited(_initializeChat());
  }

  Future<void> _initializeChat() async {
    try {
      final currentUserId = await _chatController.getCurrentUserId();
      if (!mounted) return;

      if (currentUserId == widget.sellerId) {
        throw Exception('Kamu tidak dapat mengirim pesan ke diri sendiri');
      }

      setState(() {
        _currentUserId = currentUserId;
        _initializing = false;
        _initializationError = null;
      });
      _initialLoadComplete = false;

      // Pasang listener lebih dahulu agar pesan yang masuk saat pemuatan awal
      // tidak terlewat. Riwayat tetap dimuat dari database sebagai sumber utama.
      _subscribeToRealtime();

      await _chatController.loadConversation(
        otherUserId: widget.sellerId,
      );
      if (!mounted) return;
      _initialLoadComplete = true;

      await _chatController.markMessagesAsRead(
        otherUserId: widget.sellerId,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _initializationError = e.toString();
      });
    }
  }

  void _subscribeToRealtime() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    // Hindari listener ganda ketika pengguna menekan tombol coba lagi.
    final previousChannel = _channel;
    if (previousChannel != null) {
      unawaited(previousChannel.unsubscribe().then<void>((_) {}));
    }
    if (mounted) {
      setState(() => _realtimeStatus = 'Menghubungkan...');
    }

    final channel = SupabaseService.client.channel(
      'bookcycle_chat_${currentUserId}_${widget.sellerId}',
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'pengirim_id',
            value: widget.sellerId,
          ),
          callback: (payload) {
            if (!mounted) return;

            final row = Map<String, dynamic>.from(payload.newRecord);
            final senderId = (row['pengirim_id'] as num?)?.toInt();
            final receiverId = (row['penerima_id'] as num?)?.toInt();

            // Listener INSERT hanya memasukkan pesan yang dikirim lawan bicara
            // kepada akun yang sedang login.
            if (senderId != widget.sellerId || receiverId != currentUserId) {
              return;
            }

            final message = ChatModel.fromJson(row);
            _chatController.addRealtimeMessage(
              message,
              currentUserId: currentUserId,
            );

            // Chat yang sedang terbuka otomatis menandai pesan masuk sebagai
            // terbaca. Perubahan ini akan dikirim kembali melalui event UPDATE
            // ke perangkat pengirim.
            unawaited(
              _chatController
                  .markMessagesAsRead(otherUserId: widget.sellerId)
                  .then<void>((_) {}),
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'pengirim_id',
            value: currentUserId,
          ),
          callback: (payload) {
            if (!mounted) return;

            final row = Map<String, dynamic>.from(payload.newRecord);
            final senderId = (row['pengirim_id'] as num?)?.toInt();
            final receiverId = (row['penerima_id'] as num?)?.toInt();

            // UPDATE pada pesan keluar berarti penerima mengubah status baca.
            if (senderId != currentUserId || receiverId != widget.sellerId) {
              return;
            }

            _chatController.updateRealtimeMessage(
              ChatModel.fromJson(row),
              currentUserId: currentUserId,
            );
          },
        )
        .subscribe((status, _) {
          if (!mounted) return;

          if (status == RealtimeSubscribeStatus.subscribed) {
            setState(() => _realtimeStatus = 'Realtime aktif');

            if (_initialLoadComplete) {
              // Saat reconnect setelah pemuatan awal, sinkronkan pesan yang
              // mungkin masuk ketika perangkat kehilangan koneksi.
              unawaited(_refreshAfterReconnect());
            }
          } else {
            setState(() => _realtimeStatus = 'Menyambungkan ulang...');
          }
        });

    _channel = channel;
  }

  Future<void> _refreshAfterReconnect() async {
    await _chatController.loadConversation(
      otherUserId: widget.sellerId,
      preserveExisting: true,
    );
    if (!mounted) return;
    await _chatController.markMessagesAsRead(
      otherUserId: widget.sellerId,
    );
  }

  void _onChatChanged() {
    if (!mounted || _chatController.messages.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom();
    });
  }

  Future<void> _refreshConversation() async {
    await _chatController.loadConversation(
      otherUserId: widget.sellerId,
    );
    if (!mounted) return;
    await _chatController.markMessagesAsRead(
      otherUserId: widget.sellerId,
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _chatController.isSending) return;

    final sent = await _chatController.sendMessage(
      penerimaId: widget.sellerId,
      pesan: messageText,
      bukuId: widget.bookId,
    );

    if (!mounted) return;

    if (sent) {
      _messageController.clear();
      _scrollToBottom();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _chatController.errorMessage ?? 'Pesan gagal dikirim',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _chatController.removeListener(_onChatChanged);
    _chatController.clearConversation();
    _messageController.dispose();
    _scrollController.dispose();
    final channel = _channel;
    if (channel != null) {
      unawaited(channel.unsubscribe().then<void>((_) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sellerInitial = widget.sellerName.trim().isNotEmpty
        ? widget.sellerName.trim()[0].toUpperCase()
        : 'P';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: primaryGreen,
              radius: 18,
              child: Text(
                sellerInitial,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.sellerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _realtimeStatus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.bookTitle != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.book_outlined, color: primaryGreen, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Konteks buku: ${widget.bookTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _initializing
                ? const Center(child: CircularProgressIndicator())
                : _initializationError != null
                    ? _buildInitializationError()
                    : Consumer<ChatController>(
                        builder: (context, controller, child) {
                          if (controller.isLoading && controller.messages.isEmpty) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (controller.errorMessage != null &&
                              controller.messages.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.wifi_off_outlined,
                                      color: Colors.grey,
                                      size: 42,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Pesan belum dapat dimuat',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      controller.errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton(
                                      onPressed: _refreshConversation,
                                      child: const Text('Muat Ulang'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return RefreshIndicator(
                            onRefresh: _refreshConversation,
                            child: controller.messages.isEmpty
                                ? ListView(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      SizedBox(
                                        height: 300,
                                        child: _buildEmptyConversation(),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    controller: _scrollController,
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(16),
                                    itemCount: controller.messages.length,
                                    itemBuilder: (context, index) {
                                      final message = controller.messages[index];
                                      final isMe =
                                          message.pengirimId == _currentUserId;
                                      return _buildMessageBubble(message, isMe);
                                    },
                                  ),
                          );
                        },
                      ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildInitializationError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Percakapan tidak dapat dibuka',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _initializationError ?? 'Terjadi kesalahan',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _initializing = true;
                  _initializationError = null;
                });
                unawaited(_initializeChat());
              },
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyConversation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada pesan',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Mulai percakapan dengan ${widget.sellerName}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
      child: SafeArea(
        top: false,
        child: Consumer<ChatController>(
          builder: (context, controller, child) {
            final disabled = _initializing ||
                _initializationError != null ||
                controller.isSending;

            return Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !disabled,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Tulis pesan...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: controller.isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: disabled ? null : _sendMessage,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatModel message, bool isMe) {
    final time = message.tanggalDikirim != null
        ? DateFormat('HH:mm').format(message.tanggalDikirim!.toLocal())
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? primaryGreen : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.pesan,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.sudahDibaca ? Icons.done_all : Icons.done,
                      size: 13,
                      color: message.sudahDibaca
                          ? Colors.lightBlueAccent
                          : Colors.white70,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
