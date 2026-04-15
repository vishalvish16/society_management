import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../providers/dashboard_provider.dart';

/// Dashboard for WATCHMAN role — gate-activity focused
class WatchmanDashboard extends ConsumerWidget {
  const WatchmanDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(watchmanDashboardProvider);
    final isWeb = MediaQuery.of(context).size.width >= 720;

    return statsAsync.when(
      loading: () => const AppLoadingShimmer(itemCount: 3, itemHeight: 120),
      error: (e, _) => _ErrorCard(
        message: 'Failed to load: $e',
        onRetry: () => ref.invalidate(watchmanDashboardProvider),
      ),
      data: (stats) => RefreshIndicator(
        onRefresh: () async => ref.refresh(watchmanDashboardProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          child: isWeb
              ? _WebWatchmanLayout(stats: stats)
              : _MobileWatchmanLayout(stats: stats),
        ),
      ),
    );
  }
}

// ─── Web layout ───────────────────────────────────────────────────────────────

class _WebWatchmanLayout extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _WebWatchmanLayout({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 3-stat KPI row
        _WatchmanKpiRow(stats: stats, crossAxisCount: 3),
        const SizedBox(height: AppDimensions.xxl),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _GateActivityTable(stats: stats),
            ),
            const SizedBox(width: AppDimensions.lg),
            Expanded(
              flex: 2,
              child: _WatchmanQuickActions(isWeb: true),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Mobile layout ────────────────────────────────────────────────────────────

class _MobileWatchmanLayout extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _MobileWatchmanLayout({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero stat: visitor scans today
        _WatchmanHeroCard(stats: stats),
        const SizedBox(height: AppDimensions.lg),

        // KPI cards (2 across)
        _WatchmanKpiRow(stats: stats, crossAxisCount: 2),
        const SizedBox(height: AppDimensions.lg),

        Text('Quick Actions', style: AppTextStyles.h2),
        const SizedBox(height: AppDimensions.md),
        _WatchmanQuickActions(isWeb: false),
        const SizedBox(height: AppDimensions.lg),

        Text("Today's Gate Activity", style: AppTextStyles.h2),
        const SizedBox(height: AppDimensions.md),
        _GateActivityCards(stats: stats),
      ],
    );
  }
}

// ─── Hero card (mobile only) ──────────────────────────────────────────────────

class _WatchmanHeroCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _WatchmanHeroCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scans = stats['todayVisitorScans'] ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.xl),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Visitor Scans",
            style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textOnPrimary.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            '$scans',
            style:
                AppTextStyles.amountLarge.copyWith(color: AppColors.textOnPrimary),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'Scanned at entry/exit today',
            style: AppTextStyles.caption.copyWith(
                color: AppColors.textOnPrimary.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

// ─── KPI row ──────────────────────────────────────────────────────────────────

class _WatchmanKpiRow extends StatelessWidget {
  final Map<String, dynamic> stats;
  final int crossAxisCount;
  const _WatchmanKpiRow(
      {required this.stats, required this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    final allItems = [
      _KpiItem(
        'Visitor Scans',
        '${stats['todayVisitorScans'] ?? 0}',
        Icons.person_pin_circle_rounded,
        AppColors.primary,
      ),
      _KpiItem(
        'Pending Deliveries',
        '${stats['pendingDeliveries'] ?? 0}',
        Icons.local_shipping_rounded,
        AppColors.info,
      ),
      _KpiItem(
        'Active Gate Passes',
        '${stats['activeGatePasses'] ?? 0}',
        Icons.badge_rounded,
        AppColors.success,
      ),
    ];

    // On mobile, skip visitor scans (shown in hero); on web show all 3
    final items = crossAxisCount == 2 ? allItems.sublist(1) : allItems;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppDimensions.md,
      mainAxisSpacing: AppDimensions.md,
      childAspectRatio: crossAxisCount == 3 ? 2.2 : 1.6,
      children: items.map((item) => _KpiCardWidget(item: item)).toList(),
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

// ─── Gate activity table (web) ────────────────────────────────────────────────

class _GateActivityTable extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _GateActivityTable({required this.stats});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['Visitor Scans Today', '${stats['todayVisitorScans'] ?? 0}',
          Icons.person_pin_circle_rounded, AppColors.primary],
      ['Pending Deliveries', '${stats['pendingDeliveries'] ?? 0}',
          Icons.local_shipping_rounded, AppColors.info],
      ['Active Gate Passes', '${stats['activeGatePasses'] ?? 0}',
          Icons.badge_rounded, AppColors.success],
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppDimensions.lg,
                AppDimensions.lg, AppDimensions.lg, AppDimensions.md),
            child: Text("Today's Gate Activity", style: AppTextStyles.h2),
          ),
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.lg, vertical: AppDimensions.sm),
            child: Row(
              children: [
                Expanded(
                    child: Text('Metric',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textMuted))),
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
                    child:
                        Icon(r[2] as IconData, color: r[3] as Color, size: 16),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                      child: Text(r[0] as String,
                          style: AppTextStyles.bodyMedium)),
                  Text(r[1] as String,
                      style:
                          AppTextStyles.h3.copyWith(color: r[3] as Color)),
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

// ─── Gate activity cards (mobile) ────────────────────────────────────────────

class _GateActivityCards extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _GateActivityCards({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiItem('Visitor Scans Today', '${stats['todayVisitorScans'] ?? 0}',
          Icons.person_pin_circle_rounded, AppColors.primary),
      _KpiItem('Pending Deliveries', '${stats['pendingDeliveries'] ?? 0}',
          Icons.local_shipping_rounded, AppColors.info),
      _KpiItem('Active Gate Passes', '${stats['activeGatePasses'] ?? 0}',
          Icons.badge_rounded, AppColors.success),
    ];

    return Column(
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.lg,
                      vertical: AppDimensions.md),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMd)),
                        child: Icon(item.icon, color: item.color, size: 18),
                      ),
                      const SizedBox(width: AppDimensions.md),
                      Expanded(
                          child: Text(item.label,
                              style: AppTextStyles.bodyMedium)),
                      Text(item.value, style: AppTextStyles.h3),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ─── Quick actions ────────────────────────────────────────────────────────────

class _WatchmanQuickActions extends StatelessWidget {
  final bool isWeb;
  const _WatchmanQuickActions({required this.isWeb});

  static const _actions = [
    (Icons.qr_code_scanner_rounded, 'Scan Visitor', '/visitors'),
    (Icons.local_shipping_rounded, 'Deliveries', '/deliveries'),
    (Icons.badge_rounded, 'Gate Passes', '/gatepasses'),
    (Icons.person_add_rounded, 'Log Visitor', '/visitors'),
  ];

  @override
  Widget build(BuildContext context) {
    final chips = _actions
        .map((a) => ActionChip(
              avatar: Icon(a.$1, size: 16, color: AppColors.primary),
              label: Text(a.$2,
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.primary)),
              backgroundColor: AppColors.primarySurface,
              side: BorderSide.none,
              onPressed: () => context.go(a.$3),
            ))
        .toList();

    if (isWeb) {
      return AppCard(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Actions', style: AppTextStyles.h2),
            const SizedBox(height: AppDimensions.md),
            Wrap(
                spacing: AppDimensions.sm,
                runSpacing: AppDimensions.sm,
                children: chips),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips
            .expand((c) => [c, const SizedBox(width: AppDimensions.sm)])
            .toList(),
      ),
    );
  }
}

// ─── Error card ───────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

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
                        .copyWith(color: AppColors.dangerText))),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
