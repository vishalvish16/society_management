import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/app_date_picker.dart';
import '../../../shared/widgets/show_app_sheet.dart';
import '../../bills/providers/bill_schedule_provider.dart';
import '../../plans/screens/plans_screen.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_searchable_dropdown.dart';

class BillScheduleScreen extends ConsumerWidget {
  const BillScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final hasBillSchedules = user?.hasFeature('bill_schedules') ?? false;
    final schedulesAsync = ref.watch(billSchedulesProvider);
    final notifier = ref.read(billSchedulesProvider.notifier);
    final isWide = MediaQuery.of(context).size.width >= 720;

    if (!hasBillSchedules && user?.role != 'SUPER_ADMIN') {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: isWide
            ? AppBar(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                title: const Text('Bill Schedule'),
              )
            : null,
        body: Column(
          children: [
            const AppPageHeader(
              title: 'Bill Schedule',
              icon: Icons.schedule_rounded,
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.screenPadding),
                  child: AppCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_rounded, size: 42, color: AppColors.warning),
                        const SizedBox(height: AppDimensions.md),
                        Text('Premium Feature', style: AppTextStyles.h2),
                        const SizedBox(height: AppDimensions.xs),
                        Text(
                          'Bill Schedule is available in the Premium plan.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppDimensions.lg),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PlansScreen()),
                            ),
                            icon: const Icon(Icons.workspace_premium_rounded),
                            label: const Text('View Plans'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              title: const Text('Bill Schedule'),
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUpsertSheet(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.schedule_rounded, color: AppColors.textOnPrimary),
        label: Text(
          'Set Schedule',
          style: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary),
        ),
      ),
      body: Column(
        children: [
          AppPageHeader(
            title: 'Bill Schedule',
            icon: Icons.schedule_rounded,
            actions: [
              IconButton(
                tooltip: 'Set Schedule',
                icon: const Icon(Icons.add_rounded),
                onPressed: () => _showUpsertSheet(context, ref),
              ),
            ],
          ),
          Expanded(
            child: schedulesAsync.when(
              loading: () => const AppLoadingShimmer(),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.screenPadding),
                  child: AppCard(
                    backgroundColor: AppColors.dangerSurface,
                    child: Text(
                      'Error: $e',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText),
                    ),
                  ),
                ),
              ),
              data: (schedules) {
                if (schedules.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => notifier.fetchSchedules(),
                    child: ListView(
                      children: const [
                        SizedBox(height: 80),
                        AppEmptyState(
                          emoji: '🗓️',
                          title: 'No Schedule Set',
                          subtitle:
                              'Set a schedule once and bills will generate automatically on that date & time.',
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => notifier.fetchSchedules(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppDimensions.screenPadding),
                    itemCount: schedules.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppDimensions.sm),
                    itemBuilder: (ctx, i) {
                      final s = schedules[i];
                      final billingMonth = _tryParseDate(s['billingMonth']);
                      final scheduledFor = _tryParseDate(s['scheduledFor']);
                      final dueDate = _tryParseDate(s['dueDate']);
                      final isActive = s['isActive'] == true;
                      final executedAt = _tryParseDate(s['executedAt']);
                      final defaultAmount =
                          double.tryParse(s['defaultAmount']?.toString() ?? '') ??
                              0;
                      final scheduleCategory =
                          (s['category'] as String? ?? 'MAINTENANCE')
                              .toUpperCase();

                      final monthLabel = billingMonth != null
                          ? DateFormat('MMM yyyy').format(billingMonth)
                          : '-';
                      final scheduledLabel = scheduledFor != null
                          ? DateFormat('dd MMM yyyy, hh:mm a')
                              .format(scheduledFor)
                          : '-';
                      final dueLabel = dueDate != null
                          ? DateFormat('dd MMM yyyy').format(dueDate)
                          : '-';

                      return AppCard(
                        padding: const EdgeInsets.all(AppDimensions.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    monthLabel,
                                    style: AppTextStyles.h3,
                                  ),
                                ),
                                _StatusPill(
                                  label: isActive ? 'ACTIVE' : 'INACTIVE',
                                  color: isActive
                                      ? AppColors.success
                                      : AppColors.textMuted,
                                  background: isActive
                                      ? AppColors.successSurface
                                      : AppColors.surfaceVariant,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.sm),
                            _kv(
                              'Type',
                              scheduleCategory == 'PARKING'
                                  ? 'Parking'
                                  : 'Maintenance',
                            ),
                            _kv('Schedule', scheduledLabel),
                            _kv('Amount', '₹${defaultAmount.toStringAsFixed(2)}'),
                            _kv('Due Date', dueLabel),
                            if (executedAt != null)
                              _kv(
                                'Executed',
                                DateFormat('dd MMM yyyy, hh:mm a')
                                    .format(executedAt),
                              ),
                            const SizedBox(height: AppDimensions.sm),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: () => _showUpsertSheet(
                                  context,
                                  ref,
                                  initial: s,
                                ),
                                icon:
                                    const Icon(Icons.edit_rounded, size: 18),
                                label: const Text('Edit'),
                              ),
                            ),
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

  static DateTime? _tryParseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              k,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ),
          Expanded(child: Text(v, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }

  Future<void> _showUpsertSheet(
    BuildContext context,
    WidgetRef ref, {
    Map<String, dynamic>? initial,
  }) async {
    final now = DateTime.now();
    final initialBillingMonth = _tryParseDate(initial?['billingMonth']) ?? DateTime(now.year, now.month, 1);
    final initialScheduledFor = _tryParseDate(initial?['scheduledFor']) ?? now.add(const Duration(minutes: 5));
    final initialDueDate = _tryParseDate(initial?['dueDate']) ?? now.add(const Duration(days: 10));
    final initialAmount = double.tryParse(initial?['defaultAmount']?.toString() ?? '') ?? 1000;
    final initialActive = initial?['isActive'] == false ? false : true;
    final rawCat = (initial?['category'] as String? ?? 'MAINTENANCE').toUpperCase();
    final initialScheduleCategory = rawCat == 'PARKING' ? 'PARKING' : 'MAINTENANCE';

    final amountController = TextEditingController(text: initialAmount.toStringAsFixed(0));
    DateTime billingMonth = DateTime(initialBillingMonth.year, initialBillingMonth.month, 1);
    DateTime scheduledFor = initialScheduledFor;
    DateTime dueDate = initialDueDate;
    bool isActive = initialActive;
    String scheduleCategory = initialScheduleCategory;
    bool isSaving = false;
    final hasParking =
        ref.read(authProvider).user?.hasFeature('parking_management') ?? false;

    await showAppSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => LayoutBuilder(
          builder: (ctx, constraints) => AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(
              AppDimensions.screenPadding,
              AppDimensions.lg,
              AppDimensions.screenPadding,
              MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.lg,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                    Text(
                      initial == null ? 'Set Bill Schedule' : 'Edit Bill Schedule',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      scheduleCategory == 'PARKING'
                          ? 'Parking: one bill per unit with an active parking allotment for the billing month.'
                          : 'Maintenance: bills for all occupied units (same as manual generate).',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    AppSearchableDropdown<String>(
                      label: 'Bill Type',
                      value: scheduleCategory,
                      items: [
                        const AppDropdownItem(
                          value: 'MAINTENANCE',
                          label: 'Maintenance',
                        ),
                        if (hasParking || scheduleCategory == 'PARKING')
                          const AppDropdownItem(value: 'PARKING', label: 'Parking'),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => scheduleCategory = v);
                      },
                    ),
                    const SizedBox(height: AppDimensions.md),
                    AppDateField(
                      label: 'Billing Month',
                      value: billingMonth,
                      onTap: () async {
                        final picked = await pickSingleDate(
                          ctx,
                          initial: billingMonth,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            billingMonth = DateTime(picked.year, picked.month, 1);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppDimensions.md),
                    AppDateField(
                      label: 'Schedule Date',
                      value: scheduledFor,
                      onTap: () async {
                        final picked = await pickSingleDate(
                          ctx,
                          initial: scheduledFor,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            scheduledFor = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              scheduledFor.hour,
                              scheduledFor.minute,
                            );
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: ctx,
                                initialTime: TimeOfDay.fromDateTime(scheduledFor),
                              );
                              if (picked == null) return;
                              setState(() {
                                scheduledFor = DateTime(
                                  scheduledFor.year,
                                  scheduledFor.month,
                                  scheduledFor.day,
                                  picked.hour,
                                  picked.minute,
                                );
                              });
                            },
                            icon: const Icon(Icons.access_time_rounded, size: 18),
                            label: Text(DateFormat('hh:mm a').format(scheduledFor)),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.md),
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Active'),
                            value: isActive,
                            onChanged: (v) => setState(() => isActive = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.md),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Default Amount',
                        prefixText: '₹',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    AppDateField(
                      label: 'Due Date',
                      value: dueDate,
                      onTap: () async {
                        final picked = await pickSingleDate(
                          ctx,
                          initial: dueDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => dueDate = picked);
                      },
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (isSaving) return;
                          final amount = double.tryParse(amountController.text) ?? 0;
                          if (amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid amount'),
                              ),
                            );
                            return;
                          }
                          setState(() => isSaving = true);
                          final error = await ref.read(billSchedulesProvider.notifier).upsertSchedule(
                                billingMonth: billingMonth,
                                scheduledFor: scheduledFor,
                                defaultAmount: amount,
                                dueDate: dueDate,
                                isActive: isActive,
                                category: scheduleCategory,
                              );
                          if (ctx.mounted) {
                            setState(() => isSaving = false);
                          }
                          if (!context.mounted) return;

                          if (error == null && ctx.mounted) {
                            Navigator.pop(ctx);
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error ?? 'Schedule saved successfully'),
                              backgroundColor: error == null ? AppColors.success : AppColors.danger,
                            ),
                          );
                        },
                        child: isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save Schedule'),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(ctx).padding.bottom),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  const _StatusPill({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

