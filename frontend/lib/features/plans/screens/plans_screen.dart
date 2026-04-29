import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/plans_provider.dart';
import '../../../shared/widgets/show_app_dialog.dart';

Map<String, dynamic> _normalizePlanFeatures(
  dynamic raw, {
  Map<String, dynamic>? fallback,
}) {
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }

  if (raw is List) {
    final out = <String, dynamic>{};
    for (final item in raw) {
      if (item is String) {
        out[item] = true;
        continue;
      }
      if (item is Map) {
        final key = item['key'] ?? item['name'] ?? item['code'] ?? item['id'];
        if (key == null) continue;
        final enabled = item['enabled'] ?? item['value'] ?? true;
        out[key.toString()] = enabled == true;
      }
    }
    return out;
  }

  return fallback ?? <String, dynamic>{};
}

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
    final isWide = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: isWide
          ? null
          : FloatingActionButton(
              onPressed: () => _showPlanDialog(context),
              child: const Icon(Icons.add_rounded),
            ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWide)
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
                                childAspectRatio: crossAxisCount == 3 ? 0.72 : crossAxisCount == 2 ? 0.78 : 0.68,
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
    Map<String, dynamic> features = _normalizePlanFeatures(
      plan?['features'],
      fallback: {
        'whatsapp': true,
        'visitor_qr': false,
        'pdf_receipts': false,
        'expense_approval': false,
        'attachments_count': false,
      },
    );

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (ctx) => _PlanBottomSheet(
        isEdit: isEdit,
        nameC: nameC,
        descC: descC,
        priceC: priceC,
        unitsC: unitsC,
        residentsC: residentsC,
        watchmenC: watchmenC,
        features: features,
        onCodeChanged: (v) => code = v,
        onSubmit: () async {
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
      ),
    );
  }
}

class _PlanBottomSheet extends StatefulWidget {
  final bool isEdit;
  final TextEditingController nameC, descC, priceC, unitsC, residentsC, watchmenC;
  final Map<String, dynamic> features;
  final void Function(String) onCodeChanged;
  final Future<void> Function() onSubmit;

  const _PlanBottomSheet({
    required this.isEdit,
    required this.nameC,
    required this.descC,
    required this.priceC,
    required this.unitsC,
    required this.residentsC,
    required this.watchmenC,
    required this.features,
    required this.onCodeChanged,
    required this.onSubmit,
  });

  @override
  State<_PlanBottomSheet> createState() => _PlanBottomSheetState();
}

class _PlanBottomSheetState extends State<_PlanBottomSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, dynamic> _features;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _features = widget.features;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    widget.isEdit ? 'Edit Plan' : 'Create Plan',
                    style: AppTextStyles.h2,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            // TabBar
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(text: 'Basic Info'),
                Tab(text: 'Features'),
              ],
            ),
            // TabBarView
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // ── Tab 1: Basic Info ──
                    SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!widget.isEdit) ...[
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Plan Code *',
                                helperText: 'Unique internal identifier (e.g. BASIC)',
                              ),
                              onChanged: (v) => widget.onCodeChanged(v.toLowerCase().trim()),
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextField(
                            controller: widget.nameC,
                            decoration: const InputDecoration(labelText: 'Display Name *'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: widget.descC,
                            decoration: const InputDecoration(labelText: 'Description'),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: widget.priceC,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Price (monthly) *',
                              prefixText: '\u20B9 ',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: widget.unitsC,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Max Units *'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: widget.residentsC,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Max Residents *'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: widget.watchmenC,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Max Watchmen'),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    // ── Tab 2: Features ──
                    ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      children: _features.keys.map((key) {
                        return CheckboxListTile(
                          title: Text(
                            key.replaceAll('_', ' ').toUpperCase(),
                            style: AppTextStyles.bodyMedium,
                          ),
                          value: _features[key] == true,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setState(() => _features[key] = v),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            // Action buttons
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + MediaQuery.of(context).padding.bottom),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _loading
                          ? null
                          : () async {
                              setState(() => _loading = true);
                              await widget.onSubmit();
                              if (mounted) setState(() => _loading = false);
                            },
                      child: _loading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(widget.isEdit ? 'Update' : 'Create'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final features = _normalizePlanFeatures(plan['features']);
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
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isActive ? accentColor.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: badge + inactive tag + actions
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    child: Text('Inactive', style: AppTextStyles.labelSmall.copyWith(color: AppColors.dangerText)),
                  ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onDeactivate,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.block, size: 16, color: AppColors.danger),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Name + price
            Text(displayName, style: AppTextStyles.h2),
            const SizedBox(height: 2),
            Text(
              '${currencyFormat.format(num.tryParse(plan['priceMonthly']?.toString() ?? '0') ?? 0)}/mo',
              style: AppTextStyles.amountLarge.copyWith(color: accentColor, fontSize: 20),
            ),
            Text('$subCount active societies', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            const Divider(height: 16),
            // Limits in one row
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _limitChip(Icons.apartment_outlined, '${_fmt(plan['maxUnits'])} units'),
                _limitChip(Icons.people_outline, '${_fmt(plan['maxResidents'])} res.'),
                _limitChip(Icons.security_outlined, '${_fmt(plan['maxWatchmen'])} wtch.'),
              ],
            ),
            const SizedBox(height: 8),
            // Features wrap
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: features.entries.map((e) {
                final enabled = e.value == true;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: enabled ? AppColors.successSurface : AppColors.dangerSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(enabled ? Icons.check : Icons.close,
                          size: 11, color: enabled ? AppColors.success : AppColors.danger),
                      const SizedBox(width: 3),
                      Text(
                        e.key.replaceAll('_', ' '),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: enabled ? AppColors.success : AppColors.danger,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic val) {
    final s = val?.toString() ?? '0';
    return (s == '999999' || s == '-1') ? '∞' : s;
  }

  Widget _limitChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
      ],
    );
  }
}
