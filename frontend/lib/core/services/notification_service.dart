import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../api/dio_client.dart';
import '../router/app_router.dart';

// ── Background handler (must be top-level) ──────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}

// ── Android notification channel ─────────────────────────────────────────────
const _channel = AndroidNotificationChannel(
  'society_high_importance',
  'Society Notifications',
  description: 'Notifications for bills, complaints, visitors and more.',
  importance: Importance.high,
);

final _localNotifications = FlutterLocalNotificationsPlugin();

final notificationServiceProvider = Provider((ref) => NotificationService(ref));

class NotificationService {
  final Ref ref;
  NotificationService(this.ref);

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final _logger = Logger();
  final _client = DioClient();

  Future<void> initialize() async {
    // 1. Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      _logger.w('Notification permission not granted');
    }

    // 2. Create Android high-importance channel
    if (!kIsWeb && Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    // 3. Init flutter_local_notifications (needed to show heads-up on foreground)
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        final route = details.payload;
        if (route != null && route.isNotEmpty) {
          ref.read(appRouterProvider).go(route);
        }
      },
    );

    // 4. Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 5. Foreground messages — show local heads-up notification
    FirebaseMessaging.onMessage.listen((message) {
      _logger.d('Foreground message: ${message.data}');
      _showLocalNotification(message);
    });

    // 6. Background tap — app was in background, user tapped notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _logger.d('Notification tapped (background): ${message.data}');
      _handleNavigation(message.data);
    });

    // 7. Terminated tap — app was killed, launched from notification
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      _logger.d('App launched via notification: ${initial.data}');
      Future.microtask(() => _handleNavigation(initial.data));
    }

    // NOTE: FCM token registration is intentionally NOT done here.
    // Token is sent to backend only after successful login (call registerTokenAfterLogin()).
  }

  /// Call this after a successful login to register the FCM token with the backend.
  /// Safe to call multiple times — silently skips if no token or request fails.
  Future<void> registerTokenAfterLogin() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }
      // Refresh token handler — re-registers whenever FCM rotates the token
      _fcm.onTokenRefresh.listen(_sendTokenToBackend);
    } catch (e) {
      _logger.w('Could not register FCM token: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await _client.dio.post('/notifications/fcm-token', data: {'token': token});
      _logger.i('FCM token registered with backend');
    } catch (e) {
      _logger.w('Failed to send FCM token to backend: $e');
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final route = message.data['route'] as String?;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: route,
    );
  }

  void _handleNavigation(Map<String, dynamic> data) {
    final route = data['route'] as String?;
    if (route != null && route.isNotEmpty) {
      ref.read(appRouterProvider).go(route);
    }
  }
}
