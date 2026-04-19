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

/// Dashboard for MEMBER role — unit resident with committee privileges
/// Gets society stats from backend but shows member-relevant view
class MemberDashboard extends ConsumerStatefulWidget {
  const MemberDashboard({super.key});

  @override
  ConsumerState<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends ConsumerState<MemberDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myPendingBillsProvider.notifier).fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(memberDashboardProvider);
    final pendingBills = ref.watch(myPendingBillsProvider);
    final user = ref.watch(authProvider).user;
    final isWeb = MediaQuery.of(context).size.width >= 720;

    return statsAsync.when(
      loading: () => const AppLoadingShimmer(itemCount: 4, itemHeight: 100),
      error: (e, _) => _ErrorCard(
        message: 'Failed to load: $e',
        onRetry: () => ref.invalidate(memberDashboardProvider),
      ),
      data: (stats) => DashboardRefreshWithSearchStack(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(memberDashboardProvider.future),
            ref.read(myPendingBillsProvider.notifier).fetch(),
          ]);
        },
        scrollChild: isWeb
            ? _WebMemberLayout(
                stats: stats, pendingBills: pendingBills, user: user)
            : _MobileMemberLayout(
                stats: stats, pendingBills: pendingBills, user: user),
      ),
    );
  }
}

// ─── Web layout ───────────────────────────────────────────────────────────────

class _WebMemberLayout extends StatelessWidget {
  final Map<String, dynamic> stats;
  final AsyncValue<List<Map<String, dynamic>>> pendingBills;
  final dynamic user;
  const _WebMemberLayout(
      {required this.stats, required this.pendingBills, required this.user});

  @override
  Widget build(BuildContext context) {
    final name = (user?.name?.toString().trim().isNotEmpty ?? false)
        ? user.name.toString().trim()
        : 'Member';
    final unitCode = user?.unitCode?.toString().trim();
    final subtitle = (unitCode != null && unitCode.isNotEmpty)
        ? 'Unit $unitCode · ${dashboardRoleSubtitle('MEMBER')}'
        : dashboardRoleSubtitle('MEMBER');
    final hasTrends = dashboardStatsHasTrends(stats);

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
        // My Unit and pending bills
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user?.unitCode != null)
              Expanded(child: _MyUnitCard(unitCode: user!.unitCode!)),
            if (user?.unitCode != null) const SizedBox(width: AppDimensions.md),
            Expanded(child: _PendingBillsBanner(pendingBills: pendingBills)),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        _CampaignBanner(stats: stats),
        const SizedBox(height: AppDimensions.md),

        if (hasTrends) ...[
          DashboardSectionHeaderRow(
            title: 'Insights',
            actionLabel: 'Reports',
            onAction: () => context.go('/reports/balance'),
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DashboardTrendPanel(
                  title: 'Collection trend',
                  subtitle: 'Paid bills · last 6 months',
                  color: AppColors.primary,
                  data: trendValuesFromDashboardStats(stats, key: 'collections'),
                ),
              ),
              const SizedBox(width: AppDimensions.lg),
              Expanded(
                child: DashboardTrendPanel(
                  title: 'Visitors',
                  subtitle: 'Last 6 days',
                  color: AppColors.info,
                  data: trendValuesFromDashboardStats(stats, key: 'visitors'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xxl),
        ],

        DashboardSectionHeaderRow(
          title: 'Overview',
          actionLabel: 'Balance',
          onAction: () => context.go('/reports/balance'),
        ),
        const SizedBox(height: AppDimensions.md),
        // KPI row (4 across on web)
        _MemberKpiRow(stats: stats, crossAxisCount: 4),
        const SizedBox(height: AppDimensions.xxl),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _SocietyActivityTable(stats: stats),
            ),
            const SizedBox(width: AppDimensions.lg),
            Expanded(
              flex: 2,
              child: _MemberQuickActions(isWeb: true),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Mobile layout ────────────────────────────────────────────────────────────

class _MobileMemberLayout extends StatelessWidget {
  final Map<String, dynamic> stats;
  final AsyncValue<List<Map<String, dynamic>>> pendingBills;
  final dynamic user;
  const _MobileMemberLayout(
      {required this.stats, required this.pendingBills, required this.user});

  @override
  Widget build(BuildContext context) {
    final name = (user?.name?.toString().trim().isNotEmpty ?? false)
        ? user.name.toString().trim()
        : 'Member';
    final unitCode = user?.unitCode?.toString().trim();
    final subtitle = (unitCode != null && unitCode.isNotEmpty)
        ? 'Unit $unitCode · ${dashboardRoleSubtitle('MEMBER')}'
        : dashboardRoleSubtitle('MEMBER');
    final hasTrends = dashboardStatsHasTrends(stats);

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
        if (user?.unitCode != null) ...[
          _MyUnitCard(unitCode: user!.unitCode!),
          const SizedBox(height: AppDimensions.md),
        ],
        _PendingBillsBanner(pendingBills: pendingBills),
        _CampaignBanner(stats: stats),
        const SizedBox(height: AppDimensions.md),
        if (hasTrends) ...[
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
        ],
        DashboardSectionHeaderRow(
          title: 'Overview',
          actionLabel: 'Balance',
          onAction: () => context.go('/reports/balance'),
        ),
        const SizedBox(height: AppDimensions.md),
        _MemberKpiRow(stats: stats, crossAxisCount: 2),
        const SizedBox(height: AppDimensions.lg),

        DashboardSectionHeaderRow(title: 'Quick Actions'),
        const SizedBox(height: AppDimensions.md),
        _MemberQuickActions(isWeb: false),
        const SizedBox(height: AppDimensions.lg),

        DashboardSectionHeaderRow(
          title: 'Society Activity',
          actionLabel: 'Visitors',
          onAction: () => context.go('/visitors'),
        ),
        const SizedBox(height: AppDimensions.md),
        _SocietyActivityCards(stats: stats),
      ],
    );
  }
}

// ─── Pending bills banner ─────────────────────────────────────────────────────

class _PendingBillsBanner extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> pendingBills;
  const _PendingBillsBanner({required this.pendingBills});

