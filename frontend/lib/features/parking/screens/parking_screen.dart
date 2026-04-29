import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_kpi_card.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/widgets/show_app_sheet.dart';
import '../../units/providers/unit_provider.dart';
import '../providers/parking_provider.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

Color _slotStatusColor(String status) {
  switch (status.toUpperCase()) {
    case 'AVAILABLE':
      return AppColors.success;
    case 'OCCUPIED':
      return AppColors.danger;
    case 'RESERVED':
      return AppColors.warning;
    case 'BLOCKED':
      return AppColors.danger;
    case 'UNDER_MAINTENANCE':
      return AppColors.textMuted;
    default:
      return AppColors.info;
  }
}

IconData _slotTypeIcon(String type) {
  switch (type.toUpperCase()) {
    case 'COVERED':
      return Icons.garage_rounded;
    case 'BASEMENT':
      return Icons.layers_rounded;
    case 'STILT':
      return Icons.foundation_rounded;
    case 'VISITOR':
      return Icons.person_pin_circle_rounded;
    case 'RESERVED':
      return Icons.block_rounded;
    default:
      return Icons.local_parking_rounded;
  }
}

String _slotTypeLabel(String type) {
  switch (type.toUpperCase()) {
    case 'COVERED':
      return 'Covered';
    case 'OPEN':
      return 'Open';
    case 'BASEMENT':
      return 'Basement';
    case 'VISITOR':
      return 'Visitor';
    case 'STILT':
      return 'Stilt';
    case 'RESERVED':
      return 'Reserved';
    default:
      return type;
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Tab enum
// ════════════════════════════════════════════════════════════════════════════

enum _ParkingTab { slots, allotments, sessions, charges }

// ════════════════════════════════════════════════════════════════════════════
//  Main Screen
// ════════════════════════════════════════════════════════════════════════════

class ParkingScreen extends ConsumerStatefulWidget {
  const ParkingScreen({super.key});

  @override
  ConsumerState<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends ConsumerState<ParkingScreen> {
  _ParkingTab _tab = _ParkingTab.slots;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.role.toUpperCase() ?? '';
    final isAdmin = isParkingAdmin(role);
    final isStaff = isParkingStaff(role);
    final state = ref.watch(parkingProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: _buildFab(context, isAdmin, isStaff, state),
      body: state.isLoading
          ? const AppLoadingShimmer(itemCount: 6, itemHeight: 120)
          : state.error != null
              ? Center(
                  child: _ErrorBox(
                    message: state.error!,
                    onRetry: () => ref.read(parkingProvider.notifier).load(),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(parkingProvider.notifier).load(),
                  child: CustomScrollView(
                    slivers: [
                      // Dashboard KPI strip
                      if (state.dashboard != null)
                        SliverToBoxAdapter(child: _DashboardStrip(dashboard: state.dashboard!)),

                      // Tab bar
                      SliverToBoxAdapter(
                        child: _TabBar(
                          selected: _tab,
                          isAdmin: isAdmin,
                          isStaff: isStaff,
                          onChanged: (t) => setState(() => _tab = t),
                        ),
                      ),

                      // Tab content
                      SliverPadding(
                        padding: const EdgeInsets.all(AppDimensions.screenPadding),
                        sliver: SliverToBoxAdapter(child: _buildTabContent(isAdmin, isStaff, state)),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget? _buildFab(
      BuildContext context, bool isAdmin, bool isStaff, ParkingState state) {
    if (_tab == _ParkingTab.slots && isAdmin) {
      return FloatingActionButton.extended(
        heroTag: 'parking_add_slot',
        onPressed: () => _showSlotForm(context, null),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: AppColors.textOnPrimary),
        label: Text('Add Slot',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary)),
      );
    }
    if (_tab == _ParkingTab.allotments && isAdmin) {
      return FloatingActionButton.extended(
        heroTag: 'parking_allot',
        onPressed: () => _showAllotmentForm(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.assignment_rounded, color: AppColors.textOnPrimary),
        label: Text('Allot Slot',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary)),
      );
    }
    if (_tab == _ParkingTab.sessions && isStaff) {
      return FloatingActionButton.extended(
        heroTag: 'parking_entry',
        onPressed: () => _showEntryForm(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.login_rounded, color: AppColors.textOnPrimary),
        label: Text('Log Entry',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary)),
      );
    }
    return null;
  }

  Widget _buildTabContent(bool isAdmin, bool isStaff, ParkingState state) {
    switch (_tab) {
      case _ParkingTab.slots:
        return _SlotsTab(slots: state.slots, isAdmin: isAdmin, onEdit: _showSlotForm);
      case _ParkingTab.allotments:
        return _AllotmentsTab(isAdmin: isAdmin);
      case _ParkingTab.sessions:
        return _SessionsTab(isStaff: isStaff);
      case _ParkingTab.charges:
        return _ChargesTab(isAdmin: isAdmin);
    }
  }

  // ── Slot form ──────────────────────────────────────────────────────────────

  void _showSlotForm(BuildContext context, Map<String, dynamic>? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl))),
      builder: (_) => _SlotFormSheet(
        existing: existing,
        onSubmit: (data) async {
          final err = existing != null
              ? await ref
                  .read(parkingProvider.notifier)
                  .updateSlot(existing['id'] as String, data)
              : await ref.read(parkingProvider.notifier).createSlot(data);
          if (context.mounted) {
            Navigator.pop(context);
            _snack(context, err ?? (existing != null ? 'Slot updated.' : 'Slot created.'),
                err == null);
          }
        },
      ),
    );
  }

  // ── Allotment form ─────────────────────────────────────────────────────────

  void _showAllotmentForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl))),
      builder: (_) => _AllotmentFormSheet(
        onSubmit: (data) async {
          final err = await ref.read(parkingProvider.notifier).createAllotment(data);
          if (context.mounted) {
            Navigator.pop(context);
            _snack(context, err ?? 'Parking slot allotted.', err == null);
            if (err == null) {
              ref.invalidate(parkingAllotmentsProvider);
            }
          }
        },
      ),
    );
  }

  // ── Entry form ─────────────────────────────────────────────────────────────

  void _showEntryForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl))),
      builder: (_) => _EntryFormSheet(
        onSubmit: (data) async {
          final err = await ref.read(parkingProvider.notifier).logEntry(data);
          if (context.mounted) {
            Navigator.pop(context);
            _snack(context, err ?? 'Vehicle entry logged.', err == null);
            if (err == null) ref.invalidate(parkingSessionsProvider);
          }
        },
      ),
    );
  }

  static void _snack(BuildContext context, String msg, bool ok) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ));
}

