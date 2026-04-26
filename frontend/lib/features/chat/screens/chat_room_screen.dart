import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input_bar.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String title;
  final String roomType; // GROUP or DIRECT
  final ChatUser? otherUser;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.title,
    required this.roomType,
    this.otherUser,
  });

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;
  String? _typingUserId;
  bool _isMuted = false;
  bool _muteLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
    _scrollCtrl.addListener(_onScroll);
  }

  Future<void> _init() async {
    ref.read(chatSocketProvider.notifier).joinRoom(widget.roomId);
    await ref.read(chatMessagesProvider(widget.roomId).notifier).load(refresh: true);
    await ref.read(chatApiProvider).markRead(widget.roomId);
    ref.read(chatRoomsProvider.notifier).resetUnread(widget.roomId);
    _scrollToBottom();

    // Load mute status — first try from room list cache, then fetch from API
    final rooms = ref.read(chatRoomsProvider).asData?.value ?? [];
    final cached = rooms.where((r) => r.id == widget.roomId).firstOrNull;
    if (cached != null) {
      if (mounted) setState(() => _isMuted = cached.isMuted);
    } else {
      try {
        final muted = await ref.read(chatApiProvider).getMuteStatus(widget.roomId);
        if (mounted) setState(() => _isMuted = muted);
      } catch (_) {}
    }

    final socket = ref.read(chatSocketProvider);
    socket?.on('user_typing', (data) {
      final uid = data['userId'] as String?;
      final typing = data['isTyping'] as bool? ?? false;
      if (mounted) setState(() => _typingUserId = typing ? uid : null);
    });
  }

  Future<void> _toggleMute() async {
    if (_muteLoading) return;
    setState(() => _muteLoading = true);
    try {
      final newMuted = await ref.read(chatApiProvider).setMute(widget.roomId, !_isMuted);
      if (mounted) setState(() => _isMuted = newMuted);
      ref.read(chatRoomsProvider.notifier).updateMute(widget.roomId, newMuted);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newMuted
              ? 'Notifications muted for this chat'
              : 'Notifications unmuted'),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _muteLoading = false);
    }
  }

  @override
  void dispose() {
    ref.read(chatSocketProvider.notifier).leaveRoom(widget.roomId);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels <= 80) {
      ref.read(chatMessagesProvider(widget.roomId).notifier).load();
    }
  }

  void _scrollToBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (animate) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendText(String text) async {
    try {
      final msg = await ref.read(chatApiProvider).sendText(widget.roomId, text);
      ref.read(chatMessagesProvider(widget.roomId).notifier).addMessage(msg);
      _scrollToBottom(animate: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    }
  }

  Future<void> _sendFiles(List<ChatFile> files, String type) async {
    try {
      final msg = await ref
          .read(chatApiProvider)
          .sendFiles(widget.roomId, files, type: type);
      ref.read(chatMessagesProvider(widget.roomId).notifier).addMessage(msg);
      _scrollToBottom(animate: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send file')),
        );
      }
    }
  }

  Future<void> _sendVoice(ChatFile audio, int secs) async {
    try {
      final msg = await ref
          .read(chatApiProvider)
          .sendVoice(widget.roomId, audio, secs);
      ref.read(chatMessagesProvider(widget.roomId).notifier).addMessage(msg);
      _scrollToBottom(animate: true);
    } catch (_) {}
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await ref.read(chatApiProvider).deleteMessage(messageId);
      ref.read(chatMessagesProvider(widget.roomId).notifier).markDeleted(messageId);
    } catch (_) {}
  }

  void _onTypingChanged(bool typing) {
    if (typing == _isTyping) return;
    _isTyping = typing;
    ref
        .read(chatSocketProvider.notifier)
        .sendTyping(widget.roomId, typing);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final myId = authState.user?.id ?? '';
    final messagesAsync = ref.watch(chatMessagesProvider(widget.roomId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            if (widget.roomType == 'DIRECT' && widget.otherUser != null)
              CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFF3B82F6),
                backgroundImage: widget.otherUser?.profilePhotoUrl != null
                    ? NetworkImage(
                        AppConstants.uploadUrlFromPath(
                                widget.otherUser!.profilePhotoUrl) ??
                            '')
                    : null,
                child: widget.otherUser?.profilePhotoUrl == null
                    ? Text(
                        widget.title.isNotEmpty
                            ? widget.title[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              )
            else
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.group_rounded,
                    color: Color(0xFF93C5FD), size: 18),
              ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                if (_typingUserId != null)
                  const Text('typing…',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF93C5FD))),
              ],
            ),
          ],
        ),
        actions: [
          _muteLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                )
              : Tooltip(
                  message: _isMuted ? 'Unmute notifications' : 'Mute notifications',
                  child: IconButton(
                    icon: Icon(
                      _isMuted
                          ? Icons.notifications_off_rounded
                          : Icons.notifications_active_rounded,
                      color: _isMuted
                          ? const Color(0xFF94A3B8)
                          : Colors.white,
                    ),
                    onPressed: _toggleMute,
                  ),
                ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say hi! 👋',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                  );
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMine = msg.sender.id == myId;
                    final showDateDivider = i == 0 ||
                        !_sameDay(
                            messages[i - 1].createdAt, msg.createdAt);

                    return Column(
                      children: [
                        if (showDateDivider) _DateDivider(msg.createdAt),
                        MessageBubble(
                          message: msg,
                          isMine: isMine,
                          onDelete: isMine
                              ? () => _deleteMessage(msg.id)
                              : null,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          ChatInputBar(
            onSendText: _sendText,
            onSendFiles: _sendFiles,
            onSendVoice: _sendVoice,
            onTyping: _onTypingChanged,
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider(this.date);

  String _label() {
    final now = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _label(),
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
        ],
      ),
    );
  }
}
