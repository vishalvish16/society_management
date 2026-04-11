import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/bill_provider.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(billsProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.read(billsProvider.notifier).fetchBills(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                        Text('Maintenance Bills',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                        SizedBox(height: 4),
                        Text('Manage and track society maintenance payments',
                            style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showGenerateDialog(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Generate for Month'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Filter row
              // (Future: Bill Month / Status filter)

              // Bills Table
              billsAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (bills) => Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: bills.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(60),
                          child: Center(child: Text('No bills found', style: TextStyle(color: AppColors.textMuted))),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Month', style: TextStyle(fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Due Date', style: TextStyle(fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                            ],
                            rows: bills.map<DataRow>((b) {
                              final unitCode = b['unit']?['fullCode'] ?? '-';
                              final month = b['billingMonth'] != null
                                  ? DateFormat('MMM yyyy').format(DateTime.parse(b['billingMonth']))
                                  : '-';
                              final amount = b['amount'] ?? 0;
                              final dueDate = b['dueDate'] != null
                                  ? DateFormat('dd MMM yyyy').format(DateTime.parse(b['dueDate']))
                                  : '-';
                              final status = b['status'] ?? 'PENDING';

                              return DataRow(cells: [
                                DataCell(Text(unitCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Text(month)),
                                DataCell(Text(currencyFormat.format(amount))),
                                DataCell(Text(dueDate, style: const TextStyle(fontSize: 13, color: AppColors.textMain))),
                                DataCell(_StatusBadge(status: status)),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                                      onPressed: () {}, // View receipt
                                      tooltip: 'View Receipt',
                                    ),
                                    if (status != 'PAID')
                                      IconButton(
                                        icon: const Icon(Icons.payment_rounded, size: 18, color: AppColors.secondary),
                                        onPressed: () {}, // Manual record payment
                                        tooltip: 'Record Payment',
                                      ),
                                  ],
                                )),
                              ]);
                            }).toList(),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGenerateDialog(BuildContext context, WidgetRef ref) {
    // Generate bill popup logic
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Generate Bills'),
        content: const Text('Are you sure you want to generate bills for ALL occupied units for the current month? Default amount ₹2500.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            child: const Text('Generate'),
            onPressed: () async {
              final success = await ref.read(billsProvider.notifier).bulkGenerate(
                DateTime.now(),
                2500.0,
                DateTime.now().add(const Duration(days: 10)),
              );
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bills generated for units')));
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toUpperCase()) {
      case 'PAID':
        color = AppColors.secondary;
        break;
      case 'PARTIAL':
        color = const Color(0xFF3B82F6);
        break;
      case 'OVERDUE':
        color = AppColors.error;
        break;
      case 'PENDING':
      default:
        color = const Color(0xFFF59E0B);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
