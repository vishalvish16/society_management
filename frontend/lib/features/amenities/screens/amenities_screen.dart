import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/amenities_provider.dart';

class AmenitiesScreen extends ConsumerWidget {
  const AmenitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(amenitiesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.surface, elevation: 0,
          title: Text('Amenities', style: AppTextStyles.titleLarge)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (amenities) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width >= 600 ? 3 : 2,
            crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1,
          ),
          itemCount: amenities.length,
          itemBuilder: (ctx, i) {
            final a = amenities[i];
            final isActive = a['status'] == 'active';
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: InkWell(
                onTap: isActive ? () {} : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(a['icon'] as IconData,
                        size: 36, color: isActive ? AppColors.primary : AppColors.textMuted),
                    const SizedBox(height: 10),
                    Text(a['name'] as String, style: AppTextStyles.body1, textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.secondary.withValues(alpha: 0.1)
                            : AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(a['status'] as String,
                          style: AppTextStyles.labelMedium.copyWith(
                              color: isActive ? AppColors.secondary : AppColors.error)),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
