content = r"""import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final role = user.role.toLowerCase();
    final name = user.name;
    final isSA = role == 'super_admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSA ? 'Platform Dashboard' : 'Society Dashboard',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            Text(
              'Welcome, $name',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: const Color(0xFF667EEA),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            onSelected: (val) async {
              if (val == 'logout') {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Logout', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(societyDashboardProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatsSection(isSA: isSA),
              const SizedBox(height: 24),
              _QuickActions(role: role),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsSection extends ConsumerWidget {
  final bool isSA;
  const _StatsSection({required this.isSA});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(societyDashboardProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) {
        final msg = err.toString();
        final isUnauth = msg.contains('401') || msg.contains('403');
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  isUnauth ? Icons.lock_outline : Icons.error_outline,
                  size: 48,
                  color: Colors.red.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  isUnauth ? 'Session expired. Please log in again.' : 'Failed to load stats: $msg',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          ),
        );
      },
      data: (stats) {
        if (isSA) {
          return _StatsGrid(items: [
            _StatItem('Societies', stats['totalSocieties']?.toString() ?? '0', Icons.apartment, const Color(0xFF667EEA)),
            _StatItem('Users', stats['totalUsers']?.toString() ?? '0', Icons.people, const Color(0xFF06B6D4)),
            _StatItem('Plans', stats['totalPlans']?.toString() ?? '0', Icons.card_membership, const Color(0xFF8B5CF6)),
            _StatItem('Active Subs', stats['activeSubs']?.toString() ?? '0', Icons.verified, const Color(0xFF10B981)),
          ]);
        }
        return _StatsGrid(items: [
          _StatItem('Total Units', stats['totalUnits']?.toString() ?? '0', Icons.home, const Color(0xFF667EEA)),
          _StatItem('Pending Bills', stats['pendingBills']?.toString() ?? '0', Icons.receipt_long, const Color(0xFFF59E0B)),
          _StatItem('Complaints', stats['openComplaints']?.toString() ?? '0', Icons.report_problem, const Color(0xFFEF4444)),
          _StatItem('Visitors', stats['activeVisitors']?.toString() ?? '0', Icons.person_pin, const Color(0xFF10B981)),
        ]);
      },
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final List<_StatItem> items;
  const _StatsGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: items.map((item) => _StatCard(item: item)).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                Text(
                  item.label,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

class _QuickActions extends StatelessWidget {
  final String role;
  const _QuickActions({required this.role});

  List<_ActionData> get _actions {
    if (role == 'super_admin') {
      return [
        const _ActionData('Societies', Icons.apartment, '/societies', Color(0xFF667EEA)),
        const _ActionData('Users', Icons.people, '/users', Color(0xFF06B6D4)),
        const _ActionData('Plans', Icons.card_membership, '/plans', Color(0xFF8B5CF6)),
        const _ActionData('Subscriptions', Icons.verified, '/subscriptions', Color(0xFF10B981)),
        const _ActionData('Notices', Icons.campaign, '/notices', Color(0xFFF59E0B)),
        const _ActionData('Reports', Icons.bar_chart, '/reports', Color(0xFFEF4444)),
      ];
    }
    return [
      const _ActionData('Members', Icons.people, '/members', Color(0xFF667EEA)),
      const _ActionData('Bills', Icons.receipt_long, '/bills', Color(0xFFF59E0B)),
      const _ActionData('Complaints', Icons.report_problem, '/complaints', Color(0xFFEF4444)),
      const _ActionData('Visitors', Icons.person_pin, '/visitors', Color(0xFF10B981)),
      const _ActionData('Notices', Icons.campaign, '/notices', Color(0xFF8B5CF6)),
      const _ActionData('Amenities', Icons.pool, '/amenities', Color(0xFF06B6D4)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
          children: _actions.map((a) => _ActionCard(action: a)).toList(),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final _ActionData action;
  const _ActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        try {
          context.push(action.route);
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${action.label} coming soon')),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(action.icon, color: action.color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionData {
  final String label, route;
  final IconData icon;
  final Color color;
  const _ActionData(this.label, this.icon, this.route, this.color);
}
"""

with open(r'e:\Society_Managment\frontend\lib\features\dashboard\screens\dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Written successfully")
