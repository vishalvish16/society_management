import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';

final _membersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await DioClient().dio.get('chat/members', queryParameters: {'limit': 1000});
  final body = res.data;
  final list = (body is Map && body['members'] is List) ? (body['members'] as List) : const [];
  return list.cast<Map<String, dynamic>>();
});

class ChatMemberListScreen extends ConsumerStatefulWidget {
  const ChatMemberListScreen({super.key});

  @override
  ConsumerState<ChatMemberListScreen> createState() => _ChatMemberListScreenState();
}

class _ChatMemberListScreenState extends ConsumerState<ChatMemberListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final myId = authState.user?.id ?? '';
    final membersAsync = ref.watch(_membersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('New Message',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search members…',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),
          Expanded(
            child: membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (members) {
                final filtered = members.where((m) {
                  if (m['id'] == myId) return false;
                  if (_query.isEmpty) return true;
                  final name = (m['name'] as String? ?? '').toLowerCase();
                  final ur = m['unitResidents'] as List?;
                  final unit = ur != null && ur.isNotEmpty
                      ? (ur.first['unit']?['fullCode'] as String? ?? '').toLowerCase()
                      : '';
                  return name.contains(_query) || unit.contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No members found',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (_, i) {
                    final m = filtered[i];
                    final name = m['name'] as String? ?? 'Unknown';
                    final role = m['role'] as String? ?? '';
                    // unit comes as unitResidents[0].unit.fullCode
                    final unitResidents = m['unitResidents'] as List?;
                    final unit = unitResidents != null && unitResidents.isNotEmpty
                        ? (unitResidents.first['unit']?['fullCode'] as String? ?? '')
                        : '';
                    final photo = m['profilePhotoUrl'] as String?;
                    final userId = m['id'] as String;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF8B5CF6),
                        backgroundImage: photo != null
                            ? NetworkImage(
                                AppConstants.uploadUrlFromPath(photo) ?? '')
                            : null,
                        child: photo == null
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              )
                            : null,
                      ),
                      title: Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 14)),
                      subtitle: Text(
                        [if (unit.isNotEmpty) unit, _roleLabel(role)]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                      onTap: () => _startDM(context, userId, name, photo),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startDM(
      BuildContext context, String userId, String name, String? photo) async {
    try {
      final room = await ref.read(chatApiProvider).getOrCreateDM(userId);
      if (!mounted) return;
      context.pushReplacement('/chat/room/${room.id}', extra: {
        'title': name,
        'roomType': 'DIRECT',
        'otherUser': ChatUser(
          id: userId,
          name: name,
          profilePhotoUrl: photo,
          role: '',
        ),
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open chat')),
      );
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'PRAMUKH':
        return 'Chairman';
      case 'SECRETARY':
        return 'Secretary';
      case 'TREASURER':
        return 'Treasurer';
      case 'MEMBER':
        return 'Member';
      case 'RESIDENT':
        return 'Resident';
      case 'WATCHMAN':
        return 'Watchman';
      default:
        return role.replaceAll('_', ' ').toLowerCase();
    }
  }
}
