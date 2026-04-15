import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/biometric_provider.dart';
import '../../../shared/widgets/app_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = false;

  static const _kRememberMe = 'remember_me';
  static const _kRememberMeIdentifier = 'remember_me_identifier';

  @override
  void initState() {
    super.initState();
    _loadRemembered();
    // Auto-trigger biometric on open if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometricAuto());
  }

  Future<void> _loadRemembered() async {
    final bioClient = ref.read(authProvider.notifier).client; // Need access to storage
    final rememberStr = await bioClient.storage.read(key: _kRememberMe);
    if (rememberStr == 'true') {
      final identifier = await bioClient.storage.read(key: _kRememberMeIdentifier);
      if (identifier != null && mounted) {
        setState(() {
          _identifierCtrl.text = identifier;
          _rememberMe = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _routeByRole(String role) {
    if (role.toUpperCase() == 'SUPER_ADMIN') {
      context.go('/sa-dashboard');
    } else {
      context.go('/dashboard');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authProvider.notifier).login(
      _identifierCtrl.text.trim(),
      _passCtrl.text,
    );
    if (!mounted) return;
    if (success) {
      final bioClient = ref.read(authProvider.notifier).client;
      if (_rememberMe) {
        await bioClient.storage.write(key: _kRememberMe, value: 'true');
        await bioClient.storage.write(key: _kRememberMeIdentifier, value: _identifierCtrl.text.trim());
      } else {
        await bioClient.storage.write(key: _kRememberMe, value: 'false');
        await bioClient.storage.delete(key: _kRememberMeIdentifier);
      }
      _routeByRole(ref.read(authProvider).user?.role ?? '');
    }
  }

  Future<void> _tryBiometricAuto() async {
    final bio = ref.read(biometricProvider);
    if (!bio.isEnabled || bio.isChecking) return;
    await _doBiometricLogin();
  }

  Future<void> _doBiometricLogin() async {
    final creds = await ref.read(biometricProvider.notifier).authenticate();
    if (creds == null || !mounted) return;
    final (identifier, password) = creds;
    final success =
        await ref.read(authProvider.notifier).login(identifier, password);
    if (!mounted) return;
    if (success) _routeByRole(ref.read(authProvider).user?.role ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: isWide ? _buildWeb(authState) : _buildMobile(authState)),
    );
  }

  Widget _buildWeb(AuthState authState) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            color: AppColors.primary,
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  ),
                  child: const Icon(Icons.apartment_rounded,
                      color: AppColors.textOnPrimary, size: 32),
                ),
                const SizedBox(height: AppDimensions.xxl),
                Text('Society Manager',
                    style: AppTextStyles.displayLarge
                        .copyWith(color: AppColors.textOnPrimary)),
                const SizedBox(height: AppDimensions.md),
                Text(
                  'Complete society management\nfor modern residential communities.',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: AppDimensions.xxxl),
                _pill(Icons.receipt_long_rounded, 'Billing & Payments'),
                const SizedBox(height: AppDimensions.sm),
                _pill(Icons.security_rounded, 'Visitor & Gate Management'),
                const SizedBox(height: AppDimensions.sm),
                _pill(Icons.people_rounded, 'Resident Management'),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _buildForm(authState, isMobile: false),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pill(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textOnPrimary.withValues(alpha: 0.8), size: 16),
        const SizedBox(width: AppDimensions.sm),
        Text(text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textOnPrimary.withValues(alpha: 0.8),
            )),
      ],
    );
  }

  Widget _buildMobile(AuthState authState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.screenPadding),
      child: Column(
        children: [
          const SizedBox(height: AppDimensions.xxxl),
          // App icon
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            child: Image.asset('assets/app_icon.png', width: 72, height: 72,
                errorBuilder: (context, error, stack) => Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  ),
                  child: const Icon(Icons.apartment_rounded,
                      color: AppColors.textOnPrimary, size: 40),
                )),
          ),
          const SizedBox(height: AppDimensions.lg),
          Text('Vidyron Society', style: AppTextStyles.displayMedium),
          const SizedBox(height: AppDimensions.xs),
          Text('Sign in to your account',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppDimensions.xxxl),
          _buildForm(authState, isMobile: true),
        ],
      ),
    );
  }

  Widget _buildForm(AuthState authState, {required bool isMobile}) {
    final bioState = ref.watch(biometricProvider);
    final showBiometric = isMobile && bioState.isAvailable && bioState.isEnabled;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Phone or Email',
            controller: _identifierCtrl,
            hint: 'Enter your phone or email',
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: AppDimensions.lg),
          AppTextField(
            label: 'Password',
            controller: _passCtrl,
            hint: 'Enter your password',
            obscureText: _obscure,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.textMuted,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (val) => setState(() => _rememberMe = val ?? false),
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              GestureDetector(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: Text('Remember Me', style: AppTextStyles.bodySmall),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),
          if (authState.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.lg),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.dangerSurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(authState.error!,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.dangerText)),
                    ),
                  ],
                ),
              ),
            ),
          // ── Sign In button ──────────────────────────────────────
          ElevatedButton(
            onPressed: authState.isLoading ? null : _login,
            child: authState.isLoading
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.textOnPrimary))
                : Text('Sign In', style: AppTextStyles.buttonLarge),
          ),

          // ── Biometric button (mobile only) ──────────────────────
          if (showBiometric) ...[
            const SizedBox(height: AppDimensions.md),
            OutlinedButton.icon(
              onPressed: authState.isLoading ? null : _doBiometricLogin,
              icon: const Icon(Icons.fingerprint_rounded, size: 22),
              label: const Text('Sign in with Biometrics'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
            ),
          ],

          const SizedBox(height: AppDimensions.lg),
          TextButton(
            onPressed: () => context.go('/forgot'),
            child: Text('Forgot Password?',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
