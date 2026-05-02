import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class SubscriptionSuspendedScreen extends ConsumerWidget {
  const SubscriptionSuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.dangerSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline_rounded,
                      size: 48, color: AppColors.danger),
                ),
                const SizedBox(height: 28),

                // Title
                Text(
                  'Subscription Suspended',
                  style: AppTextStyles.h1.copyWith(
                    color: const Color(0xFF1A202C),
                    fontSize: 24,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),

                // Body message
                Text(
                  'Your society\'s subscription has been temporarily suspended.\n\n'
                  'Please recharge or contact your administrator to restore full access '
                  'and continue managing your society paperlessly — from billing and visitors '
                  'to maintenance and security — all from one platform.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: const Color(0xFF4A5568),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                if (user?.societyName != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.apartment_outlined, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Text(
                          user!.societyName!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2D3748),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 36),

                // Contact admin card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.support_agent_outlined,
                          size: 32, color: AppColors.primary),
                      const SizedBox(height: 10),
                      Text(
                        'Contact Administrator',
                        style: AppTextStyles.h3.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Reach out to your society administrator or the platform support team to renew your subscription.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Sign out
                OutlinedButton.icon(
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: Color(0xFFCBD5E0)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
