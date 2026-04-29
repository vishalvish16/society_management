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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
          final bottomInset = MediaQuery.of(context).padding.bottom;
          final extraBottomSpace = (canManage ? 104.0 : 24.0) + bottomInset;
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
                        final occupancy = (u['occupancyType'] as String? ?? 'OWNER_OCCUPIED').toUpperCase();
                        final residents = (u['residents'] as List? ?? u['unitResidents'] as List? ?? []);
                        final rentals = u['rentalRecords'] as List? ?? [];
                        final rentalCount = rentals.length;
                        final ownerNotStaying = residents.any(
                          (r) => r is Map && r['isOwner'] == true && r['isStaying'] == false,
                        );
                        final residentNames = residents.map((r) => r['name'] ?? r['user']?['name'] ?? '').where((n) => n.isNotEmpty).join(', ');
                        final tenantNames = rentals.map((r) {
                          final name = r['tenantName'] ?? '';
                          final portion = r['portion'] as String? ?? '';
                          return portion.isNotEmpty ? '$name ($portion)' : name;
                        }).where((n) => n.isNotEmpty).join(', ');
                        final floor = u['floor'];
                        final wing = u['wing'] as String? ?? '';
                        final isRented = occupancy == 'RENTED' || occupancy == 'LEASED' || occupancy == 'PARTIALLY_RENTED';
                        final (bgColor, borderColor) = _getUnitColors(status, occupancy);

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
                              if (isRented)
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    occupancy == 'PARTIALLY_RENTED'
                                        ? 'Owner + ${rentalCount} Tenant${rentalCount > 1 ? 's' : ''}'
                                        : occupancy == 'LEASED'
                                            ? 'Leased${rentalCount > 1 ? ' ($rentalCount)' : ''}'
                                            : 'Rented${rentalCount > 1 ? ' ($rentalCount)' : ''}',
                                    style: AppTextStyles.caption.copyWith(fontSize: 9, color: const Color(0xFFE65100), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              if (ownerNotStaying)
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Owner not staying',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 9,
                                      color: const Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
                                  Icon(
                                    isRented ? Icons.key_rounded : Icons.person_pin_rounded,
                                    size: 14,
                                    color: borderColor.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      isRented && tenantNames.isNotEmpty
                                          ? tenantNames
                                          : residentNames.isNotEmpty
                                              ? residentNames
                                              : 'Vacant',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontSize: 11,
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontStyle: (residentNames.isNotEmpty || isRented) ? FontStyle.normal : FontStyle.italic,
                                      ),
                                      maxLines: 2,
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
                SliverToBoxAdapter(child: SizedBox(height: extraBottomSpace)),
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
    final canManage = !(ref.read(authProvider).user?.isUnitLocked ?? false);
    bool saving = false;

    showAppSheet(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: Consumer(
          builder: (ctx, ref, _) {
            // Watch unitsProvider inside widget tree so updates reflect instantly
            final units = ref.watch(unitsProvider).value ?? const [];
            final latestUnit = units.cast<Map<String, dynamic>>().firstWhere(
              (u) => u['id'].toString() == unit['id'].toString(),
              orElse: () => unit,
            );

            return StatefulBuilder(
              builder: (ctx, setState) {

            final residents = (latestUnit['residents'] as List? ??
                latestUnit['unitResidents'] as List? ??
                []);
            final rentals = latestUnit['rentalRecords'] as List? ?? [];
            final occupancy =
                (latestUnit['occupancyType'] as String? ?? 'OWNER_OCCUPIED')
                    .toUpperCase();

            final owners = residents
                .where((r) => r is Map && r['isOwner'] == true)
                .toList();
            final stayingOwners = owners
                .where((r) => (r as Map)['isStaying'] != false)
                .toList();
            final nonOwnerResidents = residents
                .where(
                  (r) =>
                      r is Map &&
                      r['isOwner'] != true &&
                      r['isStaying'] != false,
                )
                .toList();
            Future<void> showAssignPersonSheet() async {
              final searchCtrl = TextEditingController();
              bool searching = false;
              String? pickedUserId;
              String? pickedName;
              bool isOwner = false;
              bool isStaying = true;
              List<Map<String, dynamic>> results = [];

              await showAppSheet(
                context: context,
                builder: (sheetCtx) => StatefulBuilder(
                  builder: (sheetCtx, setSheetState) {
                    Future<void> doSearch() async {
                      final q = searchCtrl.text.trim();
                      if (q.length < 2) {
                        setSheetState(() => results = []);
                        return;
                      }
                      setSheetState(() => searching = true);
                      final r = await ref.read(unitsProvider.notifier).searchMembers(q);
                      if (sheetCtx.mounted) {
                        setSheetState(() {
                          results = r;
                          searching = false;
                        });
                      }
                    }

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppDimensions.screenPadding,
                        AppDimensions.lg,
                        AppDimensions.screenPadding,
                        MediaQuery.of(sheetCtx).viewInsets.bottom + AppDimensions.lg,
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
                          Text('Assign Person', style: AppTextStyles.h2),
                          const SizedBox(height: AppDimensions.sm),
                          Text(
                            'Add owner/resident and mark if they are staying in this unit.',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: AppDimensions.md),
                          AppTextField(
                            label: 'Search Member (name / phone)',
                            controller: searchCtrl,
                            onChanged: (_) => doSearch(),
                          ),
                          const SizedBox(height: AppDimensions.sm),
                          if (searching) const LinearProgressIndicator(),
                          if (!searching && results.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                'Type at least 2 letters to search.',
                                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                              ),
                            ),
                          if (results.isNotEmpty)
                            SizedBox(
                              height: 220,
                              child: ListView.builder(
                                itemCount: results.length,
                                itemBuilder: (c, i) {
                                  final m = results[i];
                                  final id = (m['id'] ?? '').toString();
                                  final name = (m['name'] ?? '-').toString();
                                  final phone = (m['phone'] ?? '').toString();
                                  final selected = pickedUserId == id;
                                  return ListTile(
                                    dense: true,
                                    title: Text(name),
                                    subtitle: phone.isNotEmpty ? Text(phone) : null,
                                    trailing: selected
                                        ? const Icon(Icons.check_circle, color: AppColors.success)
                                        : null,
                                    onTap: () => setSheetState(() {
                                      pickedUserId = id;
                                      pickedName = name;
                                    }),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: AppDimensions.sm),
                          SwitchListTile(
                            value: isOwner,
                            onChanged: (v) => setSheetState(() {
                              isOwner = v;
                              // If assigning property owner, default to not staying (can override).
                              if (isOwner && isStaying) isStaying = false;
                            }),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('This person is the Owner'),
                          ),
                          SwitchListTile(
                            value: isStaying,
                            onChanged: (v) => setSheetState(() => isStaying = v),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Staying in this unit'),
                            subtitle: Text(
                              isStaying ? 'They live in this unit' : 'They do not live here (property owner only)',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.md),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: pickedUserId == null
                                  ? null
                                  : () async {
                                      final err = await ref.read(unitsProvider.notifier).assignResident(
                                            latestUnit['id'].toString(),
                                            pickedUserId!,
                                            isOwner: isOwner,
                                            isStaying: isStaying,
                                          );
                                      if (sheetCtx.mounted) {
                                        if (err == null) {
                                          Navigator.pop(sheetCtx);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('${pickedName ?? 'Person'} assigned'),
                                                backgroundColor: AppColors.success,
                                              ),
                                            );
                                          }
                                        } else {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(err),
                                                backgroundColor: AppColors.danger,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                              child: const Text('Assign'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            }

            final viewInsets = MediaQuery.of(ctx).viewInsets;
            final sheetHeight = MediaQuery.of(ctx).size.height * 0.78;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.screenPadding,
                  AppDimensions.lg,
                  AppDimensions.screenPadding,
                  AppDimensions.lg,
                ),
                child: SizedBox(
                  height: sheetHeight,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Unit ${latestUnit['fullCode'] ?? ''}',
                          style: AppTextStyles.h1,
                        ),
                      ),
                      if (occupancy == 'RENTED' || occupancy == 'LEASED' || occupancy == 'PARTIALLY_RENTED')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          child: Text(
                            occupancy == 'PARTIALLY_RENTED' ? 'Owner + Rental' : occupancy == 'LEASED' ? 'Leased' : 'Rented',
                            style: AppTextStyles.caption.copyWith(color: const Color(0xFFE65100), fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  const TabBar(
                    tabs: [
                      Tab(text: 'Edit'),
                      Tab(text: 'Who Stays Here'),
                    ],
                    labelColor: AppColors.primary,
                    indicatorColor: AppColors.primary,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // ── Edit Tab ──
                        SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: AppDimensions.lg),
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
                                          setState(() => saving = true);
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
                                              setState(() => saving = false);
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

                        // ── Who Stays Here Tab ──
                        SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: AppDimensions.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (canManage)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.person_add_alt_1_rounded),
                                      label: const Text('Assign Owner / Resident'),
                                      onPressed: showAssignPersonSheet,
                                    ),
                                  ),
                                ),
                              // ── Owners Section ──
                              _SectionHeader(
                                icon: Icons.home_rounded,
                                title: 'Owner${owners.length > 1 ? 's' : ''}',
                                count: owners.length,
                                color: const Color(0xFF2E7D32),
                              ),
                              if (owners.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  child: Text(
                                    'No owner assigned to this unit',
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontStyle: FontStyle.italic),
                                  ),
                                )
                              else
                                ...owners.map((r) {
                                  final userId = (r['user']?['id'] ?? '').toString();
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: _PersonTile(
                                          name: r['user']?['name'] ?? '-',
                                          phone: r['user']?['phone'] ?? '',
                                          role: r['user']?['role'] ?? '',
                                          subtitle: (r['isStaying'] == false) ? 'Property owner (not staying)' : null,
                                          badge: (r['isStaying'] == false) ? 'Owner (Not Staying)' : 'Owner',
                                          badgeColor: const Color(0xFF2E7D32),
                                          icon: Icons.home_rounded,
                                        ),
                                      ),
                                      if (canManage && userId.isNotEmpty)
                                        IconButton(
                                          tooltip: 'Remove from unit',
                                          icon: const Icon(Icons.remove_circle, color: AppColors.danger),
                                          onPressed: () async {
                                            final ok = await showConfirmSheet(
                                              context: context,
                                              title: 'Remove Owner',
                                              message: 'Remove this owner from unit ${unit['fullCode'] ?? ''}?',
                                              confirmLabel: 'Remove',
                                            );
                                            if (!ok) return;
                                            final err = await ref.read(unitsProvider.notifier).removeResident(
                                                  unit['id'].toString(),
                                                  userId,
                                                );
                                            if (ctx.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(err == null ? 'Removed' : err),
                                                  backgroundColor: err == null ? AppColors.success : AppColors.danger,
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                    ],
                                  );
                                }),

                              // ── Other Residents (family members etc) ──
                              if (nonOwnerResidents.isNotEmpty) ...[
                                const SizedBox(height: AppDimensions.md),
                                _SectionHeader(
                                  icon: Icons.people_rounded,
                                  title: 'Family / Residents',
                                  count: nonOwnerResidents.length,
                                  color: AppColors.primary,
                                ),
                                ...nonOwnerResidents.map((r) {
                                  final userId = (r['user']?['id'] ?? '').toString();
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: _PersonTile(
                                          name: r['user']?['name'] ?? '-',
                                          phone: r['user']?['phone'] ?? '',
                                          role: r['user']?['role'] ?? '',
                                          badge: 'Resident',
                                          badgeColor: AppColors.primary,
                                          icon: Icons.person_rounded,
                                        ),
                                      ),
                                      if (canManage && userId.isNotEmpty)
                                        IconButton(
                                          tooltip: 'Remove from unit',
                                          icon: const Icon(Icons.remove_circle, color: AppColors.danger),
                                          onPressed: () async {
                                            final ok = await showConfirmSheet(
                                              context: context,
                                              title: 'Remove Resident',
                                              message: 'Remove this resident from unit ${unit['fullCode'] ?? ''}?',
                                              confirmLabel: 'Remove',
                                            );
                                            if (!ok) return;
                                            final err = await ref.read(unitsProvider.notifier).removeResident(
                                                  unit['id'].toString(),
                                                  userId,
                                                );
                                            if (ctx.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(err == null ? 'Removed' : err),
                                                  backgroundColor: err == null ? AppColors.success : AppColors.danger,
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                    ],
                                  );
                                }),
                              ],

                              // ── Tenants Section ──
                              if (rentals.isNotEmpty) ...[
                                const SizedBox(height: AppDimensions.md),
                                _SectionHeader(
                                  icon: Icons.key_rounded,
                                  title: 'Tenant${rentals.length > 1 ? 's' : ''} (Rental)',
                                  count: rentals.length,
                                  color: const Color(0xFFE65100),
                                ),
                                ...rentals.expand((r) {
                                  final portion = r['portion'] as String? ?? '';
                                  final rent = r['rentAmount'];
                                  final rentStr = rent != null ? '\u20B9${double.tryParse(rent.toString())?.toStringAsFixed(0) ?? rent}/mo' : '';
                                  final members = r['members'] as List? ?? [];

                                  return <Widget>[
                                    _PersonTile(
                                      name: r['tenantName'] ?? '-',
                                      phone: r['tenantPhone'] ?? '',
                                      subtitle: [
                                        if (portion.isNotEmpty) portion,
                                        if (rentStr.isNotEmpty) rentStr,
                                      ].join(' \u2022 '),
                                      badge: 'Tenant',
                                      badgeColor: const Color(0xFFE65100),
                                      icon: Icons.key_rounded,
                                    ),
                                    // Show individual family members
                                    ...members.where((m) => (m['relation'] ?? '') != 'SELF').map((m) {
                                      final relation = m['relation'] as String? ?? 'OTHER';
                                      final age = m['age'];
                                      final gender = m['gender'] as String?;
                                      final relationLabel = {
                                        'SPOUSE': 'Spouse',
                                        'CHILD': 'Child',
                                        'PARENT': 'Parent',
                                        'SIBLING': 'Sibling',
                                      }[relation] ?? 'Family';
                                      final details = [
                                        relationLabel,
                                        if (age != null) '$age yrs',
                                        if (gender != null) gender.toLowerCase(),
                                        if (portion.isNotEmpty) portion,
                                      ].join(' \u2022 ');

                                      return Padding(
                                        padding: const EdgeInsets.only(left: 20),
                                        child: _PersonTile(
                                          name: m['name'] ?? '-',
                                          phone: m['phone'] ?? '',
                                          subtitle: details,
                                          badge: relationLabel,
                                          badgeColor: const Color(0xFFFF8F00),
                                          icon: relation == 'CHILD' ? Icons.child_care : Icons.person_outline,
                                        ),
                                      );
                                    }),
                                  ];
                                }),
                              ],

                              // ── Empty State ──
                              if (stayingOwners.isEmpty && nonOwnerResidents.isEmpty && rentals.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.person_off_rounded, size: 40, color: AppColors.textMuted.withOpacity(0.5)),
                                        const SizedBox(height: 8),
                                        Text('No one assigned to this unit', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                                      ],
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
                ),
              ),
            );
              },
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
    String? errorMsg;
    bool saving = false;

    showAppSheet(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: StatefulBuilder(
          builder: (ctx, setDlgState) {
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
                    Text(errorMsg!, style: const TextStyle(color: AppColors.danger)),
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

  (Color bg, Color border) _getUnitColors(String status, [String? occupancy]) {
    if (status == 'OCCUPIED') {
      if (occupancy == 'RENTED' || occupancy == 'LEASED') {
        return (const Color(0xFFFFF3E0), const Color(0xFFE65100)); // Orange for fully rented
      }
      if (occupancy == 'PARTIALLY_RENTED') {
        return (const Color(0xFFFFF8E1), const Color(0xFFF57F17)); // Amber for owner + tenant mix
      }
      return (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)); // Green for owner-occupied
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
                fontSize: 11,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final String name;
  final String phone;
  final String? role;
  final String? subtitle;
  final String badge;
  final Color badgeColor;
  final IconData icon;

  const _PersonTile({
    required this.name,
    this.phone = '',
    this.role,
    this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final sub = subtitle ?? (phone.isNotEmpty ? phone : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.04),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: badgeColor.withOpacity(0.12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: badgeColor.withOpacity(0.15),
              child: Icon(icon, size: 16, color: badgeColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sub != null && sub.isNotEmpty)
                    Text(
                      sub,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
