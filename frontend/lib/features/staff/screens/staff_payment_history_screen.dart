import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../providers/staff_provider.dart';

class StaffPaymentHistoryScreen extends ConsumerStatefulWidget {
  const StaffPaymentHistoryScreen({super.key});

  @override
  ConsumerState<StaffPaymentHistoryScreen> createState() =>
      _StaffPaymentHistoryScreenState();
}

class _StaffPaymentHistoryScreenState
    extends ConsumerState<StaffPaymentHistoryScreen> {
  late DateTime _month;
  final _searchCtrl = TextEditingController();
  bool _includeCancelled = false;
  int _page = 1;
  final int _limit = 50;
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _ym(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  String _d(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      helpText: 'Select month (pick any date)',
    );
    if (picked == null) return;
    setState(() => _month = DateTime(picked.year, picked.month, 1));
  }

  StaffPaymentHistoryQuery get _query => StaffPaymentHistoryQuery(
        month: _ym(_month),
        q: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        page: _page,
        limit: _limit,
        includeCancelled: _includeCancelled,
      );

  String _csv(List<StaffSalaryPaymentHistoryItem> rows) {
    final b = StringBuffer();
    b.writeln('PaidAt,Staff,Role,Phone,PeriodFrom,PeriodTo,Amount,Method,Note,PaidBy');
    for (final r in rows) {
      final paidAt = _d(r.paidAt);
      final name = r.staffName.replaceAll('"', '""');
      final role = r.staffRole.replaceAll('"', '""');
      final phone = (r.staffPhone ?? '').replaceAll('"', '""');
      final from = r.periodFrom != null ? _d(r.periodFrom!) : '';
      final to = r.periodTo != null ? _d(r.periodTo!) : '';
      final note = (r.note ?? '').replaceAll('"', '""');
      final paidBy = (r.paidByName ?? '').replaceAll('"', '""');
      b.writeln(
          '$paidAt,"$name","$role","$phone",$from,$to,${r.amount.toStringAsFixed(2)},${r.paymentMethod},"$note","$paidBy"');
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(staffPaymentHistoryProvider(_query));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          _selectMode ? 'Select payments' : 'Payment History',
          style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary),
        ),
        actions: [
          if (_selectMode) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${_selectedIds.length} selected',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textOnPrimary),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Undo selected',
              onPressed: _selectedIds.isEmpty ? null : _bulkUndoSelected,
              icon: const Icon(Icons.undo_rounded,
                  color: AppColors.textOnPrimary),
            ),
            IconButton(
              tooltip: 'Exit select',
              onPressed: () => setState(() {
                _selectMode = false;
                _selectedIds.clear();
              }),
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.textOnPrimary),
            ),
          ] else ...[
            IconButton(
              tooltip: 'Select multiple',
              onPressed: () => setState(() {
                _selectMode = true;
                _selectedIds.clear();
              }),
              icon: const Icon(Icons.playlist_add_check_rounded,
                  color: AppColors.textOnPrimary),
            ),
          ],
          TextButton.icon(
            onPressed: _pickMonth,
            icon: const Icon(Icons.calendar_month_rounded,
                color: AppColors.textOnPrimary),
            label: Text(
              _ym(_month),
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.textOnPrimary),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: async.when(
        loading: () => const AppLoadingShimmer(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            child: AppCard(
              backgroundColor: AppColors.dangerSurface,
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Text('Failed to load: $e',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.dangerText)),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(staffPaymentHistoryProvider(_query)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (rows) {
          final paidRows = rows.where((r) => r.cancelledAt == null).toList();
          final cancelledRows = rows.where((r) => r.cancelledAt != null).toList();
          final paidTotal = paidRows.fold<double>(0, (s, r) => s + r.amount);
          final cancelledTotal = cancelledRows.fold<double>(0, (s, r) => s + r.amount);

          return ListView(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppDimensions.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Month: ${_ym(_month)}',
                              style: AppTextStyles.h3),
                        ),
                        Text(
                          '₹${paidTotal.toStringAsFixed(0)}',
                          style: AppTextStyles.h3
                              .copyWith(color: AppColors.success),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        _pill('Paid', '${paidRows.length}', AppColors.success),
                        _pill('Cancelled', '${cancelledRows.length}', AppColors.danger),
                        if (cancelledRows.isNotEmpty)
                          _pill('Cancelled total', '₹${cancelledTotal.toStringAsFixed(0)}', AppColors.danger),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        hintText: 'Staff name / role / phone / note',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (_) => setState(() => _page = 1),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Include cancelled payments'),
                      value: _includeCancelled,
                      onChanged: (v) => setState(() {
                        _includeCancelled = v;
                        _page = 1;
                      }),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: rows.isEmpty
                              ? null
                              : () async {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final text = _csv(rows);
                                  await Clipboard.setData(
                                      ClipboardData(text: text));
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                        content: Text('CSV copied')),
                                  );
                                },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy CSV'),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${rows.length} payments',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              if (rows.isEmpty)
                const AppEmptyState(
                  emoji: '💸',
                  title: 'No payments',
                  subtitle: 'No salary payments recorded for this month.',
                )
              else
                ...rows.map((r) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppDimensions.sm),
                      child: AppCard(
                        padding: const EdgeInsets.all(AppDimensions.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (_selectMode && r.cancelledAt == null) ...[
                                  Checkbox(
                                    value: _selectedIds.contains(r.id),
                                    onChanged: (v) => setState(() {
                                      if (v == true) {
                                        _selectedIds.add(r.id);
                                      } else {
                                        _selectedIds.remove(r.id);
                                      }
                                    }),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(r.staffName,
                                      style: AppTextStyles.h3),
                                ),
                                Text(
                                  '₹${r.amount.toStringAsFixed(0)}',
                                  style: AppTextStyles.h3
                                      .copyWith(color: AppColors.success),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${r.staffRole}${r.staffPhone != null ? ' • ${r.staffPhone}' : ''}',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                _pill('Paid', _d(r.paidAt), AppColors.primary),
                                _pill('Method', r.paymentMethod,
                                    AppColors.textSecondary),
                                if (r.periodFrom != null && r.periodTo != null)
                                  _pill(
                                    'Period',
                                    '${_d(r.periodFrom!)}→${_d(r.periodTo!)}',
                                    AppColors.textMuted,
                                  ),
                                if (r.cancelledAt != null)
                                  _pill('Cancelled', _d(r.cancelledAt!),
                                      AppColors.danger),
                              ],
                            ),
                            if (r.cancelledAt == null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _confirmCancelPayment(r),
                                  icon: const Icon(Icons.undo_rounded, size: 18),
                                  label: const Text('Undo (mark unpaid)'),
                                ),
                              ),
                            ],
                            if (r.note != null && r.note!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                r.note!,
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary),
                              ),
                            ],
                            if (r.paidByName != null &&
                                r.paidByName!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Paid by: ${r.paidByName}',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textMuted),
                              ),
                            ],
                            if (r.cancelledAt != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Cancelled by: ${r.cancelledByName ?? '-'}',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.danger),
                              ),
                              if (r.cancelReason != null &&
                                  r.cancelReason!.trim().isNotEmpty)
                                Text(
                                  'Reason: ${r.cancelReason}',
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.danger),
                                ),
                            ],
                          ],
                        ),
                      ),
                    )),

              if (rows.length >= _limit)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.sm),
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _page += 1),
                    icon: const Icon(Icons.expand_more_rounded),
                    label: const Text('Load more'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _bulkUndoSelected() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;

    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undo selected payments?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('This will cancel ${ids.length} payments and mark them unpaid.'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Undo'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      reasonCtrl.dispose();
      return;
    }
    final reason = reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim();
    reasonCtrl.dispose();

    final cancel = ref.read(staffCancelSalaryPaymentsBulkProvider);
    final err = await cancel(ids, reason: reason);
    if (!mounted) return;
    if (err == null) {
      setState(() {
        _selectedIds.clear();
        _selectMode = false;
      });
      ref.invalidate(staffPaymentHistoryProvider(_query));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payments undone')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _confirmCancelPayment(StaffSalaryPaymentHistoryItem p) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undo payment?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('This will mark the salary payment as unpaid for ${p.staffName}.'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Undo'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      reasonCtrl.dispose();
      return;
    }
    final reason = reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim();
    reasonCtrl.dispose();

    final cancel = ref.read(staffCancelSalaryPaymentProvider);
    final err = await cancel(p.id, reason: reason);
    if (!mounted) return;
    if (err == null) {
      ref.invalidate(staffPaymentHistoryProvider(_query));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment undone')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.danger),
      );
    }
  }

  Widget _pill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label: $value',
        style: AppTextStyles.caption.copyWith(color: color),
      ),
    );
  }
}

