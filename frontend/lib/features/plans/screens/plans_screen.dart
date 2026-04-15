import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/plans_provider.dart';
import '../../../shared/widgets/show_app_dialog.dart';

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(plansProvider.notifier).loadPlans());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(plansProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Subscription Plans', style: AppTextStyles.displayMedium),
                      const SizedBox(height: 4),
                      Text('Manage pricing and feature limits', style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showPlanDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Plan'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.plans.isEmpty
                      ? Center(child: Text('No plans configured', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 500 ? 2 : 1;
                            return GridView.builder(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: state.plans.length,
                              itemBuilder: (context, index) => _PlanCard(
                                plan: state.plans[index],
                                currencyFormat: currencyFormat,
                                onEdit: () => _showPlanDialog(context, plan: state.plans[index]),
                                onDeactivate: () => _confirmDeactivate(state.plans[index]),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeactivate(Map<String, dynamic> plan) {
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Plan'),
        content: Text('Deactivate "${plan['name']}"? Societies must be migrated first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref.read(plansProvider.notifier).deactivatePlan(plan['id']);
              if (!ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cannot deactivate plan with active subscriptions')),
                );
              }
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  void _showPlanDialog(BuildContext context, {Map<String, dynamic>? plan}) {
    final isEdit = plan != null;
    final nameC = TextEditingController(text: plan?['displayName'] ?? '');
    final descC = TextEditingController(text: plan?['description'] ?? '');
    final priceC = TextEditingController(text: plan?['priceMonthly']?.toString() ?? '');
    final unitsC = TextEditingController(text: plan?['maxUnits']?.toString() ?? '');
    final residentsC = TextEditingController(text: plan?['maxResidents']?.toString() ?? '');
    final watchmenC = TextEditingController(text: plan?['maxWatchmen']?.toString() ?? '2');
    String code = plan?['name'] ?? 'basic';
    Map<String, dynamic> features = Map<String, dynamic>.from(plan?['features'] ?? {
      'whatsapp': true,
      'visitor_qr': false,
      'pdf_receipts': false,
      'expense_approval': false,
      'attachments_count': false,
    });

    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Plan' : 'Create Plan'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isEdit)
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Plan Code (e.g. BASIC, ENTERPRISE) *',
                      helperText: 'Unique internal identifier',
                    ),
                    onChanged: (v) => code = v.toLowerCase().trim(),
                  ),
                const SizedBox(height: 10),
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Display Name *')),
                const SizedBox(height: 10),
                TextField(controller: descC, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 10),
                TextField(
                  controller: priceC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price (monthly) *', prefixText: '\u20B9 '),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: unitsC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max Units *'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: residentsC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max Residents *'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: watchmenC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max Watchmen'),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Plan Features', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                StatefulBuilder(
                  builder: (ctx, setInternalState) => Column(
                    children: features.keys.map((key) {
                      return CheckboxListTile(
                        title: Text(key.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 14)),
                        value: features[key] == true,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) {
                          setInternalState(() => features[key] = v);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final data = <String, dynamic>{
                'displayName': nameC.text.trim(),
                'description': descC.text.trim(),
                'priceMonthly': num.tryParse(priceC.text) ?? 0,
                'maxUnits': int.tryParse(unitsC.text) ?? 0,
                'maxResidents': int.tryParse(residentsC.text) ?? 0,
                'maxWatchmen': int.tryParse(watchmenC.text) ?? 2,
                'features': features,
              };
              if (!isEdit) data['name'] = code.toLowerCase();

              Navigator.pop(ctx);
              if (isEdit) {
                await ref.read(plansProvider.notifier).updatePlan(plan['id'], data);
              } else {
                await ref.read(plansProvider.notifier).createPlan(data);
              }
            },
            child: Text(isEdit ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final NumberFormat currencyFormat;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  const _PlanCard({required this.plan, required this.currencyFormat, required this.onEdit, required this.onDeactivate});

  @override
  Widget build(BuildContext context) {
    final isActive = plan['isActive'] == true;
    final features = plan['features'] as Map<String, dynamic>? ?? {};
    final subCount = plan['societyCount'] ?? 0;
    final name = plan['name']?.toString().toUpperCase() ?? '';
    final displayName = plan['displayName'] ?? (name.isNotEmpty ? name : 'PLAN');

    final accentColor = name == 'PREMIUM'
        ? const Color(0xFF8B5CF6)
        : name == 'STANDARD'
            ? const Color(0xFF3B82F6)
            : const Color(0xFF64748B);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isActive ? accentColor.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(name, style: AppTextStyles.labelSmall.copyWith(color: accentColor)),
                ),
                const Spacer(),
                if (!isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Inactive',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.dangerText)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(displayName, style: AppTextStyles.h2),
            const SizedBox(height: 4),
            Text(
              '${currencyFormat.format(num.tryParse(plan['priceMonthly']?.toString() ?? '0') ?? 0)}/mo',
              style: AppTextStyles.amountLarge.copyWith(color: accentColor),
            ),
            const SizedBox(height: 4),
            Text('$subCount active societies', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            const Divider(height: 24),
            _limitRow('Units', '${plan['maxUnits'] ?? 0}'),
            _limitRow('Residents', '${plan['maxResidents'] ?? 0}'),
            _limitRow('Watchmen', '${plan['maxWatchmen'] ?? 0}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: features.entries.map((e) {
                return Chip(
                  label: Text(e.key, style: AppTextStyles.labelSmall),
                  backgroundColor: e.value == true
                      ? AppColors.successSurface
                      : AppColors.dangerSurface,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(e.value == true ? Icons.check : Icons.close,
                      size: 14, color: e.value == true ? AppColors.success : AppColors.danger),
                );
              }).toList(),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
                ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.block, color: AppColors.danger, size: 20),
                    tooltip: 'Deactivate',
                    onPressed: onDeactivate,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _limitRow(String label, String value) {
    final display = (value == '999999' || value == '-1') ? 'Unlimited' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          Text(display, style: AppTextStyles.labelLarge),
        ],
      ),
    );
  }
}
