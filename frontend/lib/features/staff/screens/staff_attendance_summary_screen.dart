import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../providers/staff_provider.dart';

class StaffAttendanceSummaryScreen extends ConsumerStatefulWidget {
  const StaffAttendanceSummaryScreen({super.key});

  @override
  ConsumerState<StaffAttendanceSummaryScreen> createState() =>
      _StaffAttendanceSummaryScreenState();
}

class _StaffAttendanceSummaryScreenState
    extends ConsumerState<StaffAttendanceSummaryScreen> {
  late DateTime _from;
  late DateTime _to;
  bool _paidLeave = false;
  double _halfDayFactor = 0.5;
  String _divisorMode = 'calendar'; // calendar | working
  bool _excludeSundays = true;
  bool _excludeSaturdays = false;
  final _holidaysCtrl = TextEditingController();
  String _paymentMethod = 'CASH';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0);
  }

  @override
  void dispose() {
    _holidaysCtrl.dispose();
    super.dispose();
  }

  String _d(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _rangeLabel => '${_d(_from)} → ${_d(_to)}';

  StaffAttendanceSummaryQuery get _query => StaffAttendanceSummaryQuery(
        from: _d(_from),
        to: _d(_to),
        paidLeave: _paidLeave,
        halfDayFactor: _halfDayFactor,
        divisorMode: _divisorMode,
        excludeSundays: _excludeSundays,
        excludeSaturdays: _excludeSaturdays,
        holidays: _holidaysCtrl.text.trim().isEmpty ? null : _holidaysCtrl.text.trim(),
      );

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: 'Select attendance period',
    );
    if (picked == null) return;
    setState(() {
      _from = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _to = DateTime(picked.end.year, picked.end.month, picked.end.day);
    });
  }

  String _csv(List<StaffAttendanceSummary> rows) {
    final b = StringBuffer();
    b.writeln(
        'Staff,Role,From,To,Present,HalfDay,Leave,Absent,PayableDays,PerDayRate,SalaryPayable,Paid,PaidAt,PaymentMethod');
    for (final r in rows) {
      final from = r.from != null ? _d(r.from!) : _d(_from);
      final to = r.to != null ? _d(r.to!) : _d(_to);
      final name = r.name.replaceAll('"', '""');
      final role = r.role.replaceAll('"', '""');
      final paid = r.payment != null ? 'YES' : 'NO';
      final paidAt = r.payment?.paidAt != null ? _d(r.payment!.paidAt!) : '';
      final pm = r.payment?.paymentMethod ?? '';
      b.writeln(
          '"$name","$role",$from,$to,${r.present},${r.halfDay},${r.leave},${r.absent},${r.payableDays.toStringAsFixed(1)},${r.perDayRate.toStringAsFixed(2)},${r.salaryPayable.toStringAsFixed(2)},$paid,$paidAt,$pm');
    }
    return b.toString();
  }

  Future<void> _markPaid(StaffAttendanceSummary r) async {
    final noteCtrl = TextEditingController(text: r.payment?.note ?? '');
    String method = r.payment?.paymentMethod ?? _paymentMethod;
    bool saving = false;
    String? err;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.screenPadding,
            AppDimensions.md,
            AppDimensions.screenPadding,
            MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mark salary paid', style: AppTextStyles.h1),
              const SizedBox(height: 4),
              Text('${r.name} • $_rangeLabel',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppDimensions.md),
              Text(
                'Amount: ₹${r.salaryPayable.toStringAsFixed(0)}',
                style: AppTextStyles.h3.copyWith(color: AppColors.success),
              ),
              const SizedBox(height: AppDimensions.md),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: const [
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                  DropdownMenuItem(value: 'ONLINE', child: Text('Online')),
                  DropdownMenuItem(value: 'RAZORPAY', child: Text('Razorpay')),
                ],
                onChanged: saving ? null : (v) => setS(() => method = v ?? 'CASH'),
              ),
              const SizedBox(height: AppDimensions.sm),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'Txn id / remarks',
                ),
                minLines: 1,
                maxLines: 3,
                enabled: !saving,
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
              ],
              const SizedBox(height: AppDimensions.lg),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setS(() {
                            saving = true;
                            err = null;
                          });
                          final submit = ref.read(staffMarkSalaryPaidProvider);
                          final e = await submit({
                            'staffId': r.staffId,
                            'from': _d(_from),
                            'to': _d(_to),
                            'amount': r.salaryPayable,
                            'paymentMethod': method,
                            'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                            'divisorDays': r.divisorDays,
                            'rules': {
                              'paidLeave': _paidLeave,
                              'halfDayFactor': _halfDayFactor,
                              'divisorMode': _divisorMode,
                              'excludeSundays': _excludeSundays,
                              'excludeSaturdays': _excludeSaturdays,
                              'holidays': _holidaysCtrl.text.trim(),
                            }
                          });
                          if (!mounted || !ctx.mounted) return;
                          if (e == null) {
                            _paymentMethod = method;
                            Navigator.pop(ctx);
                            ref.invalidate(staffAttendanceSummaryProvider(_query));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Marked as paid')),
                            );
                          } else {
                            setS(() {
                              saving = false;
                              err = e;
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Mark Paid'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    noteCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(staffAttendanceSummaryProvider(_query));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'Attendance Summary',
          style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary),
        ),
        actions: [
          TextButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_rounded,
                color: AppColors.textOnPrimary),
            label: Text(
              _rangeLabel,
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.textOnPrimary),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: summaryAsync.when(
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
                    child: Text(
                      'Failed to load summary: $e',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.dangerText),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(
                        staffAttendanceSummaryProvider(_query)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(AppDimensions.screenPadding),
              children: [
                _rulesCard(rows),
                const SizedBox(height: AppDimensions.sm),
                const AppEmptyState(
                  emoji: '📅',
                  title: 'No data',
                  subtitle: 'No attendance summary found for this period.',
                ),
              ],
            );
          }

          final totalPayable =
              rows.fold<double>(0, (s, r) => s + r.salaryPayable);
          final totalPresent =
              rows.fold<int>(0, (s, r) => s + r.present);
          final totalHalfDay =
              rows.fold<int>(0, (s, r) => s + r.halfDay);
          final totalLeave =
              rows.fold<int>(0, (s, r) => s + r.leave);

          return ListView(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            children: [
              _rulesCard(rows),
              const SizedBox(height: AppDimensions.sm),
              AppCard(
                padding: const EdgeInsets.all(AppDimensions.md),
                child: Row(
                  children: [
                    const Icon(Icons.summarize_rounded,
                        color: AppColors.primary),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Period: $_rangeLabel',
                              style: AppTextStyles.h3),
                          const SizedBox(height: 2),
                          Text(
                            'Present: $totalPresent • Half days: $totalHalfDay • Leave: $totalLeave',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${totalPayable.toStringAsFixed(0)}',
                      style: AppTextStyles.h3.copyWith(color: AppColors.success),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              ...rows.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppDimensions.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(r.name, style: AppTextStyles.h3),
                              ),
                              Text(
                                '₹${r.salaryPayable.toStringAsFixed(0)}',
                                style: AppTextStyles.h3
                                    .copyWith(color: AppColors.success),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r.role,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: AppDimensions.sm),
                          Row(
                            children: [
                              if (r.payment != null)
                                _pill('Paid', 'YES', AppColors.success)
                              else
                                _pill('Paid', 'NO', AppColors.danger),
                              const Spacer(),
                              if (r.payment == null)
                                OutlinedButton.icon(
                                  onPressed: () => _markPaid(r),
                                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                                  label: const Text('Mark Paid'),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.sm),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: [
                              _pill('Present', r.present.toString(),
                                  AppColors.success),
                              _pill('Half', r.halfDay.toString(),
                                  AppColors.warning),
                              _pill('Absent', r.absent.toString(),
                                  AppColors.danger),
                              _pill('Leave', r.leave.toString(),
                                  AppColors.textMuted),
                              _pill('Payable days',
                                  r.payableDays.toStringAsFixed(1),
                                  AppColors.primary),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.sm),
                          Text(
                            'Rate: ₹${r.perDayRate.toStringAsFixed(2)}/day (Monthly ₹${r.monthlySalary.toStringAsFixed(0)} ÷ ${r.divisorDays} days)',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _rulesCard(List<StaffAttendanceSummary> rows) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Payroll rules', style: AppTextStyles.h3),
              ),
              TextButton.icon(
                onPressed: rows.isEmpty
                    ? null
                    : () async {
                        final text = _csv(rows);
                        await Clipboard.setData(ClipboardData(text: text));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('CSV copied to clipboard')),
                          );
                        }
                      },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy CSV'),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: rows.isEmpty
                      ? null
                      : () => _markAllUnpaidPaid(rows),
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Mark all unpaid as paid'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'calendar', label: Text('Calendar days')),
              ButtonSegment(value: 'working', label: Text('Working days')),
            ],
            selected: {_divisorMode},
            onSelectionChanged: (s) =>
                setState(() => _divisorMode = s.first),
          ),
          const SizedBox(height: AppDimensions.sm),
          if (_divisorMode == 'working') ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exclude Sundays'),
              value: _excludeSundays,
              onChanged: (v) => setState(() => _excludeSundays = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exclude Saturdays'),
              value: _excludeSaturdays,
              onChanged: (v) => setState(() => _excludeSaturdays = v),
            ),
            TextField(
              controller: _holidaysCtrl,
              decoration: const InputDecoration(
                labelText: 'Holidays (optional)',
                hintText: '2026-05-01, 2026-05-08',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppDimensions.sm),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Treat leave as paid'),
            value: _paidLeave,
            onChanged: (v) => setState(() => _paidLeave = v),
          ),
          const SizedBox(height: 6),
          Text(
            'Half-day counts as: ${_halfDayFactor.toStringAsFixed(2)} day',
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          Slider(
            value: _halfDayFactor,
            min: 0,
            max: 1,
            divisions: 20,
            label: _halfDayFactor.toStringAsFixed(2),
            onChanged: (v) => setState(() => _halfDayFactor = v),
          ),
        ],
      ),
    );
  }

  Future<void> _markAllUnpaidPaid(List<StaffAttendanceSummary> rows) async {
    final unpaid = rows.where((r) => r.payment == null).toList();
    if (unpaid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All staff already marked as paid')),
      );
      return;
    }

    final noteCtrl = TextEditingController();
    String method = _paymentMethod;
    bool saving = false;
    String? err;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.screenPadding,
            AppDimensions.md,
            AppDimensions.screenPadding,
            MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mark all unpaid as paid', style: AppTextStyles.h1),
              const SizedBox(height: 4),
              Text(
                'Unpaid staff: ${unpaid.length} • Period: $_rangeLabel',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppDimensions.md),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: const [
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                  DropdownMenuItem(value: 'ONLINE', child: Text('Online')),
                  DropdownMenuItem(value: 'RAZORPAY', child: Text('Razorpay')),
                ],
                onChanged: saving ? null : (v) => setS(() => method = v ?? 'CASH'),
              ),
              const SizedBox(height: AppDimensions.sm),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'Txn id / remarks (applies to all)',
                ),
                minLines: 1,
                maxLines: 3,
                enabled: !saving,
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
              ],
              const SizedBox(height: AppDimensions.lg),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setS(() {
                            saving = true;
                            err = null;
                          });
                          final submit = ref.read(staffMarkSalaryPaidBulkProvider);
                          final e = await submit({
                            'from': _d(_from),
                            'to': _d(_to),
                            'paymentMethod': method,
                            'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                            'rules': {
                              'paidLeave': _paidLeave,
                              'halfDayFactor': _halfDayFactor,
                              'divisorMode': _divisorMode,
                              'excludeSundays': _excludeSundays,
                              'excludeSaturdays': _excludeSaturdays,
                              'holidays': _holidaysCtrl.text.trim(),
                            }
                          });
                          if (!mounted || !ctx.mounted) return;
                          if (e == null) {
                            _paymentMethod = method;
                            Navigator.pop(ctx);
                            ref.invalidate(staffAttendanceSummaryProvider(_query));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Marked unpaid staff as paid')),
                            );
                          } else {
                            setS(() {
                              saving = false;
                              err = e;
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirm'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    noteCtrl.dispose();
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

