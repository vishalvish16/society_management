import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/payment_settings_provider.dart';

class PaymentSettingsScreen extends ConsumerStatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  ConsumerState<PaymentSettingsScreen> createState() =>
      _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState
    extends ConsumerState<PaymentSettingsScreen> with SingleTickerProviderStateMixin {

  late TabController _tabController;

  // UPI
  final _upiIdCtrl = TextEditingController();
  final _upiNameCtrl = TextEditingController();
  // Bank
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();
  // Note
  final _noteCtrl = TextEditingController();
  // Razorpay
  final _rzpKeyIdCtrl = TextEditingController();
  final _rzpKeySecretCtrl = TextEditingController();
  bool _secretObscured = true;

  String _activeGateway = 'none'; // 'none' | 'razorpay'
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _upiIdCtrl.dispose();
    _upiNameCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ifscCtrl.dispose();
    _accountHolderCtrl.dispose();
    _noteCtrl.dispose();
    _rzpKeyIdCtrl.dispose();
    _rzpKeySecretCtrl.dispose();
    super.dispose();
  }

  void _populate(PaymentSettings s) {
    if (_loaded) return;
    _upiIdCtrl.text = s.upiId ?? '';
    _upiNameCtrl.text = s.upiName ?? '';
    _bankNameCtrl.text = s.bankName ?? '';
    _accountNumberCtrl.text = s.accountNumber ?? '';
    _ifscCtrl.text = s.ifscCode ?? '';
    _accountHolderCtrl.text = s.accountHolderName ?? '';
    _noteCtrl.text = s.paymentNote ?? '';
    _rzpKeyIdCtrl.text = s.razorpayKeyId ?? '';
    _activeGateway = s.activeGateway ?? 'none';
    _loaded = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final data = <String, dynamic>{
      // UPI
      'upiId': _upiIdCtrl.text.trim(),
      'upiName': _upiNameCtrl.text.trim(),
      // Bank
      'bankName': _bankNameCtrl.text.trim(),
      'accountNumber': _accountNumberCtrl.text.trim(),
      'ifscCode': _ifscCtrl.text.trim().toUpperCase(),
      'accountHolderName': _accountHolderCtrl.text.trim(),
      // Note
      'paymentNote': _noteCtrl.text.trim(),
      // Gateway
      'activeGateway': _activeGateway == 'none' ? null : _activeGateway,
      'razorpayKeyId': _rzpKeyIdCtrl.text.trim(),
    };

    // Only send secret if user typed something (not empty placeholder)
    final secret = _rzpKeySecretCtrl.text.trim();
    if (secret.isNotEmpty) data['razorpayKeySecret'] = secret;

    final error = await ref.read(paymentSettingsProvider.notifier).save(data);

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? 'Payment settings saved successfully'),
        backgroundColor: error == null ? AppColors.success : AppColors.danger,
      ));
      if (error == null) {
        // Clear secret field after save
        _rzpKeySecretCtrl.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(paymentSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Payment Settings',
            style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.textOnPrimary,
          labelColor: AppColors.textOnPrimary,
          unselectedLabelColor: AppColors.textOnPrimary.withValues(alpha: 0.6),
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_rounded, size: 18), text: 'UPI'),
            Tab(icon: Icon(Icons.account_balance_outlined, size: 18), text: 'Bank'),
            Tab(icon: Icon(Icons.payment_rounded, size: 18), text: 'Gateway'),
          ],
        ),
      ),
      body: settingsAsync.when(
        loading: () => const AppLoadingShimmer(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            child: AppCard(
              backgroundColor: AppColors.dangerSurface,
              child: Text('Error: $e',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.dangerText)),
            ),
          ),
        ),
        data: (settings) {
          _populate(settings);
          return Column(
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _upiTab(),
                    _bankTab(),
                    _gatewayTab(settings),
                  ],
                ),
              ),
              // Save button pinned at bottom
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.screenPadding,
                    AppDimensions.sm,
                    AppDimensions.screenPadding,
                    AppDimensions.md,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'Saving…' : 'Save All Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        textStyle: AppTextStyles.buttonLarge,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Tab 1: UPI ─────────────────────────────────────────────────────────────

  Widget _upiTab() => SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoBanner(
              'Members will see this UPI ID and can copy it to pay from any UPI app.',
            ),
            const SizedBox(height: AppDimensions.lg),
            AppTextField(
              label: 'UPI ID',
              controller: _upiIdCtrl,
              hint: 'e.g. society@upi or 9876543210@paytm',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppDimensions.md),
            AppTextField(
              label: 'UPI Display Name',
              controller: _upiNameCtrl,
              hint: 'e.g. Sunshine Society',
            ),
            const SizedBox(height: AppDimensions.xl),
            _sectionHeader(Icons.notes_outlined, 'Payment Note'),
            const SizedBox(height: AppDimensions.md),
            AppTextField(
              label: 'Note for members (optional)',
              controller: _noteCtrl,
              hint: 'e.g. Add your flat number in the payment remarks',
              maxLines: 2,
            ),
          ],
        ),
      );

  // ── Tab 2: Bank ────────────────────────────────────────────────────────────

  Widget _bankTab() => SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoBanner(
              'Bank details are shown to members as an alternative payment method.',
            ),
            const SizedBox(height: AppDimensions.lg),
            AppTextField(
              label: 'Account Holder Name',
              controller: _accountHolderCtrl,
              hint: 'e.g. Sunshine CHS',
            ),
            const SizedBox(height: AppDimensions.md),
            AppTextField(
              label: 'Bank Name',
              controller: _bankNameCtrl,
              hint: 'e.g. SBI, HDFC, ICICI',
            ),
            const SizedBox(height: AppDimensions.md),
            AppTextField(
              label: 'Account Number',
              controller: _accountNumberCtrl,
              keyboardType: TextInputType.number,
              hint: 'Enter account number',
            ),
            const SizedBox(height: AppDimensions.md),
            AppTextField(
              label: 'IFSC Code',
              controller: _ifscCtrl,
              hint: 'e.g. SBIN0001234',
            ),
          ],
        ),
      );

  // ── Tab 3: Gateway ─────────────────────────────────────────────────────────

  Widget _gatewayTab(PaymentSettings settings) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoBanner(
              'Connect a payment gateway so members can pay directly inside the app. '
              'Payments are verified automatically — no manual UTR entry needed.',
            ),
            const SizedBox(height: AppDimensions.lg),

            // ── Active gateway selector ───────────────────────────────
            _sectionHeader(Icons.toggle_on_outlined, 'Active Gateway'),
            const SizedBox(height: AppDimensions.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _gatewayTile(
                    value: 'none',
                    label: 'No gateway (UPI / Bank only)',
                    subtitle: 'Members pay manually via UPI ID or bank transfer',
                    icon: Icons.block_rounded,
                    iconColor: AppColors.textMuted,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _gatewayTile(
                    value: 'razorpay',
                    label: 'Razorpay',
                    subtitle: 'UPI, Cards, Net Banking — payments confirmed automatically',
                    icon: Icons.bolt_rounded,
                    iconColor: const Color(0xFF2D81F7),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.xl),

            // ── Razorpay keys (shown only when razorpay selected) ─────
            if (_activeGateway == 'razorpay') ...[
              _sectionHeader(Icons.vpn_key_outlined, 'Razorpay API Keys'),
              const SizedBox(height: AppDimensions.xs),
              AppCard(
                backgroundColor: AppColors.primarySurface,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary, size: 16),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(
                        'Get your keys from Razorpay Dashboard → Settings → API Keys. '
                        'Use Test keys (rzp_test_…) for testing, Live keys for production.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.md),

              // Key ID
              TextField(
                controller: _rzpKeyIdCtrl,
                decoration: InputDecoration(
                  labelText: 'Key ID *',
                  hintText: 'rzp_test_xxxxxxxxxxxx or rzp_live_xxxxxxxxxxxx',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: _rzpKeyIdCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: 'Copy Key ID',
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: _rzpKeyIdCtrl.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Key ID copied'),
                                  duration: Duration(seconds: 1)),
                            );
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: AppDimensions.md),

              // Key Secret
              TextField(
                controller: _rzpKeySecretCtrl,
                obscureText: _secretObscured,
                decoration: InputDecoration(
                  labelText: 'Key Secret *',
                  hintText: settings.razorpayKeyId?.isNotEmpty == true
                      ? '••••••••••••••••  (leave blank to keep existing)'
                      : 'Enter your Razorpay Key Secret',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_secretObscured
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded),
                    onPressed: () =>
                        setState(() => _secretObscured = !_secretObscured),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.xs),
              Row(
                children: [
                  const Icon(Icons.security_rounded,
                      size: 12, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'Key Secret is stored securely on the server and never sent to members.',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.xl),

              // Status card
              if (settings.hasRazorpay)
                AppCard(
                  backgroundColor: AppColors.successSurface,
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 18),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Razorpay is active',
                                style: AppTextStyles.labelMedium
                                    .copyWith(color: AppColors.successText)),
                            Text(
                              'Key ID: ${settings.razorpayKeyId}',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.successText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                AppCard(
                  backgroundColor: AppColors.warningSurface,
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning, size: 18),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        child: Text(
                          'Enter both Key ID and Key Secret and save to activate Razorpay.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.warningText),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      );

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _gatewayTile({
    required String value,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    final selected = _activeGateway == value;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(label, style: AppTextStyles.bodyMedium),
      subtitle: Text(subtitle,
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
      trailing: selected
          ? const Icon(Icons.radio_button_checked_rounded,
              color: AppColors.primary)
          : const Icon(Icons.radio_button_off_rounded,
              color: AppColors.border),
      onTap: () => setState(() => _activeGateway = value),
    );
  }

  Widget _sectionHeader(IconData icon, String title) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppDimensions.sm),
          Text(title,
              style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
        ],
      );

  Widget _infoBanner(String text) => AppCard(
        backgroundColor: AppColors.primarySurface,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.primary, size: 16),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(text,
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
            ),
          ],
        ),
      );
}
