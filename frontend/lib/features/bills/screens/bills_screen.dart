import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/widgets/app_searchable_dropdown.dart';
import '../providers/bill_provider.dart';
import '../../units/providers/unit_provider.dart';
import '../../../shared/widgets/show_app_sheet.dart';
import '../../../shared/widgets/app_date_picker.dart';
import 'upi_pay_sheet.dart';
import '../../settings/screens/bill_schedule_screen.dart';
import '../../plans/screens/plans_screen.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  String _statusFilter = 'all';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(billsProvider.notifier).loadNextPage();
    }
  }

  Color _borderColor(String status) {
    switch (status) {
      case 'paid':
        return AppColors.success;
      case 'overdue':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final role = user?.role.toUpperCase() ?? '';
    final isAdmin =
        role == 'PRAMUKH' || role == 'CHAIRMAN' || role == 'SECRETARY';
    final hasBillSchedules = user?.hasFeature('bill_schedules') ?? false;
    final billsAsync = ref.watch(billsProvider);
    final notifier = ref.read(billsProvider.notifier);
    final fmt = NumberFormat('#,##0');

    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? AppBar(
              backgroundColor: AppColors.primary,
              title: Text(
                'Bills',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
              actions: isAdmin
                  ? [
                      IconButton(
                        tooltip: 'Bill Audit Logs',
                        onPressed: () => context.push('/bills/audit-logs'),
                        icon: const Icon(
                          Icons.history_rounded,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                      IconButton(
                        tooltip: hasBillSchedules
                            ? 'Bill Schedule'
                            : 'Bill Schedule (Premium)',
                        onPressed: () {
                          if (hasBillSchedules) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BillScheduleScreen(),
                              ),
                            );
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Bill Schedule is a Premium feature. Please upgrade to access it.',
                              ),
                            ),
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PlansScreen()),
                          );
                        },
                        icon: Icon(
                          hasBillSchedules
                              ? Icons.schedule_rounded
                              : Icons.lock_rounded,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ]
                  : null,
            )
          : null,
      floatingActionButton: isAdmin
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isWide) ...[
                  FloatingActionButton.extended(
                    heroTag: 'payAdvance',
                    onPressed: () => _showPayAdvanceDialog(context, ref),
                    backgroundColor: AppColors.success,
                    icon: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.textOnPrimary,
                    ),
                    label: Text(
                      'Pay Advance',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  FloatingActionButton.extended(
                    heroTag: 'generateBills',
                    onPressed: () => _showGenerateDialog(context, ref),
                    backgroundColor: AppColors.primary,
                    icon: const Icon(Icons.add, color: AppColors.textOnPrimary),
                    label: Text(
                      'Generate',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                ] else ...[
                  FloatingActionButton(
                    heroTag: 'payAdvance',
                    onPressed: () => _showPayAdvanceDialog(context, ref),
                    backgroundColor: AppColors.success,
                    tooltip: 'Pay Advance',
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  FloatingActionButton(
                    heroTag: 'generateBills',
                    onPressed: () => _showGenerateDialog(context, ref),
                    backgroundColor: AppColors.primary,
                    tooltip: 'Generate Bills',
                    child: const Icon(Icons.add, color: AppColors.textOnPrimary),
                  ),
                ],
              ],
            )
          : null,
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.screenPadding,
              vertical: AppDimensions.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                    child: Wrap(
                      spacing: AppDimensions.sm,
                      runSpacing: AppDimensions.sm,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.push('/bills/audit-logs'),
                          icon: const Icon(Icons.history_rounded, size: 18),
                          label: const Text('Audit Logs'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            if (hasBillSchedules) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BillScheduleScreen(),
                                ),
                              );
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Bill Schedule is a Premium feature. Please upgrade to access it.',
                                ),
                              ),
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PlansScreen(),
                              ),
                            );
                          },
                          icon: Icon(
                            hasBillSchedules
                                ? Icons.schedule_rounded
                                : Icons.lock_rounded,
                            size: 18,
                          ),
                          label: Text(
                            hasBillSchedules
                                ? 'Bill Schedule'
                                : 'Bill Schedule (Premium)',
                          ),
                        ),
                      ],
                    ),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final s in [
                        'all',
                        'pending',
                        'partial',
                        'paid',
                        'overdue',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(
                            right: AppDimensions.sm,
                          ),
                          child: ChoiceChip(
                            label: Text(
                              s == 'all'
                                  ? 'All'
                                  : s[0].toUpperCase() + s.substring(1),
                            ),
                            selected: _statusFilter == s,
                            selectedColor: AppColors.primarySurface,
                            labelStyle: AppTextStyles.labelMedium.copyWith(
                              color: _statusFilter == s
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                            onSelected: (_) =>
                                setState(() => _statusFilter = s),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: billsAsync.when(
              loading: () => const AppLoadingShimmer(),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.screenPadding),
                  child: AppCard(
                    backgroundColor: AppColors.dangerSurface,
                    child: Text(
                      'Error: $e',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.dangerText,
                      ),
                    ),
                  ),
                ),
              ),
              data: (bills) {
                final filtered = _statusFilter == 'all'
                    ? bills
                    : bills
                          .where(
                            (b) =>
                                (b['status'] as String? ?? '').toLowerCase() ==
                                _statusFilter,
                          )
                          .toList();

                if (filtered.isEmpty) {
                  return const AppEmptyState(
                    emoji: '📄',
                    title: 'No Bills Found',
                    subtitle: 'No bills match the selected filter.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.read(billsProvider.notifier).fetchBills(),
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.screenPadding,
                      AppDimensions.screenPadding,
                      AppDimensions.screenPadding,
                      AppDimensions.xxxl * 5, // Extra space for dual FABs
                    ),
                    itemCount: filtered.length + (notifier.hasMore ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppDimensions.sm),
                    itemBuilder: (_, i) {
                      if (i == filtered.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppDimensions.md,
                            ),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final bill = filtered[i];
                      final status = (bill['status'] as String? ?? 'pending')
                          .toLowerCase();
                      final unit = bill['unit'] as Map<String, dynamic>?;
                      final category =
                          bill['category'] as String? ?? 'MAINTENANCE';
                      final title = bill['title'] as String?;
                      final description = bill['description'] as String?;
                      final isAdvanceReceipt = category == 'ADVANCE_RECEIPT';
                      final totalDue =
                          double.tryParse(
                            bill['totalDue']?.toString() ?? '0',
                          ) ??
                          0;
                      final paidAmount =
                          double.tryParse(
                            bill['paidAmount']?.toString() ?? '0',
                          ) ??
                          0;
                      final remaining = totalDue - paidAmount;
                      final billingMonth = bill['billingMonth'] != null
                          ? DateFormat(
                              'MMM yyyy',
                            ).format(DateTime.parse(bill['billingMonth']))
                          : '';
                      final isPayable = status != 'paid';
                      final coverageFrom = bill['coverageFrom'] != null
                          ? DateFormat(
                              'MMM yyyy',
                            ).format(DateTime.parse(bill['coverageFrom']))
                          : null;
                      final coverageTo = bill['coverageTo'] != null
                          ? DateFormat(
                              'MMM yyyy',
                            ).format(DateTime.parse(bill['coverageTo']))
                          : null;

                      return AppCard(
                        leftBorderColor: _borderColor(status),
                        padding: const EdgeInsets.all(AppDimensions.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        unit?['fullCode'] ?? '-',
                                        style: AppTextStyles.h3,
                                      ),
                                      const SizedBox(height: AppDimensions.xs),
                                      if (title != null &&
                                          title != 'Maintenance Bill')
                                        Text(
                                          title,
                                          style: AppTextStyles.labelMedium
                                              .copyWith(
                                                color: AppColors.primary,
                                              ),
                                        ),
                                      Text(
                                        billingMonth,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      if (isAdvanceReceipt &&
                                          coverageFrom != null &&
                                          coverageTo != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4.0,
                                          ),
                                          child: Text(
                                            'Coverage: $coverageFrom to $coverageTo',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                  color: AppColors.success,
                                                ),
                                          ),
                                        ),
                                      if (description != null &&
                                          description.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4.0,
                                          ),
                                          child: Text(
                                            description,
                                            style: AppTextStyles.caption,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${fmt.format(totalDue)}',
                                      style: AppTextStyles.h3,
                                    ),
                                    if (paidAmount > 0)
                                      Text(
                                        'Paid: ₹${fmt.format(paidAmount)}',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.success,
                                        ),
                                      ),
                                    const SizedBox(height: AppDimensions.xs),
                                    AppStatusChip(status: status),
                                  ],
                                ),
                              ],
                            ),
                            // Pay button — visible to everyone for unpaid bills
                            if (isPayable) ...[
                              const SizedBox(height: AppDimensions.sm),
                              const Divider(height: 1),
                              const SizedBox(height: AppDimensions.sm),
                              Row(
                                children: [
                                  if (remaining < totalDue)
                                    Expanded(
                                      child: Text(
                                        'Due: ₹${fmt.format(remaining)}',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.danger,
                                        ),
                                      ),
                                    ),
                                  const Spacer(),
                                  FilledButton.icon(
                                    onPressed: () => _showPayDialog(
                                      context,
                                      bill,
                                      remaining,
                                    ),
                                    icon: const Icon(
                                      Icons.payment_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Pay Now'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppDimensions.md,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      textStyle: AppTextStyles.labelMedium,
                                    ),
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(width: AppDimensions.sm),
                                    _BillAdminMenu(
                                      onViewHistory: () =>
                                          _showAuditSheet(context, ref, bill),
                                      onDelete: () => _confirmDeleteBill(
                                        context,
                                        ref,
                                        bill,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ] else ...[
                              const SizedBox(height: AppDimensions.sm),
                              const Divider(height: 1),
                              const SizedBox(height: AppDimensions.sm),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _showSlipSheet(context, bill),
                                    icon: const Icon(
                                      Icons.receipt_long_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      isAdvanceReceipt
                                          ? 'View Advance Slip'
                                          : 'View Pay Slip',
                                    ),
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(width: AppDimensions.sm),
                                    _BillAdminMenu(
                                      onViewHistory: () =>
                                          _showAuditSheet(context, ref, bill),
                                      onDelete: () => _confirmDeleteBill(
                                        context,
                                        ref,
                                        bill,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSlipSheet(BuildContext context, Map<String, dynamic> bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (_) => _PaymentSlipSheet(bill: bill),
    );
  }

  Future<void> _showAuditSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> bill,
  ) async {
    context.push('/bills/audit-logs?billId=${bill['id']}');
  }

  Future<void> _confirmDeleteBill(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> bill,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Bill'),
        content: const Text(
          'This will soft-delete the bill entry and keep it in audit history. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final error = await ref
        .read(billsProvider.notifier)
        .deleteBill(bill['id'] as String);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Bill deleted successfully'),
        backgroundColor: error == null ? AppColors.success : AppColors.danger,
      ),
    );
  }

  void _showPayDialog(
    BuildContext context,
    Map<String, dynamic> bill,
    double remaining,
  ) {
    showPaySheet(context, bill: bill);
  }

  void _showGenerateDialog(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController(text: '1000');
    DateTime selectedMonth = DateTime.now();
    DateTime dueDate = DateTime.now().add(const Duration(days: 10));
    int cycles = 1;
    showAppSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.screenPadding,
            AppDimensions.lg,
            AppDimensions.screenPadding,
            MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.xxxl,
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
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              const Text(
                'Generate Maintenance Bills',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppDimensions.xs),
              Text(
                'Only occupied units will receive bills.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              AppSearchableDropdown<int>(
                label: 'Billing Cycle',
                value: cycles,
                items: const [
                  AppDropdownItem(value: 1, label: 'Monthly'),
                  AppDropdownItem(value: 3, label: 'Quarterly (3 Months)'),
                  AppDropdownItem(value: 6, label: 'Half-Yearly (6 Months)'),
                  AppDropdownItem(value: 12, label: 'Yearly (12 Months)'),
                ],
                onChanged: (v) {
                  if (v != null) setDlgState(() => cycles = v);
                },
              ),
              const SizedBox(height: AppDimensions.md),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount per Month',
                  prefixText: '₹',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              AppDateField(
                label: 'Start Month',
                value: selectedMonth,
                onTap: () async {
                  final picked = await pickSingleDate(
                    ctx,
                    initial: selectedMonth,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setDlgState(() => selectedMonth = picked);
                },
              ),
              const SizedBox(height: AppDimensions.md),
              AppDateField(
                label: 'Due Date',
                value: dueDate,
                onTap: () async {
                  final picked = await pickSingleDate(
                    ctx,
                    initial: dueDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setDlgState(() => dueDate = picked);
                },
              ),
              const SizedBox(height: AppDimensions.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid amount'),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final error = await ref
                        .read(billsProvider.notifier)
                        .bulkGenerate(
                          selectedMonth,
                          amount,
                          dueDate,
                          cycles: cycles,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            error ?? 'Bills generated successfully',
                          ),
                          backgroundColor: error == null
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      );
                    }
                  },
                  child: Text(
                    cycles > 1 ? 'Generate ($cycles Months)' : 'Generate Bills',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPayAdvanceDialog(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController(text: '1000');
    final monthsController = TextEditingController(text: '12');
    final notesController = TextEditingController();
    String? selectedUnitId;
    String paymentMethod = 'UPI';
    int cycleMonths = 12;
    DateTime startDate = DateTime.now();
    showAppSheet(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, modalRef, _) => StatefulBuilder(
          builder: (ctx, setDlgState) {
            final unitsAsync = modalRef.watch(unitsProvider);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.screenPadding,
                AppDimensions.lg,
                AppDimensions.screenPadding,
                MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.xxxl,
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
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  const Text(
                    'Record Advance Maintenance',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  unitsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error loading units: $e'),
                    data: (units) => AppSearchableDropdown<String>(
                      label: 'Select Unit *',
                      value: selectedUnitId,
                      items: units
                          .map(
                            (u) => AppDropdownItem(
                              value: u['id'] as String,
                              label: u['fullCode'] as String,
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDlgState(() => selectedUnitId = v),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  AppSearchableDropdown<int>(
                    label: 'Advance Cycle',
                    value: cycleMonths,
                    items: const [
                      AppDropdownItem(value: 1, label: 'Monthly'),
                      AppDropdownItem(value: 6, label: 'Half-Yearly'),
                      AppDropdownItem(value: 12, label: 'Yearly'),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setDlgState(() {
                          cycleMonths = v;
                          monthsController.text = '$v';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: monthsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'No. of Months',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.md),
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Amount/Month',
                            prefixText: '₹',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.md),
                  AppDateField(
                    label: 'Advance Start Month',
                    value: startDate,
                    onTap: () async {
                      final picked = await pickSingleDate(
                        ctx,
                        initial: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setDlgState(() => startDate = picked);
                    },
                  ),
                  const SizedBox(height: AppDimensions.md),
                  AppSearchableDropdown<String>(
                    label: 'Payment Method *',
                    value: paymentMethod,
                    items: const [
                      AppDropdownItem(value: 'UPI', label: 'UPI'),
                      AppDropdownItem(value: 'CASH', label: 'Cash'),
                      AppDropdownItem(
                        value: 'BANK_TRANSFER',
                        label: 'Bank Transfer',
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlgState(() => paymentMethod = v);
                    },
                  ),
                  const SizedBox(height: AppDimensions.md),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (selectedUnitId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a unit'),
                            ),
                          );
                          return;
                        }
                        final months = int.tryParse(monthsController.text) ?? 0;
                        final amt = double.tryParse(amountController.text) ?? 0;
                        if (months <= 0 || amt <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter valid count and amount',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        final error = await ref
                            .read(billsProvider.notifier)
                            .payAdvance(
                              unitId: selectedUnitId!,
                              monthsCount: months,
                              amountPerMonth: amt,
                              paymentMethod: paymentMethod,
                              startDate: startDate,
                              notes: notesController.text,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                error ?? 'Advance payment recorded',
                              ),
                              backgroundColor: error == null
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          );
                        }
                      },
                      child: const Text('Record Payment'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}



// ─── Payment Detail Card ──────────────────────────────────────────────────────

class _PaymentSlipSheet extends StatelessWidget {
  final Map<String, dynamic> bill;

  const _PaymentSlipSheet({required this.bill});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final unit = bill['unit'] as Map<String, dynamic>?;
    final title = bill['title'] as String?;
    final paidAt = bill['paidAt'] != null
        ? DateFormat(
            'dd MMM yyyy, hh:mm a',
          ).format(DateTime.parse(bill['paidAt']))
        : '-';
    final method = (bill['paymentMethod'] as String? ?? '-').replaceAll(
      '_',
      ' ',
    );
    final amount = double.tryParse(bill['paidAmount']?.toString() ?? '0') ?? 0;
    final coverageFrom = bill['coverageFrom'] != null
        ? DateFormat('MMM yyyy').format(DateTime.parse(bill['coverageFrom']))
        : null;
    final coverageTo = bill['coverageTo'] != null
        ? DateFormat('MMM yyyy').format(DateTime.parse(bill['coverageTo']))
        : null;

    Widget line(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.screenPadding,
        AppDimensions.lg,
        AppDimensions.screenPadding,
        MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(title ?? 'Maintenance Pay Slip', style: AppTextStyles.h2),
            const SizedBox(height: AppDimensions.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line('Unit', unit?['fullCode']?.toString() ?? '-'),
                  line('Amount', 'Rs ${fmt.format(amount)}'),
                  line('Status', bill['status']?.toString() ?? '-'),
                  line('Paid On', paidAt),
                  line('Method', method),
                  if (coverageFrom != null && coverageTo != null)
                    line('Coverage', '$coverageFrom to $coverageTo'),
                  if ((bill['description'] as String?)?.isNotEmpty == true)
                    line('Details', bill['description'] as String),
                  if ((bill['notes'] as String?)?.isNotEmpty == true)
                    line('Notes', bill['notes'] as String),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillAdminMenu extends StatelessWidget {
  final VoidCallback onViewHistory;
  final VoidCallback onDelete;

  const _BillAdminMenu({required this.onViewHistory, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) {
        if (value == 'history') {
          onViewHistory();
        } else if (value == 'delete') {
          onDelete();
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem<String>(value: 'history', child: Text('View Audit Log')),
        PopupMenuItem<String>(value: 'delete', child: Text('Delete Bill')),
      ],
    );
  }
}

