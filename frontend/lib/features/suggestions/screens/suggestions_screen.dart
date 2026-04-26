import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/widgets/unit_picker_field.dart';
import '../../../shared/widgets/app_searchable_dropdown.dart';
import '../../../shared/utils/pick_camera_photo.dart';
import '../../../shared/widgets/show_app_sheet.dart';
import '../../members/providers/members_provider.dart';
import '../providers/suggestions_provider.dart';
import 'pay_suggestion_sheet.dart';

class SuggestionsScreen extends ConsumerStatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen> {
  String _filter = 'all';
  final ScrollController _scrollController = ScrollController();
  String? _handledFocusId;

  static const _adminRoles = {'PRAMUKH', 'CHAIRMAN', 'SECRETARY'};

  bool get _isAdmin {
    final role = ref.read(authProvider).user?.role.toUpperCase() ?? '';
    return _adminRoles.contains(role);
  }

  Color _borderColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return AppColors.info;
      case 'ASSIGNED':
        return AppColors.primary;
      case 'IN_PROGRESS':
        return AppColors.warning;
      case 'RESOLVED':
      case 'CLOSED':
        return AppColors.success;
      default:
        return AppColors.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    final focusId = GoRouterState.of(context).uri.queryParameters['focusId'];
    final state = ref.watch(suggestionsProvider);

    final statusMap = {
      'all': null,
      'open': 'OPEN',
      'assigned': 'ASSIGNED',
      'in_progress': 'IN_PROGRESS',
      'resolved': 'RESOLVED',
      'closed': 'CLOSED',
    };

    final filtered = _filter == 'all'
        ? state.suggestions
        : state.suggestions
            .where((c) => (c['status'] as String? ?? '').toUpperCase() == statusMap[_filter])
            .toList();

    if (focusId != null &&
        focusId.isNotEmpty &&
        _handledFocusId != focusId &&
        filtered.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final idx = filtered.indexWhere((c) => c['id']?.toString() == focusId);
        if (idx >= 0) {
          final target = (idx * 140.0).clamp(0.0, _scrollController.position.maxScrollExtent);
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
        setState(() => _handledFocusId = focusId);
      });
    }

    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isWide
          ? AppBar(
              backgroundColor: AppColors.primary,
              title: Text('Suggestions',
                  style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.textOnPrimary),
                  onPressed: () => ref.read(suggestionsProvider.notifier).loadSuggestions(
                      status: _filter == 'all' ? null : statusMap[_filter]),
                ),
              ],
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRaiseSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: AppColors.textOnPrimary),
        label: Text('New Suggestion',
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
                  for (final s in statusMap.keys)
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
                          ref.read(suggestionsProvider.notifier).loadSuggestions(
                              status: s == 'all' ? null : statusMap[s]);
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
                            emoji: '💡',
                            title: 'No Suggestions',
                            subtitle: 'No suggestions match the selected filter.',
                          )
                        : RefreshIndicator(
                            onRefresh: () => ref
                                .read(suggestionsProvider.notifier)
                                .loadSuggestions(
                                    status: _filter == 'all'
                                        ? null
                                        : statusMap[_filter]),
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(AppDimensions.screenPadding),
                              itemCount: filtered.length,
                              separatorBuilder: (_, i) =>
                                  const SizedBox(height: AppDimensions.sm),
                              itemBuilder: (_, i) => _SuggestionCard(
                                suggestion: filtered[i],
                                borderColor:
                                    _borderColor(filtered[i]['status'] as String? ?? ''),
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
      builder: (_) => _RaiseSuggestionSheet(
        lockUnit: lockUnit,
        preUnitId: lockUnit ? user?.unitId : null,
        preUnitCode: lockUnit ? user?.unitCode : null,
        onSubmit: (data, attachments) async {
          return await ref
              .read(suggestionsProvider.notifier)
              .createSuggestion(data, attachments: attachments);
        },
      ),
    );
  }
}

