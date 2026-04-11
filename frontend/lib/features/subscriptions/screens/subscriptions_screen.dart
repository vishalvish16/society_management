import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/subscriptions_provider.dart';

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  String _statusFilter = '';
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);
  final dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(subscriptionsProvider.notifier).loadSubscriptions());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Subscriptions',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                      SizedBox(height: 4),
                      Text('Manage society subscriptions and billing',
                          style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showAssignDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Assign Plan'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter
            Row(
              children: [
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    decoration: InputDecoration(
                      labelText: 'Filter by status',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All')),
                      DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                      DropdownMenuItem(value: 'TRIAL', child: Text('Trial')),
                      DropdownMenuItem(value: 'EXPIRED', child: Text('Expired')),
                      DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                    ],
                    onChanged: (val) {
                      setState(() => _statusFilter = val ?? '');
                      ref.read(subscriptionsProvider.notifier).loadSubscriptions(
                            status: val != null && val.isNotEmpty ? val : null,
                          );
                    },
                  ),
                ),
                const Spacer(),
                Text('${state.total} subscriptions',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 16),

            // Table
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.subscriptions.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.subscriptions_outlined, size: 64, color: AppColors.textMuted),
                              SizedBox(height: 12),
                              Text('No subscriptions found',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                            ],
                          ),
                        )
                      : Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                              columns: const [
                                DataColumn(label: Text('Society', style: TextStyle(fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('Plan', style: TextStyle(fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('Cycle', style: TextStyle(fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('Start', style: TextStyle(fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('End', style: TextStyle(fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('Auto Renew', style: TextStyle(fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                              ],
                              rows: state.subscriptions.map<DataRow>((sub) {
                                final society = sub['society'] as Map<String, dynamic>? ?? {};
                                final plan = sub['plan'] as Map<String, dynamic>? ?? {};
                                final status = sub['status'] ?? '';

                                return DataRow(cells: [
                                  DataCell(Text(society['name'] ?? '-',
                                      style: const TextStyle(fontWeight: FontWeight.w500))),
                                  DataCell(_badge(plan['name'] ?? '-', const Color(0xFF3B82F6))),
                                  DataCell(_statusBadge(status)),
                                  DataCell(Text(
                                    currencyFormat.format(num.tryParse(sub['amount']?.toString() ?? '0') ?? 0),
                                  )),
                                  DataCell(Text(sub['billingCycle'] ?? '-', style: const TextStyle(fontSize: 13))),
                                  DataCell(Text(
                                    sub['startDate'] != null ? dateFormat.format(DateTime.parse(sub['startDate'])) : '-',
                                    style: const TextStyle(fontSize: 13),
                                  )),
                                  DataCell(Text(
                                    sub['endDate'] != null ? dateFormat.format(DateTime.parse(sub['endDate'])) : '-',
                                    style: const TextStyle(fontSize: 13),
                                  )),
                                  DataCell(Icon(
                                    sub['autoRenew'] == true ? Icons.check_circle : Icons.cancel,
                                    color: sub['autoRenew'] == true ? AppColors.secondary : AppColors.textMuted,
                                    size: 20,
                                  )),
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (status == 'ACTIVE' || status == 'TRIAL' || status == 'EXPIRED')
                                        IconButton(
                                          icon: const Icon(Icons.refresh, size: 18, color: AppColors.secondary),
                                          tooltip: 'Renew',
                                          onPressed: () => _confirmRenew(sub['id'], society['name'] ?? ''),
                                        ),
                                      if (status == 'ACTIVE' || status == 'TRIAL')
                                        IconButton(
                                          icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
                                          tooltip: 'Cancel',
                                          onPressed: () => _showCancelDialog(sub['id'], society['name'] ?? ''),
                                        ),
                                    ],
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
            ),

            // Pagination
            if (state.total > 20)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: state.page > 1
                          ? () => ref.read(subscriptionsProvider.notifier).loadSubscriptions(
                                page: state.page - 1,
                                status: _statusFilter.isNotEmpty ? _statusFilter : null,
                              )
                          : null,
                      child: const Text('Previous'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Page ${state.page}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    TextButton(
                      onPressed: state.page * 20 < state.total
                          ? () => ref.read(subscriptionsProvider.notifier).loadSubscriptions(
                                page: state.page + 1,
                                status: _statusFilter.isNotEmpty ? _statusFilter : null,
                              )
                          : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'ACTIVE':
        color = AppColors.secondary;
      case 'TRIAL':
        color = const Color(0xFF3B82F6);
      case 'EXPIRED':
        color = const Color(0xFFF59E0B);
      case 'CANCELLED':
        color = AppColors.error;
      default:
        color = AppColors.textMuted;
    }
    return _badge(status, color);
  }

  void _confirmRenew(String id, String societyName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renew Subscription'),
        content: Text('Renew subscription for "$societyName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(subscriptionsProvider.notifier).renewSubscription(id);
            },
            child: const Text('Renew'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(String id, String societyName) {
    final reasonC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Cancel subscription for "$societyName"?'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonC,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Reason (optional)', alignLabelWithHint: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(subscriptionsProvider.notifier).cancelSubscription(id, reasonC.text.trim());
            },
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }

  void _showAssignDialog(BuildContext context) {
    final societyIdC = TextEditingController();
    String planCode = 'BASIC';
    String cycle = 'MONTHLY';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Plan to Society'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: societyIdC,
                decoration: const InputDecoration(labelText: 'Society ID *', hintText: 'Paste society UUID'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: planCode,
                decoration: const InputDecoration(labelText: 'Plan'),
                items: const [
                  DropdownMenuItem(value: 'BASIC', child: Text('Basic')),
                  DropdownMenuItem(value: 'STANDARD', child: Text('Standard')),
                  DropdownMenuItem(value: 'PREMIUM', child: Text('Premium')),
                ],
                onChanged: (v) => planCode = v ?? 'BASIC',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: cycle,
                decoration: const InputDecoration(labelText: 'Billing Cycle'),
                items: const [
                  DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                  DropdownMenuItem(value: 'QUARTERLY', child: Text('Quarterly')),
                  DropdownMenuItem(value: 'YEARLY', child: Text('Yearly')),
                ],
                onChanged: (v) => cycle = v ?? 'MONTHLY',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (societyIdC.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await ref.read(subscriptionsProvider.notifier).assignPlan({
                'societyId': societyIdC.text.trim(),
                'planCode': planCode,
                'billingCycle': cycle,
              });
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }
}
