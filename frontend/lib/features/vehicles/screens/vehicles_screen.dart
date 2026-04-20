import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../providers/vehicles_provider.dart';
import '../../../shared/widgets/unit_picker_field.dart';
import '../../../shared/widgets/app_searchable_dropdown.dart';
import '../../../shared/widgets/show_app_sheet.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  static const _types = ['CAR', 'TWO_WHEELER', 'CYCLE', 'OTHER'];

  static const _typeLabels = {
    'CAR': 'Car',
    'TWO_WHEELER': 'Two Wheeler',
    'CYCLE': 'Cycle',
    'OTHER': 'Other',
  };

  IconData _iconFor(String? type) {
    switch ((type ?? '').toUpperCase()) {
      case 'CAR':
        return Icons.directions_car_rounded;
      case 'TWO_WHEELER':
        return Icons.two_wheeler_rounded;
      case 'CYCLE':
        return Icons.pedal_bike_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  // ── Shared form bottom sheet ────────────────────────────────────────────────
  void _showVehicleSheet(
    BuildContext context, {
    Map<String, dynamic>? existing,
  }) {
    final isEdit = existing != null;
    final user = ref.read(authProvider).user;
    final lockUnit = !isEdit && (user?.isUnitLocked ?? false);
    String? selectedUnitId = lockUnit ? user?.unitId : null;
    String? selectedUnitCode = lockUnit ? user?.unitCode : null;
    final plateCtrl = TextEditingController(
        text: existing?['numberPlate'] as String? ?? '');
    final brandCtrl =
        TextEditingController(text: existing?['brand'] as String? ?? '');
    final modelCtrl =
        TextEditingController(text: existing?['model'] as String? ?? '');
    final colourCtrl =
        TextEditingController(text: existing?['colour'] as String? ?? '');
    String selectedType =
        (existing?['type'] as String? ?? 'CAR').toUpperCase();
    if (!_types.contains(selectedType)) selectedType = 'CAR';
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          String? sheetError;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimensions.screenPadding,
              AppDimensions.lg,
              AppDimensions.screenPadding,
              MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
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
                  Text(isEdit ? 'Edit Vehicle' : 'Register Vehicle',
                      style: AppTextStyles.h1),
                  const SizedBox(height: AppDimensions.lg),

                  // Unit picker (only shown on create, hidden when locked)
                  if (!isEdit && !lockUnit) ...[
                    UnitPickerField(
                      selectedUnitId: selectedUnitId,
                      selectedUnitCode: selectedUnitCode,
                      onChanged: (id, code) => setSheetState(() {
                        selectedUnitId = id;
                        selectedUnitCode = code;
                      }),
                    ),
                    const SizedBox(height: AppDimensions.md),
                  ],

                  // Type dropdown
                  AppSearchableDropdown<String>(
                    label: 'Vehicle Type',
                    value: selectedType,
                    items: _types.map((t) => AppDropdownItem(value: t, label: _typeLabels[t] ?? t)).toList(),
                    onChanged: (v) { if (v != null) setSheetState(() => selectedType = v); },
                  ),
                  const SizedBox(height: AppDimensions.md),

                  // Number Plate
                  _buildTextField(
                    controller: plateCtrl,
                    label: 'Number Plate',
                    hint: 'e.g. MH01AB1234',
                    capitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: AppDimensions.md),

                  // Brand
                  _buildTextField(
                      controller: brandCtrl,
                      label: 'Brand',
                      hint: 'e.g. Honda'),
                  const SizedBox(height: AppDimensions.md),

                  // Model
                  _buildTextField(
                      controller: modelCtrl,
                      label: 'Model',
                      hint: 'e.g. City'),
                  const SizedBox(height: AppDimensions.md),

                  // Colour
                  _buildTextField(
                      controller: colourCtrl,
                      label: 'Colour',
                      hint: 'e.g. White'),
                  if (sheetError != null) ...[
                    const SizedBox(height: AppDimensions.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.sm),
                      decoration: BoxDecoration(
                        color: AppColors.dangerSurface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: Text(
                        sheetError!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.xl),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding:
                            const EdgeInsets.symmetric(vertical: AppDimensions.md),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                      onPressed: submitting
                          ? null
                          : () async {
                              if (plateCtrl.text.trim().isEmpty ||
                                  brandCtrl.text.trim().isEmpty ||
                                  modelCtrl.text.trim().isEmpty ||
                                  colourCtrl.text.trim().isEmpty ||
                                  (!isEdit && selectedUnitId == null)) {
                                setSheetState(() => sheetError = 'Please fill all required fields');
                                return;
                              }
                              setSheetState(() {
                                submitting = true;
                                sheetError = null;
                              });
                              final payload = {
                                'type': selectedType,
                                'numberPlate': plateCtrl.text.trim().toUpperCase(),
                                'brand': brandCtrl.text.trim(),
                                'model': modelCtrl.text.trim(),
                                'colour': colourCtrl.text.trim(),
                                if (!isEdit) 'unitId': selectedUnitId!,
                              };
                              final String? error;
                              if (isEdit) {
                                error = await ref
                                    .read(vehiclesProvider.notifier)
                                    .updateVehicle(existing['id'] as String, payload);
                              } else {
                                error = await ref
                                    .read(vehiclesProvider.notifier)
                                    .createVehicle(payload);
                              }
                              if (ctx.mounted) {
                                if (error == null) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(
                                      isEdit ? 'Vehicle updated' : 'Vehicle registered',
                                      style: AppTextStyles.bodyMedium,
                                    ),
                                    backgroundColor: AppColors.success,
                                  ));
                                } else {
                                  setSheetState(() {
                                    submitting = false;
                                    sheetError = error;
                                  });
                                }
                              }
                            },
                      child: submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textOnPrimary,
                              ),
                            )
                          : Text(isEdit ? 'Update' : 'Register',
                              style: AppTextStyles.labelLarge
                                  .copyWith(color: AppColors.textOnPrimary)),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextCapitalization capitalization = TextCapitalization.words,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md, vertical: AppDimensions.md),
      ),
      style: AppTextStyles.bodyMedium,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehiclesProvider);
    final role = ref.watch(authProvider).user?.role ?? '';
    final canDelete = ['PRAMUKH', 'SECRETARY'].contains(role);

    Widget body;
    if (state.isLoading && state.vehicles.isEmpty) {
      body = const AppLoadingShimmer();
    } else if (state.error != null && state.vehicles.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          child: AppCard(
            backgroundColor: AppColors.dangerSurface,
            child: Text('Error: ${state.error}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.dangerText)),
          ),
        ),
      );
    } else if (state.vehicles.isEmpty) {
      body = const AppEmptyState(
        emoji: '🚗',
        title: 'No Vehicles',
        subtitle: 'No vehicles have been registered.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => ref.read(vehiclesProvider.notifier).loadVehicles(),
        child: ListView.separated(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          itemCount: state.vehicles.length,
          separatorBuilder: (_, i) => const SizedBox(height: AppDimensions.sm),
          itemBuilder: (_, i) {
            final v = state.vehicles[i];
            final type = (v['type'] as String? ?? '').toUpperCase();
            final plate = v['numberPlate'] as String? ?? '-';
            final brand = v['brand'] as String? ?? '';
            final model = v['model'] as String? ?? '';
            final colour = v['colour'] as String? ?? '';
            final unitCode =
                (v['unit'] as Map<String, dynamic>?)?['fullCode'] as String? ??
                    '-';
            final ownerName =
                (v['owner'] as Map<String, dynamic>?)?['name'] as String? ?? '-';
            final id = v['id'] as String? ?? '';

            return AppCard(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: Icon(_iconFor(type),
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plate, style: AppTextStyles.unitCode),
                        const SizedBox(height: AppDimensions.xs),
                        Text(
                          [brand, model, colour]
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppDimensions.xs),
                        Row(
                          children: [
                            const Icon(Icons.home_rounded,
                                color: AppColors.textMuted, size: 12),
                            const SizedBox(width: AppDimensions.xs),
                            Text('Unit $unitCode',
                                style: AppTextStyles.caption),
                            const SizedBox(width: AppDimensions.sm),
                            const Icon(Icons.person_rounded,
                                color: AppColors.textMuted, size: 12),
                            const SizedBox(width: AppDimensions.xs),
                            Text(ownerName, style: AppTextStyles.caption),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Edit button
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.primary, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showVehicleSheet(context, existing: v),
                  ),
                  // Delete button — only for PRAMUKH / SECRETARY
                  if (canDelete) ...[
                    const SizedBox(width: AppDimensions.sm),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        // Capture messenger before await
                        final messenger = ScaffoldMessenger.of(context);
                        final confirm = await showConfirmSheet(
                          context: context,
                          title: 'Remove Vehicle',
                          message: 'Remove $plate from the registry?',
                          confirmLabel: 'Remove',
                        );
                         if (confirm == true) {
                          final error = await ref
                              .read(vehiclesProvider.notifier)
                              .deleteVehicle(id);
                          messenger.showSnackBar(SnackBar(
                            content: Text(
                              error ?? 'Vehicle removed',
                              style: AppTextStyles.bodyMedium,
                            ),
                            backgroundColor:
                                error == null ? AppColors.success : AppColors.danger,
                          ));
                        }
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isWide
          ? AppBar(
              backgroundColor: AppColors.primary,
              title: Text('Vehicles',
                  style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showVehicleSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: AppColors.textOnPrimary),
        label: Text('Register Vehicle',
            style:
                AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary)),
      ),
      body: body,
    );
  }
}
