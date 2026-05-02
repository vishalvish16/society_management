import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../dashboard/widgets/dashboard_portal_widgets.dart';
import '../providers/dashboard_provider.dart';

class SADashboardScreen extends ConsumerWidget {
  const SADashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardProvider);
    final recentAsync = ref.watch(recentSocietiesProvider);
    final isWide = MediaQuery.of(context).size.width >= 768;
    final user = ref.watch(authProvider).user;
    final name = (user?.name.trim().isNotEmpty ?? false) ? user!.name.trim() : 'Admin';

    return statsAsync.when(
      loading: () => const AppLoadingShimmer(itemCount: 6, itemHeight: 90),
      error: (e, _) => _ErrorRetry(
        message: 'Failed to load: $e',
        onRetry: () => ref.invalidate(dashboardProvider),
      ),
      data: (stats) => DashboardRefreshWithSearchStack(
        showSearchOverlay: false,
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(recentSocietiesProvider);
        },
        scrollChild: isWide
            ? _WebLayout(stats: stats, recentAsync: recentAsync, name: name)
            : _MobileLayout(stats: stats, recentAsync: recentAsync, name: name),
      ),
    );
  }
}

// ─── Mobile layout ────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final DashboardStats stats;
  final AsyncValue<List<Map<String, dynamic>>> recentAsync;
  final String name;
  const _MobileLayout({required this.stats, required this.recentAsync, required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SAMobileHeader(name: name, stats: stats),
        const SizedBox(height: AppDimensions.md),

        // Quick Actions
        _SectionLabel(title: 'Quick Actions'),
        const SizedBox(height: AppDimensions.md),
        _SAQuickActionsGrid(),
        const SizedBox(height: AppDimensions.lg),

        // Revenue KPIs
        _SectionLabel(title: 'Revenue'),
        const SizedBox(height: AppDimensions.md),
        _RevenueKpiGrid(stats: stats, crossAxisCount: 2),
        const SizedBox(height: AppDimensions.lg),

        // Subscription KPIs
        _SectionLabel(title: 'Subscriptions'),
        const SizedBox(height: AppDimensions.md),
        _SubscriptionKpiGrid(stats: stats, crossAxisCount: 2),
        const SizedBox(height: AppDimensions.lg),

        // Plan distribution
        if (stats.planDistribution.isNotEmpty) ...[
          _SectionLabel(title: 'Plan Distribution'),
          const SizedBox(height: AppDimensions.md),
          _PlanDistributionGrid(stats: stats, crossAxisCount: 2),
          const SizedBox(height: AppDimensions.lg),
        ],

        // Recent Societies
        _SectionLabel(title: 'Recent Societies'),
        const SizedBox(height: AppDimensions.md),
        _RecentSocietiesCard(recentAsync: recentAsync),
        const SizedBox(height: AppDimensions.lg),
      ],
    );
  }
}

// ─── Web layout ───────────────────────────────────────────────────────────────

class _WebLayout extends StatelessWidget {
  final DashboardStats stats;
  final AsyncValue<List<Map<String, dynamic>>> recentAsync;
  final String name;
  const _WebLayout({required this.stats, required this.recentAsync, required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardGreetingHeader(
            title: 'Platform',
            greeting: dashboardGreetingForNow(),
            name: name,
            subtitle: 'Super Admin',
            compact: false,
            enableSearch: false,
            onNotifications: () {},
          ),
          const SizedBox(height: AppDimensions.lg),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(title: 'Revenue Overview'),
                    const SizedBox(height: AppDimensions.md),
                    _RevenueKpiGrid(stats: stats, crossAxisCount: 4),
                    const SizedBox(height: AppDimensions.lg),

                    _SectionLabel(title: 'Subscriptions'),
                    const SizedBox(height: AppDimensions.md),
                    _SubscriptionKpiGrid(stats: stats, crossAxisCount: 4),
                    const SizedBox(height: AppDimensions.lg),

                    if (stats.planDistribution.isNotEmpty) ...[
                      _SectionLabel(title: 'Plan Distribution'),
                      const SizedBox(height: AppDimensions.md),
                      _PlanDistributionGrid(stats: stats, crossAxisCount: 3),
                      const SizedBox(height: AppDimensions.lg),
                    ],

                    _SectionLabel(title: 'Recent Societies'),
                    const SizedBox(height: AppDimensions.md),
                    _RecentSocietiesCard(recentAsync: recentAsync),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.lg),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SAStatsCard(stats: stats),
                    const SizedBox(height: AppDimensions.lg),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quick Actions', style: AppTextStyles.h2),
                          const SizedBox(height: AppDimensions.md),
                          _SAQuickActionsGrid(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── SA Mobile Header ─────────────────────────────────────────────────────────

class _SAMobileHeader extends StatelessWidget {
  final String name;
  final DashboardStats stats;
  const _SAMobileHeader({required this.name, required this.stats});

  String _fmtCurrency(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A5F), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dashboardGreetingForNow(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(name, style: AppTextStyles.h1.copyWith(color: Colors.white)),
                    const SizedBox(height: AppDimensions.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: Text(
                        'Super Admin · Platform',
                        style: AppTextStyles.caption.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // MRR chip
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md, vertical: AppDimensions.sm),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.trending_up_rounded, color: Colors.white, size: 15),
                const SizedBox(width: AppDimensions.xs),
                Text(
                  'MRR: ${_fmtCurrency(stats.mrr)}  ·  ARR: ${_fmtCurrency(stats.arr)}',
                  style: AppTextStyles.labelMedium.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.md),

          // Stat pills
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: [
              _StatPill(icon: Icons.apartment_rounded, label: '${stats.totalSocieties} Societies', color: AppColors.info),
              _StatPill(icon: Icons.check_circle_rounded, label: '${stats.activeSubscriptions} Active', color: AppColors.success),
              _StatPill(icon: Icons.people_rounded, label: '${stats.totalUsers} Users', color: const Color(0xFFF59E0B)),
              _StatPill(icon: Icons.cancel_rounded, label: '${stats.expiredSubscriptions} Expired', color: AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.9))),
        ],
      ),
    );
  }
}

