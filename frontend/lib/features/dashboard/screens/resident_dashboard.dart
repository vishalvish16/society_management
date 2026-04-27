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
import '../../bills/screens/upi_pay_sheet.dart';
import '../../donations/screens/donate_sheet.dart';
import '../../visitors/providers/visitors_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_portal_widgets.dart';

/// Dashboard for RESIDENT role — personal unit-centric view
class ResidentDashboard extends ConsumerStatefulWidget {
  const ResidentDashboard({super.key});

  @override
  ConsumerState<ResidentDashboard> createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends ConsumerState<ResidentDashboard> {
  Timer? _approvalRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    final ref = this.ref;
    final statsAsync = ref.watch(residentDashboardProvider);
    final pendingApprovals = ref.watch(pendingWalkinApprovalsProvider);
    final user = ref.watch(authProvider).user;
    final isWeb = MediaQuery.of(context).size.width >= 720;

    return statsAsync.when(
      loading: () => const AppLoadingShimmer(itemCount: 4, itemHeight: 100),
      error: (e, _) => _ErrorCard(
        message: 'Failed to load: $e',
        onRetry: () => ref.invalidate(residentDashboardProvider),
      ),
      data: (stats) => DashboardRefreshWithSearchStack(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(residentDashboardProvider.future),
            ref.read(pendingWalkinApprovalsProvider.notifier).fetch(),
          ]);
        },
        scrollChild: isWeb
            ? _WebResidentLayout(stats: stats, pendingApprovals: pendingApprovals, user: user)
            : _MobileResidentLayout(stats: stats, pendingApprovals: pendingApprovals, user: user),
      ),
    );
  }
}

// ─── Web layout ───────────────────────────────────────────────────────────────

class _WebResidentLayout extends StatelessWidget {
  final Map<String, dynamic> stats;
  final AsyncValue<List<dynamic>> pendingApprovals;
  final dynamic user;
  const _WebResidentLayout({required this.stats, required this.pendingApprovals, required this.user});