// ════════════════════════════════════════════════════════════════════════════
//  Dashboard KPI strip
// ════════════════════════════════════════════════════════════════════════════

class _DashboardStrip extends StatelessWidget {
  final Map<String, dynamic> dashboard;
  const _DashboardStrip({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final slots = dashboard['slots'] as Map<String, dynamic>? ?? {};
    final allotments = dashboard['allotments'] as Map<String, dynamic>? ?? {};
    final charges = dashboard['charges'] as Map<String, dynamic>? ?? {};
    final sessions = dashboard['sessions'] as Map<String, dynamic>? ?? {};

    final total = slots['total']?.toString() ?? '0';
    final available = slots['available']?.toString() ?? '0';
    final occupied = slots['occupied']?.toString() ?? '0';
    final pct = slots['occupancyPercent']?.toString() ?? '0';
    final activeAllotments = allotments['active']?.toString() ?? '0';
    final activeSessions = sessions['active']?.toString() ?? '0';
    final pendingAmount = charges['pendingAmount'];
    final pendingAmountStr = pendingAmount != null
        ? '₹${double.tryParse(pendingAmount.toString())?.toStringAsFixed(0) ?? '0'}'
        : '₹0';

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.screenPadding, AppDimensions.md, AppDimensions.screenPadding, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.sm),
          child: Text('Overview', style: AppTextStyles.h3),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            AppKpiCard(label: 'Total Slots', value: total),
            const SizedBox(width: AppDimensions.sm),
            AppKpiCard(label: 'Available', value: available, isAccent: true),
            const SizedBox(width: AppDimensions.sm),
            AppKpiCard(label: 'Occupied', value: occupied),
            const SizedBox(width: AppDimensions.sm),
            AppKpiCard(label: 'Occupancy', value: '$pct%'),
            const SizedBox(width: AppDimensions.sm),
            AppKpiCard(label: 'Allotted', value: activeAllotments),
            const SizedBox(width: AppDimensions.sm),
            AppKpiCard(label: 'Live Sessions', value: activeSessions),
            const SizedBox(width: AppDimensions.sm),
            AppKpiCard(label: 'Pending Dues', value: pendingAmountStr),
          ]),
        ),
        const SizedBox(height: AppDimensions.sm),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Tab bar
// ════════════════════════════════════════════════════════════════════════════

class _TabBar extends StatelessWidget {
  final _ParkingTab selected;
  final bool isAdmin;
  final bool isStaff;
  final ValueChanged<_ParkingTab> onChanged;
  const _TabBar(
      {required this.selected,
      required this.isAdmin,
      required this.isStaff,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tabs = <(String, _ParkingTab, bool)>[
      ('Slots', _ParkingTab.slots, true),
      ('Allotments', _ParkingTab.allotments, isAdmin),
      ('Sessions', _ParkingTab.sessions, isStaff),
      ('Charges', _ParkingTab.charges, isAdmin),
    ].where((t) => t.$3).toList();

    return Container(
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenPadding),
        child: Row(
          children: tabs.map((t) {
            final isSel = selected == t.$2;
            return GestureDetector(
              onTap: () => onChanged(t.$2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSel ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  t.$1,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: isSel ? AppColors.primary : AppColors.textMuted,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Slots Tab
// ════════════════════════════════════════════════════════════════════════════

class _SlotsTab extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> slots;
  final bool isAdmin;
  final void Function(BuildContext, Map<String, dynamic>?) onEdit;
  const _SlotsTab(
      {required this.slots, required this.isAdmin, required this.onEdit});

  @override
  ConsumerState<_SlotsTab> createState() => _SlotsTabState();
}

class _SlotsTabState extends ConsumerState<_SlotsTab> {
  String _filterStatus = 'ALL';
  String _filterType = 'ALL';

  List<Map<String, dynamic>> get _filtered {
    return widget.slots.where((s) {
      final isActive = s['isActive'] ?? true;
      final statusOk = _filterStatus == 'ALL'
          ? isActive
          : _filterStatus == 'DEACTIVATED'
              ? !isActive
              : isActive && (s['status'] as String? ?? '').toUpperCase() == _filterStatus;
      final typeOk = _filterType == 'ALL' ||
          (s['type'] as String? ?? '').toUpperCase() == _filterType;
      return statusOk && typeOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Filter chips
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _FilterChip(label: 'All', selected: _filterStatus == 'ALL',
              onTap: () => setState(() => _filterStatus = 'ALL')),
          _FilterChip(label: 'Available', selected: _filterStatus == 'AVAILABLE',
              onTap: () => setState(() => _filterStatus = 'AVAILABLE')),
          _FilterChip(label: 'Occupied', selected: _filterStatus == 'OCCUPIED',
              onTap: () => setState(() => _filterStatus = 'OCCUPIED')),
          _FilterChip(label: 'Blocked', selected: _filterStatus == 'BLOCKED',
              onTap: () => setState(() => _filterStatus = 'BLOCKED')),
          _FilterChip(label: 'Maintenance', selected: _filterStatus == 'UNDER_MAINTENANCE',
              onTap: () => setState(() => _filterStatus = 'UNDER_MAINTENANCE')),
          _FilterChip(label: 'Deactivated', selected: _filterStatus == 'DEACTIVATED',
              onTap: () => setState(() => _filterStatus = 'DEACTIVATED')),
          const SizedBox(width: 12),
          _FilterChip(label: 'Covered', selected: _filterType == 'COVERED',
              onTap: () => setState(() => _filterType = _filterType == 'COVERED' ? 'ALL' : 'COVERED')),
          _FilterChip(label: 'Open', selected: _filterType == 'OPEN',
              onTap: () => setState(() => _filterType = _filterType == 'OPEN' ? 'ALL' : 'OPEN')),
          _FilterChip(label: 'Basement', selected: _filterType == 'BASEMENT',
              onTap: () => setState(() => _filterType = _filterType == 'BASEMENT' ? 'ALL' : 'BASEMENT')),
          _FilterChip(label: 'Visitor', selected: _filterType == 'VISITOR',
              onTap: () => setState(() => _filterType = _filterType == 'VISITOR' ? 'ALL' : 'VISITOR')),
        ]),
      ),
      const SizedBox(height: AppDimensions.md),

      if (filtered.isEmpty)
        const AppEmptyState(
            emoji: '🅿️', title: 'No Slots', subtitle: 'No parking slots match your filters.')
      else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (_, i) => const SizedBox(height: AppDimensions.sm),
          itemBuilder: (ctx, i) => _SlotCard(
            slot: filtered[i],
            isAdmin: widget.isAdmin,
            onEdit: () => widget.onEdit(ctx, filtered[i]),
            onDelete: () => _confirmDelete(ctx, filtered[i]['id'] as String),
            onRestore: () => _restoreSlot(ctx, filtered[i]['id'] as String),
            onUnblock: () => _unblockSlot(ctx, filtered[i]['id'] as String),
          ),
        ),
    ]);
  }

  Future<void> _unblockSlot(BuildContext context, String id) async {
    final err =
        await ref.read(parkingProvider.notifier).updateSlot(id, {'status': 'AVAILABLE'});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Slot unblocked.'),
        backgroundColor: err == null ? AppColors.success : AppColors.danger,
      ));
      if (err == null) {
        await ref.read(parkingProvider.notifier).load();
      }
    }
  }

