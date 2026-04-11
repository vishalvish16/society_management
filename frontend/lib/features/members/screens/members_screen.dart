import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/members_provider.dart';

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(membersProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Members', style: AppTextStyles.titleLarge),
        actions: [
          IconButton(icon: const Icon(Icons.search_rounded), onPressed: () {}),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text('Add Member', style: AppTextStyles.buttonSmall),
      ),
      body: async.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          itemBuilder: (_, _) => _ShimmerTile(),
        ),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load members', style: AppTextStyles.body1),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => ref.refresh(membersProvider), child: const Text('Retry')),
          ]),
        ),
        data: (members) => members.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.people_outline_rounded, size: 64, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text('No members found', style: AppTextStyles.bodyMedium),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: members.length,
                itemBuilder: (ctx, i) {
                  final m = members[i];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Text(m.name[0].toUpperCase(),
                            style: AppTextStyles.body1.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                      ),
                      title: Text(m.name, style: AppTextStyles.body1),
                      subtitle: Text('${m.unit} • ${m.phone}', style: AppTextStyles.bodySmall),
                      trailing: _RoleBadge(role: m.role),
                      onTap: () {},
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = role == 'secretary' ? AppColors.info
        : role == 'pramukh' ? AppColors.warning
        : AppColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(role, style: AppTextStyles.labelMedium.copyWith(color: color)),
    );
  }
}

class _ShimmerTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: const ListTile(
        leading: CircleAvatar(backgroundColor: Color(0xFFE2E8F0)),
        title: _SkeletonBox(width: 140, height: 14),
        subtitle: _SkeletonBox(width: 100, height: 11),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width, height;
  const _SkeletonBox({required this.width, required this.height});

  @override
  Widget build(BuildContext context) => Container(
    width: width, height: height,
    decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
  );
}
