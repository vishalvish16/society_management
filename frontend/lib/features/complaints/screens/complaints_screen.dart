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
import '../providers/complaints_provider.dart';
import '../../../shared/widgets/unit_picker_field.dart';
import '../../../shared/widgets/app_searchable_dropdown.dart';
import '../../../shared/widgets/show_app_dialog.dart';

class ComplaintsScreen extends ConsumerStatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  ConsumerState<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends ConsumerState<ComplaintsScreen> {
  String _filter = 'all';

  static const _adminRoles = {'PRAMUKH', 'CHAIRMAN', 'SECRETARY'};

  bool get _isAdmin {
    final role = ref.read(authProvider).user?.role.toUpperCase() ?? '';
    return _adminRoles.contains(role);
  }

  Color _borderColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.danger;
      case 'in_progress':
        return AppColors.warning;
      case 'resolved':
      case 'closed':
        return AppColors.success;
      default:
        return AppColors.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(complaintsProvider);

    final filtered = _filter == 'all'
        ? state.complaints
        : state.complaints.where((c) => (c['status'] ?? '') == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Complaints',
            style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textOnPrimary),
            onPressed: () => ref.read(complaintsProvider.notifier).loadComplaints(
                status: _filter == 'all' ? null : _filter),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRaiseSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: AppColors.textOnPrimary),
        label: Text('Raise Complaint',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary)),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.screenPadding, vertical: AppDimensions.sm),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in ['all', 'open', 'in_progress', 'resolved', 'closed'])
                    Padding(
                      padding: const EdgeInsets.only(right: AppDimensions.sm),
                      child: ChoiceChip(
                        label: Text(s == 'all' ? 'All' : s.replaceAll('_', ' ').toUpperCase()),
                        selected: _filter == s,
                        selectedColor: AppColors.primarySurface,
                        labelStyle: AppTextStyles.labelMedium.copyWith(
                          color: _filter == s ? AppColors.primary : AppColors.textMuted,
                        ),
                        onSelected: (_) {
                          setState(() => _filter = s);
                          ref.read(complaintsProvider.notifier).loadComplaints(
                              status: s == 'all' ? null : s);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const AppLoadingShimmer()
                : state.error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimensions.screenPadding),
                          child: AppCard(
                            backgroundColor: AppColors.dangerSurface,
                            child: Text('Error: ${state.error}',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.dangerText)),
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? const AppEmptyState(
                            emoji: '🔧',
                            title: 'No Complaints',
                            subtitle: 'No complaints match the selected filter.',
                          )
                        : RefreshIndicator(
                            onRefresh: () => ref
                                .read(complaintsProvider.notifier)
                                .loadComplaints(status: _filter == 'all' ? null : _filter),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(AppDimensions.screenPadding),
                              itemCount: filtered.length,
                              separatorBuilder: (_, i) =>
                                  const SizedBox(height: AppDimensions.sm),
                              itemBuilder: (_, i) => _ComplaintCard(
                                complaint: filtered[i],
                                borderColor: _borderColor(
                                    filtered[i]['status'] as String? ?? ''),
                                isAdmin: _isAdmin,
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  void _showRaiseSheet(BuildContext context) {
    final user = ref.read(authProvider).user;
    final lockUnit = user?.isUnitLocked ?? false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => _RaiseComplaintSheet(
        lockUnit: lockUnit,
        preUnitId: lockUnit ? user?.unitId : null,
        preUnitCode: lockUnit ? user?.unitCode : null,
        onSubmit: (data) async {
          final ok = await ref.read(complaintsProvider.notifier).createComplaint(data);
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok ? 'Complaint raised successfully.' : 'Failed to raise complaint.'),
              backgroundColor: ok ? AppColors.success : AppColors.danger,
            ));
          }
        },
      ),
    );
  }
}

// ── Raise Complaint Bottom Sheet ──────────────────────────────────────────────

class _RaiseComplaintSheet extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final bool lockUnit;
  final String? preUnitId;
  final String? preUnitCode;
  const _RaiseComplaintSheet({
    required this.onSubmit,
    this.lockUnit = false,
    this.preUnitId,
    this.preUnitCode,
  });

  @override
  State<_RaiseComplaintSheet> createState() => _RaiseComplaintSheetState();
}

