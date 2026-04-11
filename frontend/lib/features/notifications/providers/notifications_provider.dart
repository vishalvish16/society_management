import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final String createdAt;
  final bool isRead;

  const AppNotification({required this.id, required this.title,
    required this.message, required this.type, required this.createdAt,
    this.isRead = false});

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] ?? '',
    title: j['title'] ?? '',
    message: j['message'] ?? '',
    type: j['type'] ?? 'manual',
    createdAt: j['createdAt'] ?? '',
    isRead: j['isRead'] ?? false,
  );
}

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 500));
  return [
    AppNotification(id: '1', title: 'Bill Generated', message: 'Maintenance bill for April has been generated', type: 'bill', createdAt: '2024-04-01', isRead: false),
    AppNotification(id: '2', title: 'Visitor Arrived', message: 'Your visitor Ramesh is at the gate', type: 'visitor', createdAt: '2024-04-01', isRead: true),
    AppNotification(id: '3', title: 'Notice Posted', message: 'Society meeting scheduled for 5th April', type: 'announcement', createdAt: '2024-03-31', isRead: true),
  ];
});