class _RaiseSuggestionSheet extends StatefulWidget {
  final Future<String?> Function(Map<String, dynamic>, List<PlatformFile>?) onSubmit;
  final bool lockUnit;
  final String? preUnitId;
  final String? preUnitCode;
  const _RaiseSuggestionSheet({
    required this.onSubmit,
    this.lockUnit = false,
    this.preUnitId,
    this.preUnitCode,
  });

  @override
  State<_RaiseSuggestionSheet> createState() => _RaiseSuggestionSheetState();
}

class _RaiseSuggestionSheetState extends State<_RaiseSuggestionSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late String? _selectedUnitId;
  late String? _selectedUnitCode;
  String _category = 'OTHER';
  String _priority = 'medium';
  bool _submitting = false;
  String? _errorMsg;
  List<PlatformFile> _attachments = [];

  @override
  void initState() {
    super.initState();
    _selectedUnitId = widget.preUnitId;
    _selectedUnitCode = widget.preUnitCode;
  }

  static const _categories = ['MAINTENANCE', 'SECURITY', 'CLEANLINESS', 'NOISE', 'PARKING', 'OTHER'];
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
            Text('New Suggestion', style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.lg),
            _label('Title'),
            const SizedBox(height: AppDimensions.xs),
            _textField(_titleCtrl, 'Enter suggestion title'),
            const SizedBox(height: AppDimensions.md),
            _label('Description'),
            const SizedBox(height: AppDimensions.xs),
            _textField(_descCtrl, 'Write your suggestion...', maxLines: 3),
            const SizedBox(height: AppDimensions.md),
            AppSearchableDropdown<String>(
              label: 'Category',
              value: _category,
              items: _categories.map((v) => AppDropdownItem(value: v, label: v)).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            if (!widget.lockUnit) ...[
              const SizedBox(height: AppDimensions.md),
              UnitPickerField(
                selectedUnitId: _selectedUnitId,
                selectedUnitCode: _selectedUnitCode,
                onChanged: (id, code) => setState(() {
                  _selectedUnitId = id;
                  _selectedUnitCode = code;
                }),
              ),
            ],
            const SizedBox(height: AppDimensions.md),
            AppSearchableDropdown<String>(
              label: 'Priority',
              value: _priority,
              items: _priorities
                  .map((v) => AppDropdownItem(value: v, label: v.toUpperCase()))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _priority = v);
              },
            ),
            const SizedBox(height: AppDimensions.md),
            _label('Attachments (Optional)'),
            const SizedBox(height: AppDimensions.xs),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.attach_file_rounded, size: 18),
                    label: const Text('Attach files'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.sm),
              Wrap(
                spacing: AppDimensions.sm,
                runSpacing: AppDimensions.sm,
                children: _attachments
                    .map((file) => Chip(
                          label: Text(file.name,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textPrimary)),
                          backgroundColor: AppColors.surfaceVariant,
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() => _attachments.remove(file)),
                        ))
                    .toList(),
              ),
            ],
            if (_errorMsg != null) ...[
              const SizedBox(height: AppDimensions.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.sm),
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

  Widget _label(String text) => Text(text,
      style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary));

  Widget _textField(TextEditingController ctrl, String hint, {int maxLines = 1}) => TextField(
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
    if (_titleCtrl.text.trim().isEmpty ||
        _descCtrl.text.trim().isEmpty ||
        _selectedUnitId == null) {
      setState(() => _errorMsg = 'Please fill in all required fields.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMsg = null;
    });
    final error = await widget.onSubmit({
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'category': _category,
      'unitId': _selectedUnitId!,
      'priority': _priority,
    }, _attachments);
    if (!mounted) return;
    if (error == null) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(
        content: Text('Suggestion submitted successfully.'),
        backgroundColor: AppColors.success,
      ));
    } else {
      setState(() {
        _submitting = false;
        _errorMsg = error;
      });
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'mp4', 'doc', 'docx'],
      withData: kIsWeb,
    );
    if (result != null && mounted) {
      setState(() {
        _attachments.addAll(result.files);
      });
    }
  }

  Future<void> _takePhoto() async {
    final x = await pickPhotoFromCamera();
    if (x == null || !mounted) return;
    final name = x.name.isNotEmpty
        ? x.name
        : 'suggestion_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = x.path;
    if (path.isNotEmpty) {
      final len = await x.length();
      setState(() {
        _attachments.add(PlatformFile(path: path, name: name, size: len));
      });
    } else {
      final bytes = await x.readAsBytes();
      setState(() {
        _attachments.add(PlatformFile(name: name, size: bytes.length, bytes: bytes));
      });
    }
  }
}