  void _restoreSlot(BuildContext context, String id) async {
    final ok = await showConfirmSheet(
      context: context,
      title: 'Restore Slot',
      message: 'This will reactivate the parking slot.',
      confirmLabel: 'Restore',
    );
    if (ok == true && context.mounted) {
      final err = await ref
          .read(parkingProvider.notifier)
          .updateSlot(id, {'isActive': true, 'status': 'AVAILABLE'});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err ?? 'Slot restored.'),
          backgroundColor: err == null ? AppColors.success : AppColors.danger,
        ));
      }
    }
  }

  void _confirmDelete(BuildContext context, String id) async {
    final ok = await showConfirmSheet(
      context: context,
      title: 'Remove Slot',
      message: 'This slot will be deactivated. Any active allotment must be released first.',
      confirmLabel: 'Remove',
    );
    if (ok == true && context.mounted) {
      final err = await ref.read(parkingProvider.notifier).deleteSlot(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err ?? 'Slot removed.'),
          backgroundColor: err == null ? AppColors.success : AppColors.danger,
        ));
      }
    }
  }
}

class _SlotCard extends StatelessWidget {
  final Map<String, dynamic> slot;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRestore;
  final VoidCallback onUnblock;
  const _SlotCard(
      {required this.slot,
      required this.isAdmin,
      required this.onEdit,
      required this.onDelete,
      required this.onRestore,
      required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    final number = slot['slotNumber'] as String? ?? '-';
    final type = slot['type'] as String? ?? 'OPEN';
    final status = slot['status'] as String? ?? 'AVAILABLE';
    final isActive = slot['isActive'] ?? true;
    final isBlocked = status.toUpperCase() == 'BLOCKED';
    final zone = slot['zone'] as String?;
    final floor = slot['floor'];
    final hasEV = slot['hasEVCharger'] == true;
    final isHandicapped = slot['isHandicapped'] == true;
    final notes = slot['notes'] as String?;
    final allotments = slot['allotments'] as List? ?? [];
    final activeAllotment = allotments.isNotEmpty
        ? allotments.first as Map<String, dynamic>
        : null;

    final baseColor = isActive ? _slotStatusColor(status) : AppColors.textMuted;

    return AppCard(
      leftBorderColor: baseColor,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_slotTypeIcon(type), size: 20, color: baseColor),
        ),
        const SizedBox(width: AppDimensions.md),

        // Info
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(number,
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isActive ? null : AppColors.textMuted,
                  )),
              const SizedBox(width: 8),
              if (isActive)
                AppStatusChip(status: status.toLowerCase())
              else
                _Badge(label: 'DEACTIVATED', color: AppColors.textMuted),
              const Spacer(),
              if (hasEV)
                _Badge(label: '⚡ EV', color: AppColors.info),
              if (isHandicapped) ...[
                const SizedBox(width: 4),
                _Badge(label: '♿', color: AppColors.warning),
              ],
            ]),
            const SizedBox(height: 4),
            Row(children: [
              _iconRow(_slotTypeIcon(type), _slotTypeLabel(type)),
              if (zone != null) ...[
                const SizedBox(width: 10),
                _iconRow(Icons.grid_view_rounded, 'Zone $zone'),
              ],
              if (floor != null) ...[
                const SizedBox(width: 10),
                _iconRow(Icons.layers_rounded,
                    floor == 0 ? 'Ground' : floor < 0 ? 'B${floor.abs()}' : 'F$floor'),
              ],
            ]),
            if (activeAllotment != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                _iconRow(Icons.apartment_rounded,
                    activeAllotment['unit']?['fullCode'] ?? '-'),
                if (activeAllotment['vehicle'] != null) ...[
                  const SizedBox(width: 10),
                  _iconRow(Icons.directions_car_rounded,
                      activeAllotment['vehicle']['numberPlate'] ?? '-'),
                ],
              ]),
            ],
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 2),
              _iconRow(Icons.notes_rounded, notes),
            ],
          ]),
        ),

        // Admin actions
        if (isAdmin)
          Column(children: [
            if (isActive) ...[
              if (isBlocked) ...[
                GestureDetector(
                  onTap: onUnblock,
                  child: const Icon(
                    Icons.lock_open_rounded,
                    size: 18,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              GestureDetector(
                  onTap: onEdit,
                  child: const Icon(Icons.edit_rounded, size: 16, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger)),
            ] else
              GestureDetector(
                  onTap: onRestore,
                  child: const Icon(Icons.settings_backup_restore_rounded,
                      size: 20, color: AppColors.primary)),
          ]),
      ]),
    );
  }

  Widget _iconRow(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text(text, style: AppTextStyles.caption),
      ]);
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: AppTextStyles.caption.copyWith(color: color)),
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  Allotments Tab
// ════════════════════════════════════════════════════════════════════════════

class _AllotmentsTab extends ConsumerStatefulWidget {
  final bool isAdmin;
  const _AllotmentsTab({required this.isAdmin});

