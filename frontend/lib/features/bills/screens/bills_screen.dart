import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../settings/providers/payment_settings_provider.dart';
import '../../../shared/widgets/show_app_sheet.dart';

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
      case 'paid':   return AppColors.success;
      case 'overdue': return AppColors.danger;
      default:        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.role.toUpperCase() ?? '';
    final isAdmin = role == 'PRAMUKH' || role == 'CHAIRMAN' || role == 'SECRETARY';
    final billsAsync = ref.watch(billsProvider);
    final notifier = ref.read(billsProvider.notifier);
    final fmt = NumberFormat('#,##0');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Bills',
            style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showGenerateDialog(context, ref),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: AppColors.textOnPrimary),
              label: Text('Generate',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textOnPrimary)),
            )
          : null,
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.screenPadding,
                vertical: AppDimensions.sm),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in ['all', 'pending', 'partial', 'paid', 'overdue'])
                    Padding(
                      padding: const EdgeInsets.only(right: AppDimensions.sm),
                      child: ChoiceChip(
                        label: Text(s == 'all'
                            ? 'All'
                            : s[0].toUpperCase() + s.substring(1)),
                        selected: _statusFilter == s,
                        selectedColor: AppColors.primarySurface,
                        labelStyle: AppTextStyles.labelMedium.copyWith(
                          color: _statusFilter == s
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                        onSelected: (_) => setState(() => _statusFilter = s),
                      ),
                    ),
                ],
              ),
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
                    child: Text('Error: $e',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.dangerText)),
                  ),
                ),
              ),
              data: (bills) {
                final filtered = _statusFilter == 'all'
                    ? bills
                    : bills
                        .where((b) =>
                            (b['status'] as String? ?? '').toLowerCase() ==
                            _statusFilter)
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
                    padding: const EdgeInsets.all(AppDimensions.screenPadding),
                    itemCount: filtered.length + (notifier.hasMore ? 1 : 0),
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimensions.sm),
                    itemBuilder: (_, i) {
                      if (i == filtered.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: AppDimensions.md),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final bill = filtered[i];
                      final status =
                          (bill['status'] as String? ?? 'pending').toLowerCase();
                      final unit = bill['unit'] as Map<String, dynamic>?;
                      final totalDue =
                          double.tryParse(bill['totalDue']?.toString() ?? '0') ??
                              0;
                      final paidAmount =
                          double.tryParse(
                                  bill['paidAmount']?.toString() ?? '0') ??
                              0;
                      final remaining = totalDue - paidAmount;
                      final billingMonth = bill['billingMonth'] != null
                          ? DateFormat('MMM yyyy')
                              .format(DateTime.parse(bill['billingMonth']))
                          : '';
                      final isPayable = status != 'paid';

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
                                      Text(unit?['fullCode'] ?? '-',
                                          style: AppTextStyles.h3),
                                      const SizedBox(height: AppDimensions.xs),
                                      Text(billingMonth,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                  color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('₹${fmt.format(totalDue)}',
                                        style: AppTextStyles.h3),
                                    if (paidAmount > 0)
                                      Text(
                                        'Paid: ₹${fmt.format(paidAmount)}',
                                        style: AppTextStyles.caption.copyWith(
                                            color: AppColors.success),
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
                                            color: AppColors.danger),
                                      ),
                                    ),
                                  const Spacer(),
                                  FilledButton.icon(
                                    onPressed: () => _showPayDialog(
                                        context, bill, remaining),
                                    icon: const Icon(Icons.payment_rounded,
                                        size: 16),
                                    label: const Text('Pay Now'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: AppDimensions.md,
                                          vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      textStyle: AppTextStyles.labelMedium,
                                    ),
                                  ),
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

  void _showPayDialog(
      BuildContext context, Map<String, dynamic> bill, double remaining) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => _PayBillSheet(bill: bill, remaining: remaining),
    );
  }

  void _showGenerateDialog(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController(text: '2000');
    DateTime selectedMonth = DateTime.now();
    DateTime dueDate = DateTime.now().add(const Duration(days: 10));

    showAppSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.screenPadding, AppDimensions.lg,
            AppDimensions.screenPadding,
            MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.xxxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: AppDimensions.lg),
              const Text('Generate Bills', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppDimensions.xs),
              Text('Only occupied units will receive bills.', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontStyle: FontStyle.italic)),
              const SizedBox(height: AppDimensions.lg),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Maintenance Amount', prefixText: '₹',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              ),
              const SizedBox(height: AppDimensions.md),
              ListTile(contentPadding: EdgeInsets.zero,
                title: const Text('Billing Month'),
                subtitle: Text(DateFormat('MMMM yyyy').format(selectedMonth)),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final picked = await showDatePicker(context: context,
                    initialDate: selectedMonth, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (picked != null) setDlgState(() => selectedMonth = picked);
                },
              ),
              ListTile(contentPadding: EdgeInsets.zero,
                title: const Text('Due Date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(dueDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(context: context,
                    initialDate: dueDate, firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)));
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
                      return;
                    }
                    Navigator.pop(ctx);
                    final error = await ref.read(billsProvider.notifier).bulkGenerate(selectedMonth, amount, dueDate);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(error ?? 'Bills generated successfully'),
                        backgroundColor: error == null ? AppColors.success : AppColors.danger,
                      ));
                    }
                  },
                  child: const Text('Generate Bills'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pay Bill Sheet ───────────────────────────────────────────────────────────

class _PayBillSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> bill;
  final double remaining;

  const _PayBillSheet({required this.bill, required this.remaining});

  @override
  ConsumerState<_PayBillSheet> createState() => _PayBillSheetState();
}

