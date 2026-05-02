import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/plans_provider.dart';
import '../../../shared/widgets/show_app_dialog.dart';

// Canonical feature definitions matching planConfig.js FEATURE_DEFAULTS
const _kFeatureGroups = [
  {
    'group': 'Security Management',
    'features': [
      {'key': 'visitors',           'label': 'Visitors'},
      {'key': 'visitor_qr',         'label': 'Visitor QR'},
      {'key': 'gate_passes',        'label': 'Gate Passes'},
      {'key': 'delivery_tracking',  'label': 'Delivery Tracking'},
      {'key': 'domestic_help',      'label': 'Domestic Help'},
      {'key': 'parking_management', 'label': 'Parking Management'},
    ],
  },
  {
    'group': 'Society Operations',
    'features': [
      {'key': 'society_gates',        'label': 'Society Gates'},
      {'key': 'amenities',            'label': 'Amenities'},
      {'key': 'amenity_booking',      'label': 'Amenity Booking'},
      {'key': 'move_requests',        'label': 'Move Requests'},
      {'key': 'complaint_assignment', 'label': 'Complaint Assignment'},
    ],
  },
  {
    'group': 'Finance & Billing',
    'features': [
      {'key': 'expenses',          'label': 'Expenses'},
      {'key': 'expense_approval',  'label': 'Expense Approval'},
      {'key': 'bill_schedules',    'label': 'Bill Schedules'},
      {'key': 'financial_reports', 'label': 'Financial Reports'},
      {'key': 'donations',         'label': 'Donations'},
    ],
  },
  {
    'group': 'Asset Management',
    'features': [
      {'key': 'asset_management', 'label': 'Asset Management'},
    ],
  },
];

// Full defaults map (mirrors FEATURE_DEFAULTS in planConfig.js)
Map<String, dynamic> _featureDefaults() {
  final out = <String, dynamic>{};
  for (final group in _kFeatureGroups) {
    for (final f in (group['features'] as List)) {
      out[(f as Map)['key'] as String] = false;
    }
  }
  out['attachments_count'] = 0;
  return out;
}

Map<String, dynamic> _normalizePlanFeatures(dynamic raw, {Map<String, dynamic>? fallback}) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List) {
    final out = <String, dynamic>{};
    for (final item in raw) {
      if (item is String) { out[item] = true; continue; }
      if (item is Map) {
        final key = item['key'] ?? item['name'] ?? item['code'] ?? item['id'];
        if (key == null) continue;
        out[key.toString()] = item['enabled'] ?? item['value'] ?? true;
      }
    }
    return out;
  }
  return fallback ?? {};
}

List<Map<String, dynamic>> _normalizeTiers(dynamic raw) {
  if (raw is! List) return [];
  return raw.whereType<Map>().map((t) => Map<String, dynamic>.from(t)).toList();
}

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

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
        padding: EdgeInsets.all(isWide ? 24 : 16),
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
                        Text('Manage pricing, tiers and feature limits', style: AppTextStyles.bodyMedium),
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
                      : LayoutBuilder(builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 500 ? 2 : 1;
                          return GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: crossAxisCount == 3 ? 0.65 : crossAxisCount == 2 ? 0.70 : 0.60,
                            ),
                            itemCount: state.plans.length,
                            itemBuilder: (context, index) => _PlanCard(
                              plan: state.plans[index],
                              currencyFormat: currencyFormat,
                              onEdit: () => _showPlanDialog(context, plan: state.plans[index]),
                              onEditTiers: () => _showTiersDialog(context, state.plans[index]),
                              onDeactivate: () => _confirmDeactivate(state.plans[index]),
                            ),
                          );
                        }),
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
    final priceC = TextEditingController(text: plan?['pricePerUnit']?.toString() ?? '');
    final unitsC = TextEditingController(
        text: (plan?['maxUnits'] == -1 || plan?['maxUnits'] == null) ? '' : plan!['maxUnits'].toString());
    final usersC = TextEditingController(
        text: (plan?['maxUsers'] == -1 || plan?['maxUsers'] == null) ? '' : plan!['maxUsers'].toString());
    String code = plan?['name'] ?? 'basic';
    // Merge stored features over full defaults so all keys are always present
    final defaults = _featureDefaults();
    final stored = _normalizePlanFeatures(plan?['features'], fallback: {});
    final Map<String, dynamic> features = {...defaults, ...stored};

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (ctx) => _PlanBottomSheet(
        isEdit: isEdit,
        nameC: nameC,
        priceC: priceC,
        unitsC: unitsC,
        usersC: usersC,
        features: features,
        onCodeChanged: (v) => code = v,
        onSubmit: () async {
          final maxUnits = int.tryParse(unitsC.text.trim());
          final maxUsers = int.tryParse(usersC.text.trim());
          final data = <String, dynamic>{
            'displayName': nameC.text.trim(),
            'pricePerUnit': num.tryParse(priceC.text) ?? 0,
            'maxUnits': maxUnits ?? -1,
            'maxUsers': maxUsers ?? -1,
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

  void _showTiersDialog(BuildContext context, Map<String, dynamic> plan) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (ctx) => _TiersBottomSheet(
        plan: plan,
        onSave: (tiers) async {
          Navigator.pop(ctx);
          final ok = await ref.read(plansProvider.notifier).saveTiers(plan['id'], tiers);
          if (!mounted) return;
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(content: Text(ok ? 'Pricing tiers saved' : 'Failed to save tiers')),
          );
        },
      ),
    );
  }
}

