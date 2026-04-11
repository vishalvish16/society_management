import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/vehicles_provider.dart';

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vehiclesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.surface, elevation: 0,
          title: Text('Vehicles', style: AppTextStyles.titleLarge),
          actions: [IconButton(icon: const Icon(Icons.search_rounded), onPressed: () {})]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Register Vehicle', style: AppTextStyles.buttonSmall),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error')),
        data: (vehicles) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vehicles.length,
          itemBuilder: (ctx, i) {
            final v = vehicles[i];
            final icon = v['type'] == 'car' ? Icons.directions_car_rounded
                : v['type'] == 'two_wheeler' ? Icons.two_wheeler_rounded : Icons.pedal_bike_rounded;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0))),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: AppColors.primary, size: 20)),
                title: Text(v['plate'] as String, style: AppTextStyles.body1),
                subtitle: Text('Unit ${v["unit"]} | Slot ${v["slot"]}', style: AppTextStyles.bodySmall),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ),
            );
          },
        ),
      ),
    );
  }
}
