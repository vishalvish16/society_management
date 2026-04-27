import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/permissions_provider.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  bool _saving = false;
  bool _dirty = false;

  static const _roleLabels = {
    'PRAMUKH': 'Chairman',
    'SECRETARY': 'Secretary',
    'MANAGER': 'Manager',
    'VICE_CHAIRMAN': 'Vice Chairman',
    'ASSISTANT_SECRETARY': 'Asst. Secretary',
    'TREASURER': 'Treasurer',
    'ASSISTANT_TREASURER': 'Asst. Treasurer',
    'MEMBER': 'Member',
    'RESIDENT': 'Resident',
    'WATCHMAN': 'Watchman',
  };

  static const _roleIcons = {
    'PRAMUKH': Icons.workspace_premium_rounded,
    'SECRETARY': Icons.verified_rounded,
    'MANAGER': Icons.manage_accounts_rounded,
    'VICE_CHAIRMAN': Icons.account_balance_rounded,
    'ASSISTANT_SECRETARY': Icons.edit_note_rounded,
    'TREASURER': Icons.account_balance_wallet_rounded,
    'ASSISTANT_TREASURER': Icons.wallet_rounded,
    'MEMBER': Icons.person_rounded,
    'RESIDENT': Icons.home_rounded,
    'WATCHMAN': Icons.shield_rounded,
  };

  static const _groupIcons = {
    'Main': Icons.dashboard_rounded,
    'Finance': Icons.account_balance_wallet_rounded,
    'Security': Icons.security_rounded,
    'Society': Icons.groups_rounded,
    'More': Icons.more_horiz_rounded,
  };

  static const _groupColors = {
    'Main': AppColors.primary,
    'Finance': AppColors.success,
    'Security': AppColors.warning,
    'Society': AppColors.info,
    'More': AppColors.teal,
  };

  static const _featureIcons = {
    'dashboard': Icons.dashboard_rounded,
    'units': Icons.apartment_rounded,
    'members': Icons.people_rounded,
    'bills': Icons.receipt_long_rounded,
    'expenses': Icons.account_balance_wallet_rounded,
    'expense_approval': Icons.verified_rounded,
    'donations': Icons.volunteer_activism_rounded,
    'balance_report': Icons.balance_rounded,
    'pending_dues': Icons.assignment_late_rounded,
    'visitors': Icons.person_pin_circle_rounded,
    'gate_passes': Icons.badge_rounded,
    'vehicles': Icons.directions_car_rounded,
    'parking': Icons.local_parking_rounded,
    'complaints': Icons.report_problem_rounded,
    'suggestions': Icons.lightbulb_rounded,
    'notices': Icons.campaign_rounded,
    'polls': Icons.how_to_vote_rounded,
    'events': Icons.event_rounded,
    'amenities': Icons.sports_basketball_rounded,
    'staff': Icons.support_agent_rounded,
    'deliveries': Icons.local_shipping_rounded,
    'domestic_help': Icons.cleaning_services_rounded,
    'chat': Icons.chat_rounded,
    'notifications': Icons.notifications_rounded,
  };

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _initTabs(int length) {
    if (_tabController == null || _tabController!.length != length) {
      _tabController?.dispose();
      _tabController = TabController(length: length, vsync: this);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final err = await ref.read(rolePermissionsProvider.notifier).save();
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (err == null) _dirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'Permissions saved successfully'),
      backgroundColor: err == null ? AppColors.success : AppColors.danger,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(rolePermissionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Role Permissions'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          if (_dirty)
            Padding(
              padding: const EdgeInsets.only(right: AppDimensions.sm),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
        ],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.danger),
              const SizedBox(height: AppDimensions.md),
              Text('Failed to load permissions',
                  style: AppTextStyles.h3),
              const SizedBox(height: AppDimensions.sm),
              Text(e.toString(),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppDimensions.lg),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(rolePermissionsProvider.notifier).fetch(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          _initTabs(data.roles.length);
          return _buildBody(data);
        },
      ),
    );
  }

  Widget _buildBody(RolePermissionsData data) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (isWide) return _buildDesktopLayout(data);
    return _buildMobileLayout(data);
  }

  // ── Desktop: side-by-side card grid ────────────────────────────────

  Widget _buildDesktopLayout(RolePermissionsData data) {
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabController!,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: AppTextStyles.h3,
            unselectedLabelStyle: AppTextStyles.bodyMedium,
            tabAlignment: TabAlignment.start,
            tabs: data.roles.map((role) {
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_roleIcons[role] ?? Icons.person_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(_roleLabels[role] ?? role),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: TabBarView(
            controller: _tabController!,
            children: data.roles.map((role) {
              return _buildRoleContent(data, role);
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Mobile: tabs at top ────────────────────────────────────────────

  Widget _buildMobileLayout(RolePermissionsData data) {
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabController!,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: AppTextStyles.h3,
            unselectedLabelStyle: AppTextStyles.bodyMedium,
            tabAlignment: TabAlignment.start,
            tabs: data.roles.map((role) {
              return Tab(text: _roleLabels[role] ?? role);
            }).toList(),
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: TabBarView(
            controller: _tabController!,
            children: data.roles.map((role) {
              return _buildRoleContent(data, role);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleContent(RolePermissionsData data, String role) {
    final perms = data.rolePermissions[role] ?? {};
    final user = ref.watch(authProvider).user;
    final currentRole = user?.role.toUpperCase() ?? '';
    final canEdit = !(currentRole == 'SECRETARY' && role == 'PRAMUKH');
    final grouped = <String, List<FeatureInfo>>{};
    for (final f in data.features) {
      grouped.putIfAbsent(f.group, () => []).add(f);
    }

    final enabledCount = perms.values.where((v) => v).length;
    final totalCount = data.features.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!canEdit)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.md),
              child: AppCard(
                backgroundColor: AppColors.warningSurface,
                child: Text(
                  'Only Pramukh/Chairman can change these permissions.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.warningText),
                ),
              ),
            ),
          // Role header card
          AppCard(
            padding: const EdgeInsets.all(AppDimensions.lg),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Icon(
                    _roleIcons[role] ?? Icons.person_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_roleLabels[role] ?? role, style: AppTextStyles.h2),
                      const SizedBox(height: 2),
                      Text(
                        '$enabledCount of $totalCount features enabled',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                // Toggle all
                TextButton.icon(
                  onPressed: canEdit
                      ? () {
                    final allOn = enabledCount == totalCount;
                    for (final f in data.features) {
                      ref
                          .read(rolePermissionsProvider.notifier)
                          .toggle(role, f.key, !allOn);
                    }
                    setState(() => _dirty = true);
                  }
                      : null,
                  icon: Icon(
                    enabledCount == totalCount
                        ? Icons.toggle_on_rounded
                        : Icons.toggle_off_rounded,
                    size: 20,
                  ),
                  label: Text(enabledCount == totalCount
                      ? 'Disable All'
                      : 'Enable All'),
                  style: TextButton.styleFrom(
                    foregroundColor: enabledCount == totalCount
                        ? AppColors.textMuted
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.lg),

          // Feature groups
          ...grouped.entries.map((entry) {
            final group = entry.key;
            final features = entry.value;
            final groupColor = _groupColors[group] ?? AppColors.primary;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _groupIcons[group] ?? Icons.folder_rounded,
                        size: 16,
                        color: groupColor,
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Text(
                        group.toUpperCase(),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: groupColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: features.asMap().entries.map((fEntry) {
                        final i = fEntry.key;
                        final feature = fEntry.value;
                        final enabled = perms[feature.key] ?? false;

                        return Column(
                          children: [
                            if (i > 0)
                              const Divider(
                                height: 1,
                                indent: AppDimensions.xxxl + AppDimensions.lg,
                                endIndent: AppDimensions.lg,
                              ),
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.lg,
                                vertical: 2,
                              ),
                              secondary: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: enabled
                                      ? groupColor.withValues(alpha: 0.1)
                                      : AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusSm),
                                ),
                                child: Icon(
                                  _featureIcons[feature.key] ??
                                      Icons.extension_rounded,
                                  size: 18,
                                  color: enabled
                                      ? groupColor
                                      : AppColors.textMuted,
                                ),
                              ),
                              title: Text(feature.label,
                                  style: AppTextStyles.bodyMedium),
                              value: enabled,
                              onChanged: canEdit
                                  ? (val) {
                                      ref
                                          .read(rolePermissionsProvider.notifier)
                                          .toggle(role, feature.key, val);
                                      setState(() => _dirty = true);
                                    }
                                  : null,
                              activeColor: groupColor,
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
