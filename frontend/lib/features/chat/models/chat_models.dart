class ChatAttachment {
  final String id;
  final String url;
  final String filename;
  final String mimeType;
  final int size;

  const ChatAttachment({
    required this.id,
    required this.url,
    required this.filename,
    required this.mimeType,
    required this.size,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> j) => ChatAttachment(
        id: j['id'],
        url: j['url'],
        filename: j['filename'],
        mimeType: j['mimeType'],
        size: j['size'],
      );

  bool get isImage => mimeType.startsWith('image/');
  bool get isAudio =>
      mimeType.startsWith('audio/') ||
      ['mp3', 'm4a', 'ogg', 'wav', 'webm', 'aac']
          .any((e) => filename.toLowerCase().endsWith('.$e'));
}

class ChatSender {
  final String id;
  final String name;
  final String? profilePhotoUrl;
  final String role;

  const ChatSender({
    required this.id,
    required this.name,
    this.profilePhotoUrl,
    required this.role,
  });

  factory ChatSender.fromJson(Map<String, dynamic> j) => ChatSender(
        id: j['id'] ?? '',
        name: j['name'] ?? 'Unknown',
        profilePhotoUrl: j['profilePhotoUrl'],
        role: j['role'] ?? '',
      );
}

class ChatMessage {
  final String id;
  final String roomId;
  final ChatSender sender;
  final String type; // TEXT IMAGE DOCUMENT VOICE
  final String? body;
  final int? duration;
  final DateTime createdAt;
  final bool isDeleted;
  final List<ChatAttachment> attachments;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.sender,
    required this.type,
    this.body,
    this.duration,
    required this.createdAt,
    this.isDeleted = false,
    this.attachments = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] ?? '',
        roomId: j['roomId'] ?? '',
        sender: j['sender'] != null
            ? ChatSender.fromJson(j['sender'])
            : const ChatSender(id: '', name: 'Unknown', role: ''),
        type: j['type'] ?? 'TEXT',
        body: j['body'],
        duration: j['duration'],
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt']).toLocal()
            : DateTime.now(),
        isDeleted: j['deletedAt'] != null,
        attachments: (j['attachments'] as List? ?? [])
            .map((a) => ChatAttachment.fromJson(a))
            .toList(),
      );
}

class ChatUser {
  final String id;
  final String name;
  final String? profilePhotoUrl;
  final String role;

  const ChatUser({
    required this.id,
    required this.name,
    this.profilePhotoUrl,
    required this.role,
  });

  factory ChatUser.fromJson(Map<String, dynamic> j) => ChatUser(
        id: j['id'] ?? '',
        name: j['name'] ?? 'Unknown',
        profilePhotoUrl: j['profilePhotoUrl'],
        role: j['role'] ?? '',
      );
}

class ChatRoom {
  final String id;
  final String type; // GROUP DIRECT
  final String? name;
  final DateTime updatedAt;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final ChatUser? otherUser; // for DIRECT rooms
  final bool isMuted;

  const ChatRoom({
    required this.id,
    required this.type,
    this.name,
    required this.updatedAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.otherUser,
    this.isMuted = false,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> j) => ChatRoom(
        id: j['id'] ?? '',
        type: j['type'] ?? 'GROUP',
        name: j['name'],
        updatedAt: j['updatedAt'] != null
            ? DateTime.parse(j['updatedAt']).toLocal()
            : DateTime.now(),
        lastMessage: j['lastMessage'] != null
            ? ChatMessage.fromJson(j['lastMessage'])
            : null,
        unreadCount: j['unreadCount'] ?? 0,
        otherUser:
            j['otherUser'] != null ? ChatUser.fromJson(j['otherUser']) : null,
        isMuted: j['isMuted'] == true,
      );

  String displayName(String currentUserId) {
    if (type == 'GROUP') return name ?? 'Society Chat';
    return otherUser?.name ?? 'Chat';
  }
}
