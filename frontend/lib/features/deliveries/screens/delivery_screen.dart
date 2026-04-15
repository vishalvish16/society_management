import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({super.key});

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  String _filter = 'all';

  static const _staffRoles = {'WATCHMAN', 'PRAMUKH', 'SECRETARY'};

  Color _borderColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'collected':
        return AppColors.success;
      case 'returned':
        return AppColors.textMuted;
      default:
        return AppColors.border;
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    if (raw.length >= 10) return raw.substring(0, 10);
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final deliveryState = ref.watch(deliveryProvider);
    final role = ref.watch(authProvider).user?.role ?? '';
    final isStaff = _staffRoles.contains(role);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'Deliveries',
          style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary),
        ),
      ),
      floatingActionButton: isStaff
          ? FloatingActionButton.extended(
              onPressed: () => _showLogDeliverySheet(context),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_box_rounded, color: AppColors.textOnPrimary),
              label: Text(
                'Log Delivery',
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
                  for (final s in ['all', 'pending', 'collected', 'returned'])
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
                  : deliveryState.deliveries
                      .where((d) => d['status'] == _filter)
                      .toList();

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
                  padding: const EdgeInsets.all(AppDimensions.screenPadding),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.sm),
                  itemBuilder: (_, i) {
                    final d = filtered[i];
                    final status = d['status'] as String? ?? 'pending';
                    final unit = d['unit'] is Map
                        ? (d['unit'] as Map)['fullCode'] ?? '-'
                        : (d['unit'] ?? '-').toString();
                    final agentName = d['agentName'] as String? ?? '-';
                    final company = d['company'] as String?;
                    final description = d['description'] as String?;
                    final loggedAt = _formatDate(d['loggedAt'] as String?);
                    final id = d['id'] as String? ?? '';

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
                          // Description (if present)
                          if (description != null && description.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.xs),
                            Text(
                              description,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                          // Mark Collected button for staff on pending deliveries
                          if (isStaff && status == 'pending' && id.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.sm),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => _markCollected(id),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.success,
                                  side: const BorderSide(color: AppColors.success),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                                ),
                                child: Text(
                                  'Mark Collected',
                                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.success),
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
          ),
        ],
      ),
    );
  }

  Future<void> _markCollected(String id) async {
    final success = await ref.read(deliveryProvider.notifier).markCollected(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Marked as collected' : 'Failed to update delivery'),
        ),
      );
    }
  }

  void _showLogDeliverySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
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

    final success = await ref.read(deliveryProvider.notifier).logDelivery(data);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery logged successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to log delivery')),
        );
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
            Text('Log Delivery', style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.lg),
            UnitPickerField(
              selectedUnitId: _selectedUnitId,
              selectedUnitCode: _selectedUnitCode,
              readOnly: _lockUnit,
              onChanged: (id, code) => setState(() {
                _selectedUnitId = id;
                _selectedUnitCode = code;
              }),
            ),
            const SizedBox(height: AppDimensions.md),
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
    );
  }
}
