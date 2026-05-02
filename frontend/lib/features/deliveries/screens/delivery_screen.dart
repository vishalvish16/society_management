import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../providers/delivery_provider.dart';
import '../../../shared/widgets/unit_picker_field.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_module_scaffold.dart';

class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({super.key});

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  String _filter = 'all';

  static const _staffRoles  = {'WATCHMAN', 'PRAMUKH', 'SECRETARY', 'CHAIRMAN'};
  static const _residentRoles = {'RESIDENT', 'MEMBER'};

  Color _borderColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'collected':
        return AppColors.success;
      case 'left_at_gate':
        return AppColors.info;
      case 'returned':
        return AppColors.textMuted;
      case 'expired':
        return AppColors.danger;
      default:
        return AppColors.border;
    }
  }

  /// Deliveries do not carry a QR expiry; long‑stuck **pending** items are shown as **expired** so staff can clear them.
  String _effectiveDeliveryStatus(Map<String, dynamic> d) {
    if (d['receivedAt'] != null) return 'collected';
    final status = (d['status'] as String? ?? 'pending').toLowerCase();
    if (status != 'pending') return status;
    final raw = d['createdAt'] as String?;
    if (raw == null || raw.isEmpty) return status;
    try {
      final created = DateTime.parse(raw);
      if (DateTime.now().difference(created).inHours >= 72) {
        return 'expired';
      }
    } catch (_) {}
    return status;
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    if (raw.length >= 10) return raw.substring(0, 10);
    return raw;
  }

  String _deliveryFilterLabel(String s) {
    if (s == 'all') return 'All';
    if (s == 'at_gate') return 'Collected at Gate';
    if (s == 'expired') return 'Stale / Expired';
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final deliveryState = ref.watch(deliveryProvider);
    final role = ref.watch(authProvider).user?.role ?? '';
    final isStaff    = _staffRoles.contains(role);
    final isWatchman = role == 'WATCHMAN';
    final isResident = _residentRoles.contains(role);

    final filterKeys = <String>[
      'all',
      'pending',
      if (isWatchman) 'at_gate',
      'collected',
      'returned',
      'expired',
    ];
    return AppModuleScaffold(
      title: 'Deliveries',
      icon: Icons.local_shipping_rounded,
      filterRow: AppFilterChipRow(
        darkBackground: true,
        selected: _filter,
        onSelected: (s) => setState(() => _filter = s),
        options: [for (final s in filterKeys) FilterOption(s, _deliveryFilterLabel(s))],
      ),
      primaryFab: (isStaff || isResident)
          ? ModuleFabConfig(
              onPressed: () => _showLogDeliverySheet(context),
              icon: Icons.add_box_rounded,
              tooltip: isStaff ? 'Log delivery' : 'Add delivery',
              wideExtendedLabel: isStaff ? 'Log Delivery' : 'Add delivery',
            )
          : null,
      fabHeroTagPrefix: 'deliveries',
      child: () {
              if (deliveryState.isLoading) {
                return const AppLoadingShimmer();
              }
              if (deliveryState.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.screenPadding),
                    child: AppCard(
                      backgroundColor: AppColors.dangerSurface,
                      child: Text(
                        'Error: ${deliveryState.error}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText),
                      ),
                    ),
                  ),
                );
              }

              final filtered = _filter == 'all'
                  ? deliveryState.deliveries
                  : deliveryState.deliveries.where((d) {
                      final m = Map<String, dynamic>.from(d as Map);
                      final status = _effectiveDeliveryStatus(m);
                      if (_filter == 'at_gate') return status == 'left_at_gate';
                      return status == _filter;
                    }).toList();

              if (filtered.isEmpty) {
                return const AppEmptyState(
                  emoji: '📦',
                  title: 'No Deliveries',
                  subtitle: 'No deliveries match the selected filter.',
                );
              }

              return RefreshIndicator(
                onRefresh: () => ref.read(deliveryProvider.notifier).loadDeliveries(),
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    AppDimensions.screenPadding,
                    AppDimensions.screenPadding,
                    AppDimensions.screenPadding,
                    AppDimensions.screenPadding +
                        kFloatingActionButtonMargin +
                        72 +
                        MediaQuery.of(context).padding.bottom,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.sm),
                  itemBuilder: (_, i) {
                    final d = Map<String, dynamic>.from(filtered[i] as Map);
                    final status = _effectiveDeliveryStatus(d);
                    final unit = d['unit'] is Map
                        ? (d['unit'] as Map)['fullCode'] ?? '-'
                        : (d['unit'] ?? '-').toString();
                    final agentName = d['agentName'] as String? ?? '-';
                    final company = d['company'] as String?;
                    final description = d['description'] as String?;
                    final loggedAt = _formatDate(d['loggedAt'] as String?);
                    final id = d['id'] as String? ?? '';
                    final photoUrl = d['photoUrl'] as String?;
                    final hasDropPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;
                    final droppedAt = _formatDate(d['droppedAt'] as String?);
                    final receivedAt = d['receivedAt'] as String?;
                    final receivedByUserName = (d['receivedByUser'] is Map)
                        ? ((d['receivedByUser'] as Map)['name']?.toString())
                        : null;

                    return AppCard(
                      leftBorderColor: _borderColor(status),
                      padding: const EdgeInsets.all(AppDimensions.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: agent + status
                          Row(
                            children: [
                              Expanded(
                                child: Text(agentName, style: AppTextStyles.h3),
                              ),
                              AppStatusChip(status: status),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.xs),
                          // Row 2: company (if present)
                          if (company != null && company.isNotEmpty) ...[
                            Text(
                              company,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: AppDimensions.xs),
                          ],
                          // Row 3: unit + date
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.infoSurface,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                ),
                                child: Text(
                                  'Unit $unit',
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.info),
                                ),
                              ),
                              const Spacer(),
                              Text(loggedAt, style: AppTextStyles.caption),
                            ],
                          ),
                          if (status == 'left_at_gate') ...[
                            const SizedBox(height: AppDimensions.xs),
                            Row(
                              children: [
                                const Icon(Icons.storefront_outlined, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 6),
                                Text(
                                  'Dropped: $droppedAt',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                            if (hasDropPhoto) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDimensions.sm,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.infoSurface,
                                  borderRadius:
                                      BorderRadius.circular(AppDimensions.radiusSm),
                                ),
                                child: Text(
                                  'Watchman parcel photo available',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.info),
                                ),
                              ),
                            ],
                            if (receivedAt != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.verified_rounded, size: 14, color: AppColors.success),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Collected: ${_formatDate(receivedAt)}',
                                    style: AppTextStyles.caption.copyWith(color: AppColors.success),
                                  ),
                                ],
                              ),
                            ],
                          ],
                          // Description (if present)
                          if (description != null && description.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.xs),
                            Text(
                              description,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                          if (receivedAt != null) ...[
                            const SizedBox(height: AppDimensions.xs),
                            Text(
                              'Received by ${receivedByUserName ?? 'resident'}',
                              style: AppTextStyles.caption.copyWith(color: AppColors.success),
                            ),
                          ],
                          // ── Resident: Allow / Deny / Drop at Gate on PENDING ──
                          if (isResident && status == 'pending' && id.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.sm),
                            Row(children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _respond(id, 'ALLOWED'),
                                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                  label: const Text('Allow'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.success,
                                    side: const BorderSide(color: AppColors.success),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                                    padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppDimensions.sm),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _respond(id, 'DENIED'),
                                  icon: const Icon(Icons.cancel_outlined, size: 16),
                                  label: const Text('Deny'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                    side: const BorderSide(color: AppColors.danger),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                                    padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                                  ),
                                ),
                              ),
                            ]),
                            const SizedBox(height: AppDimensions.sm),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _respond(id, 'LEFT_AT_GATE'),
                                icon: const Icon(Icons.storefront_outlined, size: 16),
                                label: const Text('Drop at Gate'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.info,
                                  side: const BorderSide(color: AppColors.info),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                                  padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                                ),
                              ),
                            ),
                          ],
                          // ── Resident: Collect from Watchman ──
                          if (isResident &&
                              receivedAt == null &&
                              (status == 'left_at_gate' || status == 'collected' || status == 'allowed') &&
                              id.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.sm),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _showCollectSheet(context, d),
                                icon: const Icon(Icons.inventory_2_outlined, size: 16),
                                label: const Text('Collect from watchman'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.textOnPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                                ),
                              ),
                            ),
                          ],
                          // ── Staff: Photograph parcel for LEFT_AT_GATE ──
                          if (isStaff && status == 'left_at_gate' && id.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.sm),
                            Container(
                              padding: const EdgeInsets.all(AppDimensions.sm),
                              decoration: BoxDecoration(
                                color: AppColors.infoSurface,
                                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                              ),
                              child: Row(children: [
                                const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.info),
                                const SizedBox(width: AppDimensions.sm),
                                Expanded(child: Text(
                                  hasDropPhoto
                                      ? 'Parcel photo uploaded.'
                                      : 'Resident chose "Drop at Gate" — photograph the parcel.',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.info),
                                )),
                              ]),
                            ),
                            const SizedBox(height: AppDimensions.sm),
                            if (!hasDropPhoto)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showDropPhotoSheet(context, id),
                                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                  label: const Text('Take Parcel Photo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.info,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                                    padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                                  ),
                                ),
                              ),
                          ],
                          // ── Staff: Mark Collected on PENDING or ALLOWED ─
                          if (isStaff && (status == 'pending' || status == 'allowed') && id.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.sm),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _markCollected(id),
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Mark Collected'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.success,
                                  side: const BorderSide(color: AppColors.success),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                                  padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                                ),
                              ),
                            ),
                          ],
                          // ── Staff: Mark Returned on PENDING or DENIED ───
                          if (isStaff && (status == 'pending' || status == 'denied') && id.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.sm),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _markReturned(id),
                                icon: const Icon(Icons.undo_rounded, size: 16),
                                label: const Text('Mark Returned to Sender'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textMuted,
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                                  padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              );
            }(),
    );
  }

  Future<void> _markCollected(String id) async {
    final error = await ref.read(deliveryProvider.notifier).markCollected(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? 'Marked as collected'),
        backgroundColor: error == null ? AppColors.success : AppColors.danger,
      ));
    }
  }

  Future<void> _markReturned(String id) async {
    final error = await ref.read(deliveryProvider.notifier).markReturned(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? 'Marked as returned to sender'),
        backgroundColor: error == null ? AppColors.success : AppColors.danger,
      ));
    }
  }

  Future<void> _respond(String id, String action) async {
    final error = await ref.read(deliveryProvider.notifier).respondDelivery(id, action);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? (action == 'ALLOWED' ? 'Delivery allowed' : 'Delivery denied')),
        backgroundColor: error == null ? AppColors.success : AppColors.danger,
      ));
    }
  }

  void _showDropPhotoSheet(BuildContext context, String deliveryId) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => _DropPhotoSheet(deliveryId: deliveryId),
    );
  }

  void _showCollectSheet(BuildContext context, Map<String, dynamic> delivery) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => _CollectFromWatchmanSheet(delivery: delivery),
    );
  }

  void _showLogDeliverySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => const _LogDeliveryForm(),
    );
  }
}