// ─── SA Quick Actions ─────────────────────────────────────────────────────────

class _SAQuickActionsGrid extends StatelessWidget {
  const _SAQuickActionsGrid();

  static const _actions = [
    (Icons.apartment_rounded,       'Societies',     '/sa/societies',     Color(0xFF2563EB)),
    (Icons.card_membership_rounded, 'Plans',         '/sa/plans',         Color(0xFF10B981)),
    (Icons.subscriptions_rounded,   'Subscriptions', '/sa/subscriptions', Color(0xFF8B5CF6)),
    (Icons.description_outlined,    'Estimates',     '/sa/estimates',     Color(0xFFF59E0B)),
    (Icons.settings_rounded,        'Settings',      '/sa/settings',      Color(0xFF64748B)),
    (Icons.tune_rounded,            'Platform',      '/sa/platform-settings', Color(0xFF0EA5E9)),
    (Icons.info_outline_rounded,    'App Info',      '/sa/app-info',      Color(0xFFEC4899)),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppDimensions.sm,
      mainAxisSpacing: AppDimensions.sm,
      childAspectRatio: 0.85,
      children: _actions
          .map((a) => _ActionTile(icon: a.$1, label: a.$2, route: a.$3, color: a.$4))
          .toList(),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  const _ActionTile({required this.icon, required this.label, required this.route, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── KPI grids ────────────────────────────────────────────────────────────────

class _RevenueKpiGrid extends StatelessWidget {
  final DashboardStats stats;
  final int crossAxisCount;
  const _RevenueKpiGrid({required this.stats, required this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final items = [
      _KpiItem('Monthly Revenue (MRR)', fmt.format(stats.mrr), Icons.trending_up_rounded, AppColors.success),
      _KpiItem('Annual Revenue (ARR)', fmt.format(stats.arr), Icons.account_balance_rounded, AppColors.primary),
      _KpiItem('Total Societies', '${stats.totalSocieties}', Icons.apartment_rounded, const Color(0xFF8B5CF6)),
      _KpiItem('Total Users', '${stats.totalUsers}', Icons.people_rounded, const Color(0xFFF59E0B)),
    ];
    return _KpiGrid(items: items, crossAxisCount: crossAxisCount);
  }
}

class _SubscriptionKpiGrid extends StatelessWidget {
  final DashboardStats stats;
  final int crossAxisCount;
  const _SubscriptionKpiGrid({required this.stats, required this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiItem('Active Subscriptions', '${stats.activeSubscriptions}', Icons.check_circle_rounded, AppColors.success),
      _KpiItem('Trial Subscriptions', '${stats.trialSubscriptions}', Icons.hourglass_bottom_rounded, const Color(0xFF3B82F6)),
      _KpiItem('Expired', '${stats.expiredSubscriptions}', Icons.cancel_rounded, AppColors.danger),
      _KpiItem('Total Units', '${stats.totalUnits}', Icons.home_rounded, const Color(0xFF06B6D4)),
    ];
    return _KpiGrid(items: items, crossAxisCount: crossAxisCount);
  }
}

class _PlanDistributionGrid extends StatelessWidget {
  final DashboardStats stats;
  final int crossAxisCount;
  const _PlanDistributionGrid({required this.stats, required this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    final items = stats.planDistribution.map((pd) {
      final color = pd.planCode == 'BASIC'
          ? const Color(0xFF94A3B8)
          : pd.planCode == 'STANDARD'
              ? const Color(0xFF3B82F6)
              : const Color(0xFF8B5CF6);
      return _KpiItem('${pd.planName} Plan', '${pd.count} societies', Icons.card_membership_rounded, color);
    }).toList();
    return _KpiGrid(items: items, crossAxisCount: crossAxisCount);
  }
}

class _KpiItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiItem(this.label, this.value, this.icon, this.color);
}

class _KpiGrid extends StatelessWidget {
  final List<_KpiItem> items;
  final int crossAxisCount;
  const _KpiGrid({required this.items, required this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppDimensions.md,
      mainAxisSpacing: AppDimensions.md,
      childAspectRatio: crossAxisCount == 4 ? 2.0 : 1.6,
      children: items.map((item) => _KpiCard(item: item)).toList(),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final _KpiItem item;
  const _KpiCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: FittedBox(
        fit: BoxFit.scaleDown,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
                Text(item.value, style: AppTextStyles.h2),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SA Stats Card (web sidebar) ─────────────────────────────────────────────

class _SAStatsCard extends StatelessWidget {
  final DashboardStats stats;
  const _SAStatsCard({required this.stats});

  String _fmtCurrency(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.xl),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Platform Overview',
              style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textOnPrimary.withValues(alpha: 0.8))),
          const SizedBox(height: AppDimensions.sm),
          Text(_fmtCurrency(stats.mrr),
              style: AppTextStyles.amountLarge.copyWith(color: AppColors.textOnPrimary)),
          Text('Monthly Revenue',
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.textOnPrimary.withValues(alpha: 0.7))),
          const SizedBox(height: AppDimensions.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.sm),
            decoration: BoxDecoration(
              color: AppColors.successSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Annual Revenue', style: AppTextStyles.labelSmall.copyWith(color: AppColors.successText)),
                Text(_fmtCurrency(stats.arr), style: AppTextStyles.h3.copyWith(color: AppColors.successText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recent Societies ─────────────────────────────────────────────────────────

class _RecentSocietiesCard extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> recentAsync;
  const _RecentSocietiesCard({required this.recentAsync});

  @override
  Widget build(BuildContext context) {
    return recentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorCard(message: 'Failed to load recent societies'),
      data: (societies) => AppCard(
        padding: EdgeInsets.zero,
        child: societies.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(AppDimensions.xxxl),
                child: Center(
                  child: Text('No societies yet',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
                ),
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 700),
                  child: DataTable(
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: [
                      DataColumn(label: Text('Name', style: AppTextStyles.labelLarge)),
                      DataColumn(label: Text('Plan', style: AppTextStyles.labelLarge)),
                      DataColumn(label: Text('Status', style: AppTextStyles.labelLarge)),
                      DataColumn(label: Text('Units', style: AppTextStyles.labelLarge)),
                      DataColumn(label: Text('Users', style: AppTextStyles.labelLarge)),
                      DataColumn(label: Text('Expiry', style: AppTextStyles.labelLarge)),
                    ],
                    rows: societies.map<DataRow>((s) {
                      final plan = s['plan'];
                      final planName = plan?['displayName'] ?? plan?['name'] ?? 'No Plan';
                      final status = s['status']?.toString().toUpperCase() ?? '-';
                      final counts = s['_count'] ?? {};
                      final isActive = status == 'ACTIVE';

                      return DataRow(cells: [
                        DataCell(SizedBox(
                          width: 150,
                          child: Text(s['name'] ?? '',
                              style: AppTextStyles.bodyMedium,
                              overflow: TextOverflow.ellipsis),
                        )),
                        DataCell(_PlanBadge(planName: planName)),
                        DataCell(_StatusBadge(status: isActive ? 'ACTIVE' : status)),
                        DataCell(Text('${counts['units'] ?? 0}')),
                        DataCell(Text('${counts['users'] ?? 0}')),
                        DataCell(Text(
                          s['planRenewalDate'] != null
                              ? DateFormat('dd MMM yy').format(DateTime.parse(s['planRenewalDate']))
                              : '-',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.h2);
  }
}

// ─── Badges ───────────────────────────────────────────────────────────────────

class _PlanBadge extends StatelessWidget {
  final String planName;
  const _PlanBadge({required this.planName});

  @override
  Widget build(BuildContext context) {
    final color = planName.toLowerCase().contains('premium')
        ? const Color(0xFF8B5CF6)
        : planName.toLowerCase().contains('standard')
            ? const Color(0xFF3B82F6)
            : const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(planName, style: AppTextStyles.labelMedium.copyWith(color: color)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'ACTIVE' => AppColors.success,
      'TRIAL' => AppColors.info,
      'EXPIRED' || 'INACTIVE' => AppColors.danger,
      'SUSPENDED' => AppColors.warning,
      _ => AppColors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status, style: AppTextStyles.labelMedium.copyWith(color: color)),
    );
  }
}

// ─── Error widgets ────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.dangerSurface,
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger),
          const SizedBox(width: AppDimensions.md),
          Expanded(child: Text(message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText))),
        ],
      ),
    );
  }
}

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
            Expanded(child: Text(message,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText))),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