  @override
  ConsumerState<_AllotmentsTab> createState() => _AllotmentsTabState();
}

class _AllotmentsTabState extends ConsumerState<_AllotmentsTab> {
  String? _statusFilter = 'ACTIVE';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(parkingAllotmentsProvider(_statusFilter));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Status filter
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _FilterChip(label: 'Active', selected: _statusFilter == 'ACTIVE',
              onTap: () => setState(() => _statusFilter = 'ACTIVE')),
          _FilterChip(label: 'All', selected: _statusFilter == null,
              onTap: () => setState(() => _statusFilter = null)),
          _FilterChip(label: 'Suspended', selected: _statusFilter == 'SUSPENDED',
              onTap: () => setState(() => _statusFilter = 'SUSPENDED')),
          _FilterChip(label: 'Released', selected: _statusFilter == 'RELEASED',
              onTap: () => setState(() => _statusFilter = 'RELEASED')),
        ]),
      ),
      const SizedBox(height: AppDimensions.md),

      async.when(
        loading: () => const AppLoadingShimmer(itemCount: 4, itemHeight: 90),
        error: (e, _) => _ErrorBox(message: e.toString(),
            onRetry: () => ref.invalidate(parkingAllotmentsProvider)),
        data: (allotments) => allotments.isEmpty
            ? const AppEmptyState(
                emoji: '📋', title: 'No Allotments', subtitle: 'No parking slots have been allotted yet.')
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allotments.length,
                separatorBuilder: (_, i) => const SizedBox(height: AppDimensions.sm),
                itemBuilder: (ctx, i) => _AllotmentCard(
                  allotment: allotments[i],
                  isAdmin: widget.isAdmin,
                  onRelease: () => _confirmRelease(ctx, allotments[i]['id'] as String),
                  onSuspend: () => _confirmSuspend(ctx, allotments[i]),
                ),
              ),
      ),
    ]);
  }

  void _confirmRelease(BuildContext context, String id) async {
    final ok = await showConfirmSheet(
        context: context,
        title: 'Release Slot',
        message: 'This will free the slot and make it available again.',
        confirmLabel: 'Release');
    if (ok == true && context.mounted) {
      final err = await ref.read(parkingProvider.notifier).releaseAllotment(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err ?? 'Slot released.'),
          backgroundColor: err == null ? AppColors.success : AppColors.danger,
        ));
        if (err == null) ref.invalidate(parkingAllotmentsProvider);
      }
    }
  }

  void _confirmSuspend(BuildContext context, Map<String, dynamic> allotment) async {
    final isSuspended = (allotment['status'] as String? ?? '').toUpperCase() == 'SUSPENDED';
    if (isSuspended) {
      final err = await ref
          .read(parkingProvider.notifier)
          .reinstateAllotment(allotment['id'] as String);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err ?? 'Allotment reinstated.'),
          backgroundColor: err == null ? AppColors.success : AppColors.danger,
        ));
        if (err == null) ref.invalidate(parkingAllotmentsProvider);
      }
      return;
    }
    final ok = await showConfirmSheet(
        context: context,
        title: 'Suspend Allotment',
        message: 'Resident will lose access to the slot until reinstated.',
        confirmLabel: 'Suspend');
    if (ok == true && context.mounted) {
      final err = await ref
          .read(parkingProvider.notifier)
          .suspendAllotment(allotment['id'] as String);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err ?? 'Allotment suspended.'),
          backgroundColor: err == null ? AppColors.success : AppColors.danger,
        ));
        if (err == null) ref.invalidate(parkingAllotmentsProvider);
      }
    }
  }
}

class _AllotmentCard extends StatelessWidget {
  final Map<String, dynamic> allotment;
  final bool isAdmin;
  final VoidCallback onRelease;
  final VoidCallback onSuspend;
  const _AllotmentCard(
      {required this.allotment,
      required this.isAdmin,
      required this.onRelease,
      required this.onSuspend});

  @override
  Widget build(BuildContext context) {
    final slot = allotment['slot'] as Map<String, dynamic>? ?? {};
    final unit = allotment['unit'] as Map<String, dynamic>? ?? {};
    final vehicle = allotment['vehicle'] as Map<String, dynamic>?;
    final status = allotment['status'] as String? ?? 'ACTIVE';
    final startDate = allotment['startDate'] as String?;
    final isSuspended = status.toUpperCase() == 'SUSPENDED';
    final isActive = status.toUpperCase() == 'ACTIVE';

    return AppCard(
      leftBorderColor: isSuspended ? AppColors.warning : AppColors.success,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.local_parking_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(slot['slotNumber'] ?? '-', style: AppTextStyles.h3),
          const SizedBox(width: 8),
          _Badge(label: _slotTypeLabel(slot['type'] ?? 'OPEN'), color: AppColors.info),
          if (slot['zone'] != null) ...[
            const SizedBox(width: 4),
            _Badge(label: 'Zone ${slot['zone']}', color: AppColors.textMuted),
          ],
          const Spacer(),
          AppStatusChip(status: status.toLowerCase()),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.apartment_rounded, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(unit['fullCode'] ?? '-', style: AppTextStyles.bodySmall),
          if (vehicle != null) ...[
            const SizedBox(width: 12),
            Icon(Icons.directions_car_rounded, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(vehicle['numberPlate'] ?? '-', style: AppTextStyles.bodySmall),
            const SizedBox(width: 4),
            Text('(${vehicle['type'] ?? ''})', style: AppTextStyles.caption),
          ],
        ]),
        if (startDate != null) ...[
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.calendar_today_rounded, size: 11, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text('Since ${DateFormat('dd MMM yyyy').format(DateTime.parse(startDate))}',
                style: AppTextStyles.caption),
          ]),
        ],
        if (isAdmin && (isActive || isSuspended)) ...[
          const SizedBox(height: AppDimensions.sm),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (isActive)
              _SmallBtn(
                  label: isSuspended ? 'Reinstate' : 'Suspend',
                  color: AppColors.warning,
                  onTap: onSuspend),
            const SizedBox(width: 8),
            if (isActive || isSuspended)
              _SmallBtn(label: 'Release', color: AppColors.danger, onTap: onRelease),
          ]),
        ],
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Sessions Tab
// ════════════════════════════════════════════════════════════════════════════

class _SessionsTab extends ConsumerWidget {
  final bool isStaff;
  const _SessionsTab({required this.isStaff});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(parkingSessionsProvider);

