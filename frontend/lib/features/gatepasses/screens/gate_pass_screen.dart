import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../providers/gate_pass_provider.dart';
import '../../../shared/widgets/unit_picker_field.dart';
import '../../../shared/widgets/show_app_dialog.dart';

class GatePassScreen extends ConsumerStatefulWidget {
  const GatePassScreen({super.key});

  @override
  ConsumerState<GatePassScreen> createState() => _GatePassScreenState();
}

class _GatePassScreenState extends ConsumerState<GatePassScreen> {
  // ── QR Scan dialog ──────────────────────────────────────────────────────────
  void _showScanDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    showAppSheet(
      context: context,
      builder: (ctx) => Padding(
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
            Text('Scan Gate Pass', style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.lg),
            TextField(
              controller: codeCtrl,
              autofocus: true,
              style: AppTextStyles.unitCode,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Pass Code',
                labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final code = codeCtrl.text.trim();
                  if (code.isEmpty) return;
                  Navigator.pop(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final dio = ref.read(dioProvider);
                    await dio.post('gatepasses/scan', data: {'passCode': code});
                    messenger.showSnackBar(SnackBar(content: Text('Pass scanned successfully', style: AppTextStyles.bodyMedium), backgroundColor: AppColors.success));
                    ref.read(gatePassProvider.notifier).loadPasses();
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('Scan failed: $e', style: AppTextStyles.bodyMedium), backgroundColor: AppColors.danger));
                  }
                },
                child: const Text('Scan Pass'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Generate Pass bottom sheet ──────────────────────────────────────────────
  void _showGeneratePassSheet(BuildContext context) {
    final user = ref.read(authProvider).user;
    final lockUnit = user?.isUnitLocked ?? false;
    String? selectedUnitId = lockUnit ? user?.unitId : null;
    String? selectedUnitCode = lockUnit ? user?.unitCode : null;
    final descCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    DateTime? validFrom;
    DateTime? validTo;
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
          Future<void> pickDate({required bool isFrom}) async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: ctx,
              initialDate: now,
              firstDate: now,
              lastDate: now.add(const Duration(days: 365)),
            );
            if (picked != null) {
              setSheetState(() {
                if (isFrom) {
                  validFrom = picked;
                } else {
                  validTo = picked;
                }
              });
            }
          }

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
                  Text('Generate Gate Pass', style: AppTextStyles.h1),
                  const SizedBox(height: AppDimensions.lg),

                  UnitPickerField(
                    selectedUnitId: selectedUnitId,
                    selectedUnitCode: selectedUnitCode,
                    readOnly: lockUnit,
                    onChanged: (id, code) => setSheetState(() {
                      selectedUnitId = id;
                      selectedUnitCode = code;
                    }),
                  ),
                  const SizedBox(height: AppDimensions.md),

                  _buildTextField(
                      controller: descCtrl,
                      label: 'Item Description',
                      hint: 'e.g. Sofa delivery'),
                  const SizedBox(height: AppDimensions.md),

                  _buildTextField(
                      controller: reasonCtrl,
                      label: 'Reason (optional)',
                      hint: 'e.g. Moving furniture'),
                  const SizedBox(height: AppDimensions.md),

                  _buildDateSelector(
                    label: 'Valid From',
                    value: validFrom,
                    onTap: () => pickDate(isFrom: true),
                  ),
                  const SizedBox(height: AppDimensions.md),

