import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../providers/dashboard_provider.dart';

/// Dashboard for PRAMUKH, CHAIRMAN, VICE_CHAIRMAN, SECRETARY,
/// ASSISTANT_SECRETARY, TREASURER, ASSISTANT_TREASURER
class AdminDashboard extends ConsumerWidget {
  final String role;
  const AdminDashboard({super.key, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(societyDashboardProvider);
    final isWeb = MediaQuery.of(context).size.width >= 720;

    return statsAsync.when(
      loading: () => const AppLoadingShimmer(itemCount: 6, itemHeight: 90),
      error: (e, _) => _ErrorRetry(
        message: 'Failed to load: $e',
        onRetry: () => ref.invalidate(societyDashboardProvider),
      ),
      data: (stats) => RefreshIndicator(
        onRefresh: () async => ref.refresh(societyDashboardProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          child: isWeb
              ? _WebAdminLayout(stats: stats, role: role)
              : _MobileAdminLayout(stats: stats, role: role),
        ),
      ),
    );
  }
}

// ─── Web layout (wide, two-column) ───────────────────────────────────────────

class _WebAdminLayout extends StatelessWidget {
  final Map<String, dynamic> stats;
  final String role;
  const _WebAdminLayout({required this.stats, required this.role});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI row (4 across)
        _KpiRow(stats: stats, crossAxisCount: 4),
        const SizedBox(height: AppDimensions.xxl),

        // Two-column: billing summary + activity table
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _BillingCard(stats: stats)),
            const SizedBox(width: AppDimensions.lg),
            Expanded(flex: 3, child: _ActivityTable(stats: stats)),
          ],
        ),
        const SizedBox(height: AppDimensions.xxl),

        // Quick actions (row)
        _QuickActionsSection(role: role, isWeb: true),
      ],
    );
  }
}

// ─── Mobile layout (single column) ───────────────────────────────────────────

class _MobileAdminLayout extends StatelessWidget {
  final Map<String, dynamic> stats;
  final String role;
  const _MobileAdminLayout({required this.stats, required this.role});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BillingCard(stats: stats),
        const SizedBox(height: AppDimensions.lg),

        Text('Overview', style: AppTextStyles.h2),
        const SizedBox(height: AppDimensions.md),
        _KpiRow(stats: stats, crossAxisCount: 2),
        const SizedBox(height: AppDimensions.lg),

        Text('Quick Actions', style: AppTextStyles.h2),
        const SizedBox(height: AppDimensions.md),
        _QuickActionsSection(role: role, isWeb: false),
        const SizedBox(height: AppDimensions.lg),

        Text("Today's Activity", style: AppTextStyles.h2),
        const SizedBox(height: AppDimensions.md),
        _ActivityCards(stats: stats),
      ],
    );
  }
}

// ─── Billing summary card ─────────────────────────────────────────────────────

class _BillingCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _BillingCard({required this.stats});

  String _fmt(dynamic v) {
    final n = (v is num) ? v : num.tryParse(v.toString()) ?? 0;
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final pending = stats['billing']?['pendingCount'] ?? 0;
    final collected = stats['billing']?['collectedThisMonth'] ?? 0;
    final vacant = stats['units']?['vacant'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.xl),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pending Bills',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.8))),
                const SizedBox(height: AppDimensions.xs),
                Text('$pending',
                    style: AppTextStyles.amountLarge
                        .copyWith(color: AppColors.textOnPrimary)),
                const SizedBox(height: AppDimensions.xs),
                Text('$vacant vacant units',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.7))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md, vertical: AppDimensions.sm),
            decoration: BoxDecoration(
              color: AppColors.successSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Column(
              children: [
                Text('Collected This Month',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.successText)),
                Text('₹${_fmt(collected)}',
                    style:
                        AppTextStyles.h3.copyWith(color: AppColors.successText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── KPI grid ─────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final Map<String, dynamic> stats;
  final int crossAxisCount;
  const _KpiRow({required this.stats, required this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiItem('Total Units', '${stats['units']?['total'] ?? 0}',
          Icons.apartment_rounded, AppColors.primary),
      _KpiItem('Occupied', '${stats['units']?['occupied'] ?? 0}',
          Icons.people_rounded, AppColors.success),
      _KpiItem('Open Complaints', '${stats['complaints']?['open'] ?? 0}',
          Icons.report_problem_rounded, AppColors.warning),
      _KpiItem('Pending Expenses', '${stats['expenses']?['pendingApproval'] ?? 0}',
          Icons.receipt_long_rounded, AppColors.info),
    ];

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppDimensions.md,
      mainAxisSpacing: AppDimensions.md,
      childAspectRatio: crossAxisCount == 4 ? 2.0 : 1.6,
      children: items
          .map((item) => _KpiCardWidget(item: item))
          .toList(),
    );
  }
}

class _KpiItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiItem(this.label, this.value, this.icon, this.color);
}

class _KpiCardWidget extends StatelessWidget {
  final _KpiItem item;
  const _KpiCardWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.label,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textMuted)),
                Text(item.value, style: AppTextStyles.h2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Activity table (web) ─────────────────────────────────────────────────────

class _ActivityTable extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _ActivityTable({required this.stats});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['Visitors Today', '${stats['visitors']?['today'] ?? 0}',
          Icons.person_pin_circle_rounded, AppColors.primary],
      ['Pending Deliveries', '${stats['deliveries']?['pending'] ?? 0}',
          Icons.local_shipping_rounded, AppColors.info],
      ['Open Complaints', '${stats['complaints']?['open'] ?? 0}',
          Icons.report_problem_rounded, AppColors.warning],
      ['Vacant Units', '${stats['units']?['vacant'] ?? 0}',
          Icons.home_work_rounded, AppColors.textMuted],
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppDimensions.lg,
                AppDimensions.lg, AppDimensions.lg, AppDimensions.md),
            child: Text("Today's Activity", style: AppTextStyles.h2),
          ),
          // Table header
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.lg, vertical: AppDimensions.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text('Metric',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textMuted)),
                ),
                Text('Count',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          ...rows.asMap().entries.map((entry) {
            final i = entry.key;
            final r = entry.value;
            return Container(
              decoration: BoxDecoration(
                border: i > 0
                    ? const Border(
                        top: BorderSide(color: AppColors.border, width: 1))
                    : null,
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.lg, vertical: AppDimensions.md),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (r[3] as Color).withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: Icon(r[2] as IconData,
                        color: r[3] as Color, size: 16),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                      child: Text(r[0] as String,
                          style: AppTextStyles.bodyMedium)),
                  Text(r[1] as String,
                      style: AppTextStyles.h3
                          .copyWith(color: r[3] as Color)),
                ],
              ),
            );
          }),
          const SizedBox(height: AppDimensions.sm),
        ],
      ),
    );
  }
}