    return async.when(
      loading: () => const AppLoadingShimmer(itemCount: 4, itemHeight: 90),
      error: (e, _) => _ErrorBox(
          message: e.toString(),
          onRetry: () => ref.invalidate(parkingSessionsProvider)),
      data: (sessions) => sessions.isEmpty
          ? const AppEmptyState(
              emoji: '🚗', title: 'No Active Sessions', subtitle: 'No vehicles are currently logged in.')
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sessions.length,
              separatorBuilder: (_, i) => const SizedBox(height: AppDimensions.sm),
              itemBuilder: (ctx, i) => _SessionCard(
                session: sessions[i],
                isStaff: isStaff,
                onExit: () async {
                  final err = await ref
                      .read(parkingProvider.notifier)
                      .logExit(sessions[i]['id'] as String);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(err ?? 'Exit logged.'),
                      backgroundColor: err == null ? AppColors.success : AppColors.danger,
                    ));
                    if (err == null) ref.invalidate(parkingSessionsProvider);
                  }
                },
              ),
            ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final bool isStaff;
  final VoidCallback onExit;
  const _SessionCard(
      {required this.session, required this.isStaff, required this.onExit});

  @override
  Widget build(BuildContext context) {
    final slot = session['slot'] as Map<String, dynamic>? ?? {};
    final vehicle = session['vehicle'] as Map<String, dynamic>?;
    final unit = session['linkedUnit'] as Map<String, dynamic>?;
    final guestPlate = session['guestPlate'] as String?;
    final guestName = session['guestName'] as String?;
    final entryAt = session['entryAt'] as String?;
    final expectedExit = session['expectedExitAt'] as String?;
    final status = session['status'] as String? ?? 'ACTIVE';
    final isOverstayed = status.toUpperCase() == 'OVERSTAYED';

    final plate = vehicle?['numberPlate'] ?? guestPlate ?? '-';
    final label = guestName != null ? '$plate ($guestName)' : plate;

    Duration? duration;
    if (entryAt != null) {
      duration = DateTime.now().difference(DateTime.parse(entryAt));
    }

    return AppCard(
      leftBorderColor: isOverstayed ? AppColors.danger : AppColors.info,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: (isOverstayed ? AppColors.danger : AppColors.info).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.directions_car_rounded,
              size: 18, color: isOverstayed ? AppColors.danger : AppColors.info),
        ),
        const SizedBox(width: AppDimensions.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(label, style: AppTextStyles.labelLarge)),
              if (isOverstayed)
                _Badge(label: 'OVERSTAYED', color: AppColors.danger),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.local_parking_rounded, size: 11, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Text(slot['slotNumber'] ?? '-', style: AppTextStyles.caption),
              if (unit != null) ...[
                const SizedBox(width: 10),
                Icon(Icons.apartment_rounded, size: 11, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Text(unit['fullCode'] ?? '-', style: AppTextStyles.caption),
              ],
            ]),
            if (entryAt != null) ...[
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.login_rounded, size: 11, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Text(DateFormat('hh:mm a').format(DateTime.parse(entryAt)),
                    style: AppTextStyles.caption),
                if (duration != null) ...[
                  const SizedBox(width: 6),
                  Text(
                      '(${duration.inHours > 0 ? '${duration.inHours}h ' : ''}${duration.inMinutes % 60}m)',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                ],
                if (expectedExit != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.logout_rounded, size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text('Due ${DateFormat('hh:mm a').format(DateTime.parse(expectedExit))}',
                      style: AppTextStyles.caption.copyWith(
                          color: isOverstayed ? AppColors.danger : AppColors.textMuted)),
                ],
              ]),
            ],
          ]),
        ),
        if (isStaff)
          TextButton(
            onPressed: onExit,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Exit'),
          ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Charges Tab
// ════════════════════════════════════════════════════════════════════════════

class _ChargesTab extends ConsumerStatefulWidget {
  final bool isAdmin;
  const _ChargesTab({required this.isAdmin});

  @override
  ConsumerState<_ChargesTab> createState() => _ChargesTabState();
}

class _ChargesTabState extends ConsumerState<_ChargesTab> {
  bool? _isPaidFilter = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(parkingChargesProvider(_isPaidFilter));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _FilterChip(label: 'Pending', selected: _isPaidFilter == false,
              onTap: () => setState(() => _isPaidFilter = false)),
          _FilterChip(label: 'Paid', selected: _isPaidFilter == true,
              onTap: () => setState(() => _isPaidFilter = true)),
          _FilterChip(label: 'All', selected: _isPaidFilter == null,
              onTap: () => setState(() => _isPaidFilter = null)),
        ]),
      ),
      const SizedBox(height: AppDimensions.md),

      async.when(
        loading: () => const AppLoadingShimmer(itemCount: 4, itemHeight: 80),
        error: (e, _) => _ErrorBox(
            message: e.toString(),
            onRetry: () => ref.invalidate(parkingChargesProvider)),
        data: (charges) => charges.isEmpty
            ? AppEmptyState(
                emoji: '💳',
                title: _isPaidFilter == false ? 'No Pending Charges' : 'No Charges',
                subtitle: 'All parking dues are cleared.')
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: charges.length,
                separatorBuilder: (_, i) => const SizedBox(height: AppDimensions.sm),
                itemBuilder: (ctx, i) => _ChargeCard(
                  charge: charges[i],
                  isAdmin: widget.isAdmin,
                  onPay: () async {
                    final err = await ref
                        .read(parkingProvider.notifier)
                        .payCharge(charges[i]['id'] as String);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(err ?? 'Charge marked paid.'),
                        backgroundColor: err == null ? AppColors.success : AppColors.danger,
                      ));
                      if (err == null) ref.invalidate(parkingChargesProvider);
                    }
                  },
                ),
              ),
      ),
    ]);
  }
}

