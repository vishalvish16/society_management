import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _identifierFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _obscure = true;
  bool _rememberMe = false;
  bool _formReady = false; // prevents flash before remembered value loads

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  static const _kRememberMe = 'remember_me';
  static const _kRememberMeIdentifier = 'remember_me_identifier';

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    _loadRemembered();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometricAuto());
  }

  Future<void> _loadRemembered() async {
    final storage = ref.read(authProvider.notifier).client.storage;
    final rememberStr = await storage.read(key: _kRememberMe);
    if (rememberStr == 'true') {
      final identifier = await storage.read(key: _kRememberMeIdentifier);
      if (identifier != null && mounted) {
        _identifierCtrl.text = identifier;
        _rememberMe = true;
      }
    }
    if (mounted) {
      setState(() => _formReady = true);
      _animCtrl.forward();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _identifierCtrl.dispose();
    _passCtrl.dispose();
    _identifierFocus.dispose();
    _passFocus.dispose();
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
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final identifier = _identifierCtrl.text.trim();
    final password = _passCtrl.text;

    final societies = await ref.read(authProvider.notifier).checkSocieties(identifier, password);
    if (!mounted) return;

    if (societies == null) return; // invalid creds — error shown by provider

    if (societies.isEmpty) {
      // Single society — already logged in
      await _saveRememberMe(identifier);
      if (!mounted) return;
      _routeByRole(ref.read(authProvider).user?.role ?? '');
      return;
    }

    // Multiple societies — show picker
    _showSocietyPicker(societies, identifier, password);
  }

  void _showSocietyPicker(
    List<Map<String, dynamic>> societies,
    String identifier,
    String password,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SocietyPickerSheet(
        societies: societies,
        onSelect: (userId) async {
          Navigator.of(ctx).pop();
          final success = await ref
              .read(authProvider.notifier)
              .loginWithUserId(identifier, password, userId);
          if (!mounted) return;
          if (success) {
            await _saveRememberMe(identifier);
            if (!mounted) return;
            _routeByRole(ref.read(authProvider).user?.role ?? '');
          }
        },
      ),
    );
  }

  Future<void> _saveRememberMe(String identifier) async {
    final storage = ref.read(authProvider.notifier).client.storage;
    if (_rememberMe) {
      await storage.write(key: _kRememberMe, value: 'true');
      await storage.write(key: _kRememberMeIdentifier, value: identifier);
    } else {
      await storage.write(key: _kRememberMe, value: 'false');
      await storage.delete(key: _kRememberMeIdentifier);
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
    final isWide = MediaQuery.of(context).size.width >= 768;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: isWide ? _buildWeb() : _buildMobile(),
        ),
      ),
    );
  }

  Widget _buildWeb() {
    return Row(
      children: [
        // Left branding panel
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
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusLg),
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
        // Right form panel
        Expanded(
          flex: 6,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _formReady ? _buildForm(isMobile: false) : const SizedBox(),
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
        Icon(icon,
            color: AppColors.textOnPrimary.withValues(alpha: 0.8), size: 16),
        const SizedBox(width: AppDimensions.sm),
        Text(text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textOnPrimary.withValues(alpha: 0.8),
            )),
      ],
    );
  }

  Widget _buildMobile() {
    if (!_formReady) {
      return const Center(child: CircularProgressIndicator());
    }
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.screenPadding, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // App icon
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusLg),
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 72,
                  height: 72,
                  errorBuilder: (ctx, err, st) => Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusLg),
                    ),
                    child: const Icon(Icons.apartment_rounded,
                        color: AppColors.textOnPrimary, size: 40),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              Text('Society Manager', style: AppTextStyles.displayMedium),
              const SizedBox(height: AppDimensions.xs),
              Text(
                'Sign in to your account',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppDimensions.xxxl),
              _buildForm(isMobile: true),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm({required bool isMobile}) {
    final authState = ref.watch(authProvider);
    final bioState = ref.watch(biometricProvider);
    final showBiometric =
        isMobile && bioState.isAvailable && bioState.isEnabled;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Identifier field ─────────────────────────────────────
          AppTextField(
            label: 'Phone or Email',
            controller: _identifierCtrl,
            focusNode: _identifierFocus,
            hint: 'Enter your phone or email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_passFocus),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: AppDimensions.lg),

          // ── Password field ───────────────────────────────────────
          AppTextField(
            label: 'Password',
            controller: _passCtrl,
            focusNode: _passFocus,
            hint: 'Enter your password',
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => authState.isLoading ? null : _login(),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Required' : null,
            suffixIcon: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: AppDimensions.md),

          // ── Remember Me + Forgot Password row ───────────────────
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 22,
                      width: 22,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (val) =>
                            setState(() => _rememberMe = val ?? false),
                        activeColor: AppColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Text('Remember me',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go('/forgot'),
                child: Text(
                  'Forgot Password?',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xxl),

          // ── Error banner ─────────────────────────────────────────
          if (authState.error != null) ...[
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.dangerSurface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.danger, size: 16),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(
                        authState.error!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.dangerText),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.md),
          ],

          // ── Sign In button ───────────────────────────────────────
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: authState.isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.6),
                foregroundColor: AppColors.textOnPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
              child: authState.isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.textOnPrimary),
                    )
                  : Text('Sign In', style: AppTextStyles.buttonLarge),
            ),
          ),

          // ── Biometric button (mobile only) ───────────────────────
          if (showBiometric) ...[
            const SizedBox(height: AppDimensions.md),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: authState.isLoading ? null : _doBiometricLogin,
                icon: const Icon(Icons.fingerprint_rounded, size: 22),
                label: const Text('Use Biometrics'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Society picker bottom sheet — shown when one phone is in multiple societies
// ─────────────────────────────────────────────────────────────────────────────
class _SocietyPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> societies;
  final void Function(String userId) onSelect;

  const _SocietyPickerSheet({
    required this.societies,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.apartment_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Society',
                        style: AppTextStyles.h2),
                    Text('Your number is registered in multiple societies',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Society tiles
          ...societies.map((s) {
            final name = s['societyName'] as String? ?? 'Society';
            final role = (s['role'] as String? ?? '').replaceAll('_', ' ');
            final unit = s['unitCode'] as String?;
            final userId = s['userId'] as String;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => onSelect(userId),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.surfaceVariant,
                  ),
                  child: Row(
                    children: [
                      // Society initial avatar
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySurface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(role,
                                      style: AppTextStyles.labelSmall.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600)),
                                ),
                                if (unit != null) ...[
                                  const SizedBox(width: 6),
                                  Text('· Unit $unit',
                                      style: AppTextStyles.labelSmall
                                          .copyWith(color: AppColors.textMuted)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