class _SuggestionCard extends ConsumerWidget {
  final Map<String, dynamic> suggestion;
  final Color borderColor;
  final bool isAdmin;
  const _SuggestionCard({required this.suggestion, required this.borderColor, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = suggestion;
    final status = s['status'] as String? ?? 'OPEN';
    final title = s['title'] as String? ?? '-';
    final category = s['category'] as String? ?? '-';
    final raisedBy = (s['raisedBy'] as Map?)?['name'] as String? ?? '-';
    final unit = (s['unit'] as Map?)?['fullCode'] as String? ?? '-';
    final assignedTo = (s['assignedTo'] as Map?)?['name'] as String?;
    final priority = s['priority'] as String? ?? 'medium';
    final createdAt = s['createdAt'] as String? ?? '';
    final id = s['id'] as String? ?? '';
    final resolutionNote = s['resolutionNote'] as String?;

    final amount = double.tryParse(s['amount']?.toString() ?? '0') ?? 0;
    final paidAmount = double.tryParse(s['paidAmount']?.toString() ?? '0') ?? 0;
    final paymentStatus = s['paymentStatus'] as String? ?? 'UNPAID';
    final isPaid = paymentStatus == 'PAID' || (amount > 0 && paidAmount >= amount);

    return GestureDetector(
      onTap: () => _showDetailSheet(context, s),
      child: AppCard(
        leftBorderColor: borderColor,
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: AppTextStyles.h3)),
                AppStatusChip(status: status.toLowerCase()),
              ],
            ),
            const SizedBox(height: AppDimensions.xs),
            Row(
              children: [
                _badge(category.toUpperCase(), AppColors.infoSurface, AppColors.info),
                const SizedBox(width: AppDimensions.sm),
                _badge(
                    (priority).toUpperCase(),
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
            if (assignedTo != null) ...[
              const SizedBox(height: AppDimensions.xs),
              Row(
                children: [
                  const Icon(Icons.assignment_ind_outlined, size: 12, color: AppColors.info),
                  const SizedBox(width: 3),
                  Text('Assigned: $assignedTo',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.info)),
                ],
              ),
            ],
            if (resolutionNote != null && resolutionNote.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 12, color: AppColors.success),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text('Note: $resolutionNote',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.successText),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
            if (amount > 0) ...[
              const SizedBox(height: AppDimensions.sm),
              const Divider(height: 1),
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Amount Due',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                      Text('₹${(amount - paidAmount).toStringAsFixed(0)}',
                          style: AppTextStyles.labelLarge.copyWith(
                              color: isPaid ? AppColors.success : AppColors.danger)),
                    ],
                  ),
                  const Spacer(),
                  if (!isPaid)
                    ElevatedButton.icon(
                      onPressed: () => showPaySuggestionSheet(context, s),
                      icon: const Icon(Icons.payment_rounded, size: 14),
                      label: const Text('PAY'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  else
                    _badge('PAID', AppColors.successSurface, AppColors.successText),
                ],
              ),
            ],
            if (isAdmin) ...[
              const SizedBox(height: AppDimensions.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _UpdateStatusButton(suggestion: s),
                  const SizedBox(width: AppDimensions.sm),
                  _DeleteButton(suggestionId: id),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context, Map<String, dynamic> s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => _SuggestionDetailSheet(suggestion: s),
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

class _SuggestionDetailSheet extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  const _SuggestionDetailSheet({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    final status = (s['status'] as String? ?? 'OPEN').toUpperCase();
    final title = s['title'] as String? ?? '-';
    final description = s['description'] as String? ?? '';
    final category = s['category'] as String? ?? '-';
    final priority = s['priority'] as String? ?? 'medium';
    final raisedBy = (s['raisedBy'] as Map?)?['name'] as String? ?? '-';
    final unit = (s['unit'] as Map?)?['fullCode'] as String? ?? '-';
    final assignedTo = (s['assignedTo'] as Map?)?['name'] as String?;
    final resolutionNote = s['resolutionNote'] as String?;
    final createdAt = s['createdAt'] as String? ?? '';
    final resolvedAt = s['resolvedAt'] as String?;
    final amount = double.tryParse(s['amount']?.toString() ?? '0') ?? 0;
    final paidAmount = double.tryParse(s['paidAmount']?.toString() ?? '0') ?? 0;
    final paymentStatus = (s['paymentStatus'] as String? ?? 'UNPAID').toUpperCase();
    final isPaid = paymentStatus == 'PAID' || (amount > 0 && paidAmount >= amount);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppDimensions.screenPadding, AppDimensions.md, AppDimensions.screenPadding, AppDimensions.xl),
        child: ListView(
          controller: ctrl,
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
            const SizedBox(height: AppDimensions.md),
            Row(
              children: [
                Expanded(child: Text(title, style: AppTextStyles.h2)),
                AppStatusChip(status: status.toLowerCase()),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            if (description.isNotEmpty) ...[
              Text('Description',
                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppDimensions.xs),
              Text(description, style: AppTextStyles.bodyMedium),
              const SizedBox(height: AppDimensions.md),
            ],
            const Divider(),
            const SizedBox(height: AppDimensions.sm),
            _row('Category', category.toUpperCase()),
            _row('Priority', priority.toUpperCase()),
            _row('Raised By', raisedBy),
            _row('Unit', unit),
            if (assignedTo != null) _row('Assigned To', assignedTo),
            _row('Raised On', createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt),
            if (resolvedAt != null)
              _row('Resolved On', resolvedAt.length >= 10 ? resolvedAt.substring(0, 10) : resolvedAt),
            if (resolutionNote != null && resolutionNote.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.md),
              const Divider(),
              const SizedBox(height: AppDimensions.sm),
              Text('Resolution Note',
                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.success)),
              const SizedBox(height: AppDimensions.xs),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.sm),
                decoration: BoxDecoration(
                  color: AppColors.successSurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Text(resolutionNote,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.successText)),
              ),
            ],
            if (amount > 0) ...[
              const SizedBox(height: AppDimensions.md),
              const Divider(),
              const SizedBox(height: AppDimensions.sm),
              Text('Payment Information',
                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppDimensions.sm),
              _row('Total Charges', '₹${amount.toStringAsFixed(2)}'),
              _row('Paid Amount', '₹${paidAmount.toStringAsFixed(2)}'),
              _row('Due Amount', '₹${(amount - paidAmount).toStringAsFixed(2)}'),
              _row('Payment Status', paymentStatus),
              if (s['paymentMethod'] != null) _row('Method', s['paymentMethod'].toString()),
              if (s['transactionId'] != null) _row('Transaction ID', s['transactionId'].toString()),
              if (s['paidAt'] != null)
                _row('Paid At', s['paidAt'].toString()),
              if (!isPaid) ...[
                const SizedBox(height: AppDimensions.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      showPaySuggestionSheet(context, s);
                    },
                    icon: const Icon(Icons.payment_rounded),
                    label: const Text('Make Payment'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
            ),
            Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
          ],
        ),
      );
}

