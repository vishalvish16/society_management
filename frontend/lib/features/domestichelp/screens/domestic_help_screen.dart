import 'package:flutter/material.dart';
import '../../../shared/widgets/show_app_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../providers/domestic_help_provider.dart';
import '../../../shared/widgets/unit_picker_field.dart';
import '../../../shared/widgets/app_searchable_dropdown.dart';

const _helperTypes = ['MAID', 'COOK', 'DRIVER', 'GARDENER', 'OTHER'];
const _adminRoles = {'PRAMUKH', 'SECRETARY'};
const _canAddRoles = {'PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT'};

class DomesticHelpScreen extends ConsumerStatefulWidget {
  const DomesticHelpScreen({super.key});

  @override
  ConsumerState<DomesticHelpScreen> createState() => _DomesticHelpScreenState();
}

class _DomesticHelpScreenState extends ConsumerState<DomesticHelpScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final helpState = ref.watch(domesticHelpProvider);
    final role = ref.watch(authProvider).user?.role ?? '';
    final canAdd = _canAddRoles.contains(role);
    final isAdmin = _adminRoles.contains(role);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'Domestic Help',
          style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary),
        ),
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              onPressed: () => _showHelperSheet(context, role: role),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.person_add_rounded, color: AppColors.textOnPrimary),
              label: Text(
                'Add Helper',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary),
              ),
            )
          : null,
      body: Column(
        children: [
          // Filter chips
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.screenPadding,
              vertical: AppDimensions.sm,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in ['all', 'active', 'suspended', 'removed'])
                    Padding(
                      padding: const EdgeInsets.only(right: AppDimensions.sm),
                      child: ChoiceChip(
                        label: Text(
                          s == 'all' ? 'All' : s[0].toUpperCase() + s.substring(1),
                        ),
                        selected: _filter == s,
                        selectedColor: AppColors.primarySurface,
                        labelStyle: AppTextStyles.labelMedium.copyWith(
                          color: _filter == s ? AppColors.primary : AppColors.textMuted,
                        ),
                        onSelected: (_) => setState(() => _filter = s),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Body
          Expanded(
            child: () {
              if (helpState.isLoading) {
                return const AppLoadingShimmer();
              }
              if (helpState.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.screenPadding),
                    child: AppCard(
                      backgroundColor: AppColors.dangerSurface,
                      child: Text(
                        'Error: ${helpState.error}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText),
                      ),
                    ),
                  ),
                );
              }

              final filtered = _filter == 'all'
                  ? helpState.helpers
                  : helpState.helpers
                      .where((h) => (h['status'] as String? ?? '').toLowerCase() == _filter)
                      .toList();

              if (filtered.isEmpty) {
                return const AppEmptyState(
                  emoji: '🧹',
                  title: 'No Domestic Helpers',
                  subtitle: 'No helpers match the selected filter.',
                );
              }

              return RefreshIndicator(
                onRefresh: () => ref.read(domesticHelpProvider.notifier).loadHelpers(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppDimensions.screenPadding),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.sm),
                  itemBuilder: (_, i) {
                    final h = filtered[i];
                    final status = h['status'] as String? ?? 'active';
                    final name = h['name'] as String? ?? '-';
                    final type = h['type'] as String? ?? '-';
                    final unit = h['unit'] is Map
                        ? (h['unit'] as Map)['fullCode'] ?? '-'
                        : (h['unit'] ?? '-').toString();
                    final phone = h['phone'] as String?;
                    final entryCode = h['entryCode'] as String?;
                    final id = h['id'] as String? ?? '';
                    final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';

                    return AppCard(
                      padding: const EdgeInsets.all(AppDimensions.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              firstLetter,
                              style: AppTextStyles.h3.copyWith(color: AppColors.textOnPrimary),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name + status
                                Row(
                                  children: [
                                    Expanded(child: Text(name, style: AppTextStyles.h3)),
                                    AppStatusChip(status: status),
                                  ],
                                ),
                                const SizedBox(height: AppDimensions.xs),
                                // Type badge + unit
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySurface,
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                      ),
                                      child: Text(
                                        type.toUpperCase(),
                                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                                      ),
                                    ),
                                    const SizedBox(width: AppDimensions.sm),
                                    Text(
                                      'Unit $unit',
                                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                                if (phone != null && phone.isNotEmpty) ...[
                                  const SizedBox(height: AppDimensions.xs),
                                  Text(
                                    phone,
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                                  ),
                                ],
                                if (entryCode != null && entryCode.isNotEmpty) ...[
                                  const SizedBox(height: AppDimensions.xs),
                                  Text(
                                    'Entry: $entryCode',
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                                  ),
                                ],
                                // Admin action buttons
                                if (id.isNotEmpty && (canAdd || isAdmin)) ...[
                                  const SizedBox(height: AppDimensions.sm),
                                  Row(
                                    children: [
                                      // Edit — available to canAdd roles
                                      if (canAdd)
                                        InkWell(
                                          onTap: () => _showHelperSheet(
                                            context,
                                            role: role,
                                            existing: h,
                                          ),
                                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                          child: Padding(
                                            padding: const EdgeInsets.all(AppDimensions.xs),
                                            child: Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                                          ),
                                        ),
                                      const Spacer(),
                                      // Suspend — admin only, only when active
                                      if (isAdmin && status == 'active') ...[
                                        OutlinedButton(
                                          onPressed: () => _confirmAction(
                                            label: 'Suspend',
                                            message: 'Suspend $name?',
                                            onConfirm: () => ref
                                                .read(domesticHelpProvider.notifier)
                                                .suspendHelper(id),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.warning,
                                            side: const BorderSide(color: AppColors.warning),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppDimensions.md,
                                              vertical: AppDimensions.xs,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                            ),
                                          ),
                                          child: Text(
                                            'Suspend',
                                            style: AppTextStyles.labelMedium.copyWith(color: AppColors.warning),
                                          ),
                                        ),
                                        const SizedBox(width: AppDimensions.sm),
                                      ],
                                      // Remove — admin only
                                      if (isAdmin && status != 'removed')
                                        OutlinedButton(
                                          onPressed: () => _confirmAction(
                                            label: 'Remove',
                                            message: 'Remove $name permanently?',
                                            onConfirm: () => ref
                                                .read(domesticHelpProvider.notifier)
                                                .removeHelper(id),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.danger,
                                            side: const BorderSide(color: AppColors.danger),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppDimensions.md,
                                              vertical: AppDimensions.xs,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                            ),
                                          ),
                                          child: Text(
                                            'Remove',
                                            style: AppTextStyles.labelMedium.copyWith(color: AppColors.danger),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            }(),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAction({
    required String label,
    required String message,
    required Future<String?> Function() onConfirm,
  }) async {
    final confirmed = await showConfirmSheet(
      context: context,
      title: label,
      message: message,
      confirmLabel: label,
      confirmColor: label == 'Remove' ? AppColors.danger : AppColors.warning,
    );
    if (!confirmed) return;
    final error = await onConfirm();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? '$label successful'),
        backgroundColor: error == null ? AppColors.success : AppColors.danger,
      ),
    );
  }

  void _showHelperSheet(BuildContext context, {required String role, Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => _HelperForm(existing: existing),
    );
  }
}

class _HelperForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  const _HelperForm({this.existing});

  @override
  ConsumerState<_HelperForm> createState() => _HelperFormState();
}

class _HelperFormState extends ConsumerState<_HelperForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String? _selectedUnitId;
  String? _selectedUnitCode;
  bool _lockUnit = false;
  late final TextEditingController _phoneController;
  late final TextEditingController _entryCodeController;
  late String _selectedType;
  bool _isLoading = false;
  String? _errorMsg;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final user = ref.read(authProvider).user;
    _lockUnit = (e == null) && (user?.isUnitLocked ?? false);
    if (_lockUnit) {
      _selectedUnitId = user?.unitId;
      _selectedUnitCode = user?.unitCode;
    }
    _nameController = TextEditingController(text: e?['name'] as String? ?? '');
    _phoneController = TextEditingController(text: e?['phone'] as String? ?? '');
    _entryCodeController = TextEditingController(text: e?['entryCode'] as String? ?? '');
    final rawType = (e?['type'] as String? ?? 'MAID').toUpperCase();
    _selectedType = _helperTypes.contains(rawType) ? rawType : 'MAID';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _entryCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    
    String? error;
    if (_isEdit) {
      error = await ref.read(domesticHelpProvider.notifier).updateHelper(
        widget.existing!['id'] as String,
        {
          'name': _nameController.text.trim(),
          'type': _selectedType,
          'phone': _phoneController.text.trim(),
        },
      );
    } else {
      if (_selectedUnitId == null) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Please select a unit';
        });
        return;
      }
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'unitId': _selectedUnitId!,
      };
      final phone = _phoneController.text.trim();
      final entryCode = _entryCodeController.text.trim();
      if (phone.isNotEmpty) data['phone'] = phone;
      if (entryCode.isNotEmpty) data['entryCode'] = entryCode;
      error = await ref.read(domesticHelpProvider.notifier).addHelper(data);
    }
 
    if (mounted) {
      if (error == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Helper updated' : 'Helper added successfully')),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.screenPadding,
        AppDimensions.lg,
        AppDimensions.screenPadding,
        MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
      ),
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
            Text(_isEdit ? 'Edit Helper' : 'Add Helper', style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.lg),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_rounded),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppDimensions.md),
            AppSearchableDropdown<String>(
              label: 'Type',
              value: _selectedType,
              items: _helperTypes.map((t) => AppDropdownItem(value: t, label: t)).toList(),
              onChanged: (v) { if (v != null) setState(() => _selectedType = v); },
            ),
            if (!_isEdit) ...[
              const SizedBox(height: AppDimensions.md),
              UnitPickerField(
                selectedUnitId: _selectedUnitId,
                selectedUnitCode: _selectedUnitCode,
                readOnly: _lockUnit,
                onChanged: (id, code) => setState(() {
                  _selectedUnitId = id;
                  _selectedUnitCode = code;
                }),
              ),
            ],
            const SizedBox(height: AppDimensions.md),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone (Optional)',
                prefixIcon: Icon(Icons.phone_rounded),
              ),
              keyboardType: TextInputType.phone,
            ),
            if (!_isEdit) ...[
              const SizedBox(height: AppDimensions.md),
              TextFormField(
                controller: _entryCodeController,
                decoration: const InputDecoration(
                  labelText: 'Entry Code (Optional)',
                  prefixIcon: Icon(Icons.vpn_key_rounded),
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.md),
            if (_errorMsg != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.sm),
                margin: const EdgeInsets.only(bottom: AppDimensions.md),
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
                    : Text(
                        _isEdit ? 'Update Helper' : 'Add Helper',
                        style: AppTextStyles.buttonLarge,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
