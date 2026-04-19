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
import '../../bills/providers/my_pending_bills_provider.dart';
import '../../bills/screens/upi_pay_sheet.dart';
import '../../donations/screens/donate_sheet.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_portal_widgets.dart';

/// Dashboard for PRAMUKH, CHAIRMAN, VICE_CHAIRMAN, SECRETARY,
/// ASSISTANT_SECRETARY, TREASURER, ASSISTANT_TREASURER
class AdminDashboard extends ConsumerStatefulWidget {
  final String role;
  const AdminDashboard({super.key, required this.role});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myPendingBillsProvider.notifier).fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(societyDashboardProvider);
    final pendingBills = ref.watch(myPendingBillsProvider);
    final user = ref.watch(authProvider).user;
    final isWeb = MediaQuery.of(context).size.width >= 720;

    return statsAsync.when(
      loading: () => const AppLoadingShimmer(itemCount: 6, itemHeight: 90),
      error: (e, _) => _ErrorRetry(
        message: 'Failed to load: $e',
        onRetry: () => ref.invalidate(societyDashboardProvider),
      ),
      data: (stats) => DashboardRefreshWithSearchStack(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(societyDashboardProvider.future),
            ref.read(myPendingBillsProvider.notifier).fetch(),
          ]);
        },
        scrollChild: isWeb
            ? _WebAdminLayout(
                stats: stats,
                role: widget.role,
                pendingBills: pendingBills,
                user: user,
              )
            : _MobileAdminLayout(
                stats: stats,
                role: widget.role,
                pendingBills: pendingBills,
                user: user,
              ),
      ),
    );
  }
}

// ─── Web layout (wide, two-column) ───────────────────────────────────────────

