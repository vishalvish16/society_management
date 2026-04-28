import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_searchable_dropdown.dart';
import '../../../shared/widgets/app_success_dialog.dart';
import '../../settings/providers/payment_settings_provider.dart';
import '../providers/donation_provider.dart';
import '../../bills/screens/razorpay_web_stub.dart' if (dart.library.html) '../../bills/screens/razorpay_web.dart';

enum _Step { choose, upiLaunched, upiConfirm }

void showDonateSheet(BuildContext context, {String? campaignId, String? campaignTitle}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
    ),
    builder: (_) => _DonateSheet(campaignId: campaignId, campaignTitle: campaignTitle),
  );
}

class _DonateSheet extends ConsumerStatefulWidget {
  final String? campaignId;
  final String? campaignTitle;
  const _DonateSheet({this.campaignId, this.campaignTitle});

  @override
  ConsumerState<_DonateSheet> createState() => _DonateSheetState();
}

class _DonateSheetState extends ConsumerState<_DonateSheet> {
  _Step _step = _Step.choose;
  String _manualMethod = 'CASH';
  final _amountCtrl = TextEditingController();
  final _utrCtrl = TextEditingController();
  final _manualNotesCtrl = TextEditingController();
  bool _isSubmitting = false;

  Razorpay? _razorpay;

  static const _adminManualMethods = ['CASH', 'BANK_TRANSFER', 'CHEQUE', 'OTHER'];

  @override
  void initState() {
    super.initState();
    // Refresh latest payment settings whenever the sheet opens
    Future.microtask(
        () => ref.read(paymentSettingsProvider.notifier).fetch(showLoading: false));
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _amountCtrl.dispose();
    _utrCtrl.dispose();
    _manualNotesCtrl.dispose();
    super.dispose();
  }

