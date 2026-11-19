import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/chat_controller.dart';
import '../../services/chat_service.dart';
import '../widgets/chat_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  static const Color _green = Color(0xFF087F3E);
  static const Color _navy = Color(0xFF092B8F);

  final TextEditingController _searchController = TextEditingController();
  late final ChatController _chatController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _chatController = context.read<ChatController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_chatController.initializeInbox());
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    unawaited(_chatController.stopInboxRealtime());
    super.dispose();
  }

  List<ChatConversationSummary> _filterConversations(
    List<ChatConversationSummary> conversations,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return conversations;

    return conversations.where((conversation) {
      return conversation.otherUserName.toLowerCase().contains(query) ||
          conversation.lastMessage.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openConversation(
    ChatConversationSummary conversation,
  ) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          sellerId: conversation.otherUserId,
          sellerName: conversation.otherUserName,
          bookId: conversation.lastBookId,
        ),
      ),
    );

    if (!mounted) return;
    await _chatController.refreshInbox();
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '';

    final local = value.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;

    if (isToday) return DateFormat('HH:mm').format(local);

    final isSameYear = local.year == now.year;
    return isSameYear
        ? DateFormat('dd MMM').format(local)
        : DateFormat('dd/MM/yy').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chat',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Percakapan dengan pembeli dan penjual.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau isi pesan...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: _green),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Hapus pencarian',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.close, size: 18),
                          ),
                    filled: true,
                    fillColor: const Color(0xFFF3F6F5),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<ChatController>(
              builder: (context, controller, child) {
                final conversations =
                    _filterConversations(controller.conversations);

                if (controller.isInboxLoading &&
                    controller.conversations.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: _green),
                  );
                }

                if (controller.inboxErrorMessage != null &&
                    controller.conversations.isEmpty) {
                  return _buildScrollableMessage(
                    icon: Icons.wifi_off_rounded,
                    title: 'Chat belum dapat dimuat',
                    message: controller.inboxErrorMessage!,
                    actionLabel: 'Coba lagi',
                    onAction: () =>
                        unawaited(controller.initializeInbox(forceRefresh: true)),
                  );
                }

                if (controller.conversations.isEmpty) {
                  return _buildScrollableMessage(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Belum ada percakapan',
                    message:
                        'Mulai percakapan melalui tombol Chat pada halaman detail buku.',
                  );
                }

                if (conversations.isEmpty) {
                  return _buildScrollableMessage(
                    icon: Icons.search_off_rounded,
                    title: 'Percakapan tidak ditemukan',
                    message: 'Coba gunakan kata kunci pencarian yang lain.',
                  );
                }

                return RefreshIndicator(
                  color: _green,
                  onRefresh: controller.refreshInbox,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                    itemCount: conversations.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 76,
                      endIndent: 8,
                      color: Color(0xFFE9EEEC),
                    ),
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      final isUnread = conversation.unreadCount > 0;
                      final isLastMessageMine =
                          conversation.lastMessageSenderId ==
                              controller.inboxCurrentUserId;
                      final preview = conversation.lastMessage.isEmpty
                          ? 'Belum ada pesan'
                          : '${isLastMessageMine ? 'Anda: ' : ''}${conversation.lastMessage}';

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openConversation(conversation),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor: const Color(0xFFE2F1E8),
                                  child: Text(
                                    _initials(conversation.otherUserName),
                                    style: const TextStyle(
                                      color: _green,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        conversation.otherUserName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _navy,
                                          fontSize: 14,
                                          fontWeight: isUnread
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        preview,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isUnread
                                              ? const Color(0xFF34443B)
                                              : Colors.grey[600],
                                          fontSize: 12,
                                          fontWeight: isUnread
                                              ? FontWeight.w700
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _formatTime(conversation.lastMessageAt),
                                      style: TextStyle(
                                        color: isUnread ? _green : Colors.grey,
                                        fontSize: 10,
                                        fontWeight: isUnread
                                            ? FontWeight.w700
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    if (isUnread)
                                      Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: const BoxDecoration(
                                          color: _green,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          conversation.unreadCount > 99
                                              ? '99+'
                                              : '${conversation.unreadCount}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'BC';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }

  Widget _buildScrollableMessage({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return RefreshIndicator(
      color: _green,
      onRefresh: _chatController.refreshInbox,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        children: [
          SizedBox(
            height: 320,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.grey[350], size: 58),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: onAction,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _green,
                        side: const BorderSide(color: _green),
                      ),
                      child: Text(actionLabel),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
