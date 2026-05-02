import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../providers/staff_provider.dart';

const _statusOptions = <String, String>{
  'PRESENT': 'Present',
  'ABSENT': 'Absent',
  'HALF_DAY': 'Half day',
  'LEAVE': 'Leave',
};

class StaffBulkAttendanceScreen extends ConsumerStatefulWidget {
  const StaffBulkAttendanceScreen({super.key});

  @override
  ConsumerState<StaffBulkAttendanceScreen> createState() =>
      _StaffBulkAttendanceScreenState();
}

class _StaffBulkAttendanceScreenState
    extends ConsumerState<StaffBulkAttendanceScreen> {
  late DateTime _date;
  final Map<String, String> _selected = {}; // staffId -> STATUS
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  String _d(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _dateKey => _d(_date);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      helpText: 'Select attendance date',
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      _selected.clear();
      _error = null;
    });
  }

  void _setAll(String status, List<StaffAttendanceSheetRow> rows) {
    setState(() {
      _error = null;
      for (final r in rows) {
        _selected[r.staffId] = status;
      }
    });
  }

  Future<void> _save(List<StaffAttendanceSheetRow> rows) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final records = <Map<String, dynamic>>[];
    for (final r in rows) {
      final s = _selected[r.staffId] ?? r.status;
      if (s == null) continue;
      records.add({'staffId': r.staffId, 'status': s.toLowerCase()});
    }
    if (records.isEmpty) {
      setState(() {
        _saving = false;
        _error = 'No attendance selected';
      });
      return;
    }

    final submit = ref.read(staffBulkAttendanceSubmitProvider);
    final err = await submit(_dateKey, records);
    if (!mounted) return;

    if (err == null) {
      ref.invalidate(staffAttendanceSheetProvider(_dateKey));
      ref.invalidate(staffProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance saved')),
      );
      setState(() => _saving = false);
      return;
    }
    setState(() {
      _saving = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sheetAsync = ref.watch(staffAttendanceSheetProvider(_dateKey));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'Bulk Attendance',
          style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary),
        ),
        actions: [
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_rounded,
                color: AppColors.textOnPrimary),
            label: Text(
              _dateKey,
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.textOnPrimary),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: sheetAsync.when(
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
                      'Failed to load sheet: $e',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.dangerText),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(staffAttendanceSheetProvider(_dateKey)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const AppEmptyState(
              emoji: '🧾',
              title: 'No staff',
              subtitle: 'Add staff members first.',
            );
          }

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
                          child: Text('Quick actions', style: AppTextStyles.h3),
                        ),
                        FilledButton(
                          onPressed: _saving ? null : () => _save(rows),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton(
                          onPressed:
                              _saving ? null : () => _setAll('PRESENT', rows),
                          child: const Text('All Present'),
                        ),
                        OutlinedButton(
                          onPressed:
                              _saving ? null : () => _setAll('ABSENT', rows),
                          child: const Text('All Absent'),
                        ),
                        OutlinedButton(
                          onPressed:
                              _saving ? null : () => _setAll('LEAVE', rows),
                          child: const Text('All Leave'),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppDimensions.sm),
                      Text(
                        _error!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.danger),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              ...rows.map((r) {
                final current = _selected[r.staffId] ?? r.status ?? 'PRESENT';
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppDimensions.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.name, style: AppTextStyles.h3),
                              const SizedBox(height: 2),
                              Text(
                                r.role,
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppDimensions.sm),
                        SizedBox(
                          width: 140,
                          child: DropdownButtonFormField<String>(
                            initialValue: _statusOptions.containsKey(current)
                                ? current
                                : 'PRESENT',
                            decoration:
                                const InputDecoration(labelText: 'Status'),
                            items: _statusOptions.entries
                                .map((e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value),
                                    ))
                                .toList(),
                            onChanged: _saving
                                ? null
                                : (v) => setState(() {
                                      if (v == null) return;
                                      _selected[r.staffId] = v;
                                    }),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

