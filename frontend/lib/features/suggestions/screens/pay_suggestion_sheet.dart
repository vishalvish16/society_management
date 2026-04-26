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
import '../../settings/providers/payment_settings_provider.dart';
import '../providers/suggestions_provider.dart';
import '../../bills/screens/razorpay_web_stub.dart'
    if (dart.library.html) '../../bills/screens/razorpay_web.dart';

enum _Step { choose, upiLaunched, upiConfirm }

void showPaySuggestionSheet(BuildContext context, Map<String, dynamic> suggestion) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
    ),
    builder: (_) => _PaySuggestionSheet(suggestion: suggestion),
  );
}

class _PaySuggestionSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> suggestion;
  const _PaySuggestionSheet({required this.suggestion});

  @override
  ConsumerState<_PaySuggestionSheet> createState() => _PaySuggestionSheetState();
}

class _PaySuggestionSheetState extends ConsumerState<_PaySuggestionSheet> {
  _Step _step = _Step.choose;
  String _manualMethod = 'CASH';
  final _utrCtrl = TextEditingController();
  final _manualNotesCtrl = TextEditingController();
  final _manualAmountCtrl = TextEditingController();
  bool _isSubmitting = false;

  Razorpay? _razorpay;

  static const _adminManualMethods = ['CASH', 'BANK_TRANSFER', 'CHEQUE', 'OTHER'];

  @override
  void initState() {
    super.initState();
    _manualAmountCtrl.text = _remainingAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _utrCtrl.dispose();
    _manualNotesCtrl.dispose();
    _manualAmountCtrl.dispose();
    super.dispose();
  }