class _ChargeCard extends StatelessWidget {
  final Map<String, dynamic> charge;
  final bool isAdmin;
  final VoidCallback onPay;
  const _ChargeCard({required this.charge, required this.isAdmin, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final unit = charge['unit'] as Map<String, dynamic>? ?? {};
    final isPaid = charge['isPaid'] == true;
    final amount = charge['amount'];
    final dueDate = charge['dueDate'] as String?;
    final status = (charge['status'] as String?) ?? (isPaid ? 'PAID' : 'PENDING');
    final description = charge['description'] as String?;

    return AppCard(
      leftBorderColor: isPaid ? AppColors.success : AppColors.warning,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('₹${double.tryParse(amount.toString())?.toStringAsFixed(0) ?? '0'}',
                  style: AppTextStyles.h3.copyWith(
                      color: isPaid ? AppColors.success : AppColors.textPrimary)),
              const SizedBox(width: 8),
              _Badge(label: 'PARKING', color: AppColors.info),
              const Spacer(),
              AppStatusChip(status: isPaid ? 'paid' : status.toLowerCase()),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.apartment_rounded, size: 11, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Text(unit['fullCode'] ?? '-', style: AppTextStyles.caption),
            ]),
            if (dueDate != null) ...[
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.calendar_today_rounded, size: 11, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Text('Due ${DateFormat('dd MMM yyyy').format(DateTime.parse(dueDate))}',
                    style: AppTextStyles.caption.copyWith(
                        color: !isPaid && DateTime.parse(dueDate).isBefore(DateTime.now())
                            ? AppColors.danger
                            : AppColors.textMuted)),
              ]),
            ],
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(description, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            ],
          ]),
        ),
        if (isAdmin && !isPaid) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onPay,
            style: TextButton.styleFrom(foregroundColor: AppColors.success),
            child: const Text('Mark Paid'),
          ),
        ],
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Slot Form Sheet
// ════════════════════════════════════════════════════════════════════════════

class _SlotFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  const _SlotFormSheet({this.existing, required this.onSubmit});

  @override
  State<_SlotFormSheet> createState() => _SlotFormSheetState();
}

class _SlotFormSheetState extends State<_SlotFormSheet> {
  final _slotNumberCtrl = TextEditingController();
  final _zoneCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _type = 'OPEN';
  bool _hasEVCharger = false;
  bool _isHandicapped = false;
  bool _submitting = false;

  static const _types = [
    ('OPEN', 'Open'),
    ('COVERED', 'Covered'),
    ('BASEMENT', 'Basement'),
    ('STILT', 'Stilt'),
    ('VISITOR', 'Visitor'),
    ('RESERVED', 'Reserved'),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _slotNumberCtrl.text = e['slotNumber'] ?? '';
      _zoneCtrl.text = e['zone'] ?? '';
      _floorCtrl.text = e['floor']?.toString() ?? '';
      _notesCtrl.text = e['notes'] ?? '';
      _type = e['type'] ?? 'OPEN';
      _hasEVCharger = e['hasEVCharger'] == true;
      _isHandicapped = e['isHandicapped'] == true;
    }
  }

  @override
  void dispose() {
    _slotNumberCtrl.dispose();
    _zoneCtrl.dispose();
    _floorCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(isEdit ? 'Edit Slot' : 'Add Parking Slot', style: AppTextStyles.h1),
          const SizedBox(height: 20),

          _label('Slot Number *'),
          _field(_slotNumberCtrl, 'e.g. A-01, B-12, V-03'),
          const SizedBox(height: 12),

          _label('Slot Type *'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _types.map((t) {
              final sel = _type == t.$1;
              return GestureDetector(
                onTap: () => setState(() => _type = t.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(t.$2,
                      style: AppTextStyles.labelMedium.copyWith(
                          color: sel ? AppColors.textOnPrimary : AppColors.textSecondary)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Zone (optional)'),
              _field(_zoneCtrl, 'e.g. A, B, VISITOR'),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Floor (optional)'),
              _field(_floorCtrl, 'e.g. -1 for B1, 0 for Ground',
                  type: TextInputType.number),
            ])),
          ]),
          const SizedBox(height: 12),

          _label('Notes (optional)'),
          _field(_notesCtrl, 'Any special instructions...', maxLines: 2),
          const SizedBox(height: 12),

          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text('EV Charging Point', style: AppTextStyles.labelLarge),
            value: _hasEVCharger,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primaryLight,
            onChanged: (v) => setState(() => _hasEVCharger = v),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text('Handicapped Accessible', style: AppTextStyles.labelLarge),
            value: _isHandicapped,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primaryLight,
            onChanged: (v) => setState(() => _isHandicapped = v),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.textOnPrimary))
                  : Text(isEdit ? 'Update Slot' : 'Create Slot',
                      style: AppTextStyles.buttonLarge),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child:
            Text(t, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
      );

  Widget _field(TextEditingController ctrl, String hint,
          {int maxLines = 1, TextInputType type = TextInputType.text}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: type,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary)),
        ),
      );

  Future<void> _submit() async {
    if (_slotNumberCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Slot number is required'),
          backgroundColor: AppColors.warning));
      return;
    }
    setState(() => _submitting = true);
    final data = <String, dynamic>{
      'slotNumber': _slotNumberCtrl.text.trim(),
      'type': _type,
      'zone': _zoneCtrl.text.trim().isEmpty ? null : _zoneCtrl.text.trim().toUpperCase(),
      'floor': _floorCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_floorCtrl.text.trim()),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'hasEVCharger': _hasEVCharger,
      'isHandicapped': _isHandicapped,
    };
    await widget.onSubmit(data);
    if (mounted) setState(() => _submitting = false);
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Allotment Form Sheet
// ════════════════════════════════════════════════════════════════════════════

class _AllotmentFormSheet extends ConsumerStatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  const _AllotmentFormSheet({required this.onSubmit});

  @override
  ConsumerState<_AllotmentFormSheet> createState() => _AllotmentFormSheetState();
}

