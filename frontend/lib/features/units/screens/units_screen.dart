import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/unit_provider.dart';
import '../../../shared/widgets/show_app_dialog.dart';

class UnitsScreen extends ConsumerStatefulWidget {
  const UnitsScreen({super.key});

  @override
  ConsumerState<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends ConsumerState<UnitsScreen> {
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
      ref.read(unitsProvider.notifier).fetchNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitsAsync = ref.watch(unitsProvider);
    final notifier = ref.read(unitsProvider.notifier);
    final currentUser = ref.watch(authProvider).user;
    final canManage = !(currentUser?.isUnitLocked ?? false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Units',
            style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context, ref),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: AppColors.textOnPrimary),
              label: Text('Add Unit',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textOnPrimary)),
            )
          : null,
      body: unitsAsync.when(
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
                     child: Text('Error: $e',
                         style: AppTextStyles.bodySmall
                             .copyWith(color: AppColors.dangerText)),
                   ),
                   TextButton(
                     onPressed: () =>
                         ref.read(unitsProvider.notifier).fetchUnits(),
                     child: const Text('Retry'),
                   ),
                ],
              ),
            ),
          ),
        ),
        data: (units) {
          if (units.isEmpty) {
            return const AppEmptyState(
              emoji: '🏠',
              title: 'No Units',
              subtitle: 'No units have been added yet.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.read(unitsProvider.notifier).fetchUnits(),
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppDimensions.screenPadding),
              itemCount: units.length + (notifier.hasMore ? 1 : 0),
              separatorBuilder: (_, index) =>
                  const SizedBox(height: AppDimensions.sm),
              itemBuilder: (_, i) {
                if (i == units.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppDimensions.md),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final u = units[i] as Map<String, dynamic>;
                final isOccupied = (u['status'] as String? ?? '').toUpperCase() == 'OCCUPIED';
                final residents = (u['residents'] as List? ?? u['unitResidents'] as List? ?? []);
                final names = residents
                    .map((r) => r['user']?['name'] ?? '')
                    .where((n) => n.isNotEmpty)
                    .join(', ');
                final floor = u['floor'];
                final wing = u['wing'] as String? ?? '';
                return AppCard(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isOccupied
                              ? AppColors.primarySurface
                              : AppColors.background,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        child: Icon(
                          isOccupied
                              ? Icons.people_rounded
                              : Icons.apartment_rounded,
                          color: isOccupied
                              ? AppColors.primary
                              : AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u['fullCode'] as String? ?? '-',
                                style: AppTextStyles.unitCode),
                            const SizedBox(height: AppDimensions.xs),
                            if (names.isNotEmpty)
                              Text(
                                names,
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            else
                              Row(
                                children: [
                                  if (wing.isNotEmpty) ...[
                                    Text('Wing $wing',
                                        style: AppTextStyles.caption),
                                    const SizedBox(width: AppDimensions.sm),
                                  ],
                                  if (floor != null)
                                    Text('Floor $floor',
                                        style: AppTextStyles.caption),
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (canManage) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: AppColors.primary, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showEditSheet(context, ref, u),
                        ),
                        const SizedBox(width: AppDimensions.sm),
                        InkWell(
                          onTap: () => _confirmDelete(
                              context, ref, u['id'] as String, u['fullCode'] as String? ?? ''),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.danger, size: 18),
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
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id, String name) async {
    final ok = await showConfirmSheet(
      context: context,
      title: 'Delete Unit',
      message: 'Delete unit $name? Only vacant units can be deleted.',
      confirmLabel: 'Delete',
    );
    if (ok && context.mounted) {
      final success = await ref.read(unitsProvider.notifier).deleteUnit(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Unit deleted' : 'Failed to delete unit'),
        ));
      }
    }
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> unit) {
    final wingCtrl = TextEditingController(text: unit['wing'] as String? ?? '');
    final unitNumCtrl = TextEditingController(text: unit['unitNumber'] as String? ?? '');
    final floorCtrl = TextEditingController(text: unit['floor']?.toString() ?? '');
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool searching = false;
    final residents = (unit['residents'] as List? ?? unit['unitResidents'] as List? ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => DefaultTabController(
        length: 2,
        child: StatefulBuilder(
          builder: (ctx, setState) => Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimensions.screenPadding,
              AppDimensions.lg,
              AppDimensions.screenPadding,
              MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                Text('Unit ${unit['fullCode'] ?? ''}', style: AppTextStyles.h1),
                const SizedBox(height: AppDimensions.sm),
                const TabBar(
                  tabs: [Tab(text: 'Edit Details'), Tab(text: 'Residents')],
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.primary,
                ),
                const SizedBox(height: AppDimensions.md),
                SizedBox(
                  height: 320,
                  child: TabBarView(
                    children: [
                      // ── Tab 1: Edit Unit Details ──────────────────────
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            AppTextField(label: 'Wing', controller: wingCtrl, hint: 'e.g. A'),
                            const SizedBox(height: AppDimensions.md),
                            AppTextField(label: 'Unit Number', controller: unitNumCtrl, hint: 'e.g. 101'),
                            const SizedBox(height: AppDimensions.md),
                            AppTextField(
                              label: 'Floor',
                              controller: floorCtrl,
                              hint: 'e.g. 1',
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: AppDimensions.xl),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                  ),
                                ),
                                onPressed: () async {
                                  final data = <String, dynamic>{};
                                  if (wingCtrl.text.trim().isNotEmpty) data['wing'] = wingCtrl.text.trim();
                                  if (unitNumCtrl.text.trim().isNotEmpty) data['unitNumber'] = unitNumCtrl.text.trim();
                                  if (floorCtrl.text.trim().isNotEmpty) data['floor'] = int.tryParse(floorCtrl.text.trim());
                                  final ok = await ref.read(unitsProvider.notifier).updateUnit(unit['id'] as String, data);
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text(ok ? 'Unit updated' : 'Failed to update unit'),
                                      backgroundColor: ok ? AppColors.success : AppColors.danger,
                                    ));
                                  }
                                },
                                child: Text('Save Changes', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Tab 2: Residents ──────────────────────────────
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Current residents
                            if (residents.isNotEmpty) ...[
                              Text('Current Residents',
                                  style: AppTextStyles.labelMedium
                                      .copyWith(color: AppColors.textMuted)),
                              const SizedBox(height: AppDimensions.xs),
                              ...residents.map((r) {
                                final name =
                                    r['user']?['name'] as String? ?? '-';
                                final userId =
                                    r['user']?['id'] as String? ?? '';
                                final isOwner = r['isOwner'] == true;
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.primarySurface,
                                    child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: AppTextStyles.labelSmall
                                            .copyWith(color: AppColors.primary)),
                                  ),
                                  title:
                                      Text(name, style: AppTextStyles.bodyMedium),
                                  subtitle: Text(isOwner ? 'Owner' : 'Tenant',
                                      style: AppTextStyles.caption),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle_outline,
                                        color: AppColors.danger, size: 18),
                                    onPressed: () async {
                                      final ok = await ref
                                          .read(unitsProvider.notifier)
                                          .removeResident(
                                              unit['id'] as String, userId);
                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(ok
                                              ? 'Resident removed'
                                              : 'Failed to remove'),
                                          backgroundColor: ok
                                              ? AppColors.success
                                              : AppColors.danger,
                                        ));
                                      }
                                    },
                                  ),
                                );
                              }),
                              const Divider(),
                            ],
                            // Assign new resident
                            Text('Assign Resident',
                                style: AppTextStyles.labelMedium
                                    .copyWith(color: AppColors.textMuted)),
                            const SizedBox(height: AppDimensions.xs),
                            TextField(
                              controller: searchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Search member by name...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: searching
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2)),
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusMd)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppDimensions.md,
                                    vertical: AppDimensions.sm),
                              ),
                              onChanged: (q) async {
                                if (q.length < 2) {
                                  setState(() => searchResults = []);
                                  return;
                                }
                                setState(() => searching = true);
                                final results = await ref
                                    .read(unitsProvider.notifier)
                                    .searchMembers(q);
                                setState(() {
                                  searchResults = results;
                                  searching = false;
                                });
                              },
                            ),
                            if (searchResults.isNotEmpty) ...[
                              const SizedBox(height: AppDimensions.xs),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: searchResults.length,
                                itemBuilder: (_, i) {
                                  final m = searchResults[i];
                                  final name = m['name'] as String? ?? '-';
                                  final role = m['role'] as String? ?? '';
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColors.primarySurface,
                                      child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                          style: AppTextStyles.labelSmall
                                              .copyWith(color: AppColors.primary)),
                                    ),
                                    title: Text(name,
                                        style: AppTextStyles.bodyMedium),
                                    subtitle:
                                        Text(role, style: AppTextStyles.caption),
                                    trailing: TextButton(
                                      onPressed: () async {
                                        final ok = await ref
                                            .read(unitsProvider.notifier)
                                            .assignResident(
                                              unit['id'] as String,
                                              m['id'] as String,
                                            );
                                        if (ctx.mounted) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                            content: Text(ok
                                                ? '$name assigned to unit'
                                                : 'Failed to assign'),
                                            backgroundColor: ok
                                                ? AppColors.success
                                                : AppColors.danger,
                                          ));
                                        }
                                      },
                                      child: const Text('Assign'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final wingCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final floorCtrl = TextEditingController();
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();

    showAppSheet(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: StatefulBuilder(
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
                const Text('Add Unit(s)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: AppDimensions.md),
                const TabBar(
                  tabs: [Tab(text: 'Single'), Tab(text: 'Bulk')],
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.primary,
                ),
                const SizedBox(height: AppDimensions.lg),
                SizedBox(
                  height: 220,
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        child: Column(children: [
                          AppTextField(label: 'Wing', controller: wingCtrl, hint: 'e.g. A'),
                          const SizedBox(height: AppDimensions.md),
                          AppTextField(label: 'Unit Number', controller: unitCtrl, hint: 'e.g. 101'),
                          const SizedBox(height: AppDimensions.md),
                          AppTextField(label: 'Floor', controller: floorCtrl, hint: 'e.g. 1', keyboardType: TextInputType.number),
                        ]),
                      ),
                      SingleChildScrollView(
                        child: Column(children: [
                          AppTextField(label: 'Wing', controller: wingCtrl, hint: 'e.g. A'),
                          const SizedBox(height: AppDimensions.md),
                          Row(children: [
                            Expanded(child: AppTextField(label: 'Start No.', controller: startCtrl, hint: '1', keyboardType: TextInputType.number)),
                            const SizedBox(width: AppDimensions.md),
                            Expanded(child: AppTextField(label: 'End No.', controller: endCtrl, hint: '200', keyboardType: TextInputType.number)),
                          ]),
                          const SizedBox(height: AppDimensions.md),
                          AppTextField(label: 'Floor', controller: floorCtrl, hint: 'Optional', keyboardType: TextInputType.number),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),
                Consumer(builder: (ctx, ref, _) {
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final tabIndex = DefaultTabController.of(ctx).index;
                        bool success = false;
                        if (tabIndex == 0) {
                          success = await ref.read(unitsProvider.notifier).createUnit({
                            'wing': wingCtrl.text.trim(),
                            'unitNumber': unitCtrl.text.trim(),
                            'floor': int.tryParse(floorCtrl.text) ?? 0,
                          });
                        } else {
                          success = await ref.read(unitsProvider.notifier).bulkCreate({
                            'wing': wingCtrl.text.trim(),
                            'startUnit': startCtrl.text.trim(),
                            'endUnit': endCtrl.text.trim(),
                            'floor': floorCtrl.text.isNotEmpty ? int.tryParse(floorCtrl.text) : null,
                          });
                        }
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(success ? 'Operation successful' : 'Operation failed'),
                          ));
                        }
                      },
                      child: const Text('Create Unit'),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
