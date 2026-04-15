import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../../shared/widgets/app_searchable_dropdown.dart';
import '../../../shared/widgets/show_app_dialog.dart';

const _roles = [
  'watchman',
  'housekeeping',
  'driver',
  'gardener',
  'sweeper',
  'electrician',
  'plumber',
  'other',
];

const _attendanceStatuses = ['present', 'absent', 'half_day', 'leave'];

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Staff',
            style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
      ),
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
              itemCount: staff.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppDimensions.sm),
              itemBuilder: (_, i) {
                final s = staff[i];
                final attendanceStatus = s.lastAttendanceStatus;
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
                          if (attendanceStatus != null)
                            AppStatusChip(status: attendanceStatus),
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

  void _showAddEditDialog(BuildContext context, WidgetRef ref,
      {StaffMember? staff}) {
    final isEdit = staff != null;
    final nameCtrl = TextEditingController(text: staff?.name);
    final phoneCtrl = TextEditingController(text: staff?.phone);
    final salaryCtrl =
        TextEditingController(text: staff?.salary.toStringAsFixed(0) ?? '');
    String role = staff?.role ?? _roles.first;
    bool isActive = staff?.isActive ?? true;

    showAppSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
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
                if (isEdit) ...[
                  const SizedBox(height: AppDimensions.md),
                  SwitchListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setDlgState(() => isActive = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
                const SizedBox(height: AppDimensions.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty || salaryCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Name and salary are required')),
                        );
                        return;
                      }
                      final data = <String, dynamic>{
                        'name': nameCtrl.text.trim(),
                        'role': role,
                        'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                        'salary': double.tryParse(salaryCtrl.text.trim()) ?? 0,
                        if (isEdit) 'isActive': isActive,
                      };
                      final success = isEdit
                          ? await ref.read(staffProvider.notifier).updateStaff(staff.id, data)
                          : await ref.read(staffProvider.notifier).createStaff(data);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(success ? (isEdit ? 'Staff updated' : 'Staff added') : 'Failed')),
                        );
                      }
                    },
                    child: Text(isEdit ? 'Update Staff' : 'Add Staff'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAttendanceDialog(BuildContext context, WidgetRef ref, StaffMember staff) {
    String status = staff.lastAttendanceStatus ?? 'present';
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

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
              const SizedBox(height: AppDimensions.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final success = await ref.read(staffProvider.notifier).markAttendance(staff.id, dateStr, status);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(success ? 'Attendance marked' : 'Failed')),
                      );
                    }
                  },
                  child: const Text('Mark Attendance'),
                ),
              ),
            ],
          ),
        ),
      ),
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
      final success = await ref.read(staffProvider.notifier).deleteStaff(staff.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'Staff deactivated' : 'Failed')),
        );
      }
    }
  }
}
