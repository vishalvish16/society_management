import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import 'admin_dashboard.dart';
import 'member_dashboard.dart';
import 'resident_dashboard.dart';
import 'watchman_dashboard.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final role = user.role.toUpperCase();
    if (role == 'SUPER_ADMIN') {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => context.go('/sa-dashboard'));
      return const Scaffold(body: SizedBox.shrink());
    }

    // Role label for AppBar subtitle
    final roleLabel = _roleLabelFor(role);

    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isWide
          ? AppBar(
              backgroundColor: AppColors.primary,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dashboard',
                      style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
                  Text(
                    '${user.name}  ·  $roleLabel',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.8)),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: AppColors.textOnPrimary),
                  onPressed: () => context.go('/notifications'),
                ),
                const SizedBox(width: AppDimensions.sm),
              ],
            )
          : null,
      body: _bodyForRole(role),
    );
  }

  /// Returns the human-readable label for a given role code.
  String _roleLabelFor(String role) {
    return switch (role) {
      'PRAMUKH' || 'CHAIRMAN' => 'Chairman',
      'VICE_CHAIRMAN' => 'Vice Chairman',
      'SECRETARY' => 'Secretary',
      'ASSISTANT_SECRETARY' => 'Asst. Secretary',
      'TREASURER' => 'Treasurer',
      'ASSISTANT_TREASURER' => 'Asst. Treasurer',
      'MEMBER' => 'Member',
      'RESIDENT' => 'Resident',
      'WATCHMAN' => 'Watchman',
      _ => role,
    };
  }

  /// Maps role to the appropriate dashboard widget.
  Widget _bodyForRole(String role) {
    // Society admin / committee roles
    const adminRoles = {
      'PRAMUKH',
      'CHAIRMAN',
      'VICE_CHAIRMAN',
      'SECRETARY',
      'ASSISTANT_SECRETARY',
      'TREASURER',
      'ASSISTANT_TREASURER',
    };

    if (adminRoles.contains(role)) {
      return AdminDashboard(role: role);
    }

    if (role == 'MEMBER') {
      return const MemberDashboard();
    }

    if (role == 'RESIDENT') {
      return const ResidentDashboard();
    }

    if (role == 'WATCHMAN') {
      return const WatchmanDashboard();
    }

    // Fallback — unknown role gets admin view
    return AdminDashboard(role: role);
  }
}