class _AllotmentFormSheetState extends ConsumerState<_AllotmentFormSheet> {
  Map<String, dynamic>? _selectedUnit;
  String? _selectedVehicleId;
  String? _selectedSlotId;
  Map<String, dynamic>? _selectedSlot;
  bool _loadingSlots = false;
  List<Map<String, dynamic>> _availableSlots = [];
  bool _loadingVehicles = false;
  List<Map<String, dynamic>> _unitVehicles = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() => _loadingSlots = true);
    final slots = await ref.read(parkingProvider.notifier).fetchAvailableSlots();
    if (mounted) setState(() { _availableSlots = slots; _loadingSlots = false; });
  }

  Future<void> _loadVehiclesForUnit(String unitId) async {
    setState(() {
      _loadingVehicles = true;
      _unitVehicles = [];
      _selectedVehicleId = null;
    });
    final vehicles = await ref.read(parkingProvider.notifier).fetchVehiclesByUnit(unitId);
    if (!mounted) return;
    setState(() {
      _unitVehicles = vehicles;
      _loadingVehicles = false;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unitsAsync = ref.watch(unitsProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Allot Parking Slot', style: AppTextStyles.h1),
          const SizedBox(height: 20),

          _label('Select Unit *'),
          const SizedBox(height: 6),
          unitsAsync.when(
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => Text('Failed to load units: $e',
                style: AppTextStyles.caption.copyWith(color: AppColors.danger)),
            data: (unitsRaw) {
              final units = unitsRaw.cast<dynamic>().whereType<Map>().map((u) => Map<String, dynamic>.from(u)).toList();

              if (units.isEmpty) {
                return Text('No units found', style: AppTextStyles.caption.copyWith(color: AppColors.danger));
              }

              String display(Map<String, dynamic> u) {
                final fullCode = (u['fullCode'] ?? '').toString();
                final wing = u['wing']?.toString();
                final unitNumber = u['unitNumber']?.toString();
                if (fullCode.isNotEmpty) return fullCode;
                if (wing != null && unitNumber != null) return '$wing-$unitNumber';
                return (u['id'] ?? '-').toString();
              }

              return Autocomplete<Map<String, dynamic>>(
                initialValue: TextEditingValue(text: _selectedUnit != null ? display(_selectedUnit!) : ''),
                displayStringForOption: (u) => display(u),
                optionsBuilder: (textEditingValue) {
                  final q = textEditingValue.text.trim().toLowerCase();
                  if (q.isEmpty) return units.take(50);
                  return units.where((u) => display(u).toLowerCase().contains(q)).take(50);
                },
                onSelected: (u) {
                  setState(() => _selectedUnit = u);
                  final unitId = (u['id'] ?? '').toString();
                  if (unitId.isNotEmpty) _loadVehiclesForUnit(unitId);
                },
                fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: textController,
                    focusNode: focusNode,
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search unit (e.g. A-101)',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.primary)),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),

          _label('Select Available Slot *'),
          const SizedBox(height: 6),
          _loadingSlots
              ? const Center(child: CircularProgressIndicator())
              : _availableSlots.isEmpty
                  ? Text('No available slots', style: AppTextStyles.caption.copyWith(color: AppColors.danger))
                  : _SlotAutocomplete(
                      slots: _availableSlots,
                      selected: _selectedSlot,
                      onSelected: (slot) => setState(() {
                        _selectedSlot = slot;
                        final id = slot?['id']?.toString();
                        _selectedSlotId = (id == null || id.trim().isEmpty) ? null : id;
                      }),
                    ),
          const SizedBox(height: 12),

          _label('Vehicle (optional)'),
          const SizedBox(height: 6),
          _selectedUnit == null
              ? Text('Select a unit to see its vehicles',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted))
              : _loadingVehicles
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String?>(
                      value: _selectedVehicleId,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.border)),
                      ),
                      hint: Text(
                        _unitVehicles.isEmpty ? 'No vehicles for this unit' : 'Choose vehicle (optional)',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No specific vehicle'),
                        ),
                        ..._unitVehicles.map((v) {
                          final plate = (v['numberPlate'] ?? '-').toString();
                          final type = (v['type'] ?? '').toString();
                          final label = type.isNotEmpty ? '$plate ($type)' : plate;
                          return DropdownMenuItem<String?>(
                            value: (v['id'] ?? '').toString(),
                            child: Text(label, style: AppTextStyles.bodyMedium),
                          );
                        }),
                      ],
                      onChanged: (v) => setState(() => _selectedVehicleId = v),
                    ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.textOnPrimary))
                  : Text('Confirm Allotment', style: AppTextStyles.buttonLarge),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child:
            Text(t, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
      );

  Future<void> _submit() async {
    final unitId = (_selectedUnit?['id'] ?? '').toString();
    if (unitId.isEmpty || _selectedSlotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Unit ID and slot are required'),
          backgroundColor: AppColors.warning));
      return;
    }
    setState(() => _submitting = true);
    final data = <String, dynamic>{
      'slotId': _selectedSlotId,
      'unitId': unitId,
      if (_selectedVehicleId != null && _selectedVehicleId!.trim().isNotEmpty) 'vehicleId': _selectedVehicleId,
    };
    await widget.onSubmit(data);
    if (mounted) setState(() => _submitting = false);
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Entry Form Sheet (Watchman logs vehicle entry)
// ════════════════════════════════════════════════════════════════════════════

