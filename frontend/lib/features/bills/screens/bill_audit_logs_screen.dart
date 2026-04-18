import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../providers/bill_provider.dart';

class BillAuditLogsScreen extends ConsumerStatefulWidget {
  final String? initialBillId;

  const BillAuditLogsScreen({super.key, this.initialBillId});

  @override
  ConsumerState<BillAuditLogsScreen> createState() => _BillAuditLogsScreenState();
}

class _BillAuditLogsScreenState extends ConsumerState<BillAuditLogsScreen> {
  static const int _limit = 20;
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String _actionFilter = 'all';
  late final String? _billIdFilter;
  String? _error;

  static const _actions = [
    'all',
    'generated',
    'payment_recorded',
    'advance_recorded',
    'deleted',
  ];

  @override
  void initState() {
    super.initState();
    _billIdFilter = widget.initialBillId;
    _scrollController.addListener(_onScroll);
    _loadLogs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadLogs(loadMore: true);
    }
  }

  Future<void> _loadLogs({bool loadMore = false}) async {
    if (loadMore) {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
        _logs.clear();
      });
    }

    try {
      final result = await ref.read(billsProvider.notifier).getAllBillAuditLogs(
            page: _page,
            limit: _limit,
            action: _actionFilter == 'all' ? null : _actionFilter,
            billId: _billIdFilter,
          );
      final logs = List<Map<String, dynamic>>.from(result['logs'] ?? const []);
      final total = result['total'] as int? ?? 0;

      setState(() {
        _logs.addAll(logs);
        _hasMore = _logs.length < total;
        if (_hasMore) _page++;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  String _formatAction(String action) {
    return action
        .toLowerCase()
        .split('_')
        .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          _billIdFilter == null ? 'Bill Audit Logs' : 'Bill History',
          style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary),
        ),
      ),
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
                children: _actions.map((action) {
                  final selected = _actionFilter == action;
                  final label = action == 'all'
                      ? 'All'
                      : _formatAction(action);
                  return Padding(
                    padding: const EdgeInsets.only(right: AppDimensions.sm),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      selectedColor: AppColors.primarySurface,
                      labelStyle: AppTextStyles.labelMedium.copyWith(
                        color: selected ? AppColors.primary : AppColors.textMuted,
                      ),
                      onSelected: (_) {
                        setState(() => _actionFilter = action);
                        _loadLogs();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const AppLoadingShimmer()
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimensions.screenPadding),
                          child: AppCard(
                            backgroundColor: AppColors.dangerSurface,
                            child: Text(
                              _error!,
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.danger),
                            ),
                          ),
                        ),
                      )
                    : _logs.isEmpty
                        ? const AppEmptyState(
                            emoji: '📜',
                            title: 'No Audit Logs',
                            subtitle: 'No bill audit logs found for this filter.',
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadLogs(),
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(AppDimensions.screenPadding),
                              itemCount: _logs.length + (_isLoadingMore ? 1 : 0),
                              separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.sm),
                              itemBuilder: (_, index) {
                                if (index == _logs.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: AppDimensions.md),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }

                                final log = _logs[index];
                                final actor = log['actor'] as Map<String, dynamic>?;
                                final bill = log['bill'] as Map<String, dynamic>?;
                                final unit = bill?['unit'] as Map<String, dynamic>?;
                                final createdAt = log['createdAt'] != null
                                    ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(log['createdAt']))
                                    : '-';
                                final billingMonth = bill?['billingMonth'] != null
                                    ? DateFormat('MMM yyyy').format(DateTime.parse(bill!['billingMonth']))
                                    : '-';
                                final isDeletedBill = bill?['deletedAt'] != null;

                                return AppCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _formatAction(log['action']?.toString() ?? 'unknown'),
                                              style: AppTextStyles.labelLarge,
                                            ),
                                          ),
                                          if (isDeletedBill)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.dangerSurface,
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                'Deleted Bill',
                                                style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: AppDimensions.xs),
                                      Text(
                                        'Unit: ${unit?['fullCode'] ?? log['unitId'] ?? '-'} • Month: $billingMonth',
                                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                                      ),
                                      Text(
                                        'By: ${actor?['name'] ?? 'System'} • $createdAt',
                                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                                      ),
                                      if ((log['note'] as String?)?.isNotEmpty == true) ...[
                                        const SizedBox(height: AppDimensions.xs),
                                        Text(log['note'] as String, style: AppTextStyles.bodyMedium),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