// ── Plan create/edit sheet ────────────────────────────────────────────

class _PlanBottomSheet extends StatefulWidget {
  final bool isEdit;
  final TextEditingController nameC, priceC, unitsC, usersC;
  final Map<String, dynamic> features;
  final void Function(String) onCodeChanged;
  final Future<void> Function() onSubmit;

  const _PlanBottomSheet({
    required this.isEdit,
    required this.nameC,
    required this.priceC,
    required this.unitsC,
    required this.usersC,
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
            const SizedBox(height: 10),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textMuted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(widget.isEdit ? 'Edit Plan' : 'Create Plan', style: AppTextStyles.h2),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [Tab(text: 'Basic Info'), Tab(text: 'Features')],
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // ── Tab 1: Basic Info
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
                                helperText: 'Unique internal identifier (e.g. basic)',
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
                            controller: widget.priceC,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Default Price per Unit / Month *',
                              prefixText: '₹ ',
                              helperText: 'Used as fallback when no pricing tiers are set',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: widget.unitsC,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Max Units',
                                  helperText: 'Leave blank = unlimited',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: widget.usersC,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Max Users',
                                  helperText: 'Leave blank = unlimited',
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'After saving, use the "Pricing Tiers" button on the plan card to configure volume-based pricing tiers.',
                                    style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Tab 2: Features
                    ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      children: [
                        for (final group in _kFeatureGroups) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(
                              group['group'] as String,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          for (final f in (group['features'] as List)) ...[
                            Builder(builder: (_) {
                              final key = (f as Map)['key'] as String;
                              final label = f['label'] as String;
                              return CheckboxListTile(
                                title: Text(label, style: AppTextStyles.bodyMedium),
                                value: _features[key] == true,
                                activeColor: AppColors.primary,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                onChanged: (v) => setState(() => _features[key] = v ?? false),
                              );
                            }),
                          ],
                        ],
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            'Limits',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Attachments per post'),
                          subtitle: Text(
                            _features['attachments_count'] == -1
                                ? 'Unlimited'
                                : _features['attachments_count'] == 0
                                    ? 'Not allowed'
                                    : '${_features['attachments_count']}',
                            style: AppTextStyles.caption,
                          ),
                          trailing: DropdownButton<int>(
                            value: _features['attachments_count'] is int ? _features['attachments_count'] as int : 0,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 0,  child: Text('0 (denied)')),
                              DropdownMenuItem(value: 5,  child: Text('5')),
                              DropdownMenuItem(value: 10, child: Text('10')),
                              DropdownMenuItem(value: 20, child: Text('20')),
                              DropdownMenuItem(value: -1, child: Text('Unlimited')),
                            ],
                            onChanged: (v) => setState(() => _features['attachments_count'] = v ?? 0),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + MediaQuery.of(context).padding.bottom),
              child: Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _loading ? null : () async {
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

// ── Pricing tiers sheet ───────────────────────────────────────────────

class _TiersBottomSheet extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Future<void> Function(List<Map<String, dynamic>>) onSave;

  const _TiersBottomSheet({required this.plan, required this.onSave});

  @override
  State<_TiersBottomSheet> createState() => _TiersBottomSheetState();
}

class _TiersBottomSheetState extends State<_TiersBottomSheet> {
  late List<_TierRow> _rows;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final existing = _normalizeTiers(widget.plan['pricingTiers']);
    _rows = existing.isEmpty
        ? [_TierRow(), _TierRow(), _TierRow()]
        : existing.map((t) => _TierRow.fromMap(t)).toList();
  }

  void _addRow() => setState(() => _rows.add(_TierRow()));

  void _removeRow(int i) {
    if (_rows.length <= 1) return;
    setState(() => _rows.removeAt(i));
  }

  List<Map<String, dynamic>>? _buildTiers() {
    final tiers = <Map<String, dynamic>>[];
    for (int i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final min = int.tryParse(r.minC.text.trim());
      final max = int.tryParse(r.maxC.text.trim()); // -1 allowed via text "-1"
      final price = double.tryParse(r.priceC.text.trim());
      if (min == null || max == null || price == null) return null;
      tiers.add({
        'minUnits': min,
        'maxUnits': max,
        'pricePerUnit': price,
        'label': r.labelC.text.trim().isEmpty ? null : r.labelC.text.trim(),
        'sortOrder': i + 1,
      });
    }
    return tiers;
  }

  String get _planName => widget.plan['displayName'] ?? widget.plan['name'] ?? 'Plan';

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textMuted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pricing Tiers', style: AppTextStyles.h2),
                        Text(_planName, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            // Instructions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  'Set Max Units = -1 for "no upper limit" (ceiling tier). '
                  'Higher unit counts should have lower per-unit rates.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.primary, height: 1.4),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  const Expanded(flex: 2, child: Text('Min', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  const SizedBox(width: 8),
                  const Expanded(flex: 2, child: Text('Max (-1=∞)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  const SizedBox(width: 8),
                  const Expanded(flex: 2, child: Text('₹/unit/mo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  const SizedBox(width: 8),
                  const Expanded(flex: 3, child: Text('Label (optional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  const SizedBox(width: 36),
                ],
              ),
            ),
            const Divider(height: 12),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(20, 4, 20, bottom + 8),
                itemCount: _rows.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: _numField(_rows[i].minC, 'e.g. 0')),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: _numField(_rows[i].maxC, 'e.g. 99')),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: _numField(_rows[i].priceC, 'e.g. 10')),
                      const SizedBox(width: 8),
                      Expanded(flex: 3, child: TextField(
                        controller: _rows[i].labelC,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'e.g. 150+ units',
                          hintStyle: const TextStyle(fontSize: 12),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      )),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 20),
                        onPressed: () => _removeRow(i),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).padding.bottom),
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Tier'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 42)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _loading ? null : () async {
                            final tiers = _buildTiers();
                            if (tiers == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('All tier fields (min, max, price) must be valid numbers')),
                              );
                              return;
                            }
                            setState(() => _loading = true);
                            await widget.onSave(tiers);
                          },
                          child: _loading
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Save Tiers'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String hint) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