class _UpdateStatusButton extends ConsumerWidget {
  final Map<String, dynamic> suggestion;
  const _UpdateStatusButton({required this.suggestion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStatus = (suggestion['status'] as String? ?? 'OPEN').toUpperCase();
    final nextStatuses = _nextStatuses(currentStatus);
    if (nextStatuses.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      onSelected: (newStatus) async {
        if (newStatus == 'ASSIGNED') {
          _showAssignDialog(context, ref);
        } else if (newStatus == 'RESOLVED') {
          _showResolveDialog(context, ref, newStatus);
        } else {
          final error = await ref
              .read(suggestionsProvider.notifier)
              .updateSuggestion(suggestion['id'] as String, {'status': newStatus});
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(error ?? 'Status updated.'),
              backgroundColor: error == null ? AppColors.success : AppColors.danger,
            ));
          }
        }
      },
      itemBuilder: (_) => nextStatuses
          .map((s) => PopupMenuItem(
                value: s,
                child: Text(s.replaceAll('_', ' '), style: AppTextStyles.bodyMedium),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm, vertical: AppDimensions.xs),
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
            Text('Update Status', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  void _showAssignDialog(BuildContext context, WidgetRef ref) {
    final members = ref.read(membersProvider).value ?? [];
    String? selectedId;
    String? selectedName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Assign Suggestion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select a member to assign this suggestion to:',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppDimensions.sm),
              if (members.isEmpty)
                Text('No members found.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted))
              else
                DropdownButtonFormField<String>(
                  initialValue: selectedId,
                  decoration: InputDecoration(
                    hintText: 'Choose member...',
                    hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.sm),
                  ),
                  isExpanded: true,
                  items: members
                      .map((m) => DropdownMenuItem(
                            value: m.id,
                            child: Text('${m.name} (${m.role})',
                                style: AppTextStyles.bodyMedium,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setS(() {
                      selectedId = v;
                      selectedName = members.firstWhere((m) => m.id == v).name;
                    });
                  },
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: selectedId == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      final error = await ref.read(suggestionsProvider.notifier).updateSuggestion(
                        suggestion['id'] as String,
                        {'status': 'ASSIGNED', 'assignedToId': selectedId},
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(error ?? 'Assigned to $selectedName.'),
                          backgroundColor: error == null ? AppColors.success : AppColors.danger,
                        ));
                      }
                    },
              child: Text('Assign', style: AppTextStyles.labelMedium.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showResolveDialog(BuildContext context, WidgetRef ref, String newStatus) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Suggestion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a resolution note (optional):',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppDimensions.sm),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe what decision was taken...',
                hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () async {
              Navigator.pop(ctx);
              final data = <String, dynamic>{'status': newStatus};
              if (noteCtrl.text.trim().isNotEmpty) data['resolutionNote'] = noteCtrl.text.trim();
              final error = await ref.read(suggestionsProvider.notifier).updateSuggestion(
                    suggestion['id'] as String,
                    data,
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(error ?? 'Suggestion resolved.'),
                  backgroundColor: error == null ? AppColors.success : AppColors.danger,
                ));
              }
            },
            child: Text('Resolve', style: AppTextStyles.labelMedium.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  List<String> _nextStatuses(String current) {
    switch (current) {
      case 'OPEN':
        return ['ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];
      case 'ASSIGNED':
        return ['IN_PROGRESS', 'RESOLVED', 'CLOSED'];
      case 'IN_PROGRESS':
        return ['RESOLVED', 'CLOSED'];
      case 'RESOLVED':
        return ['CLOSED'];
      default:
        return [];
    }
  }
}

class _DeleteButton extends ConsumerWidget {
  final String suggestionId;
  const _DeleteButton({required this.suggestionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _confirmDelete(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm, vertical: AppDimensions.xs),
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
      title: 'Delete Suggestion',
      message: 'Are you sure you want to delete this suggestion?',
      confirmLabel: 'Delete',
    );
    if (ok && context.mounted) {
      final error = await ref.read(suggestionsProvider.notifier).deleteSuggestion(suggestionId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error ?? 'Suggestion deleted.'),
          backgroundColor: error == null ? AppColors.success : AppColors.danger,
        ));
      }
    }
  }
}

