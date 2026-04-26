import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/dio_provider.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String targetType;
  final String? targetId;
  final String sentAt;
  final String? sentByName;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.targetType,
    this.targetId,
    required this.sentAt,
    this.sentByName,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        body: j['body'] ?? j['message'] ?? '',
        type: j['type'] ?? 'MANUAL',
        targetType: j['targetType'] ?? 'all',
        targetId: j['targetId'],
        sentAt: j['sentAt'] ?? j['createdAt'] ?? '',
        sentByName: j['sender']?['name'],
      );

  /// Icon based on notification type
  static const Map<String, String> _icons = {
    'BILL_GENERATED': '🧾',
    'COMPLAINT_NEW': '📢',
    'COMPLAINT_UPDATE': '🔧',
    'NOTICE_NEW': '📋',
    'EXPENSE_NEW': '💰',
    'EXPENSE_UPDATE': '✅',
    'VISITOR_CHECKIN': '🚪',
    'DELIVERY_NEW': '📦',
    'MANUAL': '🔔',
  };
  String get emoji => _icons[type] ?? '🔔';

  /// Navigation route derived from notification type for in-app list taps
  static const Map<String, String> _typeRoutes = {
    'BILL':          '/bills',
    'PAYMENT':       '/bills',
    'VISITOR':       '/visitors/pending-approvals',
    'DELIVERY':      '/deliveries',
    'COMPLAINT':     '/complaints',
    'EXPENSE':       '/expenses',
    'ANNOUNCEMENT':  '/notices',
    'PARKING':       '/parking',
  };
  String? get tapRoute => _typeRoutes[type];

  String get relativeTime {
    try {
      final dt = DateTime.parse(sentAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return sentAt.length >= 10 ? sentAt.substring(0, 10) : sentAt;
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// For admin: full notification history
final adminNotificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('notifications', queryParameters: {'limit': 50});
  final data = response.data['data'];
  final list = (data['notifications'] ?? data) as List;
  return list.map((j) => AppNotification.fromJson(j)).toList();
});

/// For members: their own notifications
final myNotificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('notifications/me');
  final list = response.data['data'] as List;
  return list.map((j) => AppNotification.fromJson(j)).toList();
});

/// Unified provider — admins see history, members see their own
final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final auth = ref.watch(authProvider);
  final role = auth.user?.role ?? '';
  final isAdmin = ['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'VICE_CHAIRMAN',
    'TREASURER', 'ASSISTANT_SECRETARY', 'ASSISTANT_TREASURER'].contains(role);

  if (isAdmin) {
    return ref.watch(adminNotificationsProvider.future);
  } else {
    return ref.watch(myNotificationsProvider.future);
  }
});

// ── Send Notification State ────────────────────────────────────────────────────

class SendNotificationState {
  final bool isSending;
  final String? error;
  final bool sent;
  const SendNotificationState({
    this.isSending = false,
    this.error,
    this.sent = false,
  });
  SendNotificationState copyWith({bool? isSending, String? error, bool? sent}) =>
      SendNotificationState(
        isSending: isSending ?? this.isSending,
        error: error,
        sent: sent ?? this.sent,
      );
}

class SendNotificationNotifier
    extends StateNotifier<SendNotificationState> {
  SendNotificationNotifier(this._ref) : super(const SendNotificationState());
  final Ref _ref;

  Future<bool> send({
    required String targetType,
    String? targetId,
    required String title,
    required String body,
    required String type,
    String? route,
  }) async {
    state = state.copyWith(isSending: true, error: null, sent: false);
    try {
      final dio = _ref.read(dioProvider);
      await dio.post('notifications/send', data: {
        'targetType': targetType,
        'targetId': targetId,
        'title': title,
        'body': body,
        'type': type,
        'route': route,
      });
      state = state.copyWith(isSending: false, sent: true);
      _ref.invalidate(adminNotificationsProvider);
      return true;
    } catch (e) {
      final msg = e.toString().contains('message')
          ? e.toString()
          : 'Failed to send notification';
      state = state.copyWith(isSending: false, error: msg);
      return false;
    }
  }
}

final sendNotificationProvider =
    StateNotifierProvider<SendNotificationNotifier, SendNotificationState>(
  (ref) => SendNotificationNotifier(ref),
);
