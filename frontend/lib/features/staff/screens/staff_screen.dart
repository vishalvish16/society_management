import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/staff_provider.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../shared/widgets/app_searchable_dropdown.dart';
import '../../../shared/widgets/show_app_sheet.dart';

const _roles = [
  'watchman',
  'housekeeping',
  'maintenance',
  'driver',
  'gardener',
  'sweeper',
  'electrician',
  'plumber',
  'other',
];

const _attendanceStatuses = ['present', 'absent', 'half_day', 'leave'];

const _shiftFormValues = <String>['day', 'night', 'full'];

String _shiftFormFromApi(String shift) {
  switch (shift.toUpperCase()) {
    case 'DAY':
      return 'day';
    case 'NIGHT':
      return 'night';
    default:
      return 'full';
  }
}

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  bool _canManage(WidgetRef ref) {
    final user = ref.read(authProvider).user;
    if (user == null) return false;
    return ['PRAMUKH', 'CHAIRMAN', 'SECRETARY'].contains(user.role);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffProvider);
    final canManage = _canManage(ref);

    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? AppBar(
              backgroundColor: AppColors.primary,
              title: Text('Staff',
                  style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
              actions: [
                if (canManage)
                  IconButton(
                    tooltip: 'Attendance Summary',
                    onPressed: () => context.push('/staff/attendance-summary'),
                    icon: const Icon(Icons.summarize_rounded,
                        color: AppColors.textOnPrimary),
                  ),
                if (canManage)
                  IconButton(
                    tooltip: 'Bulk Attendance',
                    onPressed: () => context.push('/staff/attendance-bulk'),
                    icon: const Icon(Icons.fact_check_rounded,
                        color: AppColors.textOnPrimary),
                  ),
                if (canManage)
                  IconButton(
                    tooltip: 'Payment History',
                    onPressed: () => context.push('/staff/payment-history'),
                    icon: const Icon(Icons.payments_rounded,
                        color: AppColors.textOnPrimary),
                  ),
              ],
            )
          : null,
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEditDialog(context, ref),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.person_add_rounded,
                  color: AppColors.textOnPrimary),
              label: Text('Add Staff',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textOnPrimary)),
            )
          : null,
      body: staffAsync.when(
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
                    child: Text('Failed to load staff: $e',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.dangerText)),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(staffProvider.notifier).loadStaff(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (staff) {
          if (staff.isEmpty) {
            return const AppEmptyState(
              emoji: '👷',
              title: 'No Staff',
              subtitle: 'No staff members have been added yet.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(staffProvider.notifier).loadStaff(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppDimensions.screenPadding),
              itemCount: staff.length + (isWide ? 0 : 1),
              separatorBuilder: (_, i) => i == 0 && !isWide
                  ? const SizedBox(height: AppDimensions.md)
                  : const SizedBox(height: AppDimensions.sm),
              itemBuilder: (_, i) {
                if (!isWide && i == 0) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text('Staff', style: AppTextStyles.h2),
                      ),
                      if (canManage)
                        Wrap(
                          spacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: () => context.push('/staff/attendance-summary'),
                              icon: const Icon(Icons.summarize_rounded, size: 18),
                              label: const Text('Summary'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.push('/staff/attendance-bulk'),
                              icon: const Icon(Icons.fact_check_rounded, size: 18),
                              label: const Text('Bulk'),
                            ),
                          ],
                        ),
                    ],
                  );
                }
                final idx = i - (isWide ? 0 : 1);
                final s = staff[idx];
                final todayStatus = (s.lastAttendanceStatus == 'PRESENT')
                    ? 'PRESENT'
                    : 'ABSENT';
                return AppCard(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  leftBorderColor:
                      s.isActive ? AppColors.success : AppColors.textMuted,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: s.isActive
                            ? AppColors.primarySurface
                            : AppColors.background,
                        child: Text(
                          s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                          style: AppTextStyles.h3.copyWith(
                            color: s.isActive
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: AppTextStyles.h3.copyWith(
                                color: s.isActive
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                                decoration: s.isActive
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.xs),
                            Text(
                              '${s.role}${s.phone != null ? ' • ${s.phone}' : ''}',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textMuted),
                            ),
                            Text(
                              '${s.shiftLabel}'
                              '${s.gateDisplay != null ? ' • ${s.gateDisplay}' : ''}'
                              '${s.assignedWingCodes.isNotEmpty ? ' • Wings: ${s.assignedWingCodes.join(', ')}' : ''}',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                            Text(
                              '₹${s.salary.toStringAsFixed(0)}/mo',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AppStatusChip(status: todayStatus),
                          if (canManage) ...[
                            const SizedBox(height: AppDimensions.xs),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.how_to_reg_outlined,
                                      size: 18, color: AppColors.success),
                                  tooltip: 'Mark Attendance',
                                  onPressed: () => _showAttendanceDialog(
                                      context, ref, s),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18, color: AppColors.primary),
                                  tooltip: 'Edit',
                                  onPressed: () =>
                                      _showAddEditDialog(context, ref, staff: s),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18, color: AppColors.danger),
                                  tooltip: 'Deactivate',
                                  onPressed: () =>
                                      _confirmDelete(context, ref, s),
                                ),
                                if (s.role == 'watchman')
                                  IconButton(
                                    icon: const Icon(Icons.lock_reset,
                                        size: 18, color: AppColors.textMuted),
                                    tooltip: s.hasLoginAccount
                                        ? 'Reset Login Password'
                                        : 'Set Login Password',
                                    onPressed: () =>
                                        _showResetPasswordDialog(context, ref, s),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, WidgetRef ref, StaffMember staff) {
    final passCtrl = TextEditingController();
    bool saving = false;
    String? error;

    showAppSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
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
              Text(staff.hasLoginAccount ? 'Reset Login Password' : 'Set Login Password',
                  style: AppTextStyles.h1),
              const SizedBox(height: 4),
              Text('Watchman: ${staff.name}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppDimensions.lg),
              AppTextField(
                label: 'New Password (min 6 chars)',
                controller: passCtrl,
                obscureText: true,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
              ],
              const SizedBox(height: AppDimensions.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : () async {
                    if (passCtrl.text.trim().length < 6) {
                      setS(() => error = 'Password must be at least 6 characters');
                      return;
                    }
                    setS(() { saving = true; error = null; });
                    final err = await ref.read(staffProvider.notifier)
                        .resetWatchmanPassword(staff.id, passCtrl.text.trim());
                    if (ctx.mounted) {
                      if (err == null) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password reset successfully')),
                        );
                      } else {
                        setS(() { saving = false; error = err; });
                      }
                    }
                  },
                  child: saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(staff.hasLoginAccount ? 'Reset Password' : 'Set Password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, WidgetRef ref,
      {StaffMember? staff}) {
    final isEdit = staff != null;
    final nameCtrl = TextEditingController(text: staff?.name);
    final phoneCtrl = TextEditingController(text: staff?.phone);
    final passCtrl = TextEditingController();
    final newGateCtrl = TextEditingController();
    final salaryCtrl =
        TextEditingController(text: staff?.salary.toStringAsFixed(0) ?? '');
    String role = staff?.role ?? _roles.first;
    bool isActive = staff?.isActive ?? true;
    String shiftForm = _shiftFormFromApi(staff?.shift ?? 'FULL');
    String? gateIdVal = staff?.gateId;
    final selectedWings = <String>{...(staff?.assignedWingCodes ?? const [])};
    var gatesLoaded = <Map<String, dynamic>>[];
    var wingsLoaded = <String>[];
    var metaReady = false;
    var loadScheduled = false;
    String? gateAddError;

    showAppSheet(
      context: context,
      builder: (ctx) {
        bool saving = false;
        bool addingGate = false;
        String? sheetError;
        return StatefulBuilder(
          builder: (ctx, setDlgState) => Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimensions.screenPadding, AppDimensions.lg,
              AppDimensions.screenPadding,
              MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.xxxl,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: AppDimensions.lg),
                  Text(isEdit ? 'Edit Staff' : 'Add Staff', style: AppTextStyles.h1),
                  const SizedBox(height: AppDimensions.lg),
                  AppTextField(label: 'Full Name *', controller: nameCtrl),
                  const SizedBox(height: AppDimensions.md),
                  AppTextField(label: 'Phone', controller: phoneCtrl, keyboardType: TextInputType.phone),
                  const SizedBox(height: AppDimensions.md),
                  AppTextField(label: 'Monthly Salary (₹) *', controller: salaryCtrl, keyboardType: TextInputType.number),
                  const SizedBox(height: AppDimensions.md),
                  AppSearchableDropdown<String>(
                    label: 'Role / Job Type',
                    value: _roles.contains(role) ? role : _roles.first,
                    items: _roles.map((r) => AppDropdownItem(value: r, label: r)).toList(),
                    onChanged: (v) => setDlgState(() => role = v ?? _roles.first),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Builder(builder: (_) {
                    if (!loadScheduled) {
                      loadScheduled = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        try {
                          final dio = ref.read(dioProvider);
                          final gr = await dio.get('gates');
                          final wr = await dio.get('units/wings');
                          if (!ctx.mounted) return;
                          setDlgState(() {
                            gatesLoaded = List<Map<String, dynamic>>.from(
                                gr.data['data']?['gates'] ?? []);
                            wingsLoaded = List<String>.from(
                                wr.data['data']?['wings'] ?? []);
                            for (final w in selectedWings) {
                              if (!wingsLoaded.contains(w)) wingsLoaded.add(w);
                            }
                            wingsLoaded.sort();
                            metaReady = true;
                          });
                        } catch (_) {
                          if (ctx.mounted) setDlgState(() => metaReady = true);
                        }
                      });
                    }
                    return const SizedBox.shrink();
                  }),
                  if (!metaReady)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppDimensions.sm),
                      child: LinearProgressIndicator(),
                    ),
                  DropdownButtonFormField<String>(
                    initialValue: _shiftFormValues.contains(shiftForm) ? shiftForm : 'full',
                    decoration: const InputDecoration(labelText: 'Duty shift'),
                    items: const [
                      DropdownMenuItem(value: 'day', child: Text('Day shift')),
                      DropdownMenuItem(value: 'night', child: Text('Night shift')),
                      DropdownMenuItem(
                          value: 'full',
                          child: Text('Full day / not split by shift')),
                    ],
                    onChanged: metaReady
                        ? (v) => setDlgState(() => shiftForm = v ?? 'full')
                        : null,
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    'Posted at one gate at a time. Wings list covers areas they service (e.g. one maintenance person for Wing A and B).',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  DropdownButtonFormField<String?>(
                    initialValue: gateIdVal != null &&
                            gatesLoaded.any((g) => g['id']?.toString() == gateIdVal)
                        ? gateIdVal
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Posted at gate (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('— No specific gate —'),
                      ),
                      ...gatesLoaded.map((g) {
                        final id = g['id']?.toString() ?? '';
                        final name = g['name']?.toString() ?? '';
                        final code = g['code']?.toString();
                        final label = (code != null && code.isNotEmpty)
                            ? '$code · $name'
                            : name;
                        return DropdownMenuItem<String?>(
                          value: id,
                          child: Text(label),
                        );
                      }),
                    ],
                    onChanged: metaReady
                        ? (v) => setDlgState(() => gateIdVal = v)
                        : null,
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Add new gate to society',
                          controller: newGateCtrl,
                          enabled: metaReady,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: IconButton.filledTonal(
                          tooltip: 'Add gate',
                          onPressed: !metaReady || addingGate
                              ? null
                              : () async {
                                  final name = newGateCtrl.text.trim();
                                  if (name.isEmpty) return;
                                  setDlgState(() {
                                    gateAddError = null;
                                    addingGate = true;
                                  });
                                  try {
                                    final dio = ref.read(dioProvider);
                                    final res = await dio.post('gates', data: {
                                      'name': name,
                                    });
                                    if (!ctx.mounted) return;
                                    if (res.data['success'] == true) {
                                      final g = res.data['data'] as Map<String, dynamic>?;
                                      newGateCtrl.clear();
                                      setDlgState(() {
                                        if (g != null) {
                                          gatesLoaded = [
                                            ...gatesLoaded,
                                            g,
                                          ];
                                          gateIdVal = g['id']?.toString();
                                        }
                                        addingGate = false;
                                      });
                                    } else {
                                      setDlgState(() {
                                        addingGate = false;
                                        gateAddError = res.data['message']?.toString() ??
                                            'Could not add gate';
                                      });
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      setDlgState(() {
                                        addingGate = false;
                                        gateAddError = 'Could not add gate';
                                      });
                                    }
                                  }
                                },
                          icon: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                  if (gateAddError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        gateAddError!,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.danger),
                      ),
                    ),
                  const SizedBox(height: AppDimensions.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Wings covered (optional)',
                      style: AppTextStyles.labelLarge,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  if (wingsLoaded.isEmpty && selectedWings.isEmpty)
                    Text(
                      'No wings found on units yet. Add a wing on units, or type a code below.',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ...({...wingsLoaded, ...selectedWings}.toList()..sort())
                            .map((w) {
                          final on = selectedWings.contains(w);
                          return FilterChip(
                            label: Text(w),
                            selected: on,
                            onSelected: metaReady
                                ? (v) => setDlgState(() {
                                      if (v) {
                                        selectedWings.add(w);
                                      } else {
                                        selectedWings.remove(w);
                                      }
                                    })
                                : null,
                          );
                        }),
                      ],
                    ),
                  if (!isEdit && role == 'watchman') ...[
                    const SizedBox(height: AppDimensions.sm),
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Watchman will get an app login using their phone number and password below.',
                              style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    AppTextField(
                      label: 'Login Password * (min 6 chars)',
                      controller: passCtrl,
                      obscureText: true,
                    ),
                  ],
                  if (isEdit) ...[
                    const SizedBox(height: AppDimensions.md),
                    SwitchListTile(
                      title: const Text('Active'),
                      value: isActive,
                      onChanged: (v) => setDlgState(() => isActive = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                  if (sheetError != null) ...[
                    const SizedBox(height: AppDimensions.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.sm),
                      decoration: BoxDecoration(
                        color: AppColors.dangerSurface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: Text(
                        sheetError!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.lg),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: saving ? null : () async {
                        if (nameCtrl.text.trim().isEmpty || salaryCtrl.text.trim().isEmpty) {
                          setDlgState(() => sheetError = 'Name and salary are required');
                          return;
                        }
                        if (!isEdit && role == 'watchman') {
                          if (phoneCtrl.text.trim().isEmpty) {
                            setDlgState(() => sheetError = 'Phone is required for watchman login');
                            return;
                          }
                          if (passCtrl.text.trim().length < 6) {
                            setDlgState(() => sheetError = 'Password must be at least 6 characters');
                            return;
                          }
                        }
                        
                        setDlgState(() {
                          saving = true;
                          sheetError = null;
                        });

                        final data = <String, dynamic>{
                          'name': nameCtrl.text.trim(),
                          'role': role,
                          'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          'salary': double.tryParse(salaryCtrl.text.trim()) ?? 0,
                          'shift': shiftForm,
                          'assignedWingCodes': selectedWings.toList(),
                          if (isEdit) 'isActive': isActive,
                          if (!isEdit && role == 'watchman') 'password': passCtrl.text.trim(),
                        };
                        if (isEdit) {
                          data['gateId'] = gateIdVal;
                        } else if (gateIdVal != null) {
                          data['gateId'] = gateIdVal;
                        }
                        
                        final error = isEdit
                            ? await ref.read(staffProvider.notifier).updateStaff(staff.id, data)
                            : await ref.read(staffProvider.notifier).createStaff(data);
                        
                        if (ctx.mounted) {
                          if (error == null) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isEdit ? 'Staff updated' : 'Staff added')),
                            );
                          } else {
                            setDlgState(() {
                              saving = false;
                              sheetError = error;
                            });
                          }
                        }
                      },
                      child: saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isEdit ? 'Update Staff' : 'Add Staff'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAttendanceDialog(BuildContext context, WidgetRef ref, StaffMember staff) {
    String status = (staff.lastAttendanceStatus ?? 'PRESENT').toLowerCase();
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    showAppSheet(
      context: context,
      builder: (ctx) {
        bool saving = false;
        String? sheetError;
        return StatefulBuilder(
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
                const Text('Mark Attendance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: AppDimensions.xs),
                Text(staff.name, style: AppTextStyles.h3),
                Text(dateStr, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: AppDimensions.lg),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _attendanceStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setDlgState(() => status = v ?? 'present'),
                ),
                if (sheetError != null) ...[
                  const SizedBox(height: AppDimensions.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimensions.sm),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSurface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: Text(
                      sheetError!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText),
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.lg),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: saving ? null : () async {
                      setDlgState(() {
                        saving = true;
                        sheetError = null;
                      });
                      final error = await ref.read(staffProvider.notifier).markAttendance(staff.id, dateStr, status);
                      if (ctx.mounted) {
                        if (error == null) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Attendance marked')),
                          );
                        } else {
                          setDlgState(() {
                            saving = false;
                            sheetError = error;
                          });
                        }
                      }
                    },
                    child: saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Mark Attendance'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, StaffMember staff) async {
    final confirmed = await showConfirmSheet(
      context: context,
      title: 'Deactivate Staff',
      message: 'Deactivate ${staff.name}? They will no longer appear as active staff.',
      confirmLabel: 'Deactivate',
    );
    if (confirmed && context.mounted) {
      final error = await ref.read(staffProvider.notifier).deleteStaff(staff.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Staff deactivated'),
            backgroundColor: error == null ? AppColors.success : AppColors.danger,
          ),
        );
      }
    }
  }
}