class _LogDeliveryForm extends ConsumerStatefulWidget {
  const _LogDeliveryForm();

  @override
  ConsumerState<_LogDeliveryForm> createState() => _LogDeliveryFormState();
}

class _LogDeliveryFormState extends ConsumerState<_LogDeliveryForm> {
  final _formKey = GlobalKey<FormState>();
  late String? _selectedUnitId;
  late String? _selectedUnitCode;
  late bool _lockUnit;
  final _agentNameController = TextEditingController();
  final _companyController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _lockUnit = user?.isUnitLocked ?? false;
    _selectedUnitId = _lockUnit ? user?.unitId : null;
    _selectedUnitCode = _lockUnit ? user?.unitCode : null;
  }

  @override
  void dispose() {
    _agentNameController.dispose();
    _companyController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedUnitId == null || !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = <String, dynamic>{
      'unitId': _selectedUnitId!,
      'agentName': _agentNameController.text.trim(),
    };
    final company = _companyController.text.trim();
    final description = _descriptionController.text.trim();
    if (company.isNotEmpty) data['company'] = company;
    if (description.isNotEmpty) data['description'] = description;

    final error = await ref.read(deliveryProvider.notifier).logDelivery(data);

    if (mounted) {
      if (error == null) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Delivery logged successfully')),
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMsg = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              AppDimensions.screenPadding,
              AppDimensions.lg,
              AppDimensions.screenPadding,
              MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Form(
                key: _formKey,
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
                    Text('Log Delivery', style: AppTextStyles.h1),
                    const SizedBox(height: AppDimensions.lg),
                    if (!_lockUnit) ...[
                      UnitPickerField(
                        selectedUnitId: _selectedUnitId,
                        selectedUnitCode: _selectedUnitCode,
                        onChanged: (id, code) => setState(() {
                          _selectedUnitId = id;
                          _selectedUnitCode = code;
                        }),
                      ),
                      const SizedBox(height: AppDimensions.md),
                    ],
                    TextFormField(
                      controller: _agentNameController,
                      decoration: const InputDecoration(
                        labelText: 'Agent Name',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    TextFormField(
                      controller: _companyController,
                      decoration: const InputDecoration(
                        labelText: 'Company (Optional)',
                        prefixIcon: Icon(Icons.business_rounded),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    if (_errorMsg != null) ...[
                      const SizedBox(height: AppDimensions.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppDimensions.sm),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSurface,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Text(
                          _errorMsg!,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.xl),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textOnPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: AppColors.textOnPrimary,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text('Log Delivery', style: AppTextStyles.buttonLarge),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Drop Photo Sheet ─────────────────────────────────────────────────────────

class _DropPhotoSheet extends ConsumerStatefulWidget {
  final String deliveryId;
  const _DropPhotoSheet({required this.deliveryId});

  @override
  ConsumerState<_DropPhotoSheet> createState() => _DropPhotoSheetState();
}

class _DropPhotoSheetState extends ConsumerState<_DropPhotoSheet> {
  File? _photo;
  bool  _loading = false;
  String? _error;
  final _picker = ImagePicker();

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 75, maxWidth: 1024);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _submit() async {
    if (_photo == null) {
      setState(() => _error = 'Please capture a photo first');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final error = await ref.read(deliveryProvider.notifier).uploadDropPhoto(widget.deliveryId, _photo!);
    if (mounted) {
      if (error == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Parcel photo uploaded — unit member notified.'),
          backgroundColor: AppColors.success,
        ));
      } else {
        setState(() { _loading = false; _error = error; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              AppDimensions.screenPadding,
              AppDimensions.lg,
              AppDimensions.screenPadding,
              MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
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
                  Text('Photograph Parcel', style: AppTextStyles.h1),
                  const SizedBox(height: AppDimensions.xs),
                  Text(
                    'Resident chose "Drop at Gate". Take a photo of the parcel for their records.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppDimensions.lg),

                  // ── Photo preview / capture ──────────────────────────────────
                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      useRootNavigator: true,
                      backgroundColor: AppColors.surface,
                      enableDrag: true,
                      builder: (_) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: AppDimensions.md),
                            ListTile(
                              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                              title: const Text('Take Photo'),
                              onTap: () {
                                Navigator.pop(context);
                                _pick(ImageSource.camera);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                              title: const Text('Choose from Gallery'),
                              onTap: () {
                                Navigator.pop(context);
                                _pick(ImageSource.gallery);
                              },
                            ),
                            const SizedBox(height: AppDimensions.md),
                          ],
                        ),
                      ),
                    ),
                    child: Container(
                      width: double.infinity,
                      height: _photo != null ? 200 : 120,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        border: Border.all(
                          color: _photo != null ? AppColors.primary : AppColors.border,
                        ),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: _photo != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd - 1),
                              child: Image.file(_photo!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.camera_alt_rounded,
                                    size: 36, color: AppColors.textMuted),
                                const SizedBox(height: AppDimensions.sm),
                                Text(
                                  'Tap to capture parcel photo',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: AppDimensions.sm),
                    Text(
                      _error!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText),
                    ),
                  ],

                  const SizedBox(height: AppDimensions.lg),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_rounded, size: 18),
                      label: Text(_loading ? 'Uploading…' : 'Upload & Notify Resident'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
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
}

// ─── Resident: Collect from Watchman Sheet ────────────────────────────────────

class _CollectFromWatchmanSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> delivery;
  const _CollectFromWatchmanSheet({required this.delivery});

  @override
  ConsumerState<_CollectFromWatchmanSheet> createState() =>
      _CollectFromWatchmanSheetState();
}

class _CollectFromWatchmanSheetState
    extends ConsumerState<_CollectFromWatchmanSheet> {
  bool _loading = false;
  String? _error;

  String _statusUpper() =>
      (widget.delivery['status']?.toString() ?? '').toUpperCase();

  String? _photoUrl() {
    final raw = widget.delivery['photoUrl'] as String?;
    return AppConstants.uploadUrlFromPath(raw);
  }

  Future<void> _collect() async {
    final id = widget.delivery['id']?.toString() ?? '';
    if (id.isEmpty) return;
    if (_statusUpper() == 'LEFT_AT_GATE' && _photoUrl() == null) {
      setState(() {
        _error = 'Watchman photo is not uploaded yet. Please collect after photo upload.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await ref.read(deliveryProvider.notifier).markReceived(id);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Parcel collected successfully'),
        backgroundColor: AppColors.success,
      ));
      return;
    }

    setState(() {
      _loading = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.delivery;
    final unit = d['unit'] is Map
        ? (d['unit'] as Map)['fullCode'] ?? '-'
        : (d['unit'] ?? '-').toString();
    final agentName = d['agentName'] as String? ?? '-';
    final company = d['company'] as String?;
    final description = d['description'] as String?;
    final photo = _photoUrl();
    final requirePhotoBeforeCollect = _statusUpper() == 'LEFT_AT_GATE';

    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
            Text('Collect from watchman', style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'Review the delivery details and confirm collection.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppDimensions.lg),
            AppCard(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(agentName, style: AppTextStyles.h3),
                  if (company != null && company.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      company,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    'Unit $unit',
                    style:
                        AppTextStyles.labelMedium.copyWith(color: AppColors.info),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            if (photo != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    photo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.background,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: AppColors.textMuted),
                      ),
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: AppColors.background,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              Text('Watchman photo', style: AppTextStyles.caption),
              const SizedBox(height: AppDimensions.lg),
            ],
            if (photo == null && requirePhotoBeforeCollect) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.sm),
                decoration: BoxDecoration(
                  color: AppColors.warningSurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Text(
                  'Waiting for watchman parcel photo upload.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.warningText),
                ),
              ),
              const SizedBox(height: AppDimensions.md),
            ],
            if (_error != null) ...[
              Text(_error!,
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText)),
              const SizedBox(height: AppDimensions.md),
            ],
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_loading || (requirePhotoBeforeCollect && photo == null))
                    ? null
                    : _collect,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text(_loading ? 'Collecting…' : 'Collect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