class _RaiseComplaintSheetState extends State<_RaiseComplaintSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late String? _selectedUnitId;
  late String? _selectedUnitCode;
  String _category = 'MAINTENANCE';
  String _priority = 'medium';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedUnitId = widget.preUnitId;
    _selectedUnitCode = widget.preUnitCode;
  }

  static const _categories = ['MAINTENANCE', 'SECURITY', 'CLEANLINESS', 'NOISE', 'OTHER'];
  static const _priorities = ['low', 'medium', 'high'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
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
            Text('Raise Complaint', style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.lg),
            _label('Title'),
            const SizedBox(height: AppDimensions.xs),
            _textField(_titleCtrl, 'Enter complaint title'),
            const SizedBox(height: AppDimensions.md),
            _label('Description'),
            const SizedBox(height: AppDimensions.xs),
            _textField(_descCtrl, 'Describe the issue...', maxLines: 3),
            const SizedBox(height: AppDimensions.md),
            AppSearchableDropdown<String>(
              label: 'Category',
              value: _category,
              items: _categories.map((v) => AppDropdownItem(value: v, label: v)).toList(),
              onChanged: (v) { if (v != null) setState(() => _category = v); },
            ),
            const SizedBox(height: AppDimensions.md),
            UnitPickerField(
              selectedUnitId: _selectedUnitId,
              selectedUnitCode: _selectedUnitCode,
              readOnly: widget.lockUnit,
              onChanged: (id, code) => setState(() {
                _selectedUnitId = id;
                _selectedUnitCode = code;
              }),
            ),
            const SizedBox(height: AppDimensions.md),
            AppSearchableDropdown<String>(
              label: 'Priority',
              value: _priority,
              items: _priorities.map((v) => AppDropdownItem(value: v, label: v.toUpperCase())).toList(),
              onChanged: (v) { if (v != null) setState(() => _priority = v); },
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
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.textOnPrimary),
                      )
                    : Text('Submit', style: AppTextStyles.buttonLarge),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary));

  Widget _textField(TextEditingController ctrl, String hint, {int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md, vertical: AppDimensions.md),
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


  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty || _selectedUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill in all required fields.'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    setState(() => _submitting = true);
    await widget.onSubmit({
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'category': _category,
      'unitId': _selectedUnitId!,
      'priority': _priority,
    });
    if (mounted) setState(() => _submitting = false);
  }
}

// ── Complaint Card ────────────────────────────────────────────────────────────

class _ComplaintCard extends ConsumerWidget {
  final Map<String, dynamic> complaint;
  final Color borderColor;
  final bool isAdmin;

  const _ComplaintCard({
    required this.complaint,
    required this.borderColor,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = complaint;
    final status = c['status'] as String? ?? 'open';
    final title = c['title'] as String? ?? '-';
    final category = c['category'] as String? ?? '-';
    final raisedBy = (c['raisedBy'] as Map?)?['name'] as String? ?? '-';
    final unit = (c['unit'] as Map?)?['fullCode'] as String? ?? '-';
    final priority = c['priority'] as String? ?? 'medium';
    final createdAt = c['createdAt'] as String? ?? '';
    final id = c['id'] as String? ?? '';

    return AppCard(
      leftBorderColor: borderColor,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTextStyles.h3)),
              AppStatusChip(status: status),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Row(
            children: [
              _badge(category.toUpperCase(), AppColors.infoSurface, AppColors.info),
              const SizedBox(width: AppDimensions.sm),
              _badge(priority.toUpperCase(),
                  priority == 'high'
                      ? AppColors.dangerSurface
                      : priority == 'medium'
                          ? AppColors.warningSurface
                          : AppColors.successSurface,
                  priority == 'high'
                      ? AppColors.dangerText
                      : priority == 'medium'
                          ? AppColors.warningText
                          : AppColors.successText),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Text(raisedBy, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
              const SizedBox(width: AppDimensions.sm),
              const Icon(Icons.home_outlined, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Text(unit, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
              const Spacer(),
              Text(
                createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt,
                style: AppTextStyles.caption,
              ),
            ],
          ),
          if (isAdmin) ...[
            const SizedBox(height: AppDimensions.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _UpdateStatusButton(complaintId: id, currentStatus: status),
                const SizedBox(width: AppDimensions.sm),
                _DeleteButton(complaintId: id),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: fg)),
      );
}

class _UpdateStatusButton extends ConsumerWidget {
  final String complaintId;
  final String currentStatus;
  const _UpdateStatusButton({required this.complaintId, required this.currentStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextStatuses = _nextStatuses(currentStatus);
    if (nextStatuses.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      onSelected: (newStatus) async {
        final ok = await ref
            .read(complaintsProvider.notifier)
            .updateComplaint(complaintId, {'status': newStatus});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok ? 'Status updated.' : 'Failed to update status.'),
            backgroundColor: ok ? AppColors.success : AppColors.danger,
          ));
        }
      },
      itemBuilder: (_) => nextStatuses
          .map((s) => PopupMenuItem(
                value: s,
                child: Text(s.replaceAll('_', ' ').toUpperCase(),
                    style: AppTextStyles.bodyMedium),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.sm, vertical: AppDimensions.xs),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_rounded, size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text('Update Status',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  List<String> _nextStatuses(String current) {
    switch (current) {
      case 'open':
        return ['in_progress', 'resolved', 'closed'];
      case 'in_progress':
        return ['resolved', 'closed'];
      case 'resolved':
        return ['closed'];
      default:
        return [];
    }
  }
}

class _DeleteButton extends ConsumerWidget {
  final String complaintId;
  const _DeleteButton({required this.complaintId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _confirmDelete(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.sm, vertical: AppDimensions.xs),
        decoration: BoxDecoration(
          color: AppColors.dangerSurface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: AppColors.danger),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_outline_rounded, size: 12, color: AppColors.danger),
            const SizedBox(width: 4),
            Text('Delete', style: AppTextStyles.labelSmall.copyWith(color: AppColors.danger)),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmSheet(
      context: context,
      title: 'Delete Complaint',
      message: 'Are you sure you want to delete this complaint?',
      confirmLabel: 'Delete',
    );
    if (ok && context.mounted) {
      final success = await ref.read(complaintsProvider.notifier).deleteComplaint(complaintId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Complaint deleted.' : 'Failed to delete complaint.'),
          backgroundColor: success ? AppColors.success : AppColors.danger,
        ));
      }
    }
  }
}
