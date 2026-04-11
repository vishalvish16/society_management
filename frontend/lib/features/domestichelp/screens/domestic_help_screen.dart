import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/domestic_help_provider.dart';

class DomesticHelpScreen extends ConsumerWidget {
  const DomesticHelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(domesticHelpProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.surface, elevation: 0,
          title: Text('Domestic Help', style: AppTextStyles.titleLarge)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text('Add Helper', style: AppTextStyles.buttonSmall),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error')),
        data: (helpers) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: helpers.length,
          itemBuilder: (ctx, i) {
            final h = helpers[i];
            final isActive = h['status'] == 'active';
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0))),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
                  child: const Icon(Icons.cleaning_services_rounded, color: AppColors.secondary, size: 20)),
                title: Text(h['name'] as String, style: AppTextStyles.body1),
                subtitle: Text('${h["type"]} | Unit ${h["unit"]}', style: AppTextStyles.bodySmall),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.secondary.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(h['status'] as String,
                      style: AppTextStyles.labelMedium.copyWith(color: isActive ? AppColors.secondary : AppColors.error)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
