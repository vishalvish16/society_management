import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/api/dio_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../models/chat_models.dart';
import '../widgets/chat_input_bar.dart' show ChatFile;

// ── Room list ─────────────────────────────────────────────────────────────

final chatRoomsProvider =
    StateNotifierProvider<ChatRoomsNotifier, AsyncValue<List<ChatRoom>>>(
        (ref) {
  final auth = ref.watch(authProvider);
  return ChatRoomsNotifier(ref, auth);
});

class ChatRoomsNotifier extends StateNotifier<AsyncValue<List<ChatRoom>>> {
  final Ref ref;
  final AuthState _auth;
  final _client = DioClient();

  ChatRoomsNotifier(this.ref, this._auth) : super(const AsyncValue.loading()) {
    if (_auth.isAuthenticated) {
      load();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> load() async {
    if (!_auth.isAuthenticated) return;
    if (!mounted) return;
    
    // If we're already loading, don't show loading spinner again if we have data
    final wasLoading = state is AsyncLoading;
    if (!wasLoading && state is! AsyncData) {
      state = const AsyncValue.loading();
    }
    
    try {
      final res = await _client.dio.get('/chat/rooms');
      if (!mounted) return;
      
      final rooms = (res.data['rooms'] as List)
          .map((r) => ChatRoom.fromJson(r))
          .toList();
      state = AsyncValue.data(rooms);
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void updateUnread(String roomId, int delta) {
    state.whenData((rooms) {
      state = AsyncValue.data(rooms.map((r) {
        if (r.id != roomId) return r;
        return ChatRoom(
          id: r.id, type: r.type, name: r.name, updatedAt: r.updatedAt,
          lastMessage: r.lastMessage, otherUser: r.otherUser, isMuted: r.isMuted,
          unreadCount: (r.unreadCount + delta).clamp(0, 9999),
        );
      }).toList());
    });
  }

  void resetUnread(String roomId) {
    state.whenData((rooms) {
      state = AsyncValue.data(rooms.map((r) {
        if (r.id != roomId) return r;
        return ChatRoom(
          id: r.id, type: r.type, name: r.name, updatedAt: r.updatedAt,
          lastMessage: r.lastMessage, otherUser: r.otherUser, isMuted: r.isMuted,
          unreadCount: 0,
        );
      }).toList());
    });
  }

  void updateMute(String roomId, bool isMuted) {
    state.whenData((rooms) {
      state = AsyncValue.data(rooms.map((r) {
        if (r.id != roomId) return r;
        return ChatRoom(
          id: r.id, type: r.type, name: r.name, updatedAt: r.updatedAt,
          lastMessage: r.lastMessage, otherUser: r.otherUser,
          unreadCount: r.unreadCount, isMuted: isMuted,
        );
      }).toList());
    });
  }
}

// ── Messages for a single room ────────────────────────────────────────────

final chatMessagesProvider = StateNotifierProvider.family<
    ChatMessagesNotifier, AsyncValue<List<ChatMessage>>, String>(
  (ref, roomId) {
    final auth = ref.watch(authProvider);
    return ChatMessagesNotifier(ref, auth, roomId);
  },
);

class ChatMessagesNotifier
    extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final Ref ref;
  final AuthState _auth;
  final String roomId;
  final _client = DioClient();
  bool _hasMore = true;
  bool _loading = false;

  ChatMessagesNotifier(this.ref, this._auth, this.roomId) : super(const AsyncValue.loading()) {
    if (_auth.isAuthenticated) {
      load();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> load({bool refresh = false}) async {
    if (!_auth.isAuthenticated) return;
    if (_loading) return;
    if (!refresh && !_hasMore) return;
    _loading = true;
    
    try {
      if (refresh && mounted) {
        state = const AsyncValue.loading();
      }
      
      final existing =
          refresh ? <ChatMessage>[] : state.asData?.value ?? <ChatMessage>[];
      final before = existing.isNotEmpty ? existing.first.createdAt.toIso8601String() : null;

      final res = await _client.dio.get(
        '/chat/rooms/$roomId/messages',
        queryParameters: {
          'limit': 30,
          if (before != null) 'before': before,
        },
      );
      
      if (!mounted) return;

      final fetched = (res.data['messages'] as List)
          .map((m) => ChatMessage.fromJson(m))
          .toList();
      _hasMore = fetched.length >= 30;
      state = AsyncValue.data([...fetched, ...existing]);
    } catch (e, st) {
      if (mounted && state is! AsyncData) {
        state = AsyncValue.error(e, st);
      }
    } finally {
      _loading = false;
    }
  }

  void addMessage(ChatMessage message) {
    state.whenData((msgs) {
      if (msgs.any((m) => m.id == message.id)) return;
      state = AsyncValue.data([...msgs, message]);
    });
  }

  void markDeleted(String messageId) {
    state.whenData((msgs) {
      state = AsyncValue.data(msgs.map((m) {
        if (m.id != messageId) return m;
        return ChatMessage(
          id: m.id,
          roomId: m.roomId,
          sender: m.sender,
          type: m.type,
          body: null,
          createdAt: m.createdAt,
          isDeleted: true,
          attachments: const [],
        );
      }).toList());
    });
  }
}

// ── Socket.IO service ────────────────────────────────────────────────────

final chatSocketProvider =
    StateNotifierProvider<ChatSocketNotifier, io.Socket?>(
        (ref) => ChatSocketNotifier(ref));

class ChatSocketNotifier extends StateNotifier<io.Socket?> {
  final Ref _ref;
  ChatSocketNotifier(this._ref) : super(null);

  Future<void> connect() async {
    if (state != null) return;
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'accessToken');
    if (token == null) return;

    final serverUrl = AppConstants.apiBaseUrl.replaceAll('/api/', '');
    final socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    socket.onConnect((_) => null);
    socket.on('new_message', (data) {
      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      _ref.read(chatMessagesProvider(msg.roomId).notifier).addMessage(msg);
      _ref.read(chatRoomsProvider.notifier).updateUnread(msg.roomId, 1);
    });
    socket.on('message_deleted', (data) {
      final roomId = data['roomId'] as String?;
      final messageId = data['messageId'] as String?;
      if (roomId != null && messageId != null) {
        _ref.read(chatMessagesProvider(roomId).notifier).markDeleted(messageId);
      }
    });

    socket.connect();
    state = socket;
  }

  void joinRoom(String roomId) => state?.emit('join_room', roomId);
  void leaveRoom(String roomId) => state?.emit('leave_room', roomId);
  void sendTyping(String roomId, bool isTyping) =>
      state?.emit('typing', {'roomId': roomId, 'isTyping': isTyping});

  void disconnect() {
    state?.disconnect();
    state = null;
  }

  @override
  void dispose() {
    state?.disconnect();
    super.dispose();
  }
}

// ── Send message helper ──────────────────────────────────────────────────

class ChatApi {
  final _client = DioClient();

  Future<ChatMessage> sendText(String roomId, String body) async {
    final res = await _client.dio.post(
      '/chat/rooms/$roomId/messages',
      data: {'type': 'TEXT', 'body': body},
    );
    return ChatMessage.fromJson(res.data['message']);
  }

  Future<ChatMessage> sendFiles(
    String roomId,
    List<ChatFile> files, {
    String type = 'IMAGE',
    String? body,
  }) async {
    final formData = FormData.fromMap({
      'type': type,
      if (body != null) 'body': body,
      'files': files
          .map((f) => MultipartFile.fromBytes(f.bytes, filename: f.name))
          .toList(),
    });
    final res = await _client.dio.post(
      '/chat/rooms/$roomId/messages',
      data: formData,
    );
    return ChatMessage.fromJson(res.data['message']);
  }

  Future<ChatMessage> sendVoice(
    String roomId,
    ChatFile audioFile,
    int durationSeconds,
  ) async {
    final formData = FormData.fromMap({
      'type': 'VOICE',
      'duration': durationSeconds.toString(),
      'files': MultipartFile.fromBytes(audioFile.bytes, filename: audioFile.name),
    });
    final res = await _client.dio.post(
      '/chat/rooms/$roomId/messages',
      data: formData,
    );
    return ChatMessage.fromJson(res.data['message']);
  }

  Future<void> markRead(String roomId) async {
    await _client.dio.post('/chat/rooms/$roomId/read');
  }

  Future<bool> getMuteStatus(String roomId) async {
    final res = await _client.dio.get('/chat/rooms/$roomId/mute');
    return res.data['isMuted'] == true;
  }

  Future<bool> setMute(String roomId, bool mute) async {
    final res = await _client.dio.post(
      '/chat/rooms/$roomId/mute',
      data: {'mute': mute},
    );
    return res.data['isMuted'] == true;
  }

  Future<void> deleteMessage(String messageId) async {
    await _client.dio.delete('/chat/messages/$messageId');
  }

  Future<ChatRoom> getOrCreateDM(String userId) async {
    final res = await _client.dio.post('/chat/dm/$userId');
    return ChatRoom.fromJson(res.data['room']);
  }

  Future<ChatRoom> getGroupRoom() async {
    final res = await _client.dio.get('/chat/group');
    return ChatRoom.fromJson(res.data['room']);
  }
}

final chatApiProvider = Provider((_) => ChatApi());