                  _buildDateSelector(
                    label: 'Valid To',
                    value: validTo,
                    onTap: () => pickDate(isFrom: false),
                  ),
                  const SizedBox(height: AppDimensions.xl),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                    onPressed: submitting
                        ? null
                        : () async {
                            if (selectedUnitId == null ||
                                descCtrl.text.trim().isEmpty ||
                                validFrom == null ||
                                validTo == null) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Please fill all required fields',
                                    style: AppTextStyles.bodyMedium),
                                backgroundColor: AppColors.danger,
                              ));
                              return;
                            }
                            setSheetState(() => submitting = true);
                            // Capture messenger and navigator before await gap
                            final messenger = ScaffoldMessenger.of(context);
                              final ok =
                                  await ref.read(gatePassProvider.notifier).createPass({
                                'unitId': selectedUnitId!,
                                'itemDescription': descCtrl.text.trim(),
                                if (reasonCtrl.text.trim().isNotEmpty)
                                  'reason': reasonCtrl.text.trim(),
                                'validFrom': validFrom!.toIso8601String(),
                                'validTo': validTo!.toIso8601String(),
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              messenger.showSnackBar(SnackBar(
                                content: Text(
                                  ok ? 'Gate pass generated' : 'Failed to generate pass',
                                  style: AppTextStyles.bodyMedium,
                                ),
                                backgroundColor:
                                    ok ? AppColors.success : AppColors.danger,
                              ));
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
                          : Text('Generate',
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
  }) {
    return TextField(
      controller: controller,
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

  Widget _buildDateSelector({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md, vertical: AppDimensions.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                color: AppColors.primary, size: 18),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(
                value != null
                    ? '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}'
                    : label,
                style: AppTextStyles.bodyMedium.copyWith(
                    color:
                        value != null ? AppColors.textPrimary : AppColors.textMuted),
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.length >= 10 ? iso.substring(0, 10) : iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gatePassProvider);
    final role = ref.watch(authProvider).user?.role ?? '';
    final canScan = ['WATCHMAN', 'PRAMUKH', 'SECRETARY'].contains(role);
    final canCancel = ['PRAMUKH', 'SECRETARY', 'RESIDENT'].contains(role);

    Widget body;
    if (state.isLoading && state.passes.isEmpty) {
      body = const AppLoadingShimmer();
    } else if (state.error != null && state.passes.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          child: AppCard(
            backgroundColor: AppColors.dangerSurface,
            child: Text('Error: ${state.error}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText)),
          ),
        ),
      );
    } else if (state.passes.isEmpty) {
      body = const AppEmptyState(
        emoji: '🎫',
        title: 'No Gate Passes',
        subtitle: 'No gate passes have been issued.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => ref.read(gatePassProvider.notifier).loadPasses(),
        child: ListView.separated(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          itemCount: state.passes.length,
          separatorBuilder: (_, i) => const SizedBox(height: AppDimensions.sm),
          itemBuilder: (_, i) {
            final p = state.passes[i];
            final status = (p['status'] as String? ?? 'pending').toLowerCase();
            final passCode = p['passCode'] as String? ?? '-';
            final desc = p['itemDescription'] as String? ?? '-';
            final unit =
                (p['unit'] as Map<String, dynamic>?)?['fullCode'] as String? ?? '-';
            final validFrom = _formatDate(p['validFrom'] as String?);
            final validTo = _formatDate(p['validTo'] as String?);
            final id = p['id'] as String? ?? '';
            final isActive = status == 'active';

            return AppCard(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.sm, vertical: AppDimensions.xs),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Text(passCode,
                            style: AppTextStyles.unitCode
                                .copyWith(color: AppColors.primary, fontSize: 12)),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(child: Text(desc, style: AppTextStyles.h3)),
                      AppStatusChip(status: status),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Row(
                    children: [
                      const Icon(Icons.home_rounded,
                          color: AppColors.textMuted, size: 14),
                      const SizedBox(width: AppDimensions.xs),
                      Text('Unit $unit',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted)),
                      const SizedBox(width: AppDimensions.md),
                      const Icon(Icons.calendar_today_rounded,
                          color: AppColors.textMuted, size: 14),
                      const SizedBox(width: AppDimensions.xs),
                      Expanded(
                        child: Text('$validFrom → $validTo',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted)),
                      ),
                      if (isActive && canCancel)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.danger, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            // Capture messenger before first await gap
                            final messenger = ScaffoldMessenger.of(context);
                            final confirm = await showConfirmSheet(
                              context: context,
                              title: 'Cancel Pass',
                              message: 'Cancel gate pass $passCode?',
                              confirmLabel: 'Cancel Pass',
                            );
                            if (confirm == true) {
                              final ok = await ref
                                  .read(gatePassProvider.notifier)
                                  .cancelPass(id);
                              messenger.showSnackBar(SnackBar(
                                content: Text(
                                  ok ? 'Pass cancelled' : 'Failed to cancel pass',
                                  style: AppTextStyles.bodyMedium,
                                ),
                                backgroundColor:
                                    ok ? AppColors.success : AppColors.danger,
                              ));
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Gate Passes',
            style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
        actions: [
          if (canScan)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded,
                  color: AppColors.textOnPrimary),
              onPressed: () => _showScanDialog(context),
            ),
          const SizedBox(width: AppDimensions.sm),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGeneratePassSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: AppColors.textOnPrimary),
        label: Text('Generate Pass',
            style:
                AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary)),
      ),
      body: body,
    );
  }
}
