import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/show_app_dialog.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static const _adminRoles = [
    'PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'VICE_CHAIRMAN',
    'TREASURER', 'ASSISTANT_SECRETARY', 'ASSISTANT_TREASURER'
  ];

  bool _isAdmin(String? role) => _adminRoles.contains(role);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).user?.role;
    final isAdmin = _isAdmin(role);
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Notifications',
            style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.send_rounded, color: AppColors.textOnPrimary),
              tooltip: 'Send Notification',
              onPressed: () => _showSendSheet(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textOnPrimary),
            onPressed: () {
              ref.invalidate(adminNotificationsProvider);
              ref.invalidate(myNotificationsProvider);
            },
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showSendSheet(context, ref),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.send_rounded, color: AppColors.textOnPrimary),
              label: Text('Send',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textOnPrimary)),
            )
          : null,
      body: Column(
        children: [
          // Header banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.screenPadding,
                vertical: AppDimensions.md),
            color: AppColors.primarySurface,
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    color: AppColors.primary, size: 16),
                const SizedBox(width: AppDimensions.sm),
                Text(
                  isAdmin
                      ? 'Society notification history'
                      : 'Notifications sent to you',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
          Expanded(
            child: notificationsAsync.when(
              loading: () => const AppLoadingShimmer(),
              error: (e, _) => Center(
                child: Padding(
                  padding:
                      const EdgeInsets.all(AppDimensions.screenPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 48),
                      const SizedBox(height: AppDimensions.md),
                      Text('Failed to load notifications',
                          style: AppTextStyles.h3),
                      const SizedBox(height: AppDimensions.xs),
                      Text(e.toString(),
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted),
                          textAlign: TextAlign.center),
                      const SizedBox(height: AppDimensions.lg),
                      FilledButton.icon(
                        onPressed: () {
                          ref.invalidate(adminNotificationsProvider);
                          ref.invalidate(myNotificationsProvider);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (notifications) {
                if (notifications.isEmpty) {
                  return const AppEmptyState(
                    emoji: '🔔',
                    title: 'No Notifications',
                    subtitle: 'All clear! Nothing to show yet.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(adminNotificationsProvider);
                    ref.invalidate(myNotificationsProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppDimensions.screenPadding),
                    itemCount: notifications.length,
                    separatorBuilder: (_, i) =>
                        const SizedBox(height: AppDimensions.sm),
                    itemBuilder: (_, i) =>
                        _NotificationCard(n: notifications[i], isAdmin: isAdmin),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSendSheet(BuildContext context, WidgetRef ref) {
    showAppSheet(
      context: context,
      builder: (ctx) => _SendNotificationSheet(),
    );
  }
}

// ── Notification Card ─────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final AppNotification n;
  final bool isAdmin;
  const _NotificationCard({required this.n, required this.isAdmin});

  Color get _typeColor {
    switch (n.type) {
      case 'BILL_GENERATED': return AppColors.primary;
      case 'COMPLAINT_NEW':
      case 'COMPLAINT_UPDATE': return AppColors.warning;
      case 'NOTICE_NEW': return AppColors.success;
      case 'EXPENSE_NEW':
      case 'EXPENSE_UPDATE': return const Color(0xFF7C3AED);
      case 'VISITOR_CHECKIN': return AppColors.info;
      case 'DELIVERY_NEW': return const Color(0xFFEA580C);
      default: return AppColors.primary;
    }
  }

  String get _targetLabel {
    switch (n.targetType) {
      case 'all': return 'Everyone';
      case 'role': return n.targetId ?? 'Role';
      case 'unit': return 'Unit';
      case 'user': return 'Member';
      default: return n.targetType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.md),
      leftBorderColor: _typeColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon bubble
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Center(
              child: Text(n.emoji,
                  style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(n.title,
                          style: AppTextStyles.h3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Text(n.relativeTime,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  n.body,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isAdmin) ...[
                  const SizedBox(height: AppDimensions.xs),
                  Row(
                    children: [
                      _Tag(label: _targetLabel, color: _typeColor),
                      if (n.sentByName != null) ...[
                        const SizedBox(width: AppDimensions.xs),
                        _Tag(label: 'by ${n.sentByName!}',
                            color: AppColors.textMuted),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Send Notification Sheet ───────────────────────────────────────────────────

class _SendNotificationSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SendNotificationSheet> createState() =>
      _SendNotificationSheetState();
}

class _SendNotificationSheetState
    extends ConsumerState<_SendNotificationSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _targetType = 'all';
  String _type = 'MANUAL';

  static const _targetTypes = [
    {'value': 'all', 'label': 'Everyone', 'icon': Icons.groups_rounded},
    {'value': 'role', 'label': 'By Role', 'icon': Icons.manage_accounts_rounded},
    {'value': 'unit', 'label': 'Specific Unit', 'icon': Icons.apartment_rounded},
  ];

  static const _roles = [
    'PRAMUKH', 'SECRETARY', 'TREASURER', 'WATCHMAN',
    'RESIDENT', 'MEMBER',
  ];

  static const _types = [
    {'value': 'MANUAL', 'label': 'General'},
    {'value': 'NOTICE_NEW', 'label': 'Notice'},
    {'value': 'BILL_GENERATED', 'label': 'Bill'},
    {'value': 'COMPLAINT_NEW', 'label': 'Complaint'},
  ];

  String? _selectedRole;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sendNotificationProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.screenPadding,
        AppDimensions.lg,
        AppDimensions.screenPadding,
        MediaQuery.of(context).viewInsets.bottom + AppDimensions.xxxl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text('Send Notification', style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.xs),
            Text('Push a notification to society members',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppDimensions.lg),

            // Send to (target type selector)
            Text('Send To', style: AppTextStyles.labelLarge),
            const SizedBox(height: AppDimensions.sm),
            Row(
              children: _targetTypes.map((t) {
                final selected = _targetType == t['value'];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppDimensions.sm),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _targetType = t['value'] as String;
                        _selectedRole = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppDimensions.md),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : AppColors.background,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(t['icon'] as IconData,
                                color: selected
                                    ? AppColors.textOnPrimary
                                    : AppColors.textMuted,
                                size: 20),
                            const SizedBox(height: 4),
                            Text(t['label'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? AppColors.textOnPrimary
                                      : AppColors.textMuted,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Role picker (only when targetType == 'role')
            if (_targetType == 'role') ...[
              const SizedBox(height: AppDimensions.md),
              Text('Role', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppDimensions.sm),
              Wrap(
                spacing: AppDimensions.sm,
                runSpacing: AppDimensions.sm,
                children: _roles.map((r) {
                  final sel = _selectedRole == r;
                  return ChoiceChip(
                    label: Text(r),
                    selected: sel,
                    onSelected: (_) =>
                        setState(() => _selectedRole = sel ? null : r),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: sel ? AppColors.textOnPrimary : AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: AppDimensions.lg),

            // Type
            Text('Type', style: AppTextStyles.labelLarge),
            const SizedBox(height: AppDimensions.sm),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md,
                    vertical: AppDimensions.md),
              ),
              items: _types
                  .map((t) => DropdownMenuItem(
                      value: t['value'],
                      child: Text(t['label']!)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? 'MANUAL'),
            ),
            const SizedBox(height: AppDimensions.md),

            // Title
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd)),
              ),
            ),
            const SizedBox(height: AppDimensions.md),

            // Body
            TextField(
              controller: _bodyCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Message *',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd)),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),

            // Error
            if (state.error != null) ...[
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.dangerSurface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.danger, size: 16),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(state.error!,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.dangerText)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.md),
            ],

            // Send button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: state.isSending ? null : _send,
                icon: state.isSending
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(
                    state.isSending ? 'Sending…' : 'Send Notification'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message are required')),
      );
      return;
    }
    if (_targetType == 'role' && _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a role')),
      );
      return;
    }

    final ok = await ref.read(sendNotificationProvider.notifier).send(
      targetType: _targetType,
      targetId: _targetType == 'role' ? _selectedRole : null,
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      type: _type,
    );

    if (ok && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification sent successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
