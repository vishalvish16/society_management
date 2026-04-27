import 'dart:async';
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
import '../../visitors/providers/visitors_provider.dart';
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
  Timer? _approvalRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myPendingBillsProvider.notifier).fetch();
      ref.read(pendingWalkinApprovalsProvider.notifier).fetch();
    });
    _approvalRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) ref.read(pendingWalkinApprovalsProvider.notifier).fetch();
    });
  }

  @override
  void dispose() {
    _approvalRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(memberDashboardProvider);
    final pendingBills = ref.watch(myPendingBillsProvider);
    final user = ref.watch(authProvider).user;
    final isWeb = MediaQuery.of(context).size.width >= 720;

    final pendingApprovals = ref.watch(pendingWalkinApprovalsProvider);

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
            ref.read(pendingWalkinApprovalsProvider.notifier).fetch(),
          ]);
        },
        scrollChild: isWeb
            ? _WebMemberLayout(
                stats: stats, pendingBills: pendingBills,
                pendingApprovals: pendingApprovals, user: user)
            : _MobileMemberLayout(
                stats: stats, pendingBills: pendingBills,
                pendingApprovals: pendingApprovals, user: user),
      ),
    );
  }
}

// ─── Web layout ───────────────────────────────────────────────────────────────

class _WebMemberLayout extends StatelessWidget {
  final Map<String, dynamic> stats;
  final AsyncValue<List<Map<String, dynamic>>> pendingBills;
  final AsyncValue<List<dynamic>> pendingApprovals;
  final dynamic user;
  const _WebMemberLayout(
      {required this.stats, required this.pendingBills,
       required this.pendingApprovals, required this.user});

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
        _GateApprovalBanner(pendingApprovals: pendingApprovals),
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
  final AsyncValue<List<dynamic>> pendingApprovals;
  final dynamic user;
  const _MobileMemberLayout(
      {required this.stats, required this.pendingBills,
       required this.pendingApprovals, required this.user});

  @override
  Widget build(BuildContext context) {
    final name = (user?.name?.toString().trim().isNotEmpty ?? false)
        ? user.name.toString().trim()
        : 'Member';
    final unitCode = user?.unitCode?.toString().trim() ?? '';
    final hasTrends = dashboardStatsHasTrends(stats);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Gradient header ──────────────────────────────────────────────────
        _MobileMemberHeader(
          name: name,
          unitCode: unitCode,
          stats: stats,
          onNotifications: () => context.go('/notifications'),
        ),
        const SizedBox(height: AppDimensions.md),

        // ── Urgent alerts ────────────────────────────────────────────────────
        _GateApprovalBanner(pendingApprovals: pendingApprovals),
        _PendingBillsBanner(pendingBills: pendingBills),
        _CampaignBanner(stats: stats),
        const SizedBox(height: AppDimensions.md),

        // ── Quick Actions (icon grid) ─────────────────────────────────────────
        _SectionLabel(title: 'Quick Actions'),
        const SizedBox(height: AppDimensions.md),
        _MemberQuickActionsGrid(),
        const SizedBox(height: AppDimensions.lg),

        // ── Overview KPIs ────────────────────────────────────────────────────
        _SectionLabel(
          title: 'Overview',
          actionLabel: 'Balance',
          onAction: () => context.go('/reports/balance'),
        ),
        const SizedBox(height: AppDimensions.md),
        _MemberKpiRow(stats: stats, crossAxisCount: 2),
        const SizedBox(height: AppDimensions.lg),

        // ── Society Activity ─────────────────────────────────────────────────
        _SectionLabel(
          title: 'Society Activity',
          actionLabel: 'Visitors',
          onAction: () => context.go('/visitors'),
        ),
        const SizedBox(height: AppDimensions.md),
        _SocietyActivityCards(stats: stats),
        const SizedBox(height: AppDimensions.lg),

        // ── Insights ─────────────────────────────────────────────────────────
        if (hasTrends) ...[
          _SectionLabel(
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
      ],
    );
  }
}

// ─── Shared section label ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionLabel({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.h2),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
            ),
          ),
      ],
    );
  }
}

// ─── Member mobile header ─────────────────────────────────────────────────────

