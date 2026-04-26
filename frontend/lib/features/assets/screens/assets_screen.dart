import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/widgets/show_app_sheet.dart';
import '../providers/assets_provider.dart';

const _categories = [
  'FURNITURE', 'ELECTRONICS', 'PLUMBING', 'ELECTRICAL', 'SECURITY',
  'FIRE_SAFETY', 'ELEVATOR', 'HVAC', 'GARDEN', 'SPORTS', 'CLEANING', 'OTHER',
];

const _statuses = ['ACTIVE', 'INACTIVE', 'UNDER_MAINTENANCE', 'DISPOSED', 'LOST'];
const _conditions = ['NEW', 'GOOD', 'FAIR', 'POOR', 'DAMAGED'];

const _adminRoles = {'PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'VICE_CHAIRMAN', 'TREASURER'};

IconData _categoryIcon(String cat) {
  switch (cat.toUpperCase()) {
    case 'FURNITURE': return Icons.chair_rounded;
    case 'ELECTRONICS': return Icons.devices_rounded;
    case 'PLUMBING': return Icons.plumbing_rounded;
    case 'ELECTRICAL': return Icons.electrical_services_rounded;
    case 'SECURITY': return Icons.security_rounded;
    case 'FIRE_SAFETY': return Icons.local_fire_department_rounded;
    case 'ELEVATOR': return Icons.elevator_rounded;
    case 'HVAC': return Icons.ac_unit_rounded;
    case 'GARDEN': return Icons.park_rounded;
    case 'SPORTS': return Icons.sports_tennis_rounded;
    case 'CLEANING': return Icons.cleaning_services_rounded;
    default: return Icons.inventory_2_rounded;
  }
}

Color _statusColor(String s) {
  switch (s.toUpperCase()) {
    case 'ACTIVE': return AppColors.success;
    case 'INACTIVE': return AppColors.textMuted;
    case 'UNDER_MAINTENANCE': return AppColors.warning;
    case 'DISPOSED': return AppColors.danger;
    case 'LOST': return AppColors.danger;
    default: return AppColors.info;
  }
}

class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  String? _filterCategory;
  String? _filterStatus;
  final _searchCtrl = TextEditingController();

  bool _isAdmin(String? role) => _adminRoles.contains((role ?? '').toUpperCase());

  void _applyFilters() {
    final filters = <String, String>{};
    if (_filterCategory != null) filters['category'] = _filterCategory!;
    if (_filterStatus != null) filters['status'] = _filterStatus!;
    if (_searchCtrl.text.trim().isNotEmpty) filters['search'] = _searchCtrl.text.trim();
    ref.read(assetsProvider.notifier).refresh(filters: filters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.role;
    final isAdmin = _isAdmin(role);
    final st = ref.watch(assetsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Assets', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _applyFilters,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
          if (isAdmin)
            IconButton(
              tooltip: 'Add asset',
              onPressed: () => _showAssetSheet(context, ref),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(assetsProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          children: [
            if (isAdmin && st.summary != null) _buildSummary(st.summary!),
            if (isAdmin && st.summary != null) const SizedBox(height: AppDimensions.lg),
            _buildFilters(),
            const SizedBox(height: AppDimensions.lg),
            if (st.isLoading)
              const AppLoadingShimmer()
            else if (st.error != null)
              Center(child: Text(st.error!, style: TextStyle(color: AppColors.danger)))
            else if (st.assets.isEmpty)
              AppEmptyState(
                emoji: '\u{1F4E6}',
                title: 'No assets found',
                subtitle: isAdmin
                    ? 'Add your first society asset to start tracking.'
                    : 'No assets have been registered yet.',
                actionLabel: isAdmin ? 'Add Asset' : null,
                onAction: isAdmin ? () => _showAssetSheet(context, ref) : null,
              )
            else
              ...st.assets.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.md),
                child: _AssetCard(
                  asset: a,
                  isAdmin: isAdmin,
                  onTap: () => _showDetailSheet(context, ref, a['id']),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(Map<String, dynamic> summary) {
    final totalValue = summary['totalValue'] as Map<String, dynamic>? ?? {};
    final totalCount = totalValue['_count']?['id'] ?? 0;
    final sumPrice = totalValue['_sum']?['purchasePrice'];
    final warrantyExpiring = summary['warrantyExpiring'] ?? 0;

    final byStatus = (summary['byStatus'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final activeCount = byStatus.where((s) => s['status'] == 'ACTIVE').fold<int>(0, (p, s) => p + ((s['_count']?['id'] ?? 0) as int));
    final maintenanceCount = byStatus.where((s) => s['status'] == 'UNDER_MAINTENANCE').fold<int>(0, (p, s) => p + ((s['_count']?['id'] ?? 0) as int));

    return Row(
      children: [
        _SummaryChip(label: 'Total', value: '$totalCount', color: AppColors.primary),
        const SizedBox(width: AppDimensions.sm),
        _SummaryChip(label: 'Active', value: '$activeCount', color: AppColors.success),
        const SizedBox(width: AppDimensions.sm),
        _SummaryChip(label: 'Maintenance', value: '$maintenanceCount', color: AppColors.warning),
        const SizedBox(width: AppDimensions.sm),
        _SummaryChip(label: 'Warranty Soon', value: '$warrantyExpiring', color: AppColors.danger),
        if (sumPrice != null) ...[
          const SizedBox(width: AppDimensions.sm),
          _SummaryChip(
            label: 'Value',
            value: '\u20B9${NumberFormat('#,##0').format(double.tryParse(sumPrice.toString()) ?? 0)}',
            color: AppColors.info,
          ),
        ],
      ].map((w) => Expanded(child: w)).toList(),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: AppDimensions.sm,
      runSpacing: AppDimensions.sm,
      children: [
        SizedBox(
          width: 200,
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search assets...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
            ),
            onSubmitted: (_) => _applyFilters(),
          ),
        ),
        _FilterChip(
          label: _filterCategory ?? 'Category',
          isActive: _filterCategory != null,
          items: _categories,
          onSelected: (v) { setState(() => _filterCategory = v); _applyFilters(); },
          onClear: () { setState(() => _filterCategory = null); _applyFilters(); },
        ),
        _FilterChip(
          label: _filterStatus ?? 'Status',
          isActive: _filterStatus != null,
          items: _statuses,
          onSelected: (v) { setState(() => _filterStatus = v); _applyFilters(); },
          onClear: () { setState(() => _filterStatus = null); _applyFilters(); },
        ),
      ],
    );
  }

  void _showAssetSheet(BuildContext context, WidgetRef ref, [Map<String, dynamic>? existing]) {
    showAppSheet(
      context: context,
      builder: (_) => _AssetFormSheet(existing: existing),
    );
  }

  void _showDetailSheet(BuildContext context, WidgetRef ref, String assetId) {
    showAppSheet(
      context: context,
      builder: (_) => _AssetDetailSheet(assetId: assetId),
    );
  }
}

// ── Summary Chip ───────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.h2.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ── Filter Chip ────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final List<String> items;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.items,
    required this.onSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (_) => [
        if (isActive)
          const PopupMenuItem(value: '__clear__', child: Text('Clear filter', style: TextStyle(color: AppColors.danger))),
        ...items.map((i) => PopupMenuItem(value: i, child: Text(i.replaceAll('_', ' ')))),
      ],
      child: Chip(
        label: Text(
          label.replaceAll('_', ' '),
          style: TextStyle(fontSize: 12, color: isActive ? Colors.white : AppColors.textSecondary),
        ),
        backgroundColor: isActive ? AppColors.primary : AppColors.surfaceVariant,
        deleteIcon: isActive ? const Icon(Icons.close, size: 14, color: Colors.white) : null,
        onDeleted: isActive ? onClear : null,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}

// ── Asset Card ─────────────────────────────────────────────────────────

class _AssetCard extends StatelessWidget {
  final Map<String, dynamic> asset;
  final bool isAdmin;
  final VoidCallback onTap;

  const _AssetCard({required this.asset, required this.isAdmin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = (asset['status'] ?? 'ACTIVE').toString();
    final category = (asset['category'] ?? 'OTHER').toString();
    final condition = (asset['condition'] ?? '').toString();
    final tag = asset['assetTag']?.toString();
    final location = asset['location']?.toString();
    final unit = asset['unit'] as Map<String, dynamic>?;
    final warrantyExpiry = asset['warrantyExpiry']?.toString();
    final purchasePrice = asset['purchasePrice'];
    final maintenanceCount = asset['_count']?['maintenanceLogs'] ?? 0;

    bool warrantyExpiring = false;
    if (warrantyExpiry != null) {
      final expDate = DateTime.tryParse(warrantyExpiry);
      if (expDate != null) {
        warrantyExpiring = expDate.isAfter(DateTime.now()) &&
            expDate.isBefore(DateTime.now().add(const Duration(days: 30)));
      }
    }

    return AppCard(
      leftBorderColor: _statusColor(status),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_categoryIcon(category), size: 18, color: _statusColor(status)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset['name'] ?? '', style: AppTextStyles.h3),
                    const SizedBox(height: 2),
                    Text(
                      category.replaceAll('_', ' '),
                      style: AppTextStyles.bodySmallMuted,
                    ),
                  ],
                ),
              ),
              AppStatusChip(status: status),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Wrap(
            spacing: AppDimensions.lg,
            runSpacing: AppDimensions.xs,
            children: [
              if (tag != null && tag.isNotEmpty)
                _InfoPill(icon: Icons.qr_code_2_rounded, text: tag),
              if (location != null && location.isNotEmpty)
                _InfoPill(icon: Icons.location_on_outlined, text: location),
              if (unit != null)
                _InfoPill(icon: Icons.apartment_rounded, text: unit['fullCode'] ?? ''),
              if (condition.isNotEmpty)
                _InfoPill(icon: Icons.star_outline_rounded, text: condition),
              if (purchasePrice != null)
                _InfoPill(
                  icon: Icons.currency_rupee_rounded,
                  text: NumberFormat('#,##0').format(double.tryParse(purchasePrice.toString()) ?? 0),
                ),
              if (maintenanceCount > 0)
                _InfoPill(icon: Icons.build_rounded, text: '$maintenanceCount logs'),
              if (warrantyExpiring)
                _InfoPill(icon: Icons.warning_amber_rounded, text: 'Warranty expiring!', color: AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InfoPill({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color ?? AppColors.textMuted),
        const SizedBox(width: 3),
        Text(text, style: AppTextStyles.caption.copyWith(color: color ?? AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}

// ── Asset Form Sheet (Add / Edit) ──────────────────────────────────────

class _AssetFormSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  const _AssetFormSheet({this.existing});

  @override
  ConsumerState<_AssetFormSheet> createState() => _AssetFormSheetState();
}

class _AssetFormSheetState extends ConsumerState<_AssetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _tagCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _floorCtrl;
  late final TextEditingController _vendorCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _priceCtrl;
  String _category = 'OTHER';
  String _condition = 'NEW';
  String _status = 'ACTIVE';
  DateTime? _purchaseDate;
  DateTime? _warrantyExpiry;
  final List<File> _files = [];
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?['name'] ?? '');
    _tagCtrl = TextEditingController(text: e?['assetTag'] ?? '');
    _descCtrl = TextEditingController(text: e?['description'] ?? '');
    _locationCtrl = TextEditingController(text: e?['location'] ?? '');
    _floorCtrl = TextEditingController(text: e?['floor'] ?? '');
    _vendorCtrl = TextEditingController(text: e?['vendor'] ?? '');
    _serialCtrl = TextEditingController(text: e?['serialNumber'] ?? '');
    _priceCtrl = TextEditingController(text: e?['purchasePrice']?.toString() ?? '');
    _category = (e?['category'] ?? 'OTHER').toString().toUpperCase();
    _condition = (e?['condition'] ?? 'NEW').toString().toUpperCase();
    _status = (e?['status'] ?? 'ACTIVE').toString().toUpperCase();
    if (e?['purchaseDate'] != null) _purchaseDate = DateTime.tryParse(e!['purchaseDate']);
    if (e?['warrantyExpiry'] != null) _warrantyExpiry = DateTime.tryParse(e!['warrantyExpiry']);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tagCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _floorCtrl.dispose();
    _vendorCtrl.dispose();
    _serialCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isWarranty) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isWarranty ? _warrantyExpiry : _purchaseDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      setState(() {
        if (isWarranty) { _warrantyExpiry = picked; } else { _purchaseDate = picked; }
      });
    }
  }

  Future<void> _pickFiles() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() => _files.addAll(images.map((x) => File(x.path))));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'category': _category,
      'assetTag': _tagCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'floor': _floorCtrl.text.trim(),
      'vendor': _vendorCtrl.text.trim(),
      'serialNumber': _serialCtrl.text.trim(),
      'purchasePrice': _priceCtrl.text.trim(),
      'condition': _condition,
      'status': _status,
      if (_purchaseDate != null) 'purchaseDate': _purchaseDate!.toIso8601String(),
      if (_warrantyExpiry != null) 'warrantyExpiry': _warrantyExpiry!.toIso8601String(),
    };

    final notifier = ref.read(assetsProvider.notifier);
    final err = _isEdit
        ? await notifier.updateAsset(widget.existing!['id'], data, files: _files.isNotEmpty ? _files : null)
        : await notifier.createAsset(data, files: _files.isNotEmpty ? _files : null);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (err == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Asset updated' : 'Asset created'), backgroundColor: AppColors.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 8),
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(_isEdit ? Icons.edit_rounded : Icons.add_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(_isEdit ? 'Edit Asset' : 'Add Asset', style: AppTextStyles.h1),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(AppDimensions.screenPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionHeader(title: 'Basic Info'),
                      const SizedBox(height: AppDimensions.sm),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Asset Name *', prefixIcon: Icon(Icons.inventory_2_outlined)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: AppDimensions.md),
                      DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(labelText: 'Category *', prefixIcon: Icon(Icons.category_outlined)),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' ')))).toList(),
                        onChanged: (v) => setState(() => _category = v ?? 'OTHER'),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      TextFormField(
                        controller: _tagCtrl,
                        decoration: const InputDecoration(labelText: 'Asset Tag / ID', prefixIcon: Icon(Icons.qr_code_2_outlined), hintText: 'e.g. AST-0001'),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      TextFormField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes_rounded)),
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppDimensions.xl),
                      _SectionHeader(title: 'Location'),
                      const SizedBox(height: AppDimensions.sm),
                      TextFormField(
                        controller: _locationCtrl,
                        decoration: const InputDecoration(labelText: 'Location / Block / Building', prefixIcon: Icon(Icons.location_on_outlined)),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      TextFormField(
                        controller: _floorCtrl,
                        decoration: const InputDecoration(labelText: 'Floor', prefixIcon: Icon(Icons.layers_outlined)),
                      ),
                      const SizedBox(height: AppDimensions.xl),
                      _SectionHeader(title: 'Purchase & Warranty'),
                      const SizedBox(height: AppDimensions.sm),
                      TextFormField(
                        controller: _vendorCtrl,
                        decoration: const InputDecoration(labelText: 'Vendor / Supplier', prefixIcon: Icon(Icons.store_outlined)),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      TextFormField(
                        controller: _serialCtrl,
                        decoration: const InputDecoration(labelText: 'Serial Number', prefixIcon: Icon(Icons.pin_outlined)),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      TextFormField(
                        controller: _priceCtrl,
                        decoration: const InputDecoration(labelText: 'Purchase Price (\u20B9)', prefixIcon: Icon(Icons.currency_rupee_rounded)),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppDimensions.md),
                      Row(
                        children: [
                          Expanded(
                            child: _DatePickerTile(
                              label: 'Purchase Date',
                              value: _purchaseDate != null ? dateFmt.format(_purchaseDate!) : null,
                              onTap: () => _pickDate(false),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.md),
                          Expanded(
                            child: _DatePickerTile(
                              label: 'Warranty Expiry',
                              value: _warrantyExpiry != null ? dateFmt.format(_warrantyExpiry!) : null,
                              onTap: () => _pickDate(true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.xl),
                      _SectionHeader(title: 'Condition & Status'),
                      const SizedBox(height: AppDimensions.sm),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _condition,
                              decoration: const InputDecoration(labelText: 'Condition'),
                              items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) => setState(() => _condition = v ?? 'NEW'),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.md),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _status,
                              decoration: const InputDecoration(labelText: 'Status'),
                              items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ')))).toList(),
                              onChanged: (v) => setState(() => _status = v ?? 'ACTIVE'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.xl),
                      _SectionHeader(title: 'Attachments'),
                      const SizedBox(height: AppDimensions.sm),
                      OutlinedButton.icon(
                        onPressed: _pickFiles,
                        icon: const Icon(Icons.attach_file_rounded),
                        label: Text('Pick photos (${_files.length} selected)'),
                      ),
                      if (_files.isNotEmpty) ...[
                        const SizedBox(height: AppDimensions.sm),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _files.asMap().entries.map((entry) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(entry.value, width: 60, height: 60, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: -4, right: -4,
                                child: GestureDetector(
                                  onTap: () => setState(() => _files.removeAt(entry.key)),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          )).toList(),
                        ),
                      ],
                      const SizedBox(height: AppDimensions.xxl),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _submitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_isEdit ? 'Update Asset' : 'Create Asset', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: AppDimensions.lg),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date Picker Tile ───────────────────────────────────────────────────

class _DatePickerTile extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _DatePickerTile({required this.label, this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
        ),
        child: Text(
          value ?? 'Select',
          style: TextStyle(color: value != null ? AppColors.textPrimary : AppColors.textMuted, fontSize: 13),
        ),
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.h2.copyWith(fontSize: 14, color: AppColors.primary));
  }
}

// ── Asset Detail Sheet ─────────────────────────────────────────────────

class _AssetDetailSheet extends ConsumerStatefulWidget {
  final String assetId;
  const _AssetDetailSheet({required this.assetId});

  @override
  ConsumerState<_AssetDetailSheet> createState() => _AssetDetailSheetState();
}

class _AssetDetailSheetState extends ConsumerState<_AssetDetailSheet> {
  Map<String, dynamic>? _asset;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await ref.read(assetsProvider.notifier).getAsset(widget.assetId);
    if (mounted) setState(() { _asset = a; _loading = false; });
  }

  bool get _isAdmin => _adminRoles.contains((ref.read(authProvider).user?.role ?? '').toUpperCase());

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_asset == null) {
          return const Center(child: Text('Asset not found'));
        }
        final a = _asset!;
        final attachments = (a['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final logs = (a['maintenanceLogs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final status = (a['status'] ?? 'ACTIVE').toString();
        final category = (a['category'] ?? 'OTHER').toString();

        return Column(
          children: [
            const SizedBox(height: 8),
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_categoryIcon(category), color: _statusColor(status)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a['name'] ?? '', style: AppTextStyles.h1),
                        Text(category.replaceAll('_', ' '), style: AppTextStyles.bodySmallMuted),
                      ],
                    ),
                  ),
                  AppStatusChip(status: status),
                  if (_isAdmin) ...[
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'edit') {
                          Navigator.pop(context);
                          await Future.delayed(const Duration(milliseconds: 200));
                          if (context.mounted) {
                            showAppSheet(context: context, builder: (_) => _AssetFormSheet(existing: a));
                          }
                        } else if (action == 'delete') {
                          final confirm = await showConfirmSheet(
                            context: context, title: 'Delete Asset',
                            message: 'Are you sure you want to delete "${a['name']}"?',
                            confirmLabel: 'Delete', confirmColor: AppColors.danger,
                          );
                          if (confirm && context.mounted) {
                            final err = await ref.read(assetsProvider.notifier).deleteAsset(a['id']);
                            if (context.mounted) {
                              Navigator.pop(context);
                              if (err != null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: AppColors.danger));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Asset deleted'), backgroundColor: AppColors.success));
                              }
                            }
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'), dense: true)),
                        const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: AppColors.danger), title: Text('Delete', style: TextStyle(color: AppColors.danger)), dense: true)),
                      ],
                    ),
                  ] else
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(AppDimensions.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (a['description'] != null && (a['description'] as String).isNotEmpty) ...[
                      Text(a['description'], style: AppTextStyles.bodyMedium),
                      const SizedBox(height: AppDimensions.lg),
                    ],
                    _DetailGrid(asset: a),
                    const SizedBox(height: AppDimensions.xl),

                    // Attachments
                    if (attachments.isNotEmpty) ...[
                      _SectionHeader(title: 'Attachments (${attachments.length})'),
                      const SizedBox(height: AppDimensions.sm),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: attachments.map((att) {
                          final url = AppConstants.uploadUrlFromPath(att['fileUrl']);
                          final isImage = (att['fileType'] ?? '').toString().startsWith('image/');
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: isImage && url != null
                                    ? Image.network(url, width: 80, height: 80, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _filePlaceholder(att))
                                    : _filePlaceholder(att),
                              ),
                              if (_isAdmin)
                                Positioned(
                                  top: 0, right: 0,
                                  child: GestureDetector(
                                    onTap: () async {
                                      await ref.read(assetsProvider.notifier).deleteAttachment(a['id'], att['id']);
                                      _load();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppDimensions.xl),
                    ],

                    // Maintenance Logs
                    Row(
                      children: [
                        _SectionHeader(title: 'Maintenance Log (${logs.length})'),
                        const Spacer(),
                        if (_isAdmin)
                          TextButton.icon(
                            onPressed: () => _showMaintenanceLogSheet(context, a['id']),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add'),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    if (logs.isEmpty)
                      Text('No maintenance logs yet.', style: AppTextStyles.bodySmallMuted)
                    else
                      ...logs.map((log) => Padding(
                        padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(log['title'] ?? '', style: AppTextStyles.h3)),
                                  if (log['cost'] != null)
                                    Text(
                                      '\u20B9${NumberFormat('#,##0').format(double.tryParse(log['cost'].toString()) ?? 0)}',
                                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
                                    ),
                                ],
                              ),
                              if (log['description'] != null && (log['description'] as String).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(log['description'], style: AppTextStyles.bodySmallMuted),
                                ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.person_outline, size: 12, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(log['loggedBy']?['name'] ?? '', style: AppTextStyles.caption),
                                  const Spacer(),
                                  Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    log['performedAt'] != null ? dateFmt.format(DateTime.parse(log['performedAt'])) : '',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )),
                    const SizedBox(height: AppDimensions.xxxl),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _filePlaceholder(Map<String, dynamic> att) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insert_drive_file_outlined, color: AppColors.textMuted),
          Text(
            (att['fileName'] ?? '').toString().length > 10
                ? '${(att['fileName'] as String).substring(0, 10)}...'
                : att['fileName'] ?? '',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showMaintenanceLogSheet(BuildContext ctx, String assetId) {
    showAppSheet(
      context: ctx,
      builder: (_) => _MaintenanceLogSheet(assetId: assetId, onAdded: _load),
    );
  }
}

// ── Detail Grid ────────────────────────────────────────────────────────

class _DetailGrid extends StatelessWidget {
  final Map<String, dynamic> asset;
  const _DetailGrid({required this.asset});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');
    final unit = asset['unit'] as Map<String, dynamic>?;
    final creator = asset['creator'] as Map<String, dynamic>?;

    final rows = <_DetailRow>[
      if (asset['assetTag'] != null) _DetailRow('Asset Tag', asset['assetTag']),
      _DetailRow('Category', (asset['category'] ?? '').toString().replaceAll('_', ' ')),
      _DetailRow('Condition', (asset['condition'] ?? '').toString()),
      _DetailRow('Status', (asset['status'] ?? '').toString().replaceAll('_', ' ')),
      if (asset['location'] != null) _DetailRow('Location', asset['location']),
      if (asset['floor'] != null) _DetailRow('Floor', asset['floor']),
      if (unit != null) _DetailRow('Unit', unit['fullCode'] ?? ''),
      if (asset['vendor'] != null) _DetailRow('Vendor', asset['vendor']),
      if (asset['serialNumber'] != null) _DetailRow('Serial No.', asset['serialNumber']),
      if (asset['purchaseDate'] != null)
        _DetailRow('Purchase Date', dateFmt.format(DateTime.parse(asset['purchaseDate']))),
      if (asset['purchasePrice'] != null)
        _DetailRow('Purchase Price', '\u20B9${NumberFormat('#,##0').format(double.tryParse(asset['purchasePrice'].toString()) ?? 0)}'),
      if (asset['warrantyExpiry'] != null)
        _DetailRow('Warranty Expiry', dateFmt.format(DateTime.parse(asset['warrantyExpiry']))),
      if (creator != null) _DetailRow('Added By', creator['name'] ?? ''),
      if (asset['createdAt'] != null)
        _DetailRow('Created', dateFmt.format(DateTime.parse(asset['createdAt']))),
    ];

    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final r = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(r.label, style: AppTextStyles.bodySmallMuted)),
                    Expanded(flex: 3, child: Text(r.value, style: AppTextStyles.h3)),
                  ],
                ),
              ),
              if (entry.key < rows.length - 1) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DetailRow {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);
}

// ── Maintenance Log Sheet ──────────────────────────────────────────────

class _MaintenanceLogSheet extends ConsumerStatefulWidget {
  final String assetId;
  final VoidCallback onAdded;
  const _MaintenanceLogSheet({required this.assetId, required this.onAdded});

  @override
  ConsumerState<_MaintenanceLogSheet> createState() => _MaintenanceLogSheetState();
}

class _MaintenanceLogSheetState extends ConsumerState<_MaintenanceLogSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  DateTime _performedAt = DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);

    final err = await ref.read(assetsProvider.notifier).addMaintenanceLog(
      widget.assetId,
      {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'cost': _costCtrl.text.trim(),
        'performedAt': _performedAt.toIso8601String(),
      },
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (err == null) {
      Navigator.pop(context);
      widget.onAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maintenance log added'), backgroundColor: AppColors.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.screenPadding, AppDimensions.lg,
        AppDimensions.screenPadding,
        AppDimensions.xxxl + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: AppDimensions.lg),
          Text('Add Maintenance Log', style: AppTextStyles.h1),
          const SizedBox(height: AppDimensions.lg),
          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Title *', prefixIcon: Icon(Icons.build_outlined)),
          ),
          const SizedBox(height: AppDimensions.md),
          TextFormField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes_rounded)),
            maxLines: 2,
          ),
          const SizedBox(height: AppDimensions.md),
          TextFormField(
            controller: _costCtrl,
            decoration: const InputDecoration(labelText: 'Cost (\u20B9)', prefixIcon: Icon(Icons.currency_rupee_rounded)),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppDimensions.md),
          _DatePickerTile(
            label: 'Performed At',
            value: dateFmt.format(_performedAt),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _performedAt, firstDate: DateTime(2000), lastDate: DateTime.now());
              if (d != null) setState(() => _performedAt = d);
            },
          ),
          const SizedBox(height: AppDimensions.xxl),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Add Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
