import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/show_app_sheet.dart';
import '../providers/rules_provider.dart';

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  static const _adminRoles = {'PRAMUKH', 'CHAIRMAN', 'SECRETARY'};
  static const _categories = [
    'GENERAL',
    'PARKING',
    'NOISE',
    'PETS',
    'MAINTENANCE',
    'SECURITY',
    'OTHER',
  ];

  bool _isAdmin(String? role) =>
      _adminRoles.contains((role ?? '').toUpperCase());

  IconData _categoryIcon(String cat) {
    switch (cat.toUpperCase()) {
      case 'PARKING':
        return Icons.local_parking_rounded;
      case 'NOISE':
        return Icons.volume_off_rounded;
      case 'PETS':
        return Icons.pets_rounded;
      case 'MAINTENANCE':
        return Icons.build_rounded;
      case 'SECURITY':
        return Icons.security_rounded;
      case 'OTHER':
        return Icons.more_horiz_rounded;
      default:
        return Icons.gavel_rounded;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'PARKING':
        return Colors.blue;
      case 'NOISE':
        return Colors.orange;
      case 'PETS':
        return Colors.brown;
      case 'MAINTENANCE':
        return Colors.teal;
      case 'SECURITY':
        return Colors.red;
      case 'OTHER':
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).user?.role;
    final isAdmin = _isAdmin(role);
    final st = ref.watch(rulesProvider);
    final isWide = MediaQuery.of(context).size.width >= 768;

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final rule in st.rules) {
      final cat = (rule['category']?.toString() ?? 'GENERAL').toUpperCase();
      grouped.putIfAbsent(cat, () => []).add(rule);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? AppBar(
              backgroundColor: AppColors.primary,
              title: Text('Society Rules',
                  style:
                      AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () =>
                      ref.read(rulesProvider.notifier).loadRules(),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
                if (isAdmin) ...[
                  IconButton(
                    tooltip: 'Add Rule',
                    onPressed: () => _showRuleSheet(context, ref, null),
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            )
          : null,
      floatingActionButton: isAdmin && !isWide
          ? FloatingActionButton.extended(
              onPressed: () => _showRuleSheet(context, ref, null),
              backgroundColor: AppColors.primary,
              icon:
                  const Icon(Icons.add_rounded, color: AppColors.textOnPrimary),
              label: Text('Add Rule',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textOnPrimary)),
            )
          : null,
      body: st.isLoading
          ? const AppLoadingShimmer()
          : st.error != null
              ? Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(AppDimensions.screenPadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppCard(
                          backgroundColor: AppColors.dangerSurface,
                          child: Text('Error: ${st.error}',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.dangerText)),
                        ),
                        const SizedBox(height: AppDimensions.md),
                        OutlinedButton.icon(
                          onPressed: () =>
                              ref.read(rulesProvider.notifier).loadRules(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : st.rules.isEmpty
                  ? AppEmptyState(
                      emoji: '📜',
                      title: 'No Rules Yet',
                      subtitle: isAdmin
                          ? 'Tap + to add society rules and guidelines.'
                          : 'No rules have been published for this society yet.',
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(rulesProvider.notifier).loadRules(),
                      child: ListView(
                        padding:
                            const EdgeInsets.all(AppDimensions.screenPadding),
                        children: [
                          // Summary header
                          Container(
                            padding: const EdgeInsets.all(AppDimensions.md),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.08),
                                  AppColors.primary.withValues(alpha: 0.03),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusMd),
                              border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.gavel_rounded,
                                      color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${st.rules.length} Rule${st.rules.length == 1 ? '' : 's'}',
                                        style: AppTextStyles.h3,
                                      ),
                                      Text(
                                        '${grouped.length} ${grouped.length == 1 ? 'category' : 'categories'}',
                                        style: AppTextStyles.caption.copyWith(
                                            color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppDimensions.lg),
                          // Rules grouped by category
                          ...grouped.entries.map((entry) {
                            final cat = entry.key;
                            final rules = entry.value;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(_categoryIcon(cat),
                                        size: 18,
                                        color: _categoryColor(cat)),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatCategory(cat),
                                      style: AppTextStyles.labelLarge.copyWith(
                                        color: _categoryColor(cat),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _categoryColor(cat)
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${rules.length}',
                                        style:
                                            AppTextStyles.caption.copyWith(
                                          color: _categoryColor(cat),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppDimensions.sm),
                                ...rules.asMap().entries.map((re) {
                                  final index = re.key;
                                  final rule = re.value;
                                  return _RuleCard(
                                    rule: rule,
                                    index: index + 1,
                                    color: _categoryColor(cat),
                                    isAdmin: isAdmin,
                                    onEdit: () =>
                                        _showRuleSheet(context, ref, rule),
                                    onDelete: () =>
                                        _confirmDelete(context, ref, rule),
                                    onToggle: () => _toggleActive(
                                        ref, rule),
                                  );
                                }),
                                const SizedBox(height: AppDimensions.lg),
                              ],
                            );
                          }),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
    );
  }

  String _formatCategory(String cat) {
    return cat
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  void _showRuleSheet(
      BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showAppSheet(
      context: context,
      builder: (ctx) => _RuleFormSheet(
        existing: existing,
        categories: _categories,
        onSubmit: (title, description, category) async {
          if (existing != null) {
            return await ref.read(rulesProvider.notifier).updateRule(
                  id: existing['id'],
                  title: title,
                  description: description,
                  category: category,
                );
          } else {
            return await ref.read(rulesProvider.notifier).createRule(
                  title: title,
                  description: description,
                  category: category,
                );
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Map<String, dynamic> rule) async {
    final confirmed = await showConfirmSheet(
      context: context,
      title: 'Delete Rule',
      message:
          'Are you sure you want to delete "${rule['title']}"? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (confirmed) {
      final err =
          await ref.read(rulesProvider.notifier).deleteRule(rule['id']);
      if (context.mounted && err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(err), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _toggleActive(WidgetRef ref, Map<String, dynamic> rule) async {
    await ref.read(rulesProvider.notifier).updateRule(
          id: rule['id'],
          isActive: !(rule['isActive'] ?? true),
        );
  }
}

class _RuleCard extends StatelessWidget {
  final Map<String, dynamic> rule;
  final int index;
  final Color color;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _RuleCard({
    required this.rule,
    required this.index,
    required this.color,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final title = rule['title']?.toString() ?? '';
    final description = rule['description']?.toString() ?? '';
    final isActive = rule['isActive'] ?? true;
    final createdByName =
        (rule['createdBy'] as Map?)?['name']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: AppCard(
        leftBorderColor: isActive ? color : AppColors.textMuted,
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: (isActive ? color : AppColors.textMuted)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$index',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isActive ? color : AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.h3.copyWith(
                          decoration: isActive
                              ? null
                              : TextDecoration.lineThrough,
                          color: isActive
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isActive
                                ? AppColors.textSecondary
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Inactive',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted)),
                  ),
              ],
            ),
            if (isAdmin) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (createdByName.isNotEmpty)
                    Expanded(
                      child: Text(
                        'By $createdByName',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      isActive
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    tooltip: isActive ? 'Deactivate' : 'Activate',
                    onPressed: onToggle,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded,
                        size: 18, color: AppColors.primary),
                    tooltip: 'Edit',
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.danger),
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RuleFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<String> categories;
  final Future<String?> Function(
      String title, String? description, String category) onSubmit;

  const _RuleFormSheet({
    this.existing,
    required this.categories,
    required this.onSubmit,
  });

  @override
  State<_RuleFormSheet> createState() => _RuleFormSheetState();
}

class _RuleFormSheetState extends State<_RuleFormSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late String _category;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleCtrl =
        TextEditingController(text: widget.existing?['title']?.toString() ?? '');
    _descCtrl = TextEditingController(
        text: widget.existing?['description']?.toString() ?? '');
    _category =
        (widget.existing?['category']?.toString() ?? 'GENERAL').toUpperCase();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.screenPadding,
        AppDimensions.lg,
        AppDimensions.screenPadding,
        MediaQuery.of(context).viewInsets.bottom + AppDimensions.xxxl,
      ),
      child: SingleChildScrollView(
        child: Column(
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
            Text(isEdit ? 'Edit Rule' : 'Add Rule', style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.lg),
            _label('Title'),
            const SizedBox(height: 6),
            _field(_titleCtrl, 'e.g. No loud music after 10 PM'),
            const SizedBox(height: AppDimensions.md),
            _label('Description (optional)'),
            const SizedBox(height: 6),
            _field(_descCtrl, 'Additional details about this rule...', maxLines: 3),
            const SizedBox(height: AppDimensions.md),
            _label('Category'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.categories.map((cat) {
                final selected = _category == cat;
                return ChoiceChip(
                  label: Text(_formatCategory(cat)),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = cat),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimensions.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.sm),
                decoration: BoxDecoration(
                  color: AppColors.dangerSurface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Text(_error!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.dangerText)),
              ),
            ],
            const SizedBox(height: AppDimensions.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: AppDimensions.md),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isEdit ? 'Update Rule' : 'Add Rule'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String s) =>
      Text(s,
          style: AppTextStyles.labelLarge
              .copyWith(color: AppColors.textSecondary));

  Widget _field(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  String _formatCategory(String cat) {
    return cat
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.length < 3) {
      setState(() => _error = 'Title is required (min 3 characters).');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final desc = _descCtrl.text.trim();
    final err = await widget.onSubmit(
      title,
      desc.isEmpty ? null : desc,
      _category,
    );

    if (!mounted) return;
    if (err == null) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(widget.existing != null ? 'Rule updated.' : 'Rule added.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      setState(() {
        _submitting = false;
        _error = err;
      });
    }
  }
}
