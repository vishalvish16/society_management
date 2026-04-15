import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class SuperAdminDashboard extends ConsumerWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = [
      {'label': 'Total Societies', 'value': '24', 'icon': Icons.location_city_rounded, 'color': AppColors.primary},
      {'label': 'Active Plans', 'value': '3', 'icon': Icons.workspace_premium_rounded, 'color': AppColors.success},
      {'label': 'Monthly Revenue', 'value': '₹1.2L', 'icon': Icons.currency_rupee_rounded, 'color': AppColors.info},
      {'label': 'Expiring Soon', 'value': '4', 'icon': Icons.warning_amber_rounded, 'color': AppColors.warning},
    ];

    final societies = [
      {'name': 'Green Valley CHS', 'plan': 'premium', 'units': 120, 'status': 'active', 'city': 'Mumbai'},
      {'name': 'Sunrise Residency', 'plan': 'standard', 'units': 64, 'status': 'active', 'city': 'Pune'},
      {'name': 'Royal Heights', 'plan': 'basic', 'units': 32, 'status': 'suspended', 'city': 'Nashik'},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Super Admin', style: AppTextStyles.titleLarge),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () {}),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform Overview', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            _StatsGrid(stats: stats),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Societies', style: AppTextStyles.h3),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Society'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...societies.map((s) => _SocietyCard(society: s)),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cols = w >= 900 ? 4 : w >= 600 ? 2 : 1;
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12, crossAxisSpacing: 12,
      childAspectRatio: w >= 600 ? 2.2 : 3.0,
      children: stats.map((s) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: (s['color'] as Color).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(s['icon'] as IconData, color: s['color'] as Color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(s['label'] as String, style: AppTextStyles.bodyMedium),
              Text(s['value'] as String, style: AppTextStyles.headlineLarge),
            ]),
          ]),
        ),
      )).toList(),
    );
  }
}

class _SocietyCard extends StatelessWidget {
  final Map<String, dynamic> society;
  const _SocietyCard({required this.society});

  @override
  Widget build(BuildContext context) {
    final isActive = society['status'] == 'active';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.apartment_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(society['name'] as String, style: AppTextStyles.body1),
            const SizedBox(height: 2),
            Text('${society['city']} • ${society['units']} units', style: AppTextStyles.bodySmall),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? AppColors.successSurface : AppColors.dangerSurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(isActive ? 'Active' : 'Suspended',
                style: AppTextStyles.labelMedium.copyWith(
                    color: isActive ? AppColors.success : AppColors.danger)),
          ),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: () {}),
        ]),
      ),
    );
  }
}
