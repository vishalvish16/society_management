import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/expense_provider.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.read(expensesProvider.notifier).fetchExpenses(),
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
                        Text('Society Expenses',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                        SizedBox(height: 4),
                        Text('Track and approve society spending',
                            style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddExpenseDialog(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New Expense'),
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
              // (Future: Category / Status filter)

              // Expenses List
              expensesAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (expenses) => Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: expenses.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(60),
                          child: Center(child: Text('No expenses recorded', style: TextStyle(color: AppColors.textMuted))),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: expenses.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final ex = expenses[index];
                            final amount = ex['totalAmount'] ?? 0;
                            final status = ex['status'] ?? 'PENDING';
                            final date = ex['expenseDate'] != null
                                ? DateFormat('dd MMM yyyy').format(DateTime.parse(ex['expenseDate']))
                                : '-';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(ex['category']).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.account_balance_wallet_rounded, 
                                  color: _getCategoryColor(ex['category']), size: 20),
                              ),
                              title: Text(ex['title'] ?? 'Expense', 
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('$date • ${ex['category'] ?? 'Other'}', 
                                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(currencyFormat.format(amount), 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain)),
                                  const SizedBox(height: 4),
                                  _StatusBadge(status: status),
                                ],
                              ),
                              onTap: () {}, // View detail
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String? cat) {
    if (cat == null) return Colors.grey;
    switch (cat.toUpperCase()) {
      case 'MAINTENANCE': return Colors.blue;
      case 'UTILITIES': return Colors.orange;
      case 'EVENTS': return Colors.purple;
      case 'SECURITY': return Colors.red;
      default: return Colors.blueGrey;
    }
  }

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref) {
    // Basic dialog popup
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense creation form coming soon')));
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toUpperCase()) {
      case 'APPROVED':
        color = AppColors.secondary;
        break;
      case 'REJECTED':
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
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
