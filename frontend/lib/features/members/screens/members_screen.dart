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
  String _selectedRole = 'All';
  String? _handledFocusId;

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

  void _updateFilter(String role) {
    setState(() => _selectedRole = role);
    ref.read(membersProvider.notifier).loadMembers(role: role);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(membersProvider.notifier).loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final focusId = GoRouterState.of(context).uri.queryParameters['focusId'];
    final membersAsync = ref.watch(membersProvider);
    final notifier = ref.read(membersProvider.notifier);

    final isWide = MediaQuery.of(context).size.width >= 768;
    final filtersWidget = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.lg, vertical: AppDimensions.md),
      child: Row(
        children: [
          _FilterChip(label: 'All', isSelected: _selectedRole == 'All', onTap: () => _updateFilter('All')),
          _FilterChip(label: 'Chairman', isSelected: _selectedRole == 'Chairman', onTap: () => _updateFilter('Chairman')),
          _FilterChip(label: 'Secretary', isSelected: _selectedRole == 'Secretary', onTap: () => _updateFilter('Secretary')),
          _FilterChip(label: 'Member', isSelected: _selectedRole == 'Member', onTap: () => _updateFilter('Member')),
          _FilterChip(label: 'Resident', isSelected: _selectedRole == 'Resident', onTap: () => _updateFilter('Resident')),
          _FilterChip(label: 'Watchman', isSelected: _selectedRole == 'Watchman', onTap: () => _updateFilter('Watchman')),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isWide
          ? AppBar(
              backgroundColor: AppColors.primary,
              title: Text(
                'Members',
                style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(72),
                child: filtersWidget,
              ),
            )
          : AppBar(
              backgroundColor: AppColors.primary,
              toolbarHeight: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(72),
                child: filtersWidget,
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: AppColors.textOnPrimary),
        label: Text('Add Member',
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.textOnPrimary)),
      ),
      body: membersAsync.when(
        loading: () => const AppLoadingShimmer(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (members) {
          // If navigated from global search, try to load pages until we find the target.
          if (focusId != null && focusId.isNotEmpty && _handledFocusId != focusId) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              await _focusMemberById(focusId);
              if (mounted) setState(() => _handledFocusId = focusId);
            });
          }
          if (members.isEmpty) {
            return const AppEmptyState(
                emoji: '👥',
                title: 'No Members',
                subtitle: 'No members matched your filters.');
          }
          return RefreshIndicator(
            onRefresh: () async => ref.read(membersProvider.notifier).loadMembers(),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.lg,
                    vertical: AppDimensions.md,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final m = members[i];
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final double maxWidth = constraints.maxWidth > 800 ? 800 : constraints.maxWidth;
                            return Center(
                              child: Container(
                                width: maxWidth,
                                margin: const EdgeInsets.only(bottom: AppDimensions.md),
                                child: AppCard(
                                  onTap: () => _showAddEditDialog(context, ref, member: m),
                                  leftBorderColor: m.isActive ? AppColors.success : AppColors.textMuted,
                                  padding: const EdgeInsets.all(AppDimensions.md),
                                  child: Row(
                                    children: [
                                      // Avatar and Basic Info
                                      Expanded(
                                        flex: 3,
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: m.isActive ? AppColors.primarySurface : AppColors.background,
                                              child: Text(
                                                m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                                                style: AppTextStyles.h3.copyWith(color: m.isActive ? AppColors.primary : AppColors.textMuted),
                                              ),
                                            ),
                                            const SizedBox(width: AppDimensions.sm),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    m.name,
                                                    style: AppTextStyles.h3.copyWith(
                                                      color: m.isActive ? AppColors.textPrimary : AppColors.textMuted,
                                                      decoration: m.isActive ? null : TextDecoration.lineThrough,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(m.role, style: AppTextStyles.caption.copyWith(color: AppColors.primary)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppDimensions.xs),

                                      // Contact and Unit
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.phone_outlined, size: 14, color: AppColors.textMuted),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(m.phone, style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.apartment_rounded, size: 14, color: AppColors.textMuted),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    m.unitCode.isNotEmpty ? m.unitCode : 'No Unit',
                                                    style: AppTextStyles.bodySmall,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppDimensions.xs),

                                      // Status and Actions
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          AppStatusChip(status: m.isActive ? 'active' : 'disabled'),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.lock_reset, size: 20, color: AppColors.warning),
                                                onPressed: () => _showResetPasswordDialog(context, ref, m.id, m.name),
                                                constraints: const BoxConstraints(),
                                                padding: EdgeInsets.zero,
                                              ),
                                              const SizedBox(width: AppDimensions.sm),
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                                                onPressed: () => _showAddEditDialog(context, ref, member: m),
                                                constraints: const BoxConstraints(),
                                                padding: EdgeInsets.zero,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      childCount: members.length,
                    ),
                  ),
                ),
                if (notifier.hasMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: notifier.isLoadingMore 
                          ? const CircularProgressIndicator()
                          : const SizedBox.shrink(),
                      ),
                    ),
                  ),
              ],
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

  Future<void> _focusMemberById(String id) async {
    // Keep loading more until we find the member or run out.
    for (int guard = 0; guard < 15; guard++) {
      final list = ref.read(membersProvider).value ?? const <Member>[];
      final idx = list.indexWhere((m) => m.id == id);
      if (idx >= 0) {
        // Scroll near the item then open edit dialog.
        final targetOffset = (idx * 104.0).clamp(0.0, _scrollController.position.maxScrollExtent);
        await _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
        if (!mounted) return;
        _showAddEditDialog(context, ref, member: list[idx]);
        return;
      }

      final n = ref.read(membersProvider.notifier);
      if (!n.hasMore || n.isLoadingMore) break;
      await n.loadNextPage();
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Record not found in members list')),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppDimensions.sm),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withOpacity(0.2),
        checkmarkColor: AppColors.primary,
        labelStyle: AppTextStyles.bodySmall.copyWith(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