class _PayBillSheetState extends ConsumerState<_PayBillSheet> {
  late final TextEditingController _amountCtrl;
  final _notesCtrl = TextEditingController();
  String _paymentMethod = 'UPI';
  bool _isSubmitting = false;

  static const _methods = ['UPI', 'CASH', 'BANK_TRANSFER', 'CHEQUE', 'OTHER'];

  @override
  void initState() {
    super.initState();
    _amountCtrl =
        TextEditingController(text: widget.remaining.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final error = await ref.read(billsProvider.notifier).payBill(
          widget.bill['id'] as String,
          amount,
          _paymentMethod,
          notes: _notesCtrl.text.trim(),
        );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? 'Payment recorded successfully'),
        backgroundColor: error == null ? AppColors.success : AppColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.bill['unit'] as Map<String, dynamic>?;
    final billingMonth = widget.bill['billingMonth'] != null
        ? DateFormat('MMMM yyyy')
            .format(DateTime.parse(widget.bill['billingMonth']))
        : '';
    final fmt = NumberFormat('#,##0');
    final paymentSettingsAsync = ref.watch(paymentSettingsProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppDimensions.screenPadding,
          AppDimensions.lg,
          AppDimensions.screenPadding,
          MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),

            // Bill summary
            Text('Pay Bill', style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.xs),
            Text(
              '${unit?['fullCode'] ?? '-'} • $billingMonth',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'Outstanding: ₹${fmt.format(widget.remaining)}',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.danger, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppDimensions.lg),

            // ── Payment details card (UPI / Bank) ──────────────────────
            paymentSettingsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (ps) {
                if (!ps.hasAny) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pay directly to:',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: AppDimensions.sm),

                    // UPI block
                    if (ps.hasUpi)
                      _PayDetailCard(
                        icon: Icons.qr_code_rounded,
                        iconColor: AppColors.primary,
                        bgColor: AppColors.primarySurface,
                        title: ps.upiName?.isNotEmpty == true
                            ? ps.upiName!
                            : 'UPI Payment',
                        lines: [ps.upiId!],
                        copyValue: ps.upiId,
                        copyLabel: 'UPI ID copied',
                      ),

                    if (ps.hasUpi && ps.hasBank)
                      const SizedBox(height: AppDimensions.sm),

                    // Bank block
                    if (ps.hasBank)
                      _PayDetailCard(
                        icon: Icons.account_balance_outlined,
                        iconColor: AppColors.success,
                        bgColor: AppColors.successSurface,
                        title: ps.bankName?.isNotEmpty == true
                            ? ps.bankName!
                            : 'Bank Transfer',
                        lines: [
                          if (ps.accountHolderName?.isNotEmpty == true)
                            ps.accountHolderName!,
                          'A/C: ${ps.accountNumber!}',
                          if (ps.ifscCode?.isNotEmpty == true)
                            'IFSC: ${ps.ifscCode!}',
                        ],
                        copyValue: ps.accountNumber,
                        copyLabel: 'Account number copied',
                      ),

                    // Admin note
                    if (ps.paymentNote?.isNotEmpty == true) ...[
                      const SizedBox(height: AppDimensions.sm),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppDimensions.sm),
                        decoration: BoxDecoration(
                          color: AppColors.warningSurface,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                size: 14, color: AppColors.warning),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(ps.paymentNote!,
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.warningText)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.lg),
                    const Divider(),
                    const SizedBox(height: AppDimensions.md),
                  ],
                );
              },
            ),

            // ── Confirm payment form ───────────────────────────────────
            Text('Confirm your payment:',
                style:
                    AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppDimensions.md),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount Paying (₹) *',
                prefixText: '₹',
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            AppSearchableDropdown<String>(
              label: 'Payment Method *',
              value: _paymentMethod,
              items: _methods
                  .map((m) =>
                      AppDropdownItem(value: m, label: m.replaceAll('_', ' ')))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _paymentMethod = v);
              },
            ),
            const SizedBox(height: AppDimensions.md),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'UTR / Reference / Notes (Optional)',
              ),
            ),
            const SizedBox(height: AppDimensions.xl),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirm Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Payment Detail Card ──────────────────────────────────────────────────────

class _PayDetailCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final List<String> lines;
  final String? copyValue;
  final String copyLabel;

  const _PayDetailCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.lines,
    this.copyValue,
    this.copyLabel = 'Copied',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: iconColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.textPrimary)),
                ...lines.map((l) => Text(l,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary))),
              ],
            ),
          ),
          if (copyValue != null)
            IconButton(
              icon:
                  const Icon(Icons.copy_rounded, size: 16, color: AppColors.textMuted),
              tooltip: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: copyValue!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(copyLabel),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
