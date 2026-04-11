import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: Text("Notifications", style: AppTextStyles.titleLarge),
        actions: [TextButton(onPressed: () {}, child: Text("Mark all read",
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary)))],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
        data: (notifications) => notifications.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text("No notifications", style: AppTextStyles.bodyMedium),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                itemBuilder: (ctx, i) {
                  final n = notifications[i];
                  final iconData = n.type == "bill" ? Icons.receipt_long_rounded
                      : n.type == "visitor" ? Icons.person_rounded
                      : Icons.campaign_rounded;
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: n.isRead ? const Color(0xFFE2E8F0) : AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    color: n.isRead ? AppColors.surface : AppColors.primary.withValues(alpha: 0.03),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Icon(iconData, color: AppColors.primary, size: 20),
                      ),
                      title: Text(n.title, style: AppTextStyles.body1),
                      subtitle: Text(n.message, style: AppTextStyles.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Text(n.createdAt.length >= 10 ? n.createdAt.substring(0, 10) : n.createdAt, style: AppTextStyles.caption),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
