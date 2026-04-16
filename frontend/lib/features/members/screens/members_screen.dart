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
import '../providers/members_provider.dart';
import '../../units/providers/unit_provider.dart';
import '../../../shared/widgets/app_searchable_dropdown.dart';
import '../../../shared/widgets/show_app_sheet.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
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
      ref.read(membersProvider.notifier).loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);
    final notifier = ref.read(membersProvider.notifier);
    final currentUser = ref.watch(authProvider).user;
    final canManage = !(currentUser?.isUnitLocked ?? false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'Members',
          style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(
          Icons.person_add_rounded,
          color: AppColors.textOnPrimary,
        ),
        label: Text(
          'Add Member',
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.textOnPrimary,
          ),
        ),
      ),
      body: membersAsync.when(
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
                      'Failed to load members: $e',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.dangerText,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(membersProvider.notifier).loadMembers(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (members) {
          if (members.isEmpty) {
            return const AppEmptyState(
              emoji: '👥',
              title: 'No Members',
              subtitle: 'No members have been added yet.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(membersProvider.notifier).loadMembers(),
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppDimensions.screenPadding),
              itemCount: members.length + (notifier.hasMore ? 1 : 0),
              separatorBuilder: (_, index) =>
                  const SizedBox(height: AppDimensions.sm),
              itemBuilder: (_, i) {
                if (i == members.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppDimensions.md),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final m = members[i];
                return AppCard(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  leftBorderColor: m.isActive
                      ? AppColors.success
                      : AppColors.textMuted,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: m.isActive
                            ? AppColors.primarySurface
                            : AppColors.background,
                        child: Text(
                          m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                          style: AppTextStyles.h3.copyWith(
                            color: m.isActive
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
                              m.name,
                              style: AppTextStyles.h3.copyWith(
                                color: m.isActive
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                                decoration: m.isActive
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.xs),
                            Text(
                              '${m.unitCode} • ${m.phone}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AppStatusChip(
                            status: m.isActive ? m.role : 'Disabled',
                          ),
                          if (canManage) ...[
                            const SizedBox(height: AppDimensions.xs),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  onPressed: () => _showAddEditDialog(
                                    context,
                                    ref,
                                    member: m,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.lock_reset,
                                    size: 18,
                                    color: AppColors.warning,
                                  ),
                                  onPressed: () => _showResetPasswordDialog(
                                    context,
                                    ref,
                                    m.id,
                                    m.name,
                                  ),
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

  void _showAddEditDialog(
    BuildContext context,
    WidgetRef ref, {
    Member? member,
  }) {
    final isEdit = member != null;
    final nameCtrl = TextEditingController(text: member?.name);
    final phoneCtrl = TextEditingController(text: member?.phone);
    final emailCtrl = TextEditingController(text: member?.email);
    final passCtrl = TextEditingController();
    String role = member?.role ?? 'MEMBER';
    bool isActive = member?.isActive ?? true;

    const privilegedRoles = {
      'PRAMUKH',
      'CHAIRMAN',
      'SECRETARY',
      'SUPER_ADMIN',
      'MANAGER',
    };
    final authUser = ref.read(authProvider).user;
    final currentRole = authUser?.role.toUpperCase() ?? '';
    final lockUnit = !privilegedRoles.contains(currentRole);
    String? selectedUnitId =
        member?.unitId ?? (lockUnit ? authUser?.unitId : null);

    ref.read(unitsProvider.notifier).fetchUnits();

    showAppSheet(
      context: context,
      builder: (ctx) {
        String? errorMsg;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.screenPadding,
                AppDimensions.lg,
                AppDimensions.screenPadding,
                MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.xxxl,
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
                    Text(
                      isEdit ? 'Update Member' : 'Add Member',
                      style: AppTextStyles.h1,
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    AppTextField(label: 'Full Name *', controller: nameCtrl),
                    const SizedBox(height: AppDimensions.md),
                    AppTextField(
                      label: 'Phone Number *',
                      controller: phoneCtrl,
                      hint: 'Used as Login ID',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    AppTextField(
                      label: 'Email (Optional)',
                      controller: emailCtrl,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    if (!isEdit) ...[
                      AppTextField(
                        label: 'Password *',
                        controller: passCtrl,
                        obscureText: true,
                      ),
                      const SizedBox(height: AppDimensions.md),
                    ],
                    AppSearchableDropdown<String>(
                      label: 'Role',
                      value: role,
                      items: lockUnit
                          ? const [
                              AppDropdownItem(value: 'MEMBER', label: 'Member'),
                              AppDropdownItem(
                                value: 'RESIDENT',
                                label: 'Resident',
                              ),
                            ]
                          : const [
                              AppDropdownItem(value: 'MEMBER', label: 'Member'),
                              AppDropdownItem(
                                value: 'RESIDENT',
                                label: 'Resident',
                              ),
                              AppDropdownItem(
                                value: 'PRAMUKH',
                                label: 'Chairman',
                              ),
                              AppDropdownItem(
                                value: 'VICE_CHAIRMAN',
                                label: 'Vice-Chairman',
                              ),
                              AppDropdownItem(
                                value: 'SECRETARY',
                                label: 'Secretary',
                              ),
                              AppDropdownItem(
                                value: 'TREASURER',
                                label: 'Treasurer',
                              ),
                              AppDropdownItem(
                                value: 'WATCHMAN',
                                label: 'Watchman',
                              ),
                            ],
                      onChanged: (v) => setDlgState(() => role = v ?? 'MEMBER'),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    Consumer(
                      builder: (ctx, ref, _) {
                        final unitsAsync = ref.watch(unitsProvider);
                        if (lockUnit) {
                          final unitCode =
                              member?.unitCode ?? authUser?.unitCode;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.md,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMd,
                              ),
                              border: Border.all(
                                color: selectedUnitId != null
                                    ? AppColors.primary.withOpacity(0.5)
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Assigned Unit',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      Text(
                                        unitCode ?? 'No unit assigned',
                                        style: AppTextStyles.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppColors.textMuted,
                                  size: 18,
                                ),
                              ],
                            ),
                          );
                        }
                        return unitsAsync.when(
                          data: (units) => AppSearchableDropdown<String?>(
                            label: 'Assigned Unit',
                            value:
                                units.any(
                                  (u) => u['id'].toString() == selectedUnitId,
                                )
                                ? selectedUnitId
                                : null,
                            items: [
                              const AppDropdownItem(
                                value: null,
                                label: 'No Unit',
                              ),
                              ...units.map(
                                (u) => AppDropdownItem(
                                  value: u['id'].toString(),
                                  label: u['fullCode'],
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setDlgState(() => selectedUnitId = v),
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const Text('Error loading units'),
                        );
                      },
                    ),
                    if (isEdit) ...[
                      const SizedBox(height: AppDimensions.md),
                      SwitchListTile(
                        title: const Text('Account Active'),
                        value: isActive,
                        onChanged: (v) => setDlgState(() => isActive = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                    if (errorMsg != null) ...[
                      const SizedBox(height: AppDimensions.md),
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.sm),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSurface,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusSm,
                          ),
                        ),
                        child: Text(
                          errorMsg!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.dangerText,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (nameCtrl.text.isEmpty ||
                                    phoneCtrl.text.isEmpty ||
                                    (!isEdit && passCtrl.text.isEmpty)) {
                                  setDlgState(
                                    () => errorMsg = 'Required fields missing',
                                  );
                                  return;
                                }
                                setDlgState(() {
                                  isSaving = true;
                                  errorMsg = null;
                                });
                                final Map<String, dynamic> data = {
                                  'name': nameCtrl.text.trim(),
                                  'phone': phoneCtrl.text.trim(),
                                  'email': emailCtrl.text.trim().isEmpty
                                      ? null
                                      : emailCtrl.text.trim(),
                                  'role': role,
                                  'unitId': selectedUnitId,
                                };
                                if (!isEdit) data['password'] = passCtrl.text;
                                if (isEdit) data['isActive'] = isActive;
                                final error = isEdit
                                    ? await ref
                                          .read(membersProvider.notifier)
                                          .updateMember(member.id, data)
                                    : await ref
                                          .read(membersProvider.notifier)
                                          .createMember(data);
                                if (ctx.mounted) {
                                  if (error == null) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Success'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  } else {
                                    setDlgState(() {
                                      isSaving = false;
                                      errorMsg = error;
                                    });
                                  }
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(isEdit ? 'Update' : 'Add'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showResetPasswordDialog(
    BuildContext context,
    WidgetRef ref,
    String id,
    String name,
  ) {
    final passCtrl = TextEditingController();
    showAppSheet(
      context: context,
      builder: (ctx) {
        String? errorMsg;
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setS) {
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
                    'Reset Password',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Reset password for $name',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  AppTextField(
                    label: 'New Password',
                    controller: passCtrl,
                    obscureText: true,
                  ),
                  if (errorMsg != null)
                    Text(errorMsg!, style: TextStyle(color: AppColors.danger)),
                  const SizedBox(height: AppDimensions.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (passCtrl.text.length < 6) {
                                setS(() => errorMsg = 'Min 6 chars');
                                return;
                              }
                              setS(() {
                                isSaving = true;
                                errorMsg = null;
                              });
                              final error = await ref
                                  .read(membersProvider.notifier)
                                  .resetPassword(id, passCtrl.text);
                              if (ctx.mounted) {
                                if (error == null) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Reset Done'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                } else {
                                  setS(() {
                                    isSaving = false;
                                    errorMsg = error;
                                  });
                                }
                              }
                            },
                      child: isSaving
                          ? const CircularProgressIndicator()
                          : const Text('Reset'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
