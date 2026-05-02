import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_searchable_dropdown.dart';
import '../providers/billing_settings_provider.dart';

class BillingSettingsScreen extends ConsumerStatefulWidget {
  const BillingSettingsScreen({super.key});

  @override
  ConsumerState<BillingSettingsScreen> createState() => _BillingSettingsScreenState();
}

class _BillingSettingsScreenState extends ConsumerState<BillingSettingsScreen> {
  String _type = 'NONE';
  final _amountCtrl = TextEditingController();
  final _graceCtrl = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _graceCtrl.dispose();
    super.dispose();
  }

  String _exampleText() {
    final grace = int.tryParse(_graceCtrl.text.trim()) ?? 0;
    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (_type == 'NONE') return 'Late fee is disabled. Bills will not get extra charges after due date.';
    if (_type == 'FIXED') {
      return 'Example: Due date is 10th. After ${grace} day(s) grace, ₹${amt.toStringAsFixed(0)} late fee will be added once.';
    }
    return 'Example: Due date is 10th. After ${grace} day(s) grace, late fee increases by ₹${amt.toStringAsFixed(0)} per day.';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(billingSettingsProvider);
    final notifier = ref.read(billingSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          const AppPageHeader(
            title: 'Billing Settings',
            icon: Icons.receipt_long_rounded,
          ),
          Expanded(
            child: async.when(
              loading: () => const AppLoadingShimmer(),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.screenPadding),
                  child: AppCard(
                    backgroundColor: AppColors.dangerSurface,
                    child: Text(
                      'Error: $e',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText),
                    ),
                  ),
                ),
              ),
              data: (s) {
                if (!_initialized) {
                  _initialized = true;
                  _type = s.lateFeeType;
                  _amountCtrl.text = s.lateFeeAmount.toStringAsFixed(0);
                  _graceCtrl.text = s.lateFeeGraceDays.toString();
                }

                final showAmount = _type != 'NONE';

                return ListView(
                  padding: const EdgeInsets.all(AppDimensions.screenPadding),
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Late Fee Policy', style: AppTextStyles.h3),
                          const SizedBox(height: AppDimensions.xs),
                          Text(
                            'This decides how late fee is added after due date for maintenance bills.',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: AppDimensions.lg),
                          AppSearchableDropdown<String>(
                            label: 'Late Fee Type',
                            value: _type,
                            items: const [
                              AppDropdownItem(value: 'NONE', label: 'Disabled'),
                              AppDropdownItem(value: 'FIXED', label: 'Fixed Amount (one-time)'),
                              AppDropdownItem(value: 'PER_DAY', label: 'Per Day Increment'),
                            ],
                            onChanged: (v) => setState(() => _type = v ?? 'NONE'),
                          ),
                          const SizedBox(height: AppDimensions.md),
                          TextField(
                            controller: _graceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Grace Days (after due date)',
                              hintText: '0',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.md),
                          if (showAmount)
                            TextField(
                              controller: _amountCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: _type == 'PER_DAY' ? 'Late Fee Amount per Day' : 'Late Fee Fixed Amount',
                                prefixText: '₹',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          const SizedBox(height: AppDimensions.md),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppDimensions.md),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              _exampleText(),
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.lg),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () async {
                                      final grace = int.tryParse(_graceCtrl.text.trim()) ?? 0;
                                      final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0;
                                      if (grace < 0) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Grace days must be 0 or more')),
                                        );
                                        return;
                                      }
                                      if (_type != 'NONE' && amt <= 0) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please enter a valid late fee amount')),
                                        );
                                        return;
                                      }
                                      setState(() => _saving = true);
                                      final err = await notifier.save(
                                        lateFeeType: _type,
                                        lateFeeAmount: amt,
                                        lateFeeGraceDays: grace,
                                      );
                                      if (mounted) setState(() => _saving = false);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(err ?? 'Billing settings saved'),
                                          backgroundColor: err == null ? AppColors.success : AppColors.danger,
                                        ),
                                      );
                                    },
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