  double get _remainingAmount {
    final total = double.tryParse(widget.suggestion['amount']?.toString() ?? '0') ?? 0;
    final paid = double.tryParse(widget.suggestion['paidAmount']?.toString() ?? '0') ?? 0;
    return (total - paid).clamp(0, double.infinity);
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
    final amount = _remainingAmount;
    if (amount <= 0) return;

    setState(() => _isSubmitting = true);

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('payments/create-suggestion-order', data: {
        'suggestionId': widget.suggestion['id'],
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
        'description': 'Suggestion: ${widget.suggestion['title']}',
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
              _verifyAndRecord(paymentId, rzpOrderId, signature),
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
          );
        });
        _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
          if (mounted) _showSnack(response.message ?? 'Payment failed or cancelled', isError: true);
        });
        _razorpay!.open(options);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _verifyAndRecord(String paymentId, String rzpOrderId, String signature) async {
    setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('payments/verify-suggestion', data: {
        'suggestionId': widget.suggestion['id'],
        'razorpayOrderId': rzpOrderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
      });

      ref.read(suggestionsProvider.notifier).loadSuggestions();

      if (mounted) {
        setState(() => _isSubmitting = false);
        final nav = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        nav.pop();
        if (res.data['success'] == true) {
          _showSuccessDialog(_remainingAmount, 'Payment ID: $paymentId', nav: nav, messenger: messenger);
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

  Future<void> _launchUpi() async {
    final ps = ref.read(paymentSettingsProvider).value;
    if (ps == null) return;
    final amount = _remainingAmount;

    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': ps.upiId!,
        'pn': ps.upiName?.isNotEmpty == true ? ps.upiName! : 'Society',
        'am': amount.toStringAsFixed(2),
        'cu': 'INR',
        'tn': 'Suggestion Payment: ${widget.suggestion['title']}',
      },
    );
    final canLaunch = await canLaunchUrl(uri);
    if (!canLaunch) {
      if (mounted) _showSnack('No UPI app found. Install GPay, PhonePe, or Paytm.', isError: true);
      return;
    }
    setState(() => _step = _Step.upiLaunched);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _recordManual() async {
    final amount = double.tryParse(_manualAmountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      _showSnack('Enter a valid amount');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.patch('suggestions/${widget.suggestion['id']}', data: {
        'paidAmount': (double.tryParse(widget.suggestion['paidAmount']?.toString() ?? '0') ?? 0) + amount,
        'paymentMethod': _manualMethod,
        'transactionId': _manualNotesCtrl.text.trim().isEmpty ? null : _manualNotesCtrl.text.trim(),
      });

      ref.read(suggestionsProvider.notifier).loadSuggestions();

      if (mounted) {
        setState(() => _isSubmitting = false);
        final nav = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        nav.pop();
        if (res.data['success'] == true) {
          _showSuccessDialog(amount, 'Manual Record: $_manualMethod', nav: nav, messenger: messenger);
        } else {
          messenger.showSnackBar(SnackBar(
            content: Text(res.data['message'] ?? 'Failed to record payment'),
            backgroundColor: AppColors.danger,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnack('Error: $e', isError: true);
      }
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.successSurface, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
            ),
            const SizedBox(height: AppDimensions.md),
            Text('Payment Recorded!', style: AppTextStyles.h2),
            const SizedBox(height: AppDimensions.xs),
            Text('₹${NumberFormat('#,##0').format(amount)}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
            if (reference.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.md),
              Text(reference, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final psAsync = ref.watch(paymentSettingsProvider);
    final remaining = _remainingAmount;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.screenPadding,
        AppDimensions.lg,
        AppDimensions.screenPadding,
        MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: const Icon(Icons.payment_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pay for Suggestion', style: AppTextStyles.h2),
                      Text(widget.suggestion['title'],
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.lg),
            if (_step == _Step.choose)
              psAsync.when(
                loading: () => const Center(
                  child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
                ),
                error: (err, __) => _noPaymentConfigured(),
                data: (ps) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppCard(
                        backgroundColor: AppColors.primarySurface,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Amount to Pay',
                                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary)),
                            Text('₹${remaining.toStringAsFixed(2)}',
                                style: AppTextStyles.h2.copyWith(color: AppColors.primary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.lg),
                      if (ps.hasRazorpay) ...[
                        Text('Online Payment', style: AppTextStyles.labelLarge),
                        const SizedBox(height: AppDimensions.sm),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _isSubmitting ? null : () => _launchRazorpay(ps),
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.flash_on_rounded),
                            label: const Text('Pay with Razorpay (Card/UPI/NetBanking)'),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.lg),
                      ],
                      if (ps.hasUpi && !ps.hasRazorpay) ...[
                        Text('Direct UPI Payment', style: AppTextStyles.labelLarge),
                        const SizedBox(height: AppDimensions.sm),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _launchUpi,
                            icon: const Icon(Icons.account_balance_wallet_rounded),
                            label: const Text('Pay via UPI App'),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.lg),
                      ],
                      if (_isAdmin) ...[
                        const Row(children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('Admin Manual Entry',
                                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ),
                          Expanded(child: Divider()),
                        ]),
                        const SizedBox(height: AppDimensions.lg),
                        TextField(
                          controller: _manualAmountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Amount Paid (₹)',
                            border: OutlineInputBorder(),
                            prefixText: '₹',
                          ),
                        ),
                        const SizedBox(height: AppDimensions.md),
                        Row(
                          children: [
                            Expanded(
                              child: AppSearchableDropdown<String>(
                                label: 'Method',
                                value: _manualMethod,
                                items: _adminManualMethods
                                    .map((m) => AppDropdownItem(value: m, label: m.replaceAll('_', ' ')))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _manualMethod = v);
                                },
                              ),
                            ),
                            const SizedBox(width: AppDimensions.md),
                            Expanded(
                              child: TextField(
                                controller: _manualNotesCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Ref / Note',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.lg),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _isSubmitting ? null : _recordManual,
                            icon: _isSubmitting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.edit_note_rounded),
                            label: const Text('Record Offline Payment'),
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
                    const Icon(Icons.open_in_new_rounded, color: AppColors.primary, size: 40),
                    const SizedBox(height: AppDimensions.md),
                    Text('Check your UPI app to complete payment',
                        style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                    const SizedBox(height: AppDimensions.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => setState(() => _step = _Step.upiConfirm),
                        child: const Text('I have paid, continue'),
                      ),
                    ),
                    TextButton(onPressed: () => setState(() => _step = _Step.choose), child: const Text('Cancel')),
                  ],
                ),
              ),
            if (_step == _Step.upiConfirm) ...[
              Text('Enter Transaction ID / UTR', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppDimensions.sm),
              TextField(
                controller: _utrCtrl,
                decoration: const InputDecoration(
                  labelText: 'UTR Number / Transaction ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _recordManual,
                  child: const Text('Confirm & Record'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _noPaymentConfigured() {
    return AppCard(
      backgroundColor: AppColors.warningSurface,
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 40),
          const SizedBox(height: 10),
          Text('No online payment gateway set up.',
              style: AppTextStyles.h3.copyWith(color: AppColors.warningText)),
          if (_isAdmin) ...[
            const SizedBox(height: 10),
            const Text('Manual recording is available for admins below.'),
          ],
        ],
      ),
    );
  }
}

