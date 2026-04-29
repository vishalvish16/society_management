import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../providers/notices_provider.dart';
import '../../../shared/widgets/show_app_sheet.dart';
import '../../../shared/widgets/app_date_picker.dart';
import '../../../shared/widgets/app_page_header.dart';

class NoticesScreen extends ConsumerWidget {
  const NoticesScreen({super.key});

  static const _adminRoles = {'PRAMUKH', 'CHAIRMAN', 'SECRETARY'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).user?.role.toUpperCase() ?? '';
    final isAdmin = _adminRoles.contains(role);
    final state = ref.watch(noticesProvider);

    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? AppBar(
              backgroundColor: AppColors.primary,
              title: Text('Notices',
                  style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
            )
          : null,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showNoticeSheet(context, ref, null),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: AppColors.textOnPrimary),
              label: Text('Post Notice',
                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary)),
            )
          : null,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Notices',
            icon: Icons.campaign_rounded,
            actions: isAdmin
                ? [
                    IconButton(
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'Post Notice',
                      onPressed: () => _showNoticeSheet(context, ref, null),
                    ),
                  ]
                : [],
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
                    : state.notices.isEmpty
                        ? const AppEmptyState(
                            emoji: '📢',
                            title: 'No Notices',
                            subtitle: 'No notices have been posted yet.',
                          )
                        : RefreshIndicator(
                            onRefresh: () =>
                                ref.read(noticesProvider.notifier).loadNotices(),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(AppDimensions.screenPadding),
                              itemCount: state.notices.length,
                              separatorBuilder: (_, i) =>
                                  const SizedBox(height: AppDimensions.sm),
                              itemBuilder: (_, i) => _NoticeCard(
                                notice: state.notices[i],
                                isAdmin: isAdmin,
                                onEdit: () =>
                                    _showNoticeSheet(context, ref, state.notices[i]),
                                onDelete: () =>
                                    _confirmDelete(context, ref, state.notices[i]['id'] as String? ?? ''),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  void _showNoticeSheet(
      BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showAppSheet(
      context: context,
      builder: (_) => _NoticeFormSheet(
        existing: existing,
        onSubmit: (data) async {
          if (existing != null) {
            return await ref.read(noticesProvider.notifier).updateNotice(
                existing['id'] as String, data);
          } else {
            return await ref.read(noticesProvider.notifier).createNotice(data);
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showConfirmSheet(
      context: context,
      title: 'Delete Notice',
      message: 'Are you sure you want to delete this notice?',
      confirmLabel: 'Delete',
    );
    if (ok && context.mounted) {
      final error = await ref.read(noticesProvider.notifier).deleteNotice(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error ?? 'Notice deleted.'),
          backgroundColor: error == null ? AppColors.success : AppColors.danger,
        ));
      }
    }
  }
}

// ── Notice Card ───────────────────────────────────────────────────────────────

class _NoticeCard extends StatelessWidget {
  final Map<String, dynamic> notice;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoticeCard({
    required this.notice,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final n = notice;
    final title = n['title'] as String? ?? '-';
    final body = n['body'] as String? ?? '';
    final isPinned = n['isPinned'] as bool? ?? false;
    final createdAt = n['createdAt'] as String? ?? '';
    final createdBy = (n['creator'] as Map?)?['name'] as String? ?? '-';

    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPinned) ...[
                const Icon(Icons.push_pin_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
              ],
              Expanded(child: Text(title, style: AppTextStyles.h3)),
              if (isPinned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Text('PINNED',
                      style:
                          AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                ),
              if (isAdmin) ...[
                const SizedBox(width: AppDimensions.sm),
                GestureDetector(
                  onTap: onEdit,
                  child: const Icon(Icons.edit_rounded,
                      size: 16, color: AppColors.textMuted),
                ),
                const SizedBox(width: AppDimensions.sm),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 16, color: AppColors.danger),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            body,
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Text('By $createdBy',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              const Spacer(),
              Text(
                createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Notice Form Bottom Sheet ──────────────────────────────────────────────────

class _NoticeFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final Future<String?> Function(Map<String, dynamic>) onSubmit;

  const _NoticeFormSheet({this.existing, required this.onSubmit});

  @override
  State<_NoticeFormSheet> createState() => _NoticeFormSheetState();
}

class _NoticeFormSheetState extends State<_NoticeFormSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  bool _isPinned = false;
  DateTime? _expiresAt;
  bool _submitting = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?['title'] as String? ?? '');
    _bodyCtrl = TextEditingController(text: e?['body'] as String? ?? '');
    _isPinned = e?['isPinned'] as bool? ?? false;
    final exp = e?['expiresAt'] as String?;
    if (exp != null && exp.isNotEmpty) {
      _expiresAt = DateTime.tryParse(exp);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
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
            Text(isEdit ? 'Edit Notice' : 'Post Notice', style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.lg),
            _label('Title'),
            const SizedBox(height: AppDimensions.xs),
            _textField(_titleCtrl, 'Notice title'),
            const SizedBox(height: AppDimensions.md),
            _label('Description'),
            const SizedBox(height: AppDimensions.xs),
            _textField(_bodyCtrl, 'Notice description...', maxLines: 4),
            const SizedBox(height: AppDimensions.md),
            Row(
              children: [
                Expanded(
                  child: Text('Pin this notice', style: AppTextStyles.bodyMedium),
                ),
                Switch(
                  value: _isPinned,
                  onChanged: (v) => setState(() => _isPinned = v),
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            _label('Expiry Date (optional)'),
            const SizedBox(height: AppDimensions.xs),
            AppDateField(
              label: 'Expiry Date',
              value: _expiresAt,
              clearable: true,
              onClear: () => setState(() => _expiresAt = null),
              onTap: _pickDate,
            ),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: AppDimensions.md),
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
                    : Text(isEdit ? 'Update' : 'Post',
                        style: AppTextStyles.buttonLarge),
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

  Future<void> _pickDate() async {
    final picked = await pickSingleDate(
      context,
      initial: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Title and description are required.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMsg = null;
    });
    final data = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'body': _bodyCtrl.text.trim(),
      'isPinned': _isPinned,
    };
    if (_expiresAt != null) {
      data['expiresAt'] = _expiresAt!.toIso8601String();
    }
    
    final error = await widget.onSubmit(data);
    if (mounted) {
      if (error == null) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(
          content: Text(widget.existing != null ? 'Notice updated.' : 'Notice posted.'),
          backgroundColor: AppColors.success,
        ));
      } else {
        setState(() {
          _submitting = false;
          _errorMsg = error;
        });
      }
    }
  }
}