// ─── Activity cards (mobile) ──────────────────────────────────────────────────

class _ActivityCards extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _ActivityCards({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiItem('Visitors Today', '${stats['visitors']?['today'] ?? 0}',
          Icons.person_pin_circle_rounded, AppColors.primary),
      _KpiItem('Pending Deliveries', '${stats['deliveries']?['pending'] ?? 0}',
          Icons.local_shipping_rounded, AppColors.info),
    ];

    return Column(
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.sm),
        child: AppCard(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.lg, vertical: AppDimensions.md),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd)),
                child: Icon(item.icon, color: item.color, size: 18),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(child: Text(item.label, style: AppTextStyles.bodyMedium)),
              Text(item.value, style: AppTextStyles.h3),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

// ─── Quick actions ────────────────────────────────────────────────────────────

class _QuickActionsSection extends StatelessWidget {
  final String role;
  final bool isWeb;
  const _QuickActionsSection({required this.role, required this.isWeb});

  List<_ActionItem> _actionsForRole(String role) {
    final base = [
      _ActionItem(Icons.receipt_long_rounded, 'Bills', '/bills'),
      _ActionItem(Icons.money_off_rounded, 'Expenses', '/expenses'),
      _ActionItem(Icons.person_add_rounded, 'Visitor', '/visitors'),
      _ActionItem(Icons.campaign_rounded, 'Notice', '/notices'),
      _ActionItem(Icons.report_problem_rounded, 'Complaints', '/complaints'),
    ];
    // TREASURER and ASSISTANT_TREASURER see billing-focused actions first
    if (role == 'TREASURER' || role == 'ASSISTANT_TREASURER') {
      return [
        _ActionItem(Icons.receipt_long_rounded, 'Bills', '/bills'),
        _ActionItem(Icons.money_off_rounded, 'Expenses', '/expenses'),
        _ActionItem(Icons.bar_chart_rounded, 'Reports', '/reports'),
        _ActionItem(Icons.campaign_rounded, 'Notice', '/notices'),
        _ActionItem(Icons.report_problem_rounded, 'Complaints', '/complaints'),
      ];
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final actions = _actionsForRole(role);

    if (isWeb) {
      return Wrap(
        spacing: AppDimensions.sm,
        runSpacing: AppDimensions.sm,
        children: actions
            .map((a) => _ActionChipWidget(item: a))
            .toList(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: actions.expand((a) => [
          _ActionChipWidget(item: a),
          const SizedBox(width: AppDimensions.sm),
        ]).toList(),
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final String route;
  const _ActionItem(this.icon, this.label, this.route);
}

class _ActionChipWidget extends StatelessWidget {
  final _ActionItem item;
  const _ActionChipWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(item.icon, size: 16, color: AppColors.primary),
      label: Text(item.label,
          style:
              AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
      backgroundColor: AppColors.primarySurface,
      side: BorderSide.none,
      onPressed: () => context.go(item.route),
    );
  }
}

// ─── Error retry widget ───────────────────────────────────────────────────────

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.screenPadding),
      child: AppCard(
        backgroundColor: AppColors.dangerSurface,
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(message,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.dangerText)),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
