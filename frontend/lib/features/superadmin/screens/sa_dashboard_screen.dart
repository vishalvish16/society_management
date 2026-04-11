import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/dashboard_provider.dart';

class SADashboardScreen extends ConsumerWidget {
  const SADashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardProvider);
    final recentAsync = ref.watch(recentSocietiesProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(recentSocietiesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dashboard',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                        SizedBox(height: 4),
                        Text('Platform overview and key metrics',
                            style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () {
                      ref.invalidate(dashboardProvider);
                      ref.invalidate(recentSocietiesProvider);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Stats Cards
              statsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorCard(message: 'Failed to load stats: $e'),
                data: (stats) => Column(
                  children: [
                    // Revenue row
                    _ResponsiveGrid(
                      children: [
                        _StatCard(
                          title: 'Monthly Revenue (MRR)',
                          value: currencyFormat.format(stats.mrr),
                          icon: Icons.trending_up_rounded,
                          color: AppColors.secondary,
                        ),
                        _StatCard(
                          title: 'Annual Revenue (ARR)',
                          value: currencyFormat.format(stats.arr),
                          icon: Icons.account_balance_rounded,
                          color: AppColors.primary,
                        ),
                        _StatCard(
                          title: 'Total Societies',
                          value: stats.totalSocieties.toString(),
                          icon: Icons.apartment_rounded,
                          color: const Color(0xFF8B5CF6),
                        ),
                        _StatCard(
                          title: 'Total Users',
                          value: stats.totalUsers.toString(),
                          icon: Icons.people_rounded,
                          color: const Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Subscription row
                    _ResponsiveGrid(
                      children: [
                        _StatCard(
                          title: 'Active Subscriptions',
                          value: stats.activeSubscriptions.toString(),
                          icon: Icons.check_circle_rounded,
                          color: AppColors.secondary,
                        ),
                        _StatCard(
                          title: 'Trial Subscriptions',
                          value: stats.trialSubscriptions.toString(),
                          icon: Icons.hourglass_bottom_rounded,
                          color: const Color(0xFF3B82F6),
                        ),
                        _StatCard(
                          title: 'Expired',
                          value: stats.expiredSubscriptions.toString(),
                          icon: Icons.cancel_rounded,
                          color: AppColors.error,
                        ),
                        _StatCard(
                          title: 'Total Units',
                          value: stats.totalUnits.toString(),
                          icon: Icons.home_rounded,
                          color: const Color(0xFF06B6D4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Plan Distribution
                    if (stats.planDistribution.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Plan Distribution',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                      ),
                      const SizedBox(height: 12),
                      _ResponsiveGrid(
                        children: stats.planDistribution.map((pd) {
                          final color = pd.planCode == 'BASIC'
                              ? const Color(0xFF94A3B8)
                              : pd.planCode == 'STANDARD'
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFF8B5CF6);
                          return _StatCard(
                            title: '${pd.planName} Plan',
                            value: '${pd.count} societies',
                            icon: Icons.card_membership_rounded,
                            color: color,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),

              // Recent Societies Table
              const Text('Recent Societies',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain)),
              const SizedBox(height: 12),

              recentAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorCard(message: 'Failed to load recent societies'),
                data: (societies) => Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: societies.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No societies yet', style: TextStyle(color: AppColors.textMuted))),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Plan', style: TextStyle(fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Units', style: TextStyle(fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Users', style: TextStyle(fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Created', style: TextStyle(fontWeight: FontWeight.w600))),
                            ],
                            rows: societies.map<DataRow>((s) {
                              final subs = (s['subscriptions'] as List?) ?? [];
                              final activeSub = subs.isNotEmpty ? subs[0] : null;
                              final planName = activeSub?['plan']?['name'] ?? 'No Plan';
                              final subStatus = activeSub?['status'] ?? '-';
                              final counts = s['_count'] ?? {};
                              final isActive = s['isActive'] == true;

                              return DataRow(cells: [
                                DataCell(Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                                DataCell(_PlanBadge(planName: planName)),
                                DataCell(_StatusBadge(status: isActive ? subStatus : 'INACTIVE')),
                                DataCell(Text('${counts['units'] ?? 0}')),
                                DataCell(Text('${counts['users'] ?? 0}')),
                                DataCell(Text(
                                  s['createdAt'] != null
                                      ? DateFormat('dd MMM yyyy').format(DateTime.parse(s['createdAt']))
                                      : '-',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
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
}

class _ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  const _ResponsiveGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1200 ? 4 : width >= 768 ? 2 : 1;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: width >= 768 ? 2.4 : 2.8,
      children: children,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  final String planName;
  const _PlanBadge({required this.planName});

  @override
  Widget build(BuildContext context) {
    final color = planName == 'Premium'
        ? const Color(0xFF8B5CF6)
        : planName == 'Standard'
            ? const Color(0xFF3B82F6)
            : const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(planName, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'ACTIVE':
        color = AppColors.secondary;
        break;
      case 'TRIAL':
        color = const Color(0xFF3B82F6);
        break;
      case 'EXPIRED':
      case 'INACTIVE':
        color = AppColors.error;
        break;
      default:
        color = AppColors.textMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.error.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: AppColors.error))),
          ],
        ),
      ),
    );
  }
}