  @override
  Widget build(BuildContext context) {
    final name = (user?.name?.toString().trim().isNotEmpty ?? false)
        ? user.name.toString().trim()
        : 'Resident';
    final unit = stats['unit'] as Map<String, dynamic>?;
    final unitCode = unit?['fullCode'] as String? ?? user?.unitCode?.toString().trim() ?? '';
    final subtitle = unitCode.isNotEmpty
        ? 'Unit $unitCode · ${dashboardRoleSubtitle('RESIDENT')}'
        : dashboardRoleSubtitle('RESIDENT');
    final hasTrends = dashboardStatsHasTrends(stats);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardGreetingHeader(
          title: 'Home',
          greeting: dashboardGreetingForNow(),
          name: name,
          subtitle: subtitle,
          compact: false,
          onNotifications: () => context.go('/notifications'),
        ),
        const SizedBox(height: AppDimensions.lg),
        _GateApprovalBanner(pendingApprovals: pendingApprovals),
        // Unit + balance hero
        _UnitBalanceHero(stats: stats),
        const SizedBox(height: AppDimensions.md),
        _CampaignBanner(stats: stats),
        const SizedBox(height: AppDimensions.xxl),

        if (hasTrends) ...[
          DashboardSectionHeaderRow(
            title: 'Insights',
            actionLabel: 'Bills',
            onAction: () => context.go('/bills'),
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DashboardTrendPanel(
                  title: 'Collection trend',
                  subtitle: 'Society collections',
                  color: AppColors.primary,
                  data: trendValuesFromDashboardStats(stats, key: 'collections'),
                ),
              ),
              const SizedBox(width: AppDimensions.lg),
              Expanded(
                child: DashboardTrendPanel(
                  title: 'Visitors',
                  subtitle: 'Gate activity',
                  color: AppColors.info,
                  data: trendValuesFromDashboardStats(stats, key: 'visitors'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xxl),
        ],

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pending bills (left column)
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _PendingBillsSection(stats: stats),
                  const SizedBox(height: AppDimensions.lg),
                  _DonationCampaignsSection(stats: stats),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.lg),
            // Activity + quick actions (right column)
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _ResidentActivityTable(stats: stats),
                  const SizedBox(height: AppDimensions.lg),
                  _ResidentQuickActions(isWeb: true),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Mobile layout ────────────────────────────────────────────────────────────

class _MobileResidentLayout extends StatelessWidget {
  final Map<String, dynamic> stats;
  final AsyncValue<List<dynamic>> pendingApprovals;
  final dynamic user;
  const _MobileResidentLayout({required this.stats, required this.pendingApprovals, required this.user});

  @override
  Widget build(BuildContext context) {
    final name = (user?.name?.toString().trim().isNotEmpty ?? false)
        ? user.name.toString().trim()
        : 'Resident';
    final unit = stats['unit'] as Map<String, dynamic>?;
    final unitCode = unit?['fullCode'] as String? ?? user?.unitCode?.toString().trim() ?? '';
    final hasTrends = dashboardStatsHasTrends(stats);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Gradient header ──────────────────────────────────────────────────
        _MobileHomeHeader(
          name: name,
          unitCode: unitCode,
          stats: stats,
          onNotifications: () => context.go('/notifications'),
        ),
        const SizedBox(height: AppDimensions.md),

        // ── Urgent alerts ────────────────────────────────────────────────────
        _GateApprovalBanner(pendingApprovals: pendingApprovals),
        _PendingBillsSection(stats: stats),
        const SizedBox(height: AppDimensions.md),

        // ── Quick Actions (icon grid) ─────────────────────────────────────────
        _SectionTitle(title: 'Quick Actions'),
        const SizedBox(height: AppDimensions.md),
        _ResidentQuickActionsGrid(),
        const SizedBox(height: AppDimensions.lg),

        // ── My Activity (dashboard) ────────────────────────────────────────
        _SectionTitle(title: 'My Activity', actionLabel: 'Visitors', onAction: () => context.go('/visitors')),
        const SizedBox(height: AppDimensions.md),
        _ResidentActivityCards(stats: stats),
        const SizedBox(height: AppDimensions.lg),

        // ── Campaigns ────────────────────────────────────────────────────────
        _DonationCampaignsSection(stats: stats),

        // ── Insights ─────────────────────────────────────────────────────────
        if (hasTrends) ...[
          _SectionTitle(title: 'Insights', actionLabel: 'Bills', onAction: () => context.go('/bills')),
          const SizedBox(height: AppDimensions.md),
          DashboardTrendPanel(
            title: 'Collection trend',
            subtitle: 'Society collections',
            color: AppColors.primary,
            data: trendValuesFromDashboardStats(stats, key: 'collections'),
          ),
          const SizedBox(height: AppDimensions.md),
          DashboardTrendPanel(
            title: 'Visitors',
            subtitle: 'Gate activity',
            color: AppColors.info,
            data: trendValuesFromDashboardStats(stats, key: 'visitors'),
          ),
          const SizedBox(height: AppDimensions.lg),
        ],
      ],
    );
  }
}

// ─── Shared section title ─────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionTitle({required this.title, this.actionLabel, this.onAction});

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

// ─── Mobile home header ───────────────────────────────────────────────────────

class _MobileHomeHeader extends StatelessWidget {
  final String name;
  final String unitCode;
  final Map<String, dynamic> stats;
  final VoidCallback onNotifications;
  const _MobileHomeHeader({
    required this.name,
    required this.unitCode,
    required this.stats,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final outstanding = stats['outstandingBalance'] ?? 0;
    final hasBalance = (outstanding is num ? outstanding : 0) > 0;
    final fmt = NumberFormat('#,##0');
    final activeComplaints = stats['activeComplaints'] ?? 0;
    final pendingVisitors = stats['pendingVisitors'] ?? 0;
    final pendingDeliveries = stats['pendingDeliveries'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.xs),
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
            // Greeting row
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
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          child: Text(
                            'Unit $unitCode',
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
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: const Icon(Icons.notifications_outlined,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.lg),
            // Balance chip
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md, vertical: AppDimensions.sm),
              decoration: BoxDecoration(
                color: hasBalance
                    ? Colors.red.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: hasBalance
                      ? Colors.red.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasBalance ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: AppDimensions.xs),
                  Text(
                    hasBalance
                        ? 'Due: ₹${fmt.format(outstanding)}'
                        : 'No dues — all clear!',
                    style: AppTextStyles.labelMedium.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            // Mini stat pills
            Row(
              children: [
                _StatPill(
                  icon: Icons.report_problem_rounded,
                  label: '$activeComplaints Complaints',
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppDimensions.sm),
                _StatPill(
                  icon: Icons.local_shipping_rounded,
                  label: '$pendingDeliveries Deliveries',
                  color: AppColors.info,
                ),
                const SizedBox(width: AppDimensions.sm),
                _StatPill(
                  icon: Icons.person_pin_circle_rounded,
                  label: '$pendingVisitors Visitors',
                  color: Colors.teal,
                ),
              ],
            ),
          ],
        ),
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
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Resident Quick Actions icon grid ─────────────────────────────────────────

class _ResidentQuickActionsGrid extends StatelessWidget {
  const _ResidentQuickActionsGrid();

  static const _primary = [
    (Icons.receipt_long_rounded, 'My Bills', '/bills', Color(0xFF2563EB)),
    (Icons.person_add_rounded, 'Visitor', '/visitors', Color(0xFF10B981)),
    (Icons.report_problem_rounded, 'Complaint', '/complaints', Color(0xFFF59E0B)),
    (Icons.local_shipping_rounded, 'Delivery', '/deliveries', Color(0xFF8B5CF6)),
  ];

  static const _secondary = [
    (Icons.campaign_rounded, 'Notices', '/notices', Color(0xFF0EA5E9)),
    (Icons.how_to_vote_rounded, 'Polls', '/polls', Color(0xFFEC4899)),
    (Icons.event_rounded, 'Events', '/events', Color(0xFF14B8A6)),
    (Icons.volunteer_activism_rounded, 'Donations', '/donations', Color(0xFFEF4444)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary 4-grid
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppDimensions.sm,
          mainAxisSpacing: AppDimensions.sm,
          childAspectRatio: 0.85,
          children: _primary.map((a) => _QuickActionTile(
            icon: a.$1, label: a.$2, route: a.$3, color: a.$4,
            large: true,
          )).toList(),
        ),
        const SizedBox(height: AppDimensions.md),
        // Secondary section title
        Text(
          'More',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppDimensions.sm),
        // Secondary 4-grid
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppDimensions.sm,
          mainAxisSpacing: AppDimensions.sm,
          childAspectRatio: 0.85,
          children: _secondary.map((a) => _QuickActionTile(
            icon: a.$1, label: a.$2, route: a.$3, color: a.$4,
            large: false,
          )).toList(),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  final bool large;
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
    required this.large,
  });

  @override
  Widget build(BuildContext context) {
    final iconBoxSize = large ? 52.0 : 44.0;
    final iconSize = large ? 26.0 : 22.0;

    return GestureDetector(
      onTap: () => context.go(route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 1,
              ),
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

// ─── Unit + outstanding balance hero ─────────────────────────────────────────

class _UnitBalanceHero extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _UnitBalanceHero({required this.stats});

  @override
  Widget build(BuildContext context) {
    final unit = stats['unit'] as Map<String, dynamic>?;
    final unitCode = unit?['fullCode'] as String? ?? 'No unit';
    final isOwner = unit?['isOwner'] == true;
    final outstanding = stats['outstandingBalance'] ?? 0;
    final fmt = NumberFormat('#,##0');
    final hasBalance = (outstanding is num ? outstanding : 0) > 0;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.xl),
      decoration: BoxDecoration(
        color: hasBalance ? AppColors.danger : AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unit $unitCode',
                  style: AppTextStyles.h2
                      .copyWith(color: AppColors.textOnPrimary),
                ),
                const SizedBox(height: AppDimensions.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        AppColors.textOnPrimary.withValues(alpha: 0.2),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Text(
                    isOwner ? 'Owner' : 'Tenant',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textOnPrimary),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Outstanding Balance',
                style: AppTextStyles.caption.copyWith(
                    color:
                        AppColors.textOnPrimary.withValues(alpha: 0.8)),
              ),
              Text(
                hasBalance ? '₹${fmt.format(outstanding)}' : '₹0',
                style: AppTextStyles.amountLarge
                    .copyWith(color: AppColors.textOnPrimary),
              ),
              if (!hasBalance)
                Text(
                  'All clear!',
                  style: AppTextStyles.caption.copyWith(
                      color:
                          AppColors.textOnPrimary.withValues(alpha: 0.8)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Pending bills section ────────────────────────────────────────────────────

class _PendingBillsSection extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _PendingBillsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final bills = (stats['pendingBills'] as List?) ?? [];

    if (bills.isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.xl),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 32),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No Pending Bills', style: AppTextStyles.h3),
                    Text('You\'re all caught up.',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isWeb = MediaQuery.of(context).size.width >= 720;
    if (isWeb) {
      // Table view for web
      return AppCard(
        child: Column(
          children: [
            Container(
              color: AppColors.background,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.lg,
                  vertical: AppDimensions.sm),
              child: Row(
                children: [
                  Expanded(
                      child: Text('Month',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textMuted))),
                  Text('Due',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textMuted)),
                  const SizedBox(width: AppDimensions.xl),
                  Text('Status',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textMuted)),
                  const SizedBox(width: AppDimensions.xxl),
                  Text('Action',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            ...bills.asMap().entries.map((entry) {
              final i = entry.key;
              final bill = entry.value as Map<String, dynamic>;
              final remaining = (double.tryParse(
                          bill['totalDue']?.toString() ?? '0') ??
                      0) -
                  (double.tryParse(bill['paidAmount']?.toString() ?? '0') ??
                      0);
              final month = bill['billingMonth'] != null
                  ? DateFormat('MMM yyyy')
                      .format(DateTime.parse(bill['billingMonth']))
                  : '-';
              final status =
                  (bill['status'] as String? ?? '').toLowerCase();
              final isOverdue = status == 'overdue';
              final fmt = NumberFormat('#,##0');

              return Container(
                decoration: BoxDecoration(
                  border: i > 0
                      ? const Border(
                          top:
                              BorderSide(color: AppColors.border, width: 1))
                      : null,
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.lg,
                    vertical: AppDimensions.md),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(month,
                            style: AppTextStyles.bodyMedium)),
                    Text('₹${fmt.format(remaining)}',
                        style: AppTextStyles.h3.copyWith(
                            color: isOverdue
                                ? AppColors.danger
                                : AppColors.textPrimary)),
                    const SizedBox(width: AppDimensions.xl),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? AppColors.dangerSurface
                            : AppColors.warningSurface,
                        borderRadius: BorderRadius.circular(
                            AppDimensions.radiusSm),
                      ),
                      child: Text(
                        isOverdue ? 'Overdue' : 'Pending',
                        style: AppTextStyles.labelSmall.copyWith(
                            color: isOverdue
                                ? AppColors.dangerText
                                : AppColors.warningText),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.md),
                    TextButton(
                      onPressed: () =>
                          showPaySheet(context, bill: bill),
                      child: const Text('Pay'),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: AppDimensions.sm),
          ],
        ),
      );
    }

    // Cards for mobile
    return Column(
      children: bills.map((bill) {
        final b = bill as Map<String, dynamic>;
        final remaining =
            (double.tryParse(b['totalDue']?.toString() ?? '0') ?? 0) -
                (double.tryParse(b['paidAmount']?.toString() ?? '0') ?? 0);
        final month = b['billingMonth'] != null
            ? DateFormat('MMM yyyy')
                .format(DateTime.parse(b['billingMonth']))
            : '-';
        final status = (b['status'] as String? ?? '').toLowerCase();
        final isOverdue = status == 'overdue';
        final fmt = NumberFormat('#,##0');
        final bg =
            isOverdue ? AppColors.dangerSurface : AppColors.warningSurface;
        final border = isOverdue ? AppColors.danger : AppColors.warning;
        final textColor =
            isOverdue ? AppColors.dangerText : AppColors.warningText;

        return Padding(
          padding:
              const EdgeInsets.only(bottom: AppDimensions.sm),
          child: GestureDetector(
            onTap: () => showPaySheet(context, bill: b),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: bg,
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusLg),
                border: Border.all(
                    color: border.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: border.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd),
                    ),
                    child: Icon(
                      isOverdue
                          ? Icons.warning_rounded
                          : Icons.notifications_active_rounded,
                      color: border,
                      size: 20,
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
                            style: AppTextStyles.labelLarge
                                .copyWith(color: textColor)),
                        Text(month,
                            style: AppTextStyles.bodySmall.copyWith(
                                color:
                                    textColor.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${fmt.format(remaining)}',
                          style: AppTextStyles.h3
                              .copyWith(color: border)),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: border,
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
      }).toList(),
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

// ─── Activity table (web) ─────────────────────────────────────────────────────

class _ResidentActivityTable extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _ResidentActivityTable({required this.stats});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['Active Complaints', '${stats['activeComplaints'] ?? 0}',
          Icons.report_problem_rounded, AppColors.warning],
      ['Awaiting Visitors', '${stats['pendingVisitors'] ?? 0}',
          Icons.person_pin_circle_rounded, AppColors.primary],
      ['Pending Deliveries', '${stats['pendingDeliveries'] ?? 0}',
          Icons.local_shipping_rounded, AppColors.info],
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppDimensions.lg,
                AppDimensions.lg, AppDimensions.lg, AppDimensions.md),
            child: Text('My Activity', style: AppTextStyles.h2),
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

class _ResidentActivityCards extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _ResidentActivityCards({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item('Active Complaints', '${stats['activeComplaints'] ?? 0}',
          Icons.report_problem_rounded, AppColors.warning),
      _Item('Awaiting Visitors', '${stats['pendingVisitors'] ?? 0}',
          Icons.person_pin_circle_rounded, AppColors.primary),
      _Item('Pending Deliveries', '${stats['pendingDeliveries'] ?? 0}',
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
              Text(item.value,
                  style:
                      AppTextStyles.h3.copyWith(color: item.color)),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

class _Item {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Item(this.label, this.value, this.icon, this.color);
}

// ─── Quick actions ────────────────────────────────────────────────────────────

class _ResidentQuickActions extends StatelessWidget {
  final bool isWeb;
  const _ResidentQuickActions({required this.isWeb});

  static const _actions = [
    (Icons.receipt_long_rounded, 'My Bills', '/bills'),
    (Icons.report_problem_rounded, 'Complaint', '/complaints'),
    (Icons.person_add_rounded, 'Visitor', '/visitors'),
    (Icons.local_shipping_rounded, 'Delivery', '/deliveries'),
    (Icons.campaign_rounded, 'Notices', '/notices'),
    (Icons.how_to_vote_rounded, 'Polls', '/polls'),
    (Icons.event_rounded, 'Events', '/events'),
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
      return Wrap(
          spacing: AppDimensions.sm, runSpacing: AppDimensions.sm, children: chips);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.expand((c) => [c, const SizedBox(width: AppDimensions.sm)]).toList(),
      ),
    );
  }
}

// ─── Donation Campaigns section ──────────────────────────────────────────────

class _DonationCampaignsSection extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _DonationCampaignsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final campaigns = (stats['activeCampaigns'] as List?) ?? [];
    if (campaigns.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Active Campaigns', style: AppTextStyles.h2),
            if (campaigns.length > 1)
              TextButton(
                onPressed: () => context.go('/donations'),
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        ...campaigns.take(2).map((c) {
          final campaign = c as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.sm),
            child: AppCard(
              backgroundColor: AppColors.primarySurface,
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: const Icon(Icons.campaign_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign['title'] ?? 'Untitled Campaign',
                          style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
                        ),
                        if (campaign['description'] != null)
                          Text(
                            campaign['description'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  ElevatedButton(
                    onPressed: () => context.go('/donations'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Donate'),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: AppDimensions.lg),
      ],
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
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.dangerText.withValues(alpha: 0.8)),
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
                    style: AppTextStyles.labelSmall
                        .copyWith(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
