import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/utils/pick_camera_photo.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../providers/expense_provider.dart';
import '../../../shared/widgets/app_searchable_dropdown.dart';
import '../../../shared/widgets/show_app_sheet.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _statusFilter = 'all';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(expensesProvider.notifier).loadNextPage();
    }
  }

  Color _borderColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.role ?? '';
    final isAdmin =
        role == 'CHAIRMAN' ||
        role == 'SECRETARY' ||
        role == 'WATCHMAN' ||
        role == 'PRAMUKH';
    final expensesAsync = ref.watch(expensesProvider);
    final notifier = ref.read(expensesProvider.notifier);
    final fmt = NumberFormat('#,##0');

    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isWide
          ? AppBar(
              backgroundColor: AppColors.primary,
              title: Text(
                'Expenses',
                style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary),
              ),
            )
          : null,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: AppColors.textOnPrimary),
              label: Text(
                'Add Expense',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.screenPadding,
              vertical: AppDimensions.sm,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in ['all', 'pending', 'approved', 'rejected'])
                    Padding(
                      padding: const EdgeInsets.only(right: AppDimensions.sm),
                      child: ChoiceChip(
                        label: Text(
                          s == 'all'
                              ? 'All'
                              : s[0].toUpperCase() + s.substring(1),
                        ),
                        selected: _statusFilter == s,
                        selectedColor: AppColors.primarySurface,
                        labelStyle: AppTextStyles.labelMedium.copyWith(
                          color: _statusFilter == s
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                        onSelected: (_) => setState(() => _statusFilter = s),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: expensesAsync.when(
              loading: () => const AppLoadingShimmer(),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.screenPadding),
                  child: AppCard(
                    backgroundColor: AppColors.dangerSurface,
                    child: Text(
                      'Error: $e',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.dangerText,
                      ),
                    ),
                  ),
                ),
              ),
              data: (expenses) {
                final filtered = _statusFilter == 'all'
                    ? expenses
                    : expenses
                          .where(
                            (e) =>
                                (e['status'] as String? ?? '').toLowerCase() ==
                                _statusFilter,
                          )
                          .toList();
                if (filtered.isEmpty) {
                  return const AppEmptyState(
                    emoji: '💰',
                    title: 'No Expenses',
                    subtitle: 'No expenses match the selected filter.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.read(expensesProvider.notifier).fetchExpenses(),
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppDimensions.screenPadding),
                    itemCount: filtered.length + (notifier.hasMore ? 1 : 0),
                    separatorBuilder: (_, index) =>
                        const SizedBox(height: AppDimensions.sm),
                    itemBuilder: (_, i) {
                      if (i == filtered.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppDimensions.md,
                            ),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final ex = filtered[i];
                      final status = (ex['status'] as String? ?? 'pending')
                          .toLowerCase();
                      final amount =
                          double.tryParse(
                            ex['totalAmount']?.toString() ?? '0',
                          ) ??
                          0;
                      final date = ex['expenseDate'] != null
                          ? DateFormat(
                              'dd MMM yyyy',
                            ).format(DateTime.parse(ex['expenseDate']))
                          : '-';
                      final attachments = ex['attachments'] as List? ?? [];
                      final hasAttachment = attachments.isNotEmpty;

                      final submitterName =
                          ex['submitter']?['name'] as String? ?? '-';
                      final approverName = ex['approver']?['name'] as String?;

                      return AppCard(
                        leftBorderColor: _borderColor(status),
                        padding: const EdgeInsets.all(AppDimensions.md),
                        onTap: () => _showDetailSheet(context, ex, isAdmin),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySurface,
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusMd,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ex['title'] as String? ?? '-',
                                        style: AppTextStyles.h3,
                                      ),
                                      const SizedBox(height: AppDimensions.xs),
                                      Row(
                                        children: [
                                          Text(
                                            '$date • ${ex['category'] ?? '-'}',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                  color: AppColors.textMuted,
                                                ),
                                          ),
                                          if (hasAttachment) ...[
                                            const SizedBox(
                                              width: AppDimensions.sm,
                                            ),
                                            const Icon(
                                              Icons.attach_file,
                                              size: 14,
                                              color: AppColors.primary,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${fmt.format(amount)}',
                                      style: AppTextStyles.h3,
                                    ),
                                    const SizedBox(height: AppDimensions.xs),
                                    AppStatusChip(status: status),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.sm),
                            // Submitter / Approver row
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 13,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'By $submitterName',
                                  style: AppTextStyles.caption,
                                ),
                                if (approverName != null) ...[
                                  const SizedBox(width: AppDimensions.md),
                                  const Icon(
                                    Icons.verified_outlined,
                                    size: 13,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Approved by $approverName',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // Edit action for pending (admin only)
                            if (isAdmin && status == 'pending') ...[
                              const SizedBox(height: AppDimensions.sm),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _showEditDialog(context, ex),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 14,
                                  ),
                                  label: const Text('Edit'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    textStyle: AppTextStyles.labelMedium,
                                  ),
                                ),
                              ),
                            ],
                            // Approve / Reject actions for pending (admin only)
                            if (isAdmin && status == 'pending') ...[
                              const SizedBox(height: AppDimensions.sm),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _confirmReject(
                                      context,
                                      ex['id'],
                                      notifier,
                                    ),
                                    icon: const Icon(Icons.close, size: 14),
                                    label: const Text('Reject'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.danger,
                                      side: const BorderSide(
                                        color: AppColors.danger,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      textStyle: AppTextStyles.labelMedium,
                                    ),
                                  ),
                                  const SizedBox(width: AppDimensions.sm),
                                  FilledButton.icon(
                                    onPressed: () => _confirmApprove(
                                      context,
                                      ex['id'],
                                      notifier,
                                    ),
                                    icon: const Icon(Icons.check, size: 14),
                                    label: const Text('Approve'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      textStyle: AppTextStyles.labelMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentViewer(BuildContext context, String fileUrl) {
    final fullUrl =
        AppConstants.apiBaseUrl.replaceAll('/api/', '/uploads/') + fileUrl;
    final isPdf = fileUrl.toLowerCase().endsWith('.pdf');

    if (isPdf) {
      launchUrl(Uri.parse(fullUrl));
      return;
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'View Attachment',
                style: TextStyle(color: Colors.white),
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                child: Image.network(
                  fullUrl,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 48,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Could not load image',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(
    BuildContext context,
    Map<String, dynamic> ex,
    bool isAdmin,
  ) {
    final status = (ex['status'] as String? ?? 'pending').toLowerCase();
    final attachments = ex['attachments'] as List? ?? [];
    final fmt = NumberFormat('#,##0');
    final amount = double.tryParse(ex['totalAmount']?.toString() ?? '0') ?? 0;
    final date = ex['expenseDate'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(ex['expenseDate']))
        : '-';
    final submitterName = ex['submitter']?['name'] as String? ?? '-';
    final approverName = ex['approver']?['name'] as String?;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    ex['title'] as String? ?? '-',
                    style: AppTextStyles.h1,
                  ),
                ),
                AppStatusChip(status: status),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            _detailRow(Icons.attach_money, 'Amount', '₹${fmt.format(amount)}'),
            _detailRow(
              Icons.category_outlined,
              'Category',
              ex['category'] ?? '-',
            ),
            _detailRow(Icons.calendar_today_outlined, 'Date', date),
            _detailRow(Icons.person_outline, 'Submitted by', submitterName),
            if (approverName != null)
              _detailRow(
                Icons.verified_outlined,
                'Approved by',
                approverName,
                color: AppColors.success,
              ),
            if (ex['paymentMethod'] != null)
              _detailRow(
                Icons.payment_outlined,
                'Payment Method',
                ex['paymentMethod'],
              ),
            if (ex['referenceId'] != null &&
                (ex['referenceId'] as String).isNotEmpty)
              _detailRow(
                Icons.tag,
                'Reference ID',
                ex['referenceId'],
              ),
            if (ex['description'] != null &&
                (ex['description'] as String).isNotEmpty)
              _detailRow(
                Icons.notes_outlined,
                'Description',
                ex['description'],
              ),
            if (ex['rejectionReason'] != null)
              _detailRow(
                Icons.info_outline,
                'Rejection Reason',
                ex['rejectionReason'],
                color: AppColors.danger,
              ),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.sm),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _showAttachmentViewer(context, attachments.first['fileUrl']);
                },
                child: Row(
                  children: [
                    const Icon(
                      Icons.attach_file,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      attachments.first['fileName'] ?? 'View Attachment',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.xl),
            if (isAdmin && status == 'approved')
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final error = await ref.read(expensesProvider.notifier).convertToBill(ex['id']);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(error ?? 'Expense split and bill generated for all units'),
                        backgroundColor: error == null ? AppColors.success : AppColors.danger,
                      ));
                    }
                  },
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Split Among Units (Generate Bills)'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ),
            const SizedBox(height: AppDimensions.xl),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? AppColors.textMuted),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReject(
    BuildContext context,
    String id,
    ExpensesNotifier notifier,
  ) {
    final reasonC = TextEditingController();
    showAppSheet(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        String? sheetError;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Reject Expense',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonC,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason *',
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (sheetError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.sm),
                      decoration: BoxDecoration(
                        color: AppColors.dangerSurface,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSm,
                        ),
                      ),
                      child: Text(
                        sheetError!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.dangerText,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (reasonC.text.trim().isEmpty) return;

                              setSheetState(() {
                                isSubmitting = true;
                                sheetError = null;
                              });

                              final error = await notifier.updateStatus(
                                id,
                                'rejected',
                                reason: reasonC.text.trim(),
                              );

                              if (context.mounted) {
                                if (error == null) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Expense rejected'),
                                      backgroundColor: AppColors.warning,
                                    ),
                                  );
                                } else {
                                  setSheetState(() {
                                    isSubmitting = false;
                                    sheetError = error;
                                  });
                                }
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Reject Expense'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmApprove(
    BuildContext context,
    String id,
    ExpensesNotifier notifier,
  ) {
    String? selectedMethod = 'CASH';
    final methods = ['CASH', 'BANK', 'UPI', 'ONLINE', 'RAZORPAY'];
    final refC = TextEditingController();

    showAppSheet(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        String? sheetError;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Approve Expense',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please select the payment method and enter the reference ID (if any).',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 24),
                  AppSearchableDropdown<String>(
                    label: 'Payment Method',
                    value: selectedMethod,
                    items: methods
                        .map((m) => AppDropdownItem(value: m, label: m))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheetState(() => selectedMethod = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: refC,
                    decoration: const InputDecoration(
                      labelText: 'Reference ID / Transaction ID',
                      hintText: 'e.g. UPI Ref, Check No, etc.',
                    ),
                  ),
                  if (sheetError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.sm),
                      decoration: BoxDecoration(
                        color: AppColors.dangerSurface,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSm,
                        ),
                      ),
                      child: Text(
                        sheetError!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.dangerText,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setSheetState(() {
                                isSubmitting = true;
                                sheetError = null;
                              });

                              final error = await notifier.updateStatus(
                                id,
                                'approved',
                                paymentMethod: selectedMethod,
                                referenceId: refC.text.trim(),
                              );

                              if (context.mounted) {
                                if (error == null) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Expense approved'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                } else {
                                  setSheetState(() {
                                    isSubmitting = false;
                                    sheetError = error;
                                  });
                                }
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Approve Expense'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (_) => const _AddExpenseSheet(),
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> ex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (_) => _EditExpenseSheet(expense: ex),
    );
  }
}