class _WebAdminLayout extends StatelessWidget {
  final Map<String, dynamic> stats;
  final String role;
  final AsyncValue<List<Map<String, dynamic>>> pendingBills;
  final dynamic user;
  const _WebAdminLayout({
    required this.stats,
    required this.role,
    required this.pendingBills,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final name = (user?.name?.toString().trim().isNotEmpty ?? false)
        ? user.name.toString().trim()
        : 'Admin';
    // UserModel has societyId/unitCode but no societyName; avoid dynamic noSuchMethod.
    final unitCode = user?.unitCode?.toString().trim();
    final subtitle = (unitCode != null && unitCode.isNotEmpty)
        ? 'Unit $unitCode'
        : dashboardRoleSubtitle(role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardGreetingHeader(
          title: 'Dashboard',
          greeting: dashboardGreetingForNow(),
          name: name,
          subtitle: subtitle,
          compact: false,
          onNotifications: () => context.go('/notifications'),
        ),
        const SizedBox(height: AppDimensions.lg),

        // Personal pending bills banner (only if user has a unit)
        if (user?.unitCode != null) ...[
          _AdminPendingBillsBanner(pendingBills: pendingBills),
          const SizedBox(height: AppDimensions.md),
        ],
        _AdminCampaignBanner(stats: stats),
        const SizedBox(height: AppDimensions.md),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left main column
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    title: 'Overview',
                    onViewAll: () => context.go('/reports/balance'),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  _KpiRow(stats: stats, crossAxisCount: 4),
                  const SizedBox(height: AppDimensions.lg),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _BillingCard(stats: stats)),
                      const SizedBox(width: AppDimensions.lg),
                      Expanded(
                        flex: 4,
                        child: DashboardTrendPanel(
                          title: 'Collection Trend',
                          subtitle: 'Last 6 months',
                          color: AppColors.primary,
                          data: trendValuesFromDashboardStats(stats, key: 'collections'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.lg),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: DashboardTrendPanel(
                          title: 'Attendance / Active',
                          subtitle: 'Daily activity',
                          color: AppColors.info,
                          data: trendValuesFromDashboardStats(stats, key: 'visitors'),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.lg),
                      Expanded(
                        flex: 3,
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _CardTitleRow(
                                title: 'Quick Actions',
                                trailing: TextButton(
                                  onPressed: () => context.go('/settings'),
                                  child: const Text('Manage'),
                                ),
                              ),
                              const SizedBox(height: AppDimensions.md),
                              _QuickAccessGrid(role: role),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.lg),
            // Right column
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CardTitleRow(
                          title: "Today's Activity",
                          trailing: TextButton(
                            onPressed: () => context.go('/visitors'),
                            child: const Text('View all'),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.sm),
                        _ActivityTable(stats: stats),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CardTitleRow(
                          title: 'Recent Activity',
                          trailing: TextButton(
                            onPressed: () => context.go('/notifications'),
                            child: const Text('View all'),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.sm),
                        _RecentActivityList(stats: stats),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  _SectionHeader(
                    title: 'Shortcuts',
                    onViewAll: () => context.go('/dashboard'),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  _QuickActionsSection(role: role, isWeb: true),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Mobile layout (single column) ───────────────────────────────────────────

class _MobileAdminLayout extends ConsumerWidget {
  final Map<String, dynamic> stats;
  final String role;
  final AsyncValue<List<Map<String, dynamic>>> pendingBills;
  final dynamic user;
  const _MobileAdminLayout({
    required this.stats,
    required this.role,
    required this.pendingBills,
    required this.user,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = (user?.name?.toString().trim().isNotEmpty ?? false)
        ? user.name.toString().trim()
        : 'Admin';
    final unitCode = user?.unitCode?.toString().trim();
    final subtitle = (unitCode != null && unitCode.isNotEmpty)
        ? 'Unit $unitCode'
        : dashboardRoleSubtitle(role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardGreetingHeader(
          title: 'Dashboard',
          greeting: dashboardGreetingForNow(),
          name: name,
          subtitle: subtitle,
          compact: true,
          onNotifications: () => context.go('/notifications'),
        ),
        const SizedBox(height: AppDimensions.md),
        // Personal pending bills banner (only if user has a unit)
        if (user?.unitCode != null) ...[
          _AdminPendingBillsBanner(pendingBills: pendingBills),
          const SizedBox(height: AppDimensions.md),
        ],
        _AdminCampaignBanner(stats: stats),
        const SizedBox(height: AppDimensions.md),
        _BillingCard(stats: stats),
        const SizedBox(height: AppDimensions.lg),

        DashboardSectionHeaderRow(
          title: 'Overview',
          actionLabel: 'Balance',
          onAction: () => context.go('/reports/balance'),
        ),
        const SizedBox(height: AppDimensions.md),
        _KpiRow(stats: stats, crossAxisCount: 2),
        const SizedBox(height: AppDimensions.lg),

        DashboardSectionHeaderRow(
          title: 'Insights',
          actionLabel: 'Reports',
          onAction: () => context.go('/reports/balance'),
        ),
        const SizedBox(height: AppDimensions.md),
        DashboardTrendPanel(
          title: 'Collection trend',
          subtitle: 'Paid bills · last 6 months',
          color: AppColors.primary,
          data: trendValuesFromDashboardStats(stats, key: 'collections'),
        ),
        const SizedBox(height: AppDimensions.md),
        DashboardTrendPanel(
          title: 'Visitors',
          subtitle: 'Last 6 days',
          color: AppColors.info,
          data: trendValuesFromDashboardStats(stats, key: 'visitors'),
        ),
        const SizedBox(height: AppDimensions.lg),

        const DashboardSectionHeaderRow(title: 'Quick actions'),
        const SizedBox(height: AppDimensions.md),
        _QuickActionsSection(role: role, isWeb: false),
        const SizedBox(height: AppDimensions.lg),

        DashboardSectionHeaderRow(
          title: "Today's activity",
          actionLabel: 'View all',
          onAction: () => context.go('/visitors'),
        ),
        const SizedBox(height: AppDimensions.md),
        _ActivityCards(stats: stats),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;
  const _SectionHeader({required this.title, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTextStyles.h2)),
        TextButton(onPressed: onViewAll, child: const Text('View all')),
      ],
    );
  }
}

class _CardTitleRow extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _CardTitleRow({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTextStyles.h2)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  final String role;
  const _QuickAccessGrid({required this.role});

  @override
  Widget build(BuildContext context) {
    final actions = _actionsForRole(role);
    final items = actions.take(6).toList();
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppDimensions.sm,
      mainAxisSpacing: AppDimensions.sm,
      childAspectRatio: 0.95, // Made taller to avoid overflow
      children: items
          .map(
            (a) => _QuickTile(
              icon: a.icon,
              label: a.label,
              onTap: () => context.go(a.route),
            ),
          )
          .toList(),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimensions.sm), // Slightly smaller padding
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              label,
              style: AppTextStyles.labelMedium,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _RecentActivityList({required this.stats});

  @override
  Widget build(BuildContext context) {
    final rows = <_RecentItem>[
      _RecentItem(
        icon: Icons.person_pin_circle_rounded,
        title: 'Visitors today',
        subtitle: '${stats['visitors']?['today'] ?? 0} checked in',
        color: AppColors.primary,
      ),
      _RecentItem(
        icon: Icons.local_shipping_rounded,
        title: 'Deliveries pending',
        subtitle: '${stats['deliveries']?['pending'] ?? 0} awaiting',
        color: AppColors.info,
      ),
      _RecentItem(
        icon: Icons.report_problem_rounded,
        title: 'Open complaints',
        subtitle: '${stats['complaints']?['open'] ?? 0} unresolved',
        color: AppColors.warning,
      ),
      _RecentItem(
        icon: Icons.receipt_long_rounded,
        title: 'Pending bills',
        subtitle: '${stats['billing']?['pendingCount'] ?? 0} unpaid',
        color: AppColors.teal,
      ),
    ];

    return Column(
      children: rows
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.sm),
              child: _RecentRow(item: r),
            ),
          )
          .toList(),
    );
  }
}

class _RecentItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _RecentItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

class _RecentRow extends StatelessWidget {
  final _RecentItem item;
  const _RecentRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          child: Icon(item.icon, size: 18, color: item.color),
        ),
        const SizedBox(width: AppDimensions.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: AppTextStyles.bodyMedium),
              Text(item.subtitle, style: AppTextStyles.bodySmallMuted),
            ],
          ),
        ),
        Text(
          _timeLikeLabel(item.title),
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  String _timeLikeLabel(String seed) {
    // deterministic pseudo “time” label based on string hash
    final h = seed.codeUnits.fold<int>(0, (p, c) => (p + c) % 97);
    final mins = 2 + (h % 50);
    return '${mins}m';
  }
}

// ─── Personal pending bills banner (for admins with a unit) ──────────────────

class _AdminPendingBillsBanner extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> pendingBills;
  const _AdminPendingBillsBanner({required this.pendingBills});

  @override
  Widget build(BuildContext context) {
    return pendingBills.when(
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
      data: (bills) {
        if (bills.isEmpty) return const SizedBox.shrink();
        final fmt = NumberFormat('#,##0');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...bills.map((bill) {
              final unit = bill['unit'] as Map?;
              final unitCode = unit?['fullCode'] as String? ?? '-';
              final month = bill['billingMonth'] != null
                  ? DateFormat('MMM yyyy')
                      .format(DateTime.parse(bill['billingMonth']))
                  : '';
              final remaining =
                  (double.tryParse(bill['totalDue']?.toString() ?? '0') ?? 0) -
                      (double.tryParse(bill['paidAmount']?.toString() ?? '0') ?? 0);
              final isOverdue =
                  (bill['status'] as String? ?? '').toLowerCase() == 'overdue';

              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                child: GestureDetector(
                  onTap: () => showPaySheet(context, bill: bill),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.md),
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? AppColors.dangerSurface
                          : AppColors.warningSurface,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusLg),
                      border: Border.all(
                        color: (isOverdue ? AppColors.danger : AppColors.warning)
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: (isOverdue
                                    ? AppColors.danger
                                    : AppColors.warning)
                                .withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                          child: Icon(
                            isOverdue
                                ? Icons.warning_rounded
                                : Icons.notifications_active_rounded,
                            color: isOverdue
                                ? AppColors.danger
                                : AppColors.warning,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOverdue
                                    ? 'Overdue Payment!'
                                    : 'Maintenance Due',
                                style: AppTextStyles.labelLarge.copyWith(
                                    color: isOverdue
                                        ? AppColors.dangerText
                                        : AppColors.warningText),
                              ),
                              Text(
                                'Unit $unitCode · $month',
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: (isOverdue
                                            ? AppColors.dangerText
                                            : AppColors.warningText)
                                        .withValues(alpha: 0.8)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${fmt.format(remaining)}',
                              style: AppTextStyles.h3.copyWith(
                                  color: isOverdue
                                      ? AppColors.danger
                                      : AppColors.warning),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: isOverdue
                                    ? AppColors.danger
                                    : AppColors.warning,
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusSm),
                              ),
                              child: Text('Pay Now',
                                  style: AppTextStyles.labelSmall
                                      .copyWith(color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ─── Campaign banner ─────────────────────────────────────────────────────────

class _AdminCampaignBanner extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _AdminCampaignBanner({required this.stats});

  @override
  Widget build(BuildContext context) {
    final campaigns = (stats['activeCampaigns'] as List?) ?? [];
    // Only show campaigns where user hasn't paid yet
    final filtered = campaigns.where((c) => c['hasPaid'] == false).toList();

    if (filtered.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        ...filtered.map((c) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.md),
            child: AppCard(
              padding: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => showDonateSheet(
                  context,
                  campaignId: c['id'],
                  campaignTitle: c['title'],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.lg),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.volunteer_activism_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Campaign',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c['title'] ?? 'Donation Campaign',
                                style: AppTextStyles.h3.copyWith(color: Colors.white),
                              ),
                              if (c['description'] != null)
                                Text(
                                  c['description'],
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppDimensions.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Donate',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
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
    final balance = stats['billing']?['societyBalance'] ?? 0;
    final vacant = stats['units']?['vacant'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.xl),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Column(
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
            const SizedBox(width: AppDimensions.xxl),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md, vertical: AppDimensions.sm),
              decoration: BoxDecoration(
                color: AppColors.successSurface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Column(
                children: [
                  Text('Society Balance',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.successText)),
                  Text('₹${_fmt(balance)}',
                      style:
                          AppTextStyles.h3.copyWith(color: AppColors.successText)),
                ],
              ),
            ),
          ],
        ),
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
                Text(item.label,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textMuted)),
                Text(item.value, style: AppTextStyles.h2),
              ],
            ),
          ],
        ),
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
      _KpiItem('Open Complaints', '${stats['complaints']?['open'] ?? 0}',
          Icons.report_problem_rounded, AppColors.warning),
      _KpiItem('Vacant Units', '${stats['units']?['vacant'] ?? 0}',
          Icons.home_work_rounded, AppColors.textMuted),
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
      _ActionItem(Icons.bar_chart_rounded, 'Reports', '/reports/balance'),
      _ActionItem(Icons.campaign_rounded, 'Notice', '/notices'),
      _ActionItem(Icons.report_problem_rounded, 'Complaints', '/complaints'),
    ];
  }
  return base;
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
