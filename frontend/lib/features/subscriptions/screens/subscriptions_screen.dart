import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../providers/subscriptions_provider.dart';
import '../../societies/providers/societies_provider.dart';
import '../../../shared/widgets/app_searchable_dropdown.dart';
import '../../../shared/widgets/show_app_sheet.dart';
import '../../../shared/widgets/show_app_dialog.dart';

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  String _statusFilter = '';
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);
  final dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(subscriptionsProvider.notifier).loadSubscriptions());
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return AppColors.success;
      case 'TRIAL':
        return AppColors.info;
      case 'EXPIRED':
        return AppColors.warning;
      case 'CANCELLED':
        return AppColors.danger;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionsProvider);
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w >= 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: AppColors.primary,
              title: Text(
                'Subscriptions',
                style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: AppDimensions.md),
                  child: FilledButton.icon(
                    onPressed: () => _showAssignDialog(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.textOnPrimary,
                      foregroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Assign Plan'),
                  ),
                ),
              ],
            ),
      body: isDesktop ? _buildDesktop(context, state) : _buildMobile(context, state),
    );
  }

  Widget _buildMobile(BuildContext context, SubscriptionsState state) {
    return Column(
      children: [
        // Filter bar
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.screenPadding,
            vertical: AppDimensions.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in {
                        '': 'All',
                        'ACTIVE': 'Active',
                        'TRIAL': 'Trial',
                        'EXPIRED': 'Expired',
                        'CANCELLED': 'Cancelled',
                      }.entries)
                        Padding(
                          padding:
                              const EdgeInsets.only(right: AppDimensions.sm),
                          child: ChoiceChip(
                            label: Text(entry.value),
                            selected: _statusFilter == entry.key,
                            selectedColor: AppColors.primarySurface,
                            labelStyle: AppTextStyles.labelMedium.copyWith(
                              color: _statusFilter == entry.key
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                            onSelected: (_) {
                              setState(() => _statusFilter = entry.key);
                              ref
                                  .read(subscriptionsProvider.notifier)
                                  .loadSubscriptions(
                                    status: entry.key.isNotEmpty ? entry.key : null,
                                  );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Text(
                '${state.total}',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: () {
            if (state.isLoading) return const AppLoadingShimmer();
            if (state.subscriptions.isEmpty) {
              return const AppEmptyState(
                emoji: '📋',
                title: 'No Subscriptions',
                subtitle: 'No subscriptions match the selected filter.',
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref
                  .read(subscriptionsProvider.notifier)
                  .loadSubscriptions(
                    status: _statusFilter.isNotEmpty ? _statusFilter : null,
                  ),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppDimensions.screenPadding),
                itemCount: state.subscriptions.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppDimensions.sm),
                itemBuilder: (_, i) => _SubscriptionCard(
                  sub: state.subscriptions[i],
                  statusColor: _statusColor,
                  currencyFormat: currencyFormat,
                  dateFormat: dateFormat,
                  onRenew: (id) => _confirmRenew(state.subscriptions[i]),
                  onCancel: (id) => _showCancelDialog(
                      id,
                      (state.subscriptions[i]['society'] as Map?)?['name'] ??
                          ''),
                ),
              ),
            );
          }(),
        ),

        // Pagination
        if (state.total > 20)
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.screenPadding,
              vertical: AppDimensions.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: state.page > 1
                      ? () => ref
                          .read(subscriptionsProvider.notifier)
                          .loadSubscriptions(
                            page: state.page - 1,
                            status: _statusFilter.isNotEmpty ? _statusFilter : null,
                          )
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text('Page ${state.page}', style: AppTextStyles.labelLarge),
                IconButton(
                  onPressed: state.page * 20 < state.total
                      ? () => ref
                          .read(subscriptionsProvider.notifier)
                          .loadSubscriptions(
                            page: state.page + 1,
                            status: _statusFilter.isNotEmpty ? _statusFilter : null,
                          )
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDesktop(BuildContext context, SubscriptionsState state) {
    final dist = <String, int>{};
    for (final s in state.subscriptions) {
      final st = (s['status'] ?? (s['society']?['status']) ?? '')
          .toString()
          .toUpperCase();
      dist[st] = (dist[st] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Subscriptions', style: AppTextStyles.displayMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Manage plans, renewals and cancellations',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showAssignDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Assign Plan'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => context.go('/sa/subscriptions/report'),
                icon: const Icon(Icons.table_view_rounded, size: 18),
                label: const Text('Report'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _StatMiniCard(
                label: 'Total',
                value: '${state.total}',
                icon: Icons.receipt_long_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              _StatMiniCard(
                label: 'Active',
                value: '${dist['ACTIVE'] ?? 0}',
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
              ),
              const SizedBox(width: 12),
              _StatMiniCard(
                label: 'Trial',
                value: '${dist['TRIAL'] ?? 0}',
                icon: Icons.hourglass_bottom_rounded,
                color: AppColors.info,
              ),
              const SizedBox(width: 12),
              _StatMiniCard(
                label: 'Expiring/Expired',
                value: '${(dist['EXPIRED'] ?? 0)}',
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
              ),
              const SizedBox(width: 12),
              _StatMiniCard(
                label: 'Cancelled',
                value: '${dist['CANCELLED'] ?? 0}',
                icon: Icons.cancel_rounded,
                color: AppColors.danger,
              ),
              const Spacer(),
              Text(
                '${state.total} records',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  for (final entry in {
                    '': 'All',
                    'ACTIVE': 'Active',
                    'TRIAL': 'Trial',
                    'EXPIRED': 'Expired',
                    'CANCELLED': 'Cancelled',
                  }.entries) ...[
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _statusFilter == entry.key,
                      selectedColor: AppColors.primarySurface,
                      labelStyle: AppTextStyles.labelMedium.copyWith(
                        color: _statusFilter == entry.key
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                      onSelected: (_) {
                        setState(() => _statusFilter = entry.key);
                        ref.read(subscriptionsProvider.notifier).loadSubscriptions(
                              status: entry.key.isNotEmpty ? entry.key : null,
                            );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => ref.read(subscriptionsProvider.notifier).loadSubscriptions(
                          status: _statusFilter.isNotEmpty ? _statusFilter : null,
                        ),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.subscriptions.isEmpty
                    ? const AppEmptyState(
                        emoji: '📋',
                        title: 'No Subscriptions',
                        subtitle: 'No subscriptions match the selected filter.',
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 1100),
                          child: Card(
                            margin: EdgeInsets.zero,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                    const Color(0xFFF8FAFC)),
                                columns: const [
                                  DataColumn(label: Text('Society')),
                                  DataColumn(label: Text('Plan')),
                                  DataColumn(label: Text('Cycle')),
                                  DataColumn(label: Text('Period')),
                                  DataColumn(label: Text('Amount')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Auto')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: state.subscriptions.map<DataRow>((sub) {
                                  final society =
                                      sub['society'] as Map<String, dynamic>? ??
                                          {};
                                  final status =
                                      (sub['status'] ?? society['status'] ?? '')
                                          .toString()
                                          .toUpperCase();
                                  final sColor = _statusColor(status);
                                  final id = sub['id'] as String? ?? '';
                                  final plan =
                                      sub['plan']?['displayName']?.toString() ??
                                          '-';
                                  final cycle =
                                      (sub['billingCycle']?.toString() ?? '-');
                                  final amount = num.tryParse(
                                          sub['amount']?.toString() ?? '0') ??
                                      0;
                                  final pStart = sub['periodStart'] != null
                                      ? dateFormat.format(DateTime.parse(
                                          sub['periodStart'] as String))
                                      : '-';
                                  final pEnd = sub['periodEnd'] != null
                                      ? dateFormat.format(DateTime.parse(
                                          sub['periodEnd'] as String))
                                      : '-';
                                  final autoRenew = sub['autoRenew'] == true;

                                  return DataRow(cells: [
                                    DataCell(Text(
                                      (society['name'] ?? '-').toString(),
                                      overflow: TextOverflow.ellipsis,
                                    )),
                                    DataCell(Text(plan, overflow: TextOverflow.ellipsis)),
                                    DataCell(Text(
                                      cycle.isNotEmpty
                                          ? cycle[0].toUpperCase() +
                                              cycle.substring(1).toLowerCase()
                                          : '-',
                                    )),
                                    DataCell(Text('$pStart → $pEnd')),
                                    DataCell(Text(currencyFormat.format(amount))),
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: sColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status,
                                        style: AppTextStyles.labelSmall
                                            .copyWith(color: sColor),
                                      ),
                                    )),
                                    DataCell(Icon(
                                      autoRenew
                                          ? Icons.autorenew_rounded
                                          : Icons.sync_disabled_rounded,
                                      size: 18,
                                      color: autoRenew
                                          ? AppColors.success
                                          : AppColors.textMuted,
                                    )),
                                    DataCell(Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: id.isEmpty
                                              ? null
                                              : () => _confirmRenew(sub),
                                          icon: const Icon(Icons.refresh_rounded, size: 16),
                                          label: const Text('Renew'),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          onPressed: id.isEmpty ||
                                                  !(status == 'ACTIVE' ||
                                                      status == 'TRIAL')
                                              ? null
                                              : () => _showCancelDialog(
                                                  id, (society['name'] ?? '').toString()),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.danger,
                                            side: const BorderSide(
                                                color: AppColors.danger),
                                          ),
                                          icon: const Icon(Icons.cancel_outlined, size: 16),
                                          label: const Text('Cancel'),
                                        ),
                                      ],
                                    )),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
          ),
          if (state.total > 20)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: state.page > 1
                        ? () => ref.read(subscriptionsProvider.notifier).loadSubscriptions(
                              page: state.page - 1,
                              status: _statusFilter.isNotEmpty ? _statusFilter : null,
                            )
                        : null,
                    child: const Text('Previous'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Page ${state.page}',
                        style: AppTextStyles.labelLarge),
                  ),
                  TextButton(
                    onPressed: state.page * 20 < state.total
                        ? () => ref.read(subscriptionsProvider.notifier).loadSubscriptions(
                              page: state.page + 1,
                              status: _statusFilter.isNotEmpty ? _statusFilter : null,
                            )
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  DateTime _addMonths(DateTime date, int months) =>
      DateTime(date.year, date.month + months, date.day);

  void _confirmRenew(Map<String, dynamic> sub) {
    final society = sub['society'] as Map<String, dynamic>? ?? {};
    final societyName = (society['name'] ?? '').toString();
    final societyId = (sub['id'] ?? society['id'] ?? '').toString();
    final currentPlan = (sub['plan']?['name'] ?? 'basic').toString().toLowerCase();
    final periodEndRaw = sub['periodEnd'];
    final currentEnd = periodEndRaw is String
        ? DateTime.tryParse(periodEndRaw) ?? DateTime.now()
        : periodEndRaw is DateTime
            ? periodEndRaw
            : DateTime.now();

    String planName = currentPlan;
    String cycle = 'monthly';
    int periods = 1;
    final periodsC = TextEditingController(text: '1');
    final discountC = TextEditingController(text: '0');
    String paymentMethod = 'UPI';
    final txnIdC = TextEditingController();
    final notesC = TextEditingController();
    bool submitting = false;

    final txnErr = ValueNotifier<String?>(null);
    bool useCustomStartDate = false;
    DateTime startDate = DateTime.now();

    DateTime previewEnd() {
      final effectiveStart = useCustomStartDate
          ? DateTime(startDate.year, startDate.month, startDate.day)
          : (currentEnd.isBefore(DateTime.now()) ? DateTime.now() : currentEnd);
      final base = DateTime(effectiveStart.year, effectiveStart.month, effectiveStart.day);
      final months = cycle == 'yearly' ? 12 : cycle == 'quarterly' ? 3 : 1;
      return _addMonths(base, months * periods);
    }

    showAppSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final nextEnd = previewEnd();
          final disc = double.tryParse(discountC.text.trim()) ?? 0;
          final d = disc.clamp(0, 100);

          // Display-only estimate (backend is source of truth)
          num monthly = planName == 'premium'
              ? 4999
              : planName == 'standard'
                  ? 2499
                  : 999;
          num yearly = planName == 'premium'
              ? 4999 * 12
              : planName == 'standard'
                  ? 2499 * 12
                  : 999 * 12;
          num baseTotal = 0;
          if (cycle == 'yearly') baseTotal = yearly * periods;
          else if (cycle == 'quarterly') baseTotal = (monthly * 3) * periods;
          else baseTotal = monthly * periods;
          final est = (baseTotal * (1 - d / 100)).round();

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Renew / Change Plan', style: AppTextStyles.h2),
                const SizedBox(height: 4),
                Text(
                  societyName,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                AppSearchableDropdown<String>(
                  label: 'Plan',
                  value: planName,
                  items: const [
                    AppDropdownItem(value: 'basic', label: 'Basic'),
                    AppDropdownItem(value: 'standard', label: 'Standard'),
                    AppDropdownItem(value: 'premium', label: 'Premium'),
                  ],
                  onChanged: (v) => setS(() => planName = v ?? 'basic'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AppSearchableDropdown<String>(
                        label: 'Billing Cycle',
                        value: cycle,
                        items: const [
                          AppDropdownItem(value: 'monthly', label: 'Monthly'),
                          AppDropdownItem(value: 'quarterly', label: 'Quarterly'),
                          AppDropdownItem(value: 'yearly', label: 'Yearly'),
                        ],
                        onChanged: (v) => setS(() => cycle = v ?? 'monthly'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: periodsC,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'No. of Periods',
                          helperText: 'e.g. 1, 2, 3',
                        ),
                        onChanged: (v) => setS(() {
                          periods = int.tryParse(v) ?? 1;
                          if (periods < 1) periods = 1;
                          if (periodsC.text != '$periods') {
                            periodsC.text = '$periods';
                            periodsC.selection = TextSelection.fromPosition(
                              TextPosition(offset: periodsC.text.length),
                            );
                          }
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: useCustomStartDate,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Override start date'),
                  subtitle: Text(
                    useCustomStartDate
                        ? 'Expiry will be calculated from selected start date'
                        : 'Expiry will be calculated from current expiry',
                    style:
                        AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                  onChanged: submitting
                      ? null
                      : (v) => setS(() => useCustomStartDate = v ?? false),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  onTap: (!useCustomStartDate || submitting)
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setS(() => startDate = picked);
                          }
                        },
                  child: Opacity(
                    opacity: useCustomStartDate ? 1 : 0.55,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        helperText: 'Used only when override is enabled',
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 18, color: AppColors.textMuted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              dateFormat.format(startDate),
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                          const Icon(Icons.expand_more_rounded,
                              color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: discountC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Discount % (manual)',
                    helperText: '0 to 100',
                  ),
                  onChanged: (_) => setS(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AppSearchableDropdown<String>(
                        label: 'Payment Type',
                        value: paymentMethod,
                        items: const [
                          AppDropdownItem(value: 'UPI', label: 'UPI'),
                          AppDropdownItem(value: 'BANK', label: 'Bank Transfer'),
                          AppDropdownItem(value: 'ONLINE', label: 'Online'),
                          AppDropdownItem(value: 'CASH', label: 'Cash'),
                          AppDropdownItem(value: 'RAZORPAY', label: 'Razorpay'),
                        ],
                        onChanged: (v) =>
                            setS(() => paymentMethod = v ?? 'UPI'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ValueListenableBuilder<String?>(
                        valueListenable: txnErr,
                        builder: (_, err, __) => TextField(
                          controller: txnIdC,
                          decoration: InputDecoration(
                            labelText: 'Transaction ID *',
                            helperText: 'Reference / UTR / Payment ID',
                            errorText: err,
                          ),
                          onChanged: (_) => txnErr.value = null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesC,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Preview', style: AppTextStyles.labelLarge),
                      const SizedBox(height: 6),
                      Text(
                        'Current expiry: ${dateFormat.format(currentEnd)}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                      if (useCustomStartDate)
                        Text(
                          'Start date: ${dateFormat.format(startDate)}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                      Text(
                        'Next expiry: ${dateFormat.format(nextEnd)}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Estimated amount: ${currencyFormat.format(est)}',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: submitting ? null : () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                if (txnIdC.text.trim().isEmpty) {
                                  txnErr.value = 'Required';
                                  return;
                                }
                                setS(() => submitting = true);
                                final ok = await ref
                                    .read(subscriptionsProvider.notifier)
                                    .renewSubscription(societyId, {
                                  'planName': planName,
                                  'billingCycle': cycle,
                                  'periods': periods,
                                  'discountPercent': d,
                                  if (useCustomStartDate)
                                    'startDate': DateTime(
                                      startDate.year,
                                      startDate.month,
                                      startDate.day,
                                    ).toIso8601String(),
                                  'paymentMethod': paymentMethod,
                                  'reference': txnIdC.text.trim(),
                                  'notes': notesC.text.trim().isEmpty
                                      ? null
                                      : notesC.text.trim(),
                                });
                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok
                                          ? 'Subscription updated'
                                          : 'Failed to renew'),
                                      backgroundColor:
                                          ok ? AppColors.success : AppColors.danger,
                                    ),
                                  );
                                }
                              },
                        child: Text(submitting ? 'Saving...' : 'Confirm'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCancelDialog(String id, String societyName) {
    final reasonC = TextEditingController();
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Cancel Subscription', style: AppTextStyles.h1),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cancel subscription for "$societyName"?', style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppDimensions.md),
            TextField(
              controller: reasonC,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Back', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(subscriptionsProvider.notifier)
                  .cancelSubscription(id, reasonC.text.trim());
            },
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }

  void _showAssignDialog(BuildContext context) {
    String? selectedSocietyId;
    String planName = 'basic';
    String cycle = 'monthly';
    final searchC = TextEditingController();

    ref.read(societiesProvider.notifier).loadSocieties();

    showAppDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final societies = ref.read(societiesProvider).societies;
          final filtered = searchC.text.isEmpty
              ? societies
              : societies
                  .where((s) => (s['name'] as String? ?? '')
                      .toLowerCase()
                      .contains(searchC.text.toLowerCase()))
                  .toList();

          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Assign Plan to Society', style: AppTextStyles.h1),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: searchC,
                    decoration: const InputDecoration(
                      labelText: 'Search Society *',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  if (filtered.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final s = filtered[i];
                          final isSelected = s['id'] == selectedSocietyId;
                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            selectedTileColor: AppColors.primarySurface,
                            title: Text(s['name'] ?? '', style: AppTextStyles.bodyMedium),
                            subtitle: Text(s['city'] ?? '',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textSecondary)),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: AppColors.primary, size: 18)
                                : null,
                            onTap: () => setDlgState(() {
                              selectedSocietyId = s['id'];
                              searchC.text = s['name'] ?? '';
                            }),
                          );
                        },
                      ),
                    ),
                  ] else if (searchC.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('No societies found',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted)),
                  ],
                  const SizedBox(height: AppDimensions.md),
                  AppSearchableDropdown<String>(
                    label: 'Plan',
                    value: planName,
                    items: const [
                      AppDropdownItem(value: 'basic', label: 'Basic'),
                      AppDropdownItem(value: 'standard', label: 'Standard'),
                      AppDropdownItem(value: 'premium', label: 'Premium'),
                    ],
                    onChanged: (v) => setDlgState(() => planName = v ?? 'basic'),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  AppSearchableDropdown<String>(
                    label: 'Billing Cycle',
                    value: cycle,
                    items: const [
                      AppDropdownItem(value: 'monthly', label: 'Monthly'),
                      AppDropdownItem(value: 'quarterly', label: 'Quarterly'),
                      AppDropdownItem(value: 'yearly', label: 'Yearly'),
                    ],
                    onChanged: (v) => setDlgState(() => cycle = v ?? 'monthly'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
              ),
              FilledButton(
                onPressed: selectedSocietyId == null
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await ref.read(subscriptionsProvider.notifier).assignPlan({
                          'societyId': selectedSocietyId,
                          'planName': planName,
                          'billingCycle': cycle,
                        });
                      },
                child: const Text('Assign'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final Map<String, dynamic> sub;
  final Color Function(String) statusColor;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;
  final void Function(String) onRenew;
  final void Function(String) onCancel;

  const _SubscriptionCard({
    required this.sub,
    required this.statusColor,
    required this.currencyFormat,
    required this.dateFormat,
    required this.onRenew,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final society = sub['society'] as Map<String, dynamic>? ?? {};
    final status = (sub['status'] ?? society['status'] ?? '').toString().toUpperCase();
    final id = sub['id'] as String? ?? '';
    final sColor = statusColor(status);
    final amount = num.tryParse(sub['amount']?.toString() ?? '0') ?? 0;
    final periodStart = sub['periodStart'] != null
        ? dateFormat.format(DateTime.parse(sub['periodStart'] as String))
        : '-';
    final periodEnd = sub['periodEnd'] != null
        ? dateFormat.format(DateTime.parse(sub['periodEnd'] as String))
        : '-';
    final billingCycle = (sub['billingCycle'] as String? ?? '-');
    final autoRenew = sub['autoRenew'] == true;
    final planName = sub['plan']?['displayName'] as String? ?? '-';

    return AppCard(
      leftBorderColor: sColor,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Society name + status badge
          Row(
            children: [
              Expanded(
                child: Text(society['name'] ?? '-', style: AppTextStyles.h3),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: sColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: AppTextStyles.labelSmall.copyWith(color: sColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),

          // Row 2: Plan + cycle
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.infoSurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Text(planName,
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.info)),
              ),
              const SizedBox(width: AppDimensions.sm),
              Text(
                billingCycle[0].toUpperCase() + billingCycle.substring(1).toLowerCase(),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                currencyFormat.format(amount),
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),

          // Row 3: Dates
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                '$periodStart → $periodEnd',
                style: AppTextStyles.caption,
              ),
              const Spacer(),
              Icon(
                autoRenew ? Icons.autorenew_rounded : Icons.sync_disabled_rounded,
                size: 14,
                color: autoRenew ? AppColors.success : AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                autoRenew ? 'Auto renew' : 'Manual',
                style: AppTextStyles.caption.copyWith(
                  color: autoRenew ? AppColors.success : AppColors.textMuted,
                ),
              ),
            ],
          ),

          // Actions
          if (status == 'ACTIVE' || status == 'TRIAL' || status == 'EXPIRED') ...[
            const SizedBox(height: AppDimensions.sm),
            Row(
              children: [
                if (status == 'ACTIVE' || status == 'TRIAL' || status == 'EXPIRED')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onRenew(id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success),
                        padding: const EdgeInsets.symmetric(vertical: AppDimensions.xs),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text('Renew', style: AppTextStyles.labelMedium),
                    ),
                  ),
                if ((status == 'ACTIVE' || status == 'TRIAL') && id.isNotEmpty) ...[
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onCancel(id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(vertical: AppDimensions.xs),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: Text('Cancel', style: AppTextStyles.labelMedium),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Text(value, style: AppTextStyles.h3),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