class _EntryFormSheet extends ConsumerStatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  const _EntryFormSheet({required this.onSubmit});

  @override
  ConsumerState<_EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends ConsumerState<_EntryFormSheet> {
  final _guestPlateCtrl = TextEditingController();
  final _guestNameCtrl = TextEditingController();
  final _guestPhoneCtrl = TextEditingController();
  final _unitIdCtrl = TextEditingController();
  String? _selectedSlotId;
  bool _loadingSlots = false;
  List<Map<String, dynamic>> _visitorSlots = [];
  bool _submitting = false;
  TimeOfDay? _expectedExitTime;

  @override
  void initState() {
    super.initState();
    _loadVisitorSlots();
  }

  Future<void> _loadVisitorSlots() async {
    setState(() => _loadingSlots = true);
    final slots = await ref.read(parkingProvider.notifier).fetchAvailableSlots(type: 'VISITOR');
    if (mounted) setState(() { _visitorSlots = slots; _loadingSlots = false; });
  }

  @override
  void dispose() {
    _guestPlateCtrl.dispose();
    _guestNameCtrl.dispose();
    _guestPhoneCtrl.dispose();
    _unitIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Log Vehicle Entry', style: AppTextStyles.h1),
          const SizedBox(height: 20),

          // Guest plate
          _label('Vehicle Number Plate *'),
          _field(_guestPlateCtrl, 'e.g. GJ01AB1234'),
          const SizedBox(height: 12),

          _label('Visitor Name (optional)'),
          _field(_guestNameCtrl, 'Full name'),
          const SizedBox(height: 12),

          _label('Visitor Phone (optional)'),
          _field(_guestPhoneCtrl, '10-digit phone', type: TextInputType.phone),
          const SizedBox(height: 12),

          _label('Visiting Unit (optional)'),
          _field(_unitIdCtrl, 'Paste unit ID'),
          const SizedBox(height: 12),

          _label('Assign Visitor Slot *'),
          const SizedBox(height: 6),
          _loadingSlots
              ? const Center(child: CircularProgressIndicator())
              : _visitorSlots.isEmpty
                  ? Text('No visitor slots available',
                      style: AppTextStyles.caption.copyWith(color: AppColors.danger))
                  : DropdownButtonFormField<String>(
                      initialValue: _selectedSlotId,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.border)),
                      ),
                      hint: Text('Choose slot',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
                      items: _visitorSlots.map((s) {
                        final label = '${s['slotNumber']} — Visitor${s['zone'] != null ? ' · ${s['zone']}' : ''}';
                        return DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(label, style: AppTextStyles.bodyMedium));
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedSlotId = v),
                    ),
          const SizedBox(height: 12),

          // Expected exit time
          _label('Expected Exit Time (optional)'),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                      colorScheme: Theme.of(ctx)
                          .colorScheme
                          .copyWith(primary: AppColors.primary)),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _expectedExitTime = picked);
            },
            child: AbsorbPointer(
              child: TextField(
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: _expectedExitTime != null
                      ? _expectedExitTime!.format(context)
                      : 'Tap to set time',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: _expectedExitTime != null
                          ? AppColors.textPrimary
                          : AppColors.textMuted),
                  prefixIcon: const Icon(Icons.schedule_rounded, size: 18),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.textOnPrimary))
                  : Text('Log Entry', style: AppTextStyles.buttonLarge),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child:
            Text(t, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
      );

  Widget _field(TextEditingController ctrl, String hint,
          {int maxLines = 1, TextInputType type = TextInputType.text}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: type,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary)),
        ),
      );

  Future<void> _submit() async {
    if (_guestPlateCtrl.text.trim().isEmpty || _selectedSlotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Vehicle plate and slot are required'),
          backgroundColor: AppColors.warning));
      return;
    }
    setState(() => _submitting = true);

    DateTime? expectedExit;
    if (_expectedExitTime != null) {
      final now = DateTime.now();
      expectedExit =
          DateTime(now.year, now.month, now.day, _expectedExitTime!.hour, _expectedExitTime!.minute);
      if (expectedExit.isBefore(now)) expectedExit = expectedExit.add(const Duration(days: 1));
    }

    final data = <String, dynamic>{
      'slotId': _selectedSlotId,
      'guestPlate': _guestPlateCtrl.text.trim().toUpperCase(),
      if (_guestNameCtrl.text.trim().isNotEmpty) 'guestName': _guestNameCtrl.text.trim(),
      if (_guestPhoneCtrl.text.trim().isNotEmpty) 'guestPhone': _guestPhoneCtrl.text.trim(),
      if (_unitIdCtrl.text.trim().isNotEmpty) 'linkedUnitId': _unitIdCtrl.text.trim(),
      if (expectedExit != null) 'expectedExitAt': expectedExit.toIso8601String(),
    };
    await widget.onSubmit(data);
    if (mounted) setState(() => _submitting = false);
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(label,
              style: AppTextStyles.labelMedium.copyWith(
                  color:
                      selected ? AppColors.textOnPrimary : AppColors.textSecondary)),
        ),
      );
}

class _SlotAutocomplete extends StatefulWidget {
  final List<Map<String, dynamic>> slots;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>?> onSelected;
  const _SlotAutocomplete({required this.slots, required this.selected, required this.onSelected});

  @override
  State<_SlotAutocomplete> createState() => _SlotAutocompleteState();
}

class _SlotAutocompleteState extends State<_SlotAutocomplete> {
  late final TextEditingController _ctrl;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.selected != null ? _display(widget.selected!) : '');
  }

  @override
  void didUpdateWidget(covariant _SlotAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.selected?['id']?.toString();
    final newId = widget.selected?['id']?.toString();
    if (oldId != newId) {
      _ctrl.text = widget.selected != null ? _display(widget.selected!) : '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _display(Map<String, dynamic> s) {
    final slotNumber = (s['slotNumber'] ?? '-').toString();
    return slotNumber;
  }

  String _fullInfo(Map<String, dynamic> s) {
    final slotNumber = (s['slotNumber'] ?? '-').toString();
    final type = _slotTypeLabel((s['type'] ?? '').toString());
    final zone = s['zone']?.toString();
    final floor = s['floor'];

    final parts = <String>[
      type,
      if (zone != null && zone.trim().isNotEmpty) 'Zone ${zone.trim()}',
      if (floor != null) 'F$floor',
    ];

    return '$slotNumber — ${parts.join(' · ')}';
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Map<String, dynamic>>(
      textEditingController: _ctrl,
      focusNode: _focusNode,
      displayStringForOption: (s) => _display(s),
      optionsBuilder: (textEditingValue) {
        final q = textEditingValue.text.trim().toLowerCase();
        if (q.isEmpty) return widget.slots.take(20);
        return widget.slots.where((s) {
          final info = _fullInfo(s).toLowerCase();
          return info.contains(q);
        }).take(20);
      },
      onSelected: (s) => widget.onSelected(s),
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: MediaQuery.of(context).size.width - 40,
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
                itemBuilder: (BuildContext context, int index) {
                  final option = options.elementAt(index);
                  final slotNumber = option['slotNumber']?.toString() ?? '-';
                  final type = _slotTypeLabel((option['type'] ?? '').toString());
                  final zone = option['zone']?.toString();
                  final floor = option['floor'];

                  return ListTile(
                    dense: true,
                    title: Text(slotNumber, style: AppTextStyles.labelLarge),
                    subtitle: Text(
                      '$type ${zone != null ? "· Zone $zone" : ""} ${floor != null ? "· F$floor" : ""}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Search slot (e.g. A-01, Zone A, Covered)',
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary)),
            suffixIcon: (_ctrl.text.isEmpty)
                ? null
                : IconButton(
                    onPressed: () {
                      _ctrl.clear();
                      widget.onSelected(null);
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
          ),
          onChanged: (_) => setState(() {}),
        );
      },
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(6)),
          child: Text(label,
              style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: AppCard(
          backgroundColor: AppColors.dangerSurface,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Error: $message',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText)),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      );
}