  bool get _isAdmin {
    final role = ref.read(authProvider).user?.role.toUpperCase() ?? '';
    return role == 'PRAMUKH' || role == 'CHAIRMAN';
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : null,
    ));
  }

  Future<void> _launchRazorpay(PaymentSettings ps) async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) { _showSnack('Enter a valid amount first'); return; }

    setState(() => _isSubmitting = true);

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('payments/create-donation-order', data: {
        'amount': amount,
        'campaignId': widget.campaignId,
      });

      if (res.data['success'] != true) {
        _showSnack(res.data['message'] ?? 'Could not create order', isError: true);
        setState(() => _isSubmitting = false);
        return;
      }

      final orderData = res.data['data'];
      final orderId = orderData['orderId'] as String;
      final orderAmount = orderData['amount'] as int;
      final user = ref.read(authProvider).user;

      final options = <String, dynamic>{
        'key': ps.razorpayKeyId,
        'order_id': orderId,
        'amount': orderAmount,
        'currency': 'INR',
        'name': ps.upiName?.isNotEmpty == true ? ps.upiName : 'Society',
        'description': widget.campaignTitle != null ? 'Donation: ${widget.campaignTitle}' : 'Society Donation',
        'prefill': {
          'name': user?.name ?? '',
          'contact': user?.phone ?? '',
        },
        'theme': {'color': '#1565C0'},
      };

      setState(() => _isSubmitting = false);

      if (kIsWeb) {
        openRazorpayWeb(
          options: options,
          onSuccess: (paymentId, rzpOrderId, signature) =>
              _verifyAndRecord(paymentId, rzpOrderId, signature, amount),
          onError: (msg) => _showSnack(msg, isError: true),
        );
      } else {
        _razorpay?.clear();
        _razorpay = Razorpay();
        _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
            _verifyAndRecord(
            response.paymentId ?? '',
            response.orderId ?? '',
            response.signature ?? '',
            amount,
            );
        });
        _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
             if (mounted) _showSnack(response.message ?? 'Payment failed or cancelled', isError: true);
        });
        _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
            if (mounted) _showSnack('External wallet: ${response.walletName}');
        });
        options['send_sms_hash'] = true;
        options['remember_customer'] = false;
        _razorpay!.open(options);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _verifyAndRecord(String paymentId, String rzpOrderId, String signature, double amount) async {
    setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('payments/verify-donation', data: {
        'razorpayOrderId': rzpOrderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
        'amount': amount,
        'campaignId': widget.campaignId,
        'note': widget.campaignTitle != null ? 'For ${widget.campaignTitle}' : null,
      });

      ref.read(donationsProvider.notifier).fetchDonations();
      ref.invalidate(donationCampaignsProvider);

      if (mounted) {
        setState(() => _isSubmitting = false);
        final nav = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        nav.pop();
        if (res.data['success'] == true) {
          _showSuccessDialog(amount, 'Payment ID: $paymentId', nav: nav, messenger: messenger);
        } else {
          messenger.showSnackBar(SnackBar(
            content: Text(res.data['message'] ?? 'Verification failed'),
            backgroundColor: AppColors.danger,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnack('Verification error: $e', isError: true);
      }
    }
  }

  Uri _buildUpiUri(PaymentSettings ps, double amount) => Uri(
        scheme: 'upi',
        host: 'pay',
        queryParameters: {
          'pa': ps.upiId!,
          'pn': ps.upiName?.isNotEmpty == true ? ps.upiName! : 'Society',
          'am': amount.toStringAsFixed(2),
          'cu': 'INR',
          'tn': widget.campaignTitle != null ? 'Donation - ${widget.campaignTitle}' : 'Society Donation',
        },
      );

  Future<void> _launchUpi() async {
    final ps = ref.read(paymentSettingsProvider).value;
    if (ps == null) return;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) { _showSnack('Enter a valid amount first'); return; }
    
    final uri = _buildUpiUri(ps, amount);
    final canLaunch = await canLaunchUrl(uri);
    if (!canLaunch) {
      if (mounted) _showSnack('No UPI app found. Install GPay, PhonePe, or Paytm.', isError: true);
      return;
    }
    setState(() => _step = _Step.upiLaunched);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submitUpi() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) { _showSnack('Enter a valid amount'); return; }
    final utr = _utrCtrl.text.trim();
    if (utr.isEmpty) { _showSnack('Enter the UPI Transaction ID / UTR'); return; }
    await _recordPayment(amount, 'UPI', 'UTR: $utr');
  }

  Future<void> _submitManual() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) { _showSnack('Enter a valid amount'); return; }
    final notes = _manualNotesCtrl.text.trim();
    await _recordPayment(amount, _manualMethod, notes.isEmpty ? null : notes);
  }

  Future<void> _recordPayment(double amount, String method, String? notes) async {
    setState(() => _isSubmitting = true);
    final error = await ref.read(donationsProvider.notifier).makeDonation({
      'amount': amount,
      'paymentMethod': method,
      'campaignId': widget.campaignId,
      'note': notes,
    });
    
    ref.invalidate(donationCampaignsProvider);
    
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    nav.pop();

    if (error == null) {
      _showSuccessDialog(amount, notes ?? '', nav: nav, messenger: messenger);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.danger));
    }
  }

  void _showSuccessDialog(
    double amount,
    String reference, {
    required NavigatorState nav,
    required ScaffoldMessengerState messenger,
  }) {
    showDialog(
      context: nav.context,
      barrierDismissible: false,
      builder: (ctx) => AppSuccessDialog(
        title: 'Donation Recorded!',
        subtitle: '₹${NumberFormat('#,##0').format(amount)}',
        referenceText: reference,
        doneLabel: 'Done',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final psAsync = ref.watch(paymentSettingsProvider);
    final isAdmin = _isAdmin;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.screenPadding, AppDimensions.lg, AppDimensions.screenPadding,
        MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: AppDimensions.lg),
            
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                  child: const Icon(Icons.volunteer_activism, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Make Donation', style: AppTextStyles.h2),
                      if (widget.campaignTitle != null)
                        Text(widget.campaignTitle!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.lg),

            if (_step == _Step.choose)
              psAsync.when(
                loading: () => const Padding(padding: EdgeInsets.all(AppDimensions.xl), child: Center(child: CircularProgressIndicator())),
                error: (_, _) => _noPaymentConfigured(isAdmin),
                data: (ps) {
                  if (!ps.hasAny && !isAdmin) return _noPaymentConfigured(false);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Amount (₹) *', prefixText: '₹'),
                      ),
                      const SizedBox(height: AppDimensions.lg),

                      if (ps.hasRazorpay) ...[
                        Text('Pay Online', style: AppTextStyles.labelLarge.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(height: AppDimensions.sm),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _isSubmitting ? null : () => _launchRazorpay(ps),
                            icon: _isSubmitting 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.payment_rounded),
                            label: const Text('Pay with Card / UPI / NetBanking'),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.lg),
                      ],

                      if (ps.hasUpi && !ps.hasRazorpay) ...[
                        Text('Pay via UPI App', style: AppTextStyles.labelLarge.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(height: AppDimensions.sm),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _launchUpi,
                            icon: const Icon(Icons.account_balance_wallet_rounded),
                            label: const Text('Open UPI App'),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.lg),
                      ],

                      if (isAdmin) ...[
                        const Row(children: [
                          Expanded(child: Divider()),
                          Padding(padding: EdgeInsets.symmetric(horizontal: AppDimensions.sm), child: Text('Admin: Record offline donation', style: TextStyle(fontSize: 12, color: AppColors.textMuted))),
                          Expanded(child: Divider()),
                        ]),
                        const SizedBox(height: AppDimensions.lg),
                        AppSearchableDropdown<String>(
                          label: 'Payment Method',
                          value: _manualMethod,
                          items: _adminManualMethods.map((m) => AppDropdownItem(value: m, label: m.replaceAll('_', ' '))).toList(),
                          onChanged: (v) { if (v != null) setState(() => _manualMethod = v); },
                        ),
                        const SizedBox(height: AppDimensions.md),
                        TextField(controller: _manualNotesCtrl, decoration: const InputDecoration(labelText: 'Reference / Notes (Optional)')),
                        const SizedBox(height: AppDimensions.lg),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _isSubmitting ? null : _submitManual,
                            icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.edit_note_rounded),
                            label: const Text('Record Offline Donation'),
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary, side: const BorderSide(color: AppColors.border)),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),

            if (_step == _Step.upiLaunched)
              AppCard(
                backgroundColor: AppColors.primarySurface,
                child: Column(
                  children: [
                    const SizedBox(height: AppDimensions.md),
                    const Icon(Icons.open_in_new_rounded, color: AppColors.primary, size: 40),
                    const SizedBox(height: AppDimensions.md),
                    Text('Complete payment in your UPI app', style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                    const SizedBox(height: AppDimensions.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => setState(() => _step = _Step.upiConfirm),
                        child: const Text('I have paid — Enter details'),
                      ),
                    ),
                    TextButton(onPressed: () => setState(() => _step = _Step.choose), child: const Text('Cancel')),
	    const SizedBox(height: AppDimensions.sm),
                  ],
                ),
              ),

            if (_step == _Step.upiConfirm) ...[
              AppCard(
                backgroundColor: AppColors.successSurface,
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 20),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(child: Text('Payment done in UPI app — enter details.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.successText))),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              TextField(
                controller: _utrCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'UPI Transaction ID / UTR *', hintText: 'e.g. 402912345678', prefixIcon: Icon(Icons.tag_rounded)),
              ),
              const SizedBox(height: AppDimensions.xl),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = _Step.choose), child: const Text('Back'))),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submitUpi,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                      child: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Confirm Payment'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _noPaymentConfigured(bool isAdmin) {
    if (!isAdmin) {
      return AppCard(
        backgroundColor: AppColors.warningSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.info_outline, color: AppColors.warning, size: 18),
              SizedBox(width: AppDimensions.sm),
              Text('Payment not set up yet', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.warningText)),
            ]),
            const SizedBox(height: AppDimensions.xs),
            Text('Payment details haven\'t been configured yet. Please contact your society admin.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.warningText)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          backgroundColor: AppColors.warningSurface,
          child: Row(children: [
            const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
            const SizedBox(width: AppDimensions.sm),
            Expanded(child: Text('No payment method configured. Admin can record offline manually.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.warningText))),
          ]),
        ),
        const SizedBox(height: AppDimensions.lg),
        AppSearchableDropdown<String>(
          label: 'Payment Method',
          value: _manualMethod,
          items: _adminManualMethods.map((m) => AppDropdownItem(value: m, label: m.replaceAll('_', ' '))).toList(),
          onChanged: (v) { if (v != null) setState(() => _manualMethod = v); },
        ),
        const SizedBox(height: AppDimensions.md),
        TextField(controller: _amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount Paid (₹) *', prefixText: '₹')),
        const SizedBox(height: AppDimensions.md),
        TextField(controller: _manualNotesCtrl, decoration: const InputDecoration(labelText: 'Reference / Notes (Optional)')),
        const SizedBox(height: AppDimensions.lg),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _submitManual,
            icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.edit_note_rounded),
            label: const Text('Record Offline Donation'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary, side: const BorderSide(color: AppColors.border)),
          ),
        ),
      ],
    );
  }
}
