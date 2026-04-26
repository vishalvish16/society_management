import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatSocketProvider.notifier).connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final myId = authState.user?.id ?? '';
    final roomsAsync = ref.watch(chatRoomsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Messages',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'New Message',
            onPressed: () => context.push('/chat/members'),
          ),
        ],
      ),
      body: roomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text('$e', style: const TextStyle(color: Color(0xFF94A3B8))),
              TextButton(
                onPressed: () => ref.read(chatRoomsProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (rooms) {
          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 64, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 16),
                  const Text('No conversations yet',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  const Text('Start a group chat or message a member',
                      style:
                          TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.group_rounded),
                    label: const Text('Join Society Chat'),
                    onPressed: () => _openGroupChat(context),
                  ),
                ],
              ),
            );
          }

          // Split group from direct
          final groupRooms = rooms.where((r) => r.type == 'GROUP').toList();
          final directRooms = rooms.where((r) => r.type == 'DIRECT').toList();

          return RefreshIndicator(
            onRefresh: () => ref.read(chatRoomsProvider.notifier).load(),
            child: ListView(
              children: [
                // Group rooms section
                if (groupRooms.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'SOCIETY',
                    trailing: TextButton(
                      onPressed: () => _openGroupChat(context),
                      child: const Text('Open'),
                    ),
                  ),
                  ...groupRooms.map((r) => _RoomTile(
                        room: r,
                        myId: myId,
                        onTap: () => _openRoom(context, r, myId),
                      )),
                  const Divider(height: 1),
                ],
                // Direct message section
                _SectionHeader(
                  label: 'DIRECT MESSAGES',
                  trailing: IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () => context.push('/chat/members'),
                  ),
                ),
                if (directRooms.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text(
                      'No direct messages. Tap + to start one.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  )
                else
                  ...directRooms.map((r) => _RoomTile(
                        room: r,
                        myId: myId,
                        onTap: () => _openRoom(context, r, myId),
                      )),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        onPressed: () => _openGroupChat(context),
        tooltip: 'Society Chat',
        child: const Icon(Icons.group_rounded),
      ),
    );
  }

  Future<void> _openGroupChat(BuildContext context) async {
    try {
      final room = await ref.read(chatApiProvider).getGroupRoom();
      if (!mounted) return;
      context.push('/chat/room/${room.id}', extra: {
        'title': room.name ?? 'Society Chat',
        'roomType': 'GROUP',
      });
    } catch (_) {}
  }

  void _openRoom(BuildContext context, ChatRoom room, String myId) {
    final title = room.displayName(myId);
    context.push('/chat/room/${room.id}', extra: {
      'title': title,
      'roomType': room.type,
      'otherUser': room.otherUser,
    });
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Widget? trailing;
  const _SectionHeader({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final ChatRoom room;
  final String myId;
  final VoidCallback onTap;

  const _RoomTile({
    required this.room,
    required this.myId,
    required this.onTap,
  });

  String _lastMessagePreview() {
    final lm = room.lastMessage;
    if (lm == null) return 'No messages yet';
    if (lm.isDeleted) return '🚫 Message deleted';
    switch (lm.type) {
      case 'IMAGE':
        return '📷 Photo';
      case 'VOICE':
        return '🎤 Voice message';
      case 'DOCUMENT':
        return '📎 ${lm.attachments.isNotEmpty ? lm.attachments.first.filename : "Document"}';
      default:
        return lm.body ?? '';
    }
  }

  String _timeLabel() {
    final lm = room.lastMessage;
    if (lm == null) return '';
    final now = DateTime.now();
    final d = lm.createdAt;
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return DateFormat('h:mm a').format(d);
    }
    if (now.difference(d).inDays < 7) {
      return DateFormat('EEE').format(d);
    }
    return DateFormat('d/M/yy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final isGroup = room.type == 'GROUP';
    final name = room.displayName(myId);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final hasUnread = room.unreadCount > 0;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: isGroup
            ? const Color(0xFF3B82F6)
            : const Color(0xFF8B5CF6),
        child: isGroup
            ? const Icon(Icons.group_rounded, color: Colors.white, size: 22)
            : Text(
                initial,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
          fontSize: 14,
          color: const Color(0xFF1E293B),
        ),
      ),
      subtitle: Text(
        _lastMessagePreview(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: hasUnread
              ? const Color(0xFF1E293B)
              : const Color(0xFF94A3B8),
          fontWeight:
              hasUnread ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _timeLabel(),
            style: TextStyle(
              fontSize: 11,
              color: hasUnread
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF94A3B8),
            ),
          ),
          if (hasUnread) ...[
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

