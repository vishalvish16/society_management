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
import '../../../shared/widgets/show_app_sheet.dart';
import '../../../shared/widgets/app_date_picker.dart';
import 'gate_pass_qr_screen.dart';

class GatePassScreen extends ConsumerStatefulWidget {
  const GatePassScreen({super.key});

  @override
  ConsumerState<GatePassScreen> createState() => _GatePassScreenState();
}

class _GatePassScreenState extends ConsumerState<GatePassScreen> {
  String _formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $h:$m';
    } catch (_) {
      return iso;
    }
  }

  // ── QR Scan dialog ──────────────────────────────────────────────────────────
  void _showScanDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    showAppSheet(
      context: context,
      builder: (ctx) {
        bool scanning = false;
        String? scanError;
        return StatefulBuilder(
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
                if (scanError != null) ...[
                  const SizedBox(height: AppDimensions.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimensions.sm),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSurface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: Text(
                      scanError!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText),
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.lg),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: scanning
                              ? null
                              : () async {
                                  await _submitScanDecision(
                                    context: context,
                                    sheetContext: ctx,
                                    setDlgState: setDlgState,
                                    codeCtrl: codeCtrl,
                                    decision: 'APPROVED',
                                    onError: (msg) => setDlgState(() => scanError = msg),
                                    onScanning: (v) => setDlgState(() => scanning = v),
                                  );
                                },
                          child: scanning
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Approve'),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: scanning
                              ? null
                              : () async {
                                  await _submitScanDecision(
                                    context: context,
                                    sheetContext: ctx,
                                    setDlgState: setDlgState,
                                    codeCtrl: codeCtrl,
                                    decision: 'REJECTED',
                                    onError: (msg) => setDlgState(() => scanError = msg),
                                    onScanning: (v) => setDlgState(() => scanning = v),
                                  );
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitScanDecision({
    required BuildContext context,
    required BuildContext sheetContext,
    required void Function(void Function()) setDlgState,
    required TextEditingController codeCtrl,
    required String decision,
    required void Function(String msg) onError,
    required void Function(bool v) onScanning,
  }) async {
    final code = codeCtrl.text.trim();
    if (code.isEmpty) return;
    onScanning(true);
    onError('');
    try {
      final dio = ref.read(dioProvider);
      await dio.post('gatepasses/scan',
          data: {'passCode': code, 'decision': decision});
      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gate pass $decision', style: AppTextStyles.bodyMedium),
            backgroundColor:
                decision == 'APPROVED' ? AppColors.success : AppColors.danger));
        ref.read(gatePassProvider.notifier).loadPasses();
      }
    } catch (e) {
      if (sheetContext.mounted) {
        onScanning(false);
        onError(e.toString());
      }
    }
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
    String? sheetError;

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
          Future<void> pickRange() async {
            final now = DateTime.now();
            final picked = await pickDateRange(
              ctx,
              initialFrom: validFrom,
              initialTo: validTo,
              firstDate: now,
              lastDate: now.add(const Duration(days: 365)),
            );
            if (picked != null) {
              setSheetState(() {
                validFrom = picked.start;
                validTo = picked.end;
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
                   Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: AppDimensions.lg),
                  Text('Generate Gate Pass', style: AppTextStyles.h1),
                  const SizedBox(height: AppDimensions.lg),

                  if (!lockUnit) ...[
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

                  AppDateRangeField(
                    label: 'Validity Period',
                    from: validFrom,
                    to: validTo,
                    onTap: pickRange,
                  ),
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
                        sheetError ?? '',
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
                              setSheetState(() => sheetError = 'Please fill all required fields');
                              return;
                            }
                            setSheetState(() {
                              submitting = true;
                              sheetError = null;
                            });
                               final error =
                                  await ref.read(gatePassProvider.notifier).createPass({
                                'unitId': selectedUnitId!,
                                'itemDescription': descCtrl.text.trim(),
                                if (reasonCtrl.text.trim().isNotEmpty)
                                  'reason': reasonCtrl.text.trim(),
                                'validFrom': validFrom!.toIso8601String(),
                                'validTo': validTo!.toIso8601String(),
                              });
                              if (ctx.mounted) {
                                if (error == null) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text('Gate pass generated', style: AppTextStyles.bodyMedium),
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

  /// Shows **expired** when `validTo` has passed even if the row is still `ACTIVE` in the database.
  String _effectiveGatePassStatus(Map<String, dynamic> p) {
    final status = (p['status'] as String? ?? '').toLowerCase();
    if (status == 'used' || status == 'cancelled' || status == 'expired') {
      return status;
    }
    final raw = p['validTo'] as String?;
    if (raw != null && raw.isNotEmpty) {
      try {
        if (DateTime.parse(raw).isBefore(DateTime.now())) {
          return 'expired';
        }
      } catch (_) {}
    }
    return status;
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
            final p = Map<String, dynamic>.from(state.passes[i] as Map);
            final status = _effectiveGatePassStatus(p);
            final passCode = p['passCode'] as String? ?? '-';
            final desc = p['itemDescription'] as String? ?? '-';
            final unit =
                (p['unit'] as Map<String, dynamic>?)?['fullCode'] as String? ?? '-';
            final validFrom = _formatDate(p['validFrom'] as String?);
            final validTo = _formatDate(p['validTo'] as String?);
            final id = p['id'] as String? ?? '';
            final isActive = status == 'active';
            final decision = (p['decision'] as String?)?.toUpperCase();
            final scannedAt = p['scannedAt'] as String?;
            final scannedBy = (p['scannedBy'] as Map<String, dynamic>?)?['name'] as String?;

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
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GatePassQrScreen(pass: p),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          child: Icon(
                            isActive ? Icons.qr_code_rounded : Icons.history_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      if (isActive && canCancel) ...[
                        const SizedBox(width: AppDimensions.sm),
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
                               final error = await ref
                                  .read(gatePassProvider.notifier)
                                  .cancelPass(id);
                              messenger.showSnackBar(SnackBar(
                                content: Text(
                                  error ?? 'Pass cancelled',
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
                  if (!isActive && decision != null) ...[
                    const SizedBox(height: AppDimensions.sm),
                    Row(
                      children: [
                        Icon(
                          decision == 'APPROVED'
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 16,
                          color: decision == 'APPROVED'
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                        const SizedBox(width: AppDimensions.xs),
                        Expanded(
                          child: Text(
                            '$decision'
                            '${scannedBy != null ? ' · by $scannedBy' : ''}'
                            '${scannedAt != null ? ' · ${_formatDateTime(scannedAt)}' : ''}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? AppBar(
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
            )
          : null,
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