// ─── Add Expense Sheet ────────────────────────────────────────────────────────

class _AddExpenseSheet extends ConsumerStatefulWidget {
  const _AddExpenseSheet();

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'MAINTENANCE';
  DateTime _date = DateTime.now();
  XFile? _attachment;
  bool _isSubmitting = false;
  String? _errorMsg;

  static const _categories = [
    'MAINTENANCE',
    'UTILITIES',
    'EVENTS',
    'SECURITY',
    'OTHER',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAttachmentFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || !mounted) return;
    final file = result.files.single;
    if (file.bytes != null) {
      setState(() => _attachment = XFile.fromData(file.bytes!, name: file.name));
    } else if (file.path != null) {
      setState(() => _attachment = XFile(file.path!));
    }
  }

  Future<void> _takeAttachmentPhoto() async {
    final shot = await pickPhotoFromCamera();
    if (shot != null && mounted) {
      setState(() => _attachment = shot);
    }
  }

  void _previewAttachment() async {
    if (_attachment == null) return;
    final file = _attachment!;
    final isPdf = file.name.toLowerCase().endsWith('.pdf');

    if (isPdf) {
      if (file.path.isNotEmpty) {
        await OpenFilex.open(file.path);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot preview PDF from memory. Please upload to view.'),
            ),
          );
        }
      }
    } else {
      if (!mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              InteractiveViewer(
                child: Center(
                  child: Image.memory(bytes),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill title and amount')),
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMsg = null;
    });
    final error = await ref.read(expensesProvider.notifier).createExpense({
      'title': _titleCtrl.text.trim(),
      'amount': double.tryParse(_amountCtrl.text.trim()) ?? 0,
      'category': _category,
      'expenseDate': _date.toIso8601String(),
      'description': _descCtrl.text.trim(),
    }, attachments: _attachment != null ? [_attachment!] : null);
    if (mounted) {
      if (error == null) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Expense added'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() {
          _isSubmitting = false;
          _errorMsg = error;
        });
      }
    }
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
            Text('Add Expense', style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.lg),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title *'),
            ),
            const SizedBox(height: AppDimensions.md),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      prefixText: '₹',
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  flex: 3,
                  child: AppSearchableDropdown<String>(
                    label: 'Category',
                    value: _category,
                    items: _categories
                        .map((c) => AppDropdownItem(value: c, label: c))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Expense Date'),
              subtitle: Text(DateFormat('dd MMM yyyy').format(_date)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: AppDimensions.md),
            Text('Attachment (optional)', style: AppTextStyles.labelMedium),
            const SizedBox(height: AppDimensions.xs),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickAttachmentFile,
                    icon: const Icon(Icons.attach_file_rounded, size: 18),
                    label: const Text('Attach file'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _takeAttachmentPhoto,
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.xs),
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: _attachment != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _attachment!.name.toLowerCase().endsWith('.pdf')
                                ? Icons.picture_as_pdf
                                : Icons.image,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: AppDimensions.sm),
                          Expanded(
                            child: Text(
                              _attachment!.name,
                              style: AppTextStyles.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: _previewAttachment,
                            icon: const Icon(Icons.visibility_outlined,
                                size: 18, color: AppColors.primary),
                            tooltip: 'Preview',
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _attachment = null),
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Remove',
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Text(
                        'No attachment selected',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ),
            ),
            const SizedBox(height: AppDimensions.md),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
              ),
            ),
            if (_errorMsg != null) ...[
              const SizedBox(height: AppDimensions.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.sm),
                margin: const EdgeInsets.only(bottom: AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.dangerSurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Text(
                  _errorMsg!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.dangerText,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.xl),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Add Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit Expense Sheet ───────────────────────────────────────────────────────

class _EditExpenseSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> expense;
  const _EditExpenseSheet({required this.expense});

  @override
  ConsumerState<_EditExpenseSheet> createState() => _EditExpenseSheetState();
}

class _EditExpenseSheetState extends ConsumerState<_EditExpenseSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  late String _category;
  late DateTime _date;
  XFile? _attachment;
  bool _isSubmitting = false;
  String? _errorMsg;

  static const _categories = [
    'MAINTENANCE',
    'UTILITIES',
    'EVENTS',
    'SECURITY',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    final ex = widget.expense;
    _titleCtrl = TextEditingController(text: ex['title'] as String? ?? '');
    _amountCtrl = TextEditingController(
      text: (double.tryParse(ex['totalAmount']?.toString() ?? '0') ?? 0)
          .toStringAsFixed(0),
    );
    _descCtrl = TextEditingController(text: ex['description'] as String? ?? '');
    _category = ex['category'] as String? ?? 'MAINTENANCE';
    _date = ex['expenseDate'] != null
        ? DateTime.parse(ex['expenseDate'])
        : DateTime.now();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAttachmentFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || !mounted) return;
    final file = result.files.single;
    if (file.bytes != null) {
      setState(() => _attachment = XFile.fromData(file.bytes!, name: file.name));
    } else if (file.path != null) {
      setState(() => _attachment = XFile(file.path!));
    }
  }

  Future<void> _takeAttachmentPhoto() async {
    final shot = await pickPhotoFromCamera();
    if (shot != null && mounted) {
      setState(() => _attachment = shot);
    }
  }

  void _previewAttachment() async {
    if (_attachment == null) return;
    final file = _attachment!;
    final isPdf = file.name.toLowerCase().endsWith('.pdf');

    if (isPdf) {
      if (file.path.isNotEmpty) {
        await OpenFilex.open(file.path);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot preview PDF from memory. Please upload to view.'),
            ),
          );
        }
      }
    } else {
      if (!mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              InteractiveViewer(
                child: Center(
                  child: Image.memory(bytes),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill title and amount')),
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMsg = null;
    });
    final error = await ref
        .read(expensesProvider.notifier)
        .updateExpense(widget.expense['id'], {
          'title': _titleCtrl.text.trim(),
          'amount': double.tryParse(_amountCtrl.text.trim()) ?? 0,
          'category': _category,
          'expenseDate': _date.toIso8601String(),
          'description': _descCtrl.text.trim(),
        }, attachments: _attachment != null ? [_attachment!] : null);
    if (mounted) {
      if (error == null) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Expense updated'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() {
          _isSubmitting = false;
          _errorMsg = error;
        });
      }
    }
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
            Text('Edit Expense', style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.lg),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title *'),
            ),
            const SizedBox(height: AppDimensions.md),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      prefixText: '₹',
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  flex: 3,
                  child: AppSearchableDropdown<String>(
                    label: 'Category',
                    value: _category,
                    items: _categories
                        .map((c) => AppDropdownItem(value: c, label: c))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Expense Date'),
              subtitle: Text(DateFormat('dd MMM yyyy').format(_date)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              'Replace attachment (optional)',
              style: AppTextStyles.labelMedium,
            ),
            const SizedBox(height: AppDimensions.xs),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickAttachmentFile,
                    icon: const Icon(Icons.attach_file_rounded, size: 18),
                    label: const Text('Attach file'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _takeAttachmentPhoto,
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.xs),
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: _attachment != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _attachment!.name.toLowerCase().endsWith('.pdf')
                                ? Icons.picture_as_pdf
                                : Icons.image,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: AppDimensions.sm),
                          Expanded(
                            child: Text(
                              _attachment!.name,
                              style: AppTextStyles.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: _previewAttachment,
                            icon: const Icon(Icons.visibility_outlined,
                                size: 18, color: AppColors.primary),
                            tooltip: 'Preview',
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _attachment = null),
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Remove',
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Text(
                        'No new attachment — existing file kept',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ),
            ),
            const SizedBox(height: AppDimensions.md),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
              ),
            ),
            if (_errorMsg != null) ...[
              const SizedBox(height: AppDimensions.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.sm),
                margin: const EdgeInsets.only(bottom: AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.dangerSurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Text(
                  _errorMsg!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.dangerText,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.xl),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Update Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
