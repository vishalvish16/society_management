import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/biometric_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/confirm_logout.dart';
import 'payment_settings_screen.dart';
import 'profile_screen.dart';
import '../../../shared/widgets/show_app_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final user = ref.watch(authProvider).user;
    final role = user?.role.toUpperCase() ?? '';
    final isAdmin =
        role == 'PRAMUKH' || role == 'CHAIRMAN' || role == 'SECRETARY';
    final bioState = ref.watch(biometricProvider);
    final isMobile = !kIsWeb;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: null, // Shells (SAShell/SMShell) provide the header
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile card ───────────────────────────────────────────
            if (user != null)
              AppCard(
                padding: const EdgeInsets.all(AppDimensions.lg),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primarySurface,
                        backgroundImage: AppConstants.uploadUrlFromPath(user.profilePhotoUrl) != null
                            ? NetworkImage(
                                AppConstants.uploadUrlFromPath(user.profilePhotoUrl)!,
                              )
                            : null,
                        child: AppConstants.uploadUrlFromPath(user.profilePhotoUrl) == null
                            ? Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                style: AppTextStyles.h2.copyWith(color: AppColors.primary),
                              )
                            : null,
                      ),
                      const SizedBox(width: AppDimensions.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name, style: AppTextStyles.h3),
                            const SizedBox(height: AppDimensions.xs),
                            Text(user.role.toLowerCase(),
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textMuted)),
                            const SizedBox(height: AppDimensions.xs),
                            Text(
                              'Tap to edit profile · ${user.profileCompletenessPercent}% complete',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.primary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppDimensions.lg),

            // ── Appearance ─────────────────────────────────────────────
            Text('Appearance',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppDimensions.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text('Dark Mode', style: AppTextStyles.bodyMedium),
                    subtitle: Text(
                      isDark ? 'Dark theme is on' : 'Light theme is on',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                    value: isDark,
                    onChanged: (val) =>
                        ref.read(themeModeProvider.notifier).state =
                            val ? ThemeMode.dark : ThemeMode.light,
                    activeThumbColor: AppColors.primary,
                  ),
                  const Divider(
                      height: 1,
                      indent: AppDimensions.lg,
                      endIndent: AppDimensions.lg),
                  ListTile(
                    leading: const Icon(Icons.brightness_auto_rounded,
                        color: AppColors.primary),
                    title:
                        Text('System Theme', style: AppTextStyles.bodyMedium),
                    subtitle: Text('Follow device setting',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted)),
                    trailing: themeMode == ThemeMode.system
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.primary)
                        : null,
                    onTap: () =>
                        ref.read(themeModeProvider.notifier).state =
                            ThemeMode.system,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.lg),

            // ── Security (mobile only) ─────────────────────────────────
            if (isMobile) ...[
              Text('Security',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppDimensions.sm),
              AppCard(
                padding: EdgeInsets.zero,
                child: bioState.isChecking
                    ? const ListTile(
                        leading: Icon(Icons.fingerprint_rounded,
                            color: AppColors.primary),
                        title: Text('Biometric Login'),
                        trailing: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : !bioState.isAvailable
                        ? ListTile(
                            leading: const Icon(Icons.fingerprint_rounded,
                                color: AppColors.textMuted),
                            title: Text('Biometric Login',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: AppColors.textMuted)),
                            subtitle: Text(
                              'Not available on this device',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textMuted),
                            ),
                          )
                        : SwitchListTile(
                            secondary: Icon(
                              Icons.fingerprint_rounded,
                              color: bioState.isEnabled
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                            title: Text('Biometric Login',
                                style: AppTextStyles.bodyMedium),
                            subtitle: Text(
                              bioState.isEnabled
                                  ? 'Use fingerprint or face to sign in'
                                  : 'Sign in faster with biometrics',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textMuted),
                            ),
                            value: bioState.isEnabled,
                            onChanged: (val) => val
                                ? _enableBiometric(context, ref)
                                : _disableBiometric(context, ref),
                            activeThumbColor: AppColors.primary,
                          ),
              ),
              const SizedBox(height: AppDimensions.lg),
            ],

            // ── Society (admin only) ───────────────────────────────────
            if (isAdmin) ...[
              Text('Society',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppDimensions.sm),
              AppCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined,
                      color: AppColors.primary),
                  title: Text('Payment Settings',
                      style: AppTextStyles.bodyMedium),
                  subtitle: Text('UPI, bank details & payment gateway',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PaymentSettingsScreen())),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
            ],

            // ── Account ────────────────────────────────────────────────
            Text('Account',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppDimensions.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded,
                        color: AppColors.primary),
                    title: Text('Change Password',
                        style: AppTextStyles.bodyMedium),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
                    onTap: () => _showChangePasswordDialog(context, ref),
                  ),
                  const Divider(
                      height: 1,
                      indent: AppDimensions.lg,
                      endIndent: AppDimensions.lg),
                  ListTile(
                    leading:
                        const Icon(Icons.logout_rounded, color: AppColors.danger),
                    title: Text('Sign Out',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.danger)),
                    onTap: () => _confirmLogout(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Biometric helpers ────────────────────────────────────────────────────

  Future<void> _enableBiometric(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    
    // We need the user's password to store for biometric re-auth.
    // Use the logged-in user's primary identifier (phone or email).
    final identifier = user.phone;

    // Ask them to enter password once to confirm.
    final password = await _showPasswordDialog(context);
    if (password == null) return;

    final error = await ref
        .read(biometricProvider.notifier)
        .enable(identifier, password);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Biometric login enabled'),
      backgroundColor: error == null ? AppColors.success : AppColors.danger,
    ));
  }

  Future<void> _disableBiometric(BuildContext context, WidgetRef ref) async {
    await ref.read(biometricProvider.notifier).disable();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Biometric login disabled'),
    ));
  }

  /// Asks user to re-enter their password to store for biometric use.
  Future<String?> _showPasswordDialog(BuildContext context) async {
    final passwordCtrl = TextEditingController();
    bool obscure = true;

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (builderCtx, setDialogState) => AlertDialog(
          title: const Text('Confirm your password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter your login password to enable biometric sign-in.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final pw = passwordCtrl.text;
                if (pw.isEmpty) return;
                Navigator.pop(dialogCtx, pw);
              },
              child: const Text('Enable'),
            ),
          ],
        ),
      ),
    );
    passwordCtrl.dispose();
    return result;
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showLogoutConfirmSheet(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
    );
    if (!confirm) return;
    await ref.read(authProvider.notifier).logout();
  }

  // ── Change password ──────────────────────────────────────────────────────

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentC = TextEditingController();
    final newC = TextEditingController();
    final confirmC = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showAppSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.screenPadding, AppDimensions.lg,
            AppDimensions.screenPadding,
            MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.xxxl,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: AppDimensions.lg),
                const Text('Change Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: AppDimensions.lg),
                TextFormField(
                  controller: currentC, obscureText: true,
                  decoration: const InputDecoration(labelText: 'Current Password'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppDimensions.md),
                TextFormField(
                  controller: newC, obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
                  validator: (v) => (v == null || v.length < 8) ? 'Min 8 characters' : null,
                ),
                const SizedBox(height: AppDimensions.md),
                TextFormField(
                  controller: confirmC, obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm New Password'),
                  validator: (v) => v != newC.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: AppDimensions.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isLoading ? null : () async {
                      if (formKey.currentState!.validate()) {
                        setState(() => isLoading = true);
                        final error = await ref.read(authProvider.notifier).changePassword(currentC.text, newC.text);
                        if (error == null) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully')));
                        } else {
                          setState(() => isLoading = false);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.danger));
                        }
                      }
                    },
                    child: isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Change Password'),
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
