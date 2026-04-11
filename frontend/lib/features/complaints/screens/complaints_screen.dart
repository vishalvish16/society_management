import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/complaints_provider.dart';

class ComplaintsScreen extends ConsumerWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(complaintsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Complaints', style: AppTextStyles.titleLarge),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Raise Complaint', style: AppTextStyles.buttonSmall),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load', style: AppTextStyles.body1),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => ref.refresh(complaintsProvider), child: const Text('Retry')),
          ]),
        ),
        data: (list) => list.isEmpty
            ? Center(child: Text('No complaints', style: AppTextStyles.bodyMedium))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (ctx, i) {
                  final c = list[i];
                  final statusColor = c.status == 'open' ? AppColors.error
                      : c.status == 'in_progress' ? AppColors.warning
                      : AppColors.secondary;
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
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
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.report_problem_rounded, color: AppColors.error, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.title, style: AppTextStyles.body1),
                          const SizedBox(height: 2),
                          Text('Unit ${c.unit} • ${c.date.substring(0, 10)}', style: AppTextStyles.bodySmall),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(c.status.replaceAll('_', ' '),
                              style: AppTextStyles.labelMedium.copyWith(color: statusColor)),
                        ),
                      ]),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
