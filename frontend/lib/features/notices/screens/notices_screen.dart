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
import '../../../shared/widgets/show_app_dialog.dart';

class NoticesScreen extends ConsumerWidget {
  const NoticesScreen({super.key});

  static const _adminRoles = {'PRAMUKH', 'CHAIRMAN', 'SECRETARY'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).user?.role.toUpperCase() ?? '';
    final isAdmin = _adminRoles.contains(role);
    final state = ref.watch(noticesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Notices',
            style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showNoticeSheet(context, ref, null),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: AppColors.textOnPrimary),
              label: Text('Post Notice',
                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary)),
            )
          : null,
      body: state.isLoading
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
    );
  }

  void _showNoticeSheet(
      BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => _NoticeFormSheet(
        existing: existing,
        onSubmit: (data) async {
          bool ok;
          if (existing != null) {
            ok = await ref.read(noticesProvider.notifier).updateNotice(
                existing['id'] as String, data);
          } else {
            ok = await ref.read(noticesProvider.notifier).createNotice(data);
          }
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok
                  ? (existing != null ? 'Notice updated.' : 'Notice posted.')
                  : 'Failed to save notice.'),
              backgroundColor: ok ? AppColors.success : AppColors.danger,
            ));
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
      final success = await ref.read(noticesProvider.notifier).deleteNotice(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Notice deleted.' : 'Failed to delete notice.'),
          backgroundColor: success ? AppColors.success : AppColors.danger,
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
    final createdBy = (n['createdBy'] as Map?)?['name'] as String? ?? '-';

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
  final Future<void> Function(Map<String, dynamic>) onSubmit;

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
            _label('Body'),
            const SizedBox(height: AppDimensions.xs),
            _textField(_bodyCtrl, 'Notice content...', maxLines: 4),
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
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md, vertical: AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 16, color: AppColors.textMuted),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(
                        _expiresAt != null
                            ? '${_expiresAt!.year}-${_expiresAt!.month.toString().padLeft(2, '0')}-${_expiresAt!.day.toString().padLeft(2, '0')}'
                            : 'No expiry',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: _expiresAt != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    if (_expiresAt != null)
                      GestureDetector(
                        onTap: () => setState(() => _expiresAt = null),
                        child: const Icon(Icons.clear_rounded,
                            size: 16, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
            ),
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Title and body are required.'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    setState(() => _submitting = true);
    final data = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'body': _bodyCtrl.text.trim(),
      'isPinned': _isPinned,
    };
    if (_expiresAt != null) {
      data['expiresAt'] = _expiresAt!.toIso8601String();
    }
    await widget.onSubmit(data);
    if (mounted) setState(() => _submitting = false);
  }
}