  @override
  Widget build(BuildContext context) {
    return pendingBills.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (bills) {
        if (bills.isEmpty) return const SizedBox.shrink();
        final fmt = NumberFormat('#,##0');
        return Column(
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
                      (double.tryParse(
                              bill['paidAmount']?.toString() ?? '0') ??
                          0);
              final status =
                  (bill['status'] as String? ?? '').toLowerCase();
              final isOverdue = status == 'overdue';

              return Padding(
                padding:
                    const EdgeInsets.only(bottom: AppDimensions.sm),
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
                        color: (isOverdue
                                ? AppColors.danger
                                : AppColors.warning)
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
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMd),
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
            const SizedBox(height: AppDimensions.sm),
          ],
        );
      },
    );
  }
}

// ─── Campaign banner ─────────────────────────────────────────────────────────

class _CampaignBanner extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _CampaignBanner({required this.stats});

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

// ─── KPI row ──────────────────────────────────────────────────────────────────

class _MemberKpiRow extends StatelessWidget {
  final Map<String, dynamic> stats;
  final int crossAxisCount;
  const _MemberKpiRow(
      {required this.stats, required this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiItem('Total Units', '${stats['units']?['total'] ?? 0}',
          Icons.apartment_rounded, AppColors.primary),
      _KpiItem('Occupied', '${stats['units']?['occupied'] ?? 0}',
          Icons.people_rounded, AppColors.success),
      _KpiItem('Open Complaints', '${stats['complaints']?['open'] ?? 0}',
          Icons.report_problem_rounded, AppColors.warning),
      _KpiItem('Visitors Today', '${stats['visitors']?['today'] ?? 0}',
          Icons.person_pin_circle_rounded, AppColors.info),
    ];

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppDimensions.md,
      mainAxisSpacing: AppDimensions.md,
      childAspectRatio: crossAxisCount == 4 ? 2.0 : 1.6,
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

// ─── Society activity table (web) ─────────────────────────────────────────────

class _SocietyActivityTable extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _SocietyActivityTable({required this.stats});

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
            child: Text('Society Activity', style: AppTextStyles.h2),
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
                    child: Icon(r[2] as IconData,
                        color: r[3] as Color, size: 16),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                      child:
                          Text(r[0] as String, style: AppTextStyles.bodyMedium)),
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

// ─── Activity cards (mobile) ──────────────────────────────────────────────────

class _SocietyActivityCards extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _SocietyActivityCards({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiItem('Visitors Today', '${stats['visitors']?['today'] ?? 0}',
          Icons.person_pin_circle_rounded, AppColors.primary),
      _KpiItem('Pending Deliveries',
          '${stats['deliveries']?['pending'] ?? 0}',
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
              Expanded(
                  child: Text(item.label, style: AppTextStyles.bodyMedium)),
              Text(item.value, style: AppTextStyles.h3),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

// ─── Quick actions ────────────────────────────────────────────────────────────

class _MemberQuickActions extends StatelessWidget {
  final bool isWeb;
  const _MemberQuickActions({required this.isWeb});

  static const _actions = [
    (Icons.receipt_long_rounded, 'Bills', '/bills'),
    (Icons.report_problem_rounded, 'Complaints', '/complaints'),
    (Icons.person_add_rounded, 'Visitor', '/visitors'),
    (Icons.campaign_rounded, 'Notices', '/notices'),
    (Icons.local_shipping_rounded, 'Deliveries', '/deliveries'),
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

// --- My Unit Card -------------------------------------------------------------

class _MyUnitCard extends StatelessWidget {
  final String unitCode;
  const _MyUnitCard({required this.unitCode});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.md),
      leftBorderColor: AppColors.primary,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
            child: const Icon(Icons.apartment_rounded,
                color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Unit',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(unitCode, style: AppTextStyles.h2),
              ],
            ),
          ),
          const Icon(Icons.verified_user_rounded,
              color: AppColors.success, size: 18),
          const SizedBox(width: 4),
          Text('Assigned',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.success)),
        ],
      ),
    );
  }
}
