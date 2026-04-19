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
import '../../../shared/widgets/app_text_field.dart';
import '../providers/unit_provider.dart';
import '../../../shared/widgets/show_app_sheet.dart';
import '../../../shared/widgets/app_status_chip.dart';

class UnitsScreen extends ConsumerStatefulWidget {
  const UnitsScreen({super.key});

  @override
  ConsumerState<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends ConsumerState<UnitsScreen> {
  final ScrollController _scrollController = ScrollController();
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

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(unitsProvider.notifier).fetchNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final focusId = GoRouterState.of(context).uri.queryParameters['focusId'];
    final unitsAsync = ref.watch(unitsProvider);
    final notifier = ref.read(unitsProvider.notifier);
    final currentUser = ref.watch(authProvider).user;
    final canManage = !(currentUser?.isUnitLocked ?? false);

    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isWide
          ? AppBar(
              backgroundColor: AppColors.primary,
              title: Text(
                'Units',
                style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary),
              ),
            )
          : null,
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
          if (focusId != null && focusId.isNotEmpty && _handledFocusId != focusId) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              await _focusUnitById(focusId);
              if (mounted) setState(() => _handledFocusId = focusId);
            });
          }
          if (units.isEmpty) {
            return const AppEmptyState(
              emoji: '🏠',
              title: 'No Units',
              subtitle: 'No units have been added yet.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.read(unitsProvider.notifier).fetchUnits(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification) {
                  // If we are at the bottom or the content is smaller than screen
                  if (_scrollController.position.extentAfter < 500) {
                    ref.read(unitsProvider.notifier).fetchNextPage();
                  }
                }
                return false;
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(AppDimensions.lg),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 140,
                      mainAxisSpacing: AppDimensions.md,
                      crossAxisSpacing: AppDimensions.md,
                      childAspectRatio: 0.9,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final u = units[i] as Map<String, dynamic>;
                        final status = (u['status'] as String? ?? 'VACANT').toUpperCase();
                        final residents = (u['residents'] as List? ?? u['unitResidents'] as List? ?? []);
                        final residentNames = residents.map((r) => r['name'] ?? r['user']?['name'] ?? '').where((n) => n.isNotEmpty).join(', ');
                        final floor = u['floor'];
                        final wing = u['wing'] as String? ?? '';
                        final (bgColor, borderColor) = _getUnitColors(status);

                        return AppCard(
                          onTap: () => _showEditSheet(context, ref, u),
                          backgroundColor: bgColor.withOpacity(0.5),
                          leftBorderColor: borderColor,
                          padding: const EdgeInsets.all(AppDimensions.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      u['fullCode'] as String? ?? '-',
                                      style: AppTextStyles.h3.copyWith(
                                        color: borderColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  AppStatusChip(status: status),
                                ],
                              ),
                              const SizedBox(height: AppDimensions.xs),
                              if (wing.isNotEmpty || floor != null)
                                Text(
                                  '${wing.isNotEmpty ? 'W: $wing' : ''}${wing.isNotEmpty && floor != null ? ' | ' : ''}${floor != null ? 'F: $floor' : ''}',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                                  maxLines: 1,
                                ),
                              const Spacer(),
                              Row(
                                children: [
                                  Icon(Icons.person_pin_rounded, size: 14, color: borderColor.withOpacity(0.7)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      residentNames.isNotEmpty ? residentNames : 'Vacant',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontSize: 11,
                                        color: AppColors.textPrimary,
                                        fontStyle: residentNames.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (canManage && status == 'VACANT')
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: GestureDetector(
                                    onTap: () => _confirmDelete(context, ref, u['id'], u['fullCode'] ?? ''),
                                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 16),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                      childCount: units.length,
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

  (Color bg, Color border) _getUnitColors(String status) {
    if (status == 'OCCUPIED') {
      return (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)); // Green pastel
    } else if (status == 'VACANT') {
      return (const Color(0xFFE3F2FD), const Color(0xFF1565C0)); // Blue pastel
    }
    return (AppColors.background, AppColors.border);
  }

  Future<void> _focusUnitById(String id) async {
    for (int guard = 0; guard < 20; guard++) {
      final list = ref.read(unitsProvider).value ?? const <dynamic>[];
      final idx = list.indexWhere((u) => (u is Map) && u['id']?.toString() == id);
      if (idx >= 0) {
        // Grid rows: approximate scroll position
        final row = idx ~/ 4;
        final targetOffset = (row * 170.0).clamp(0.0, _scrollController.position.maxScrollExtent);
        await _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
        if (!mounted) return;
        final u = list[idx] as Map<String, dynamic>;
        _showEditSheet(context, ref, u);
        return;
      }

      final n = ref.read(unitsProvider.notifier);
      if (!n.hasMore || n.isLoadingMore) break;
      await n.fetchNextPage();
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Record not found in units list')),
    );
  }
}

class _UnitInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  const _UnitInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: accentColor.withOpacity(0.6)),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontSize: 10),
          ),
          Text(
            value,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
