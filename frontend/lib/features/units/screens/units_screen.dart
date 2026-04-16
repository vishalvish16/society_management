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
import '../../../shared/widgets/show_app_sheet.dart';
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
        title: Text(
          'Units',
          style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context, ref),
              backgroundColor: AppColors.primary,
              icon: const Icon(
                Icons.add_rounded,
                color: AppColors.textOnPrimary,
              ),
              label: Text(
                'Add Unit',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
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
                    child: Text(
                      'Error: $e',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.dangerText,
                      ),
                    ),
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
                final isOccupied =
                    (u['status'] as String? ?? '').toUpperCase() == 'OCCUPIED';
                final residents =
                    (u['residents'] as List? ??
                    u['unitResidents'] as List? ??
                    []);
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
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMd,
                          ),
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
                            Text(
                              u['fullCode'] as String? ?? '-',
                              style: AppTextStyles.unitCode,
                            ),
                            const SizedBox(height: AppDimensions.xs),
                            if (names.isNotEmpty)
                              Text(
                                names,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            else
                              Row(
                                children: [
                                  if (wing.isNotEmpty) ...[
                                    Text(
                                      'Wing $wing',
                                      style: AppTextStyles.caption,
                                    ),
                                    const SizedBox(width: AppDimensions.sm),
                                  ],
                                  if (floor != null)
                                    Text(
                                      'Floor $floor',
                                      style: AppTextStyles.caption,
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (canManage) ...[
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showEditSheet(context, ref, u),
                        ),
                        const SizedBox(width: AppDimensions.sm),
                        InkWell(
                          onTap: () => _confirmDelete(
                            context,
                            ref,
                            u['id'] as String,
                            u['fullCode'] as String? ?? '',
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.danger,
                            size: 18,
                          ),
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

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
    String name,
  ) async {
    final ok = await showConfirmSheet(
      context: context,
      title: 'Delete Unit',
      message: 'Delete unit $name? Only vacant units can be deleted.',
      confirmLabel: 'Delete',
    );
    if (ok && context.mounted) {
      final error = await ref.read(unitsProvider.notifier).deleteUnit(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error == null ? 'Unit deleted' : 'Failed to delete unit: $error',
            ),
            backgroundColor: error == null
                ? AppColors.success
                : AppColors.danger,
          ),
        );
      }
    }
  }

  void _showEditSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> unit,
  ) {
    final wingCtrl = TextEditingController(text: unit['wing'] as String? ?? '');
    final unitNumCtrl = TextEditingController(
      text: unit['unitNumber'] as String? ?? '',
    );
    final floorCtrl = TextEditingController(
      text: unit['floor']?.toString() ?? '',
    );
    final residents =
        (unit['residents'] as List? ?? unit['unitResidents'] as List? ?? []);

    showAppSheet(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: StatefulBuilder(
          builder: (ctx, setState) {
            String? errorMsg;
            bool saving = false;
            final searchCtrl = TextEditingController();
            List<Map<String, dynamic>> searchResults = [];
            bool searching = false;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.screenPadding,
                AppDimensions.lg,
                AppDimensions.screenPadding,
                MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.lg,
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
                  const SizedBox(height: AppDimensions.md),
                  Text(
                    'Unit ${unit['fullCode'] ?? ''}',
                    style: AppTextStyles.h1,
                  ),
                  const TabBar(
                    tabs: [
                      Tab(text: 'Edit'),
                      Tab(text: 'Residents'),
                    ],
                    labelColor: AppColors.primary,
                    indicatorColor: AppColors.primary,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  SizedBox(
                    height: 320,
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              AppTextField(label: 'Wing', controller: wingCtrl),
                              const SizedBox(height: AppDimensions.md),
                              AppTextField(
                                label: 'Unit Number',
                                controller: unitNumCtrl,
                              ),
                              const SizedBox(height: AppDimensions.md),
                              AppTextField(
                                label: 'Floor',
                                controller: floorCtrl,
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: AppDimensions.xl),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: saving
                                      ? null
                                      : () async {
                                          setState(() {
                                            saving = true;
                                            errorMsg = null;
                                          });
                                          final error = await ref
                                              .read(unitsProvider.notifier)
                                              .updateUnit(unit['id'], {
                                                'wing': wingCtrl.text,
                                                'unitNumber': unitNumCtrl.text,
                                                'floor': int.tryParse(
                                                  floorCtrl.text,
                                                ),
                                              });
                                          if (ctx.mounted) {
                                            if (error == null) {
                                              Navigator.pop(ctx);
                                            } else {
                                              setState(() {
                                                saving = false;
                                                errorMsg = error;
                                              });
                                            }
                                          }
                                        },
                                  child: saving
                                      ? const CircularProgressIndicator()
                                      : const Text('Save'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              ...residents.map(
                                (r) => ListTile(
                                  title: Text(r['user']?['name'] ?? '-'),
                                  trailing: IconButton(
                                    icon: Icon(Icons.remove_circle_outline),
                                    onPressed: () {},
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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
          builder: (ctx, setDlgState) {
            String? errorMsg;
            bool saving = false;
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
                    'Add Unit(s)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const TabBar(
                    tabs: [
                      Tab(text: 'Single'),
                      Tab(text: 'Bulk'),
                    ],
                    labelColor: AppColors.primary,
                    indicatorColor: AppColors.primary,
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  SizedBox(
                    height: 220,
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              AppTextField(label: 'Wing', controller: wingCtrl),
                              const SizedBox(height: AppDimensions.md),
                              AppTextField(label: 'Unit', controller: unitCtrl),
                            ],
                          ),
                        ),
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              AppTextField(label: 'Wing', controller: wingCtrl),
                              const SizedBox(height: AppDimensions.md),
                              Row(
                                children: [
                                  Expanded(
                                    child: AppTextField(
                                      label: 'Start',
                                      controller: startCtrl,
                                    ),
                                  ),
                                  const SizedBox(width: AppDimensions.md),
                                  Expanded(
                                    child: AppTextField(
                                      label: 'End',
                                      controller: endCtrl,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (errorMsg != null)
                    Text(errorMsg!, style: TextStyle(color: AppColors.danger)),
                  const SizedBox(height: AppDimensions.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              setDlgState(() {
                                saving = true;
                                errorMsg = null;
                              });
                              final tabIndex = DefaultTabController.of(
                                ctx,
                              ).index;
                              final error = tabIndex == 0
                                  ? await ref
                                        .read(unitsProvider.notifier)
                                        .createUnit({
                                          'wing': wingCtrl.text,
                                          'unitNumber': unitCtrl.text,
                                          'floor':
                                              int.tryParse(floorCtrl.text) ?? 0,
                                        })
                                  : await ref
                                        .read(unitsProvider.notifier)
                                        .bulkCreate({
                                          'wing': wingCtrl.text,
                                          'startUnit': startCtrl.text,
                                          'endUnit': endCtrl.text,
                                        });
                              if (ctx.mounted) {
                                if (error == null) {
                                  Navigator.pop(ctx);
                                } else {
                                  setDlgState(() {
                                    saving = false;
                                    errorMsg = error;
                                  });
                                }
                              }
                            },
                      child: saving
                          ? const CircularProgressIndicator()
                          : const Text('Create'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
