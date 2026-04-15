import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../bills/screens/upi_pay_sheet.dart';
import '../providers/dashboard_provider.dart';

/// Dashboard for RESIDENT role — personal unit-centric view
class ResidentDashboard extends ConsumerWidget {
  const ResidentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(residentDashboardProvider);
    final isWeb = MediaQuery.of(context).size.width >= 720;

    return statsAsync.when(
      loading: () => const AppLoadingShimmer(itemCount: 4, itemHeight: 100),
      error: (e, _) => _ErrorCard(
        message: 'Failed to load: $e',
        onRetry: () => ref.invalidate(residentDashboardProvider),
      ),
      data: (stats) => RefreshIndicator(
        onRefresh: () async => ref.refresh(residentDashboardProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          child: isWeb
              ? _WebResidentLayout(stats: stats)
              : _MobileResidentLayout(stats: stats),
        ),
      ),
    );
  }
}

// ─── Web layout ───────────────────────────────────────────────────────────────

class _WebResidentLayout extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _WebResidentLayout({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Unit + balance hero
        _UnitBalanceHero(stats: stats),
        const SizedBox(height: AppDimensions.xxl),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pending bills (left column)
            Expanded(
              flex: 3,
              child: _PendingBillsSection(stats: stats),
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
  const _MobileResidentLayout({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UnitBalanceHero(stats: stats),
        const SizedBox(height: AppDimensions.lg),

        Text('Pending Bills', style: AppTextStyles.h2),
        const SizedBox(height: AppDimensions.md),
        _PendingBillsSection(stats: stats),
        const SizedBox(height: AppDimensions.lg),

        Text('Quick Actions', style: AppTextStyles.h2),
        const SizedBox(height: AppDimensions.md),
        _ResidentQuickActions(isWeb: false),
        const SizedBox(height: AppDimensions.lg),

        Text('My Activity', style: AppTextStyles.h2),
        const SizedBox(height: AppDimensions.md),
        _ResidentActivityCards(stats: stats),
      ],
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