class _MobileMemberHeader extends StatelessWidget {
  final String name;
  final String unitCode;
  final Map<String, dynamic> stats;
  final VoidCallback onNotifications;
  const _MobileMemberHeader({
    required this.name,
    required this.unitCode,
    required this.stats,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final totalUnits = stats['units']?['total'] ?? 0;
    final openComplaints = stats['complaints']?['open'] ?? 0;
    final visitorsToday = stats['visitors']?['today'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      child: Padding(
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
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        style: AppTextStyles.h1.copyWith(color: Colors.white),
                      ),
                      if (unitCode.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: AppDimensions.xs),
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.sm, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          child: Text(
                            'Unit $unitCode · Member',
                            style: AppTextStyles.caption
                                .copyWith(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onNotifications,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: const Icon(Icons.notifications_outlined,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            // Stat pills row
            Row(
              children: [
                _MiniPill(Icons.apartment_rounded, '$totalUnits Units', AppColors.primaryLight),
                const SizedBox(width: AppDimensions.sm),
                _MiniPill(Icons.report_problem_rounded, '$openComplaints Complaints', AppColors.warning),
                const SizedBox(width: AppDimensions.sm),
                _MiniPill(Icons.person_pin_circle_rounded, '$visitorsToday Today', Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniPill(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption
                .copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

// ─── Member Quick Actions icon grid ──────────────────────────────────────────

class _MemberQuickActionsGrid extends StatelessWidget {
  const _MemberQuickActionsGrid();

  static const _primary = [
    (Icons.receipt_long_rounded, 'Bills', '/bills', Color(0xFF2563EB)),
    (Icons.person_add_rounded, 'Visitor', '/visitors', Color(0xFF10B981)),
    (Icons.report_problem_rounded, 'Complaints', '/complaints', Color(0xFFF59E0B)),
    (Icons.local_shipping_rounded, 'Deliveries', '/deliveries', Color(0xFF8B5CF6)),
  ];

  static const _secondary = [
    (Icons.campaign_rounded, 'Notices', '/notices', Color(0xFF0EA5E9)),
    (Icons.how_to_vote_rounded, 'Polls', '/polls', Color(0xFFEC4899)),
    (Icons.event_rounded, 'Events', '/events', Color(0xFF14B8A6)),
    (Icons.bar_chart_rounded, 'Reports', '/reports/balance', Color(0xFFEF4444)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppDimensions.sm,
          mainAxisSpacing: AppDimensions.sm,
          childAspectRatio: 0.85,
          children: _primary
              .map((a) => _ActionTile(icon: a.$1, label: a.$2, route: a.$3, color: a.$4, large: true))
              .toList(),
        ),
        const SizedBox(height: AppDimensions.md),
        Text('More', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: AppDimensions.sm),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppDimensions.sm,
          mainAxisSpacing: AppDimensions.sm,
          childAspectRatio: 0.85,
          children: _secondary
              .map((a) => _ActionTile(icon: a.$1, label: a.$2, route: a.$3, color: a.$4, large: false))
              .toList(),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  final bool large;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
    required this.large,
  });

  @override
  Widget build(BuildContext context) {
    final boxSize = large ? 52.0 : 44.0;
    final iconSize = large ? 26.0 : 22.0;
    return GestureDetector(
      onTap: () => context.go(route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: boxSize,
            height: boxSize,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: iconSize),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
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

// ─── Gate approval banner ─────────────────────────────────────────────────────

class _GateApprovalBanner extends StatelessWidget {
  final AsyncValue<List<dynamic>> pendingApprovals;
  const _GateApprovalBanner({required this.pendingApprovals});

  @override
  Widget build(BuildContext context) {
    final count = pendingApprovals.when(
      data: (list) => list.length,
      loading: () => 0,
      error: (_, _) => 0,
    );
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: GestureDetector(
        onTap: () => context.go('/visitors/pending-approvals'),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.lg, vertical: AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.dangerSurface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: const Icon(Icons.person_pin_circle_rounded,
                    color: AppColors.danger, size: 22),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1
                          ? '1 visitor waiting at gate!'
                          : '$count visitors waiting at gate!',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.dangerText),
                    ),
                    Text(
                      'Tap to Allow or Deny entry',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.dangerText.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Text('Review',
                    style: AppTextStyles.labelSmall.copyWith(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
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
    (Icons.how_to_vote_rounded, 'Polls', '/polls'),
    (Icons.event_rounded, 'Events', '/events'),
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
