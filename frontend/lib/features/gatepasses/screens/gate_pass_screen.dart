import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/gate_pass_provider.dart';

class GatePassScreen extends ConsumerWidget {
  const GatePassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gatePassProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.surface, elevation: 0,
          title: Text('Gate Passes', style: AppTextStyles.titleLarge),
          actions: [IconButton(icon: const Icon(Icons.qr_code_scanner_rounded), onPressed: () {})]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Generate Pass', style: AppTextStyles.buttonSmall),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading passes')),
        data: (passes) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: passes.length,
          itemBuilder: (ctx, i) {
            final p = passes[i];
            final color = p['status'] == 'active' ? AppColors.secondary
                : p['status'] == 'used' ? AppColors.textMuted : AppColors.error;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0))),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.badge_rounded, color: AppColors.primary)),
                title: Text(p['visitor'] as String, style: AppTextStyles.body1),
                subtitle: Text('Unit ${p["unit"]} | Valid till ${p["validTill"]}', style: AppTextStyles.bodySmall),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(p['status'] as String, style: AppTextStyles.labelMedium.copyWith(color: color)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