class _TierRow {
  final TextEditingController minC;
  final TextEditingController maxC;
  final TextEditingController priceC;
  final TextEditingController labelC;

  _TierRow()
      : minC = TextEditingController(),
        maxC = TextEditingController(),
        priceC = TextEditingController(),
        labelC = TextEditingController();

  _TierRow.fromMap(Map<String, dynamic> t)
      : minC = TextEditingController(text: t['minUnits']?.toString() ?? ''),
        maxC = TextEditingController(text: t['maxUnits']?.toString() ?? ''),
        priceC = TextEditingController(text: t['pricePerUnit']?.toString() ?? ''),
        labelC = TextEditingController(text: t['label']?.toString() ?? '');
}

// ── Plan card ─────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final NumberFormat currencyFormat;
  final VoidCallback onEdit;
  final VoidCallback onEditTiers;
  final VoidCallback onDeactivate;

  const _PlanCard({
    required this.plan,
    required this.currencyFormat,
    required this.onEdit,
    required this.onEditTiers,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = plan['isActive'] == true;
    final features = _normalizePlanFeatures(plan['features']);
    final tiers = _normalizeTiers(plan['pricingTiers']);
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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(name, style: AppTextStyles.labelSmall.copyWith(color: accentColor)),
                ),
                const Spacer(),
                if (!isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.dangerSurface, borderRadius: BorderRadius.circular(8)),
                    child: Text('Inactive', style: AppTextStyles.labelSmall.copyWith(color: AppColors.dangerText)),
                  ),
                const SizedBox(width: 4),
                _actionBtn(Icons.edit_outlined, AppColors.primary, onEdit),
                _actionBtn(Icons.stacked_bar_chart, accentColor, onEditTiers, tooltip: 'Pricing Tiers'),
                if (isActive) _actionBtn(Icons.block, AppColors.danger, onDeactivate),
              ],
            ),
            const SizedBox(height: 8),
            Text(displayName, style: AppTextStyles.h2),
            const SizedBox(height: 2),
            Text(
              '₹${plan['pricePerUnit'] ?? 0}/unit/mo (base)',
              style: AppTextStyles.amountLarge.copyWith(color: accentColor, fontSize: 18),
            ),
            Text('$subCount active societies', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            const Divider(height: 14),
            // Limits
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _limitChip(Icons.apartment_outlined, '${_fmt(plan['maxUnits'])} units'),
                _limitChip(Icons.people_outline, '${_fmt(plan['maxUsers'])} users'),
              ],
            ),
            // Tiers summary
            if (tiers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Pricing Tiers', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted, fontSize: 10)),
              const SizedBox(height: 4),
              ...tiers.map((t) {
                final min = t['minUnits'];
                final max = t['maxUnits'];
                final price = t['pricePerUnit'];
                final range = max == -1 ? '$min+ units' : '$min–$max units';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.6), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(range, style: const TextStyle(fontSize: 11, color: Color(0xFF4A5568)))),
                      Text('₹$price/unit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accentColor)),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 8),
            // Features
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
                      Icon(enabled ? Icons.check : Icons.close, size: 11, color: enabled ? AppColors.success : AppColors.danger),
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

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap, {String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  String _fmt(dynamic val) {
    final s = val?.toString() ?? '0';
    return (s == '999999' || s == '-1') ? '∞' : s;
  }

  Widget _limitChip(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: AppColors.textMuted),
      const SizedBox(width: 4),
      Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
    ],
  );
}
