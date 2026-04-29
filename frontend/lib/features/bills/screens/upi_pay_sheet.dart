import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:upi_india/upi_india.dart';
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
import '../providers/my_pending_bills_provider.dart';
import '../providers/bill_provider.dart';
import 'razorpay_web_stub.dart' if (dart.library.html) 'razorpay_web.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────

void showPaySheet(BuildContext context, {required Map<String, dynamic> bill}) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    enableDrag: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl)),
    ),
    builder: (_) => _PaySheet(bill: bill),
  );
}

// ─── Steps ────────────────────────────────────────────────────────────────────

enum _Step { choose, upiLaunched, upiConfirm }

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _PaySheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> bill;
  const _PaySheet({required this.bill});

  @override
  ConsumerState<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<_PaySheet> {
  _Step _step = _Step.choose;
  String _manualMethod = 'CASH';
  final _amountCtrl = TextEditingController();
  final _utrCtrl = TextEditingController();
  final _manualNotesCtrl = TextEditingController();
  bool _isSubmitting = false;

  Razorpay? _razorpay;
  final _upiIndia = UpiIndia();
  List<UpiApp>? _upiApps;
  bool _loadingUpiApps = false;

  static const _adminManualMethods = ['CASH', 'BANK_TRANSFER', 'CHEQUE', 'OTHER'];

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = _remaining.toStringAsFixed(0);
    _loadUpiApps();
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

  // ── Computed ──────────────────────────────────────────────────────────────

  double get _remaining {
    final total = double.tryParse(widget.bill['totalDue']?.toString() ?? '0') ?? 0;
    final paid = double.tryParse(widget.bill['paidAmount']?.toString() ?? '0') ?? 0;
    return total - paid;
  }

  String get _billingMonth {
    final raw = widget.bill['billingMonth'];
    if (raw == null) return '';
    return DateFormat('MMMM yyyy').format(DateTime.parse(raw));
  }

  String get _category =>
      (widget.bill['category'] as String? ?? 'MAINTENANCE').toUpperCase();

  String get _title {
    final t = (widget.bill['title'] as String?)?.trim();
    if (t != null && t.isNotEmpty) return t;
    if (_category == 'AMENITY') return 'Amenity Booking';
    return 'Maintenance Bill';
  }

  String get _subTitle {
    // For amenity bills, show due date (booking date). Otherwise show billing month.
    if (_category == 'AMENITY' && widget.bill['dueDate'] != null) {
      final due = DateTime.tryParse(widget.bill['dueDate'] as String);
      if (due != null) return DateFormat('dd MMM yyyy').format(due);
    }
    return _billingMonth;
  }

  String get _unitCode =>
      (widget.bill['unit'] as Map?)?['fullCode'] as String? ?? '-';

  bool get _isAdmin {
    final role = ref.read(authProvider).user?.role.toUpperCase() ?? '';
    return role == 'PRAMUKH' || role == 'CHAIRMAN' || role == 'SECRETARY';
  }

  Future<void> _loadUpiApps() async {
    if (kIsWeb) return;
    setState(() => _loadingUpiApps = true);
    try {
      final apps = await _upiIndia.getAllUpiApps(mandatoryTransactionId: false);
      if (!mounted) return;
      setState(() {
        _upiApps = apps;
        _loadingUpiApps = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _upiApps = const [];
        _loadingUpiApps = false;
      });
    }
  }

  // ── Razorpay ─────────────────────────────────────────────────────────────

  Future<void> _launchRazorpay(PaymentSettings ps) async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? _remaining;
    if (amount <= 0) { _showSnack('Enter a valid amount first'); return; }

    setState(() => _isSubmitting = true);

    try {
      // 1. Create backend order
      final dio = ref.read(dioProvider);
      final res = await dio.post('payments/create-order', data: {
        'billId': widget.bill['id'],
      });

      if (res.data['success'] != true) {
        _showSnack(res.data['message'] ?? 'Could not create order', isError: true);
        setState(() => _isSubmitting = false);
        return;
      }

      final orderData = res.data['data'];
      final orderId = orderData['orderId'] as String;
      final orderAmount = orderData['amount'] as int; // paise from backend
      final user = ref.read(authProvider).user;

      final options = <String, dynamic>{
        'key': ps.razorpayKeyId,
        'order_id': orderId,
        'amount': orderAmount,
        'currency': 'INR',
        'name': ps.upiName?.isNotEmpty == true ? ps.upiName : 'Society',
        'description': '$_title - $_unitCode - $_subTitle',
        'prefill': {
          'name': user?.name ?? '',
          'contact': user?.phone ?? '',
        },
        'theme': {'color': '#1565C0'},
      };

      setState(() => _isSubmitting = false);

      if (kIsWeb) {
        // 2a. Web: use JS interop checkout
        openRazorpayWeb(
          options: options,
          onSuccess: (paymentId, rzpOrderId, signature) =>
              _verifyAndRecord(paymentId, rzpOrderId, signature),
          onError: (msg) => _showSnack(msg, isError: true),
        );
      } else {
        // 2b. Native: use razorpay_flutter SDK
        _razorpay?.clear();
        _razorpay = Razorpay();
        _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onRazorpaySuccess);
        _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onRazorpayError);
        _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _onRazorpayExternalWallet);
        options['send_sms_hash'] = true;
        options['remember_customer'] = false;
        _razorpay!.open(options);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _verifyAndRecord(
      String paymentId, String rzpOrderId, String signature) async {
    setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('payments/verify', data: {
        'billId': widget.bill['id'],
        'razorpayOrderId': rzpOrderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
        'paidAmount': double.tryParse(_amountCtrl.text.trim()) ?? _remaining,
      });

      await ref.read(myPendingBillsProvider.notifier).fetch();
      ref.read(billsProvider.notifier).fetchBills();

      if (mounted) {
        setState(() => _isSubmitting = false);
        final nav = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        nav.pop();
        if (res.data['success'] == true) {
          _showSuccessDialog(
            double.tryParse(_amountCtrl.text.trim()) ?? _remaining,
            'Payment ID: $paymentId',
            nav: nav,
            messenger: messenger,
          );
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

  void _onRazorpaySuccess(PaymentSuccessResponse response) {
    _verifyAndRecord(
      response.paymentId ?? '',
      response.orderId ?? '',
      response.signature ?? '',
    );
  }

  void _onRazorpayError(PaymentFailureResponse response) {
    if (mounted) {
      _showSnack(response.message ?? 'Payment failed or cancelled', isError: true);
    }
  }

  void _onRazorpayExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      _showSnack('External wallet: ${response.walletName}');
    }
  }

  // ── Manual UPI ────────────────────────────────────────────────────────────

  Uri _buildUpiUri(PaymentSettings ps, double amount) => Uri(
        scheme: 'upi',
        host: 'pay',
        queryParameters: {
          'pa': ps.upiId!,
          'pn': ps.upiName?.isNotEmpty == true ? ps.upiName! : 'Society',
          'am': amount.toStringAsFixed(2),
          'cu': 'INR',
          'tn': '$_title $_subTitle - $_unitCode',
        },
      );

  Future<void> _launchUpiFallbackDeepLink(PaymentSettings ps) async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? _remaining;
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

  Future<void> _launchUpiIntent(PaymentSettings ps, {UpiApp? app}) async {
    if (kIsWeb) {
      await _launchUpiFallbackDeepLink(ps);
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? _remaining;
    if (amount <= 0) {
      _showSnack('Enter a valid amount first');
      return;
    }

    final upiId = ps.upiId;
    if (upiId == null || upiId.trim().isEmpty) {
      _showSnack('UPI ID not configured', isError: true);
      return;
    }

    final safeId = (widget.bill['id'] as String?) ?? '';
    final compactId = safeId.replaceAll('-', '');
    final shortId = compactId.length >= 12 ? compactId.substring(0, 12) : compactId;
    final txnRef = 'BILL-$shortId';

    final selectedApp = app ?? (_upiApps?.isNotEmpty == true ? _upiApps!.first : null);
    if (selectedApp == null) {
      _showSnack('No UPI app found. Install GPay, PhonePe, or Paytm.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final resp = await _upiIndia.startTransaction(
        app: selectedApp,
        receiverUpiId: upiId,
        receiverName: ps.upiName?.isNotEmpty == true ? ps.upiName! : 'Society',
        transactionRefId: txnRef,
        transactionNote: '$_title $_subTitle - $_unitCode',
        amount: amount,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      final status = (resp.status ?? '').toUpperCase();
      if (status == UpiPaymentStatus.SUCCESS) {
        final ref = [
          if ((resp.transactionId ?? '').isNotEmpty) 'txnId=${resp.transactionId}',
          if ((resp.responseCode ?? '').isNotEmpty) 'code=${resp.responseCode}',
          if ((resp.approvalRefNo ?? '').isNotEmpty) 'apr=${resp.approvalRefNo}',
          'ref=$txnRef',
        ].join(' | ');
        await _recordPayment(amount, 'UPI', 'UPI Intent | $ref');
        return;
      }

      if (status == UpiPaymentStatus.SUBMITTED) {
        setState(() => _step = _Step.upiLaunched);
        _showSnack('Payment is pending/processing in bank. If amount is debited, enter UTR to confirm.');
        return;
      }

      _showSnack('UPI payment failed or cancelled', isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnack('Could not start UPI payment: $e', isError: true);
    }
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
    final billId = widget.bill['id'] as String;
    final error = await ref.read(myPendingBillsProvider.notifier)
        .payBill(billId, amount, method, notes);
    ref.read(billsProvider.notifier).fetchBills();
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    // Capture parent context references BEFORE popping the sheet.
    // After Navigator.pop the sheet's context is unmounted and unusable.
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    nav.pop();

    if (error == null) {
      _showSuccessDialog(amount, notes ?? '', nav: nav, messenger: messenger);
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  // ── Snack / Dialog ────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : null,
    ));
  }

  void _showSuccessDialog(
    double amount,
    String reference, {
    required NavigatorState nav,
    required ScaffoldMessengerState messenger,
  }) {
    final fmt = NumberFormat('#,##0');
    showDialog(
      context: nav.context,
      barrierDismissible: false,
      builder: (ctx) => AppSuccessDialog(
        title: 'Payment Recorded!',
        subtitle: '₹${fmt.format(amount)} · $_unitCode · $_subTitle',
        referenceText: reference,
        doneLabel: 'Done',
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    final psAsync = ref.watch(paymentSettingsProvider);
    final isAdmin = _isAdmin;

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
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),

            // ── Bill summary ─────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.warningSurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: AppColors.warning, size: 22),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_title, style: AppTextStyles.h2),
                      Text('$_unitCode · $_subTitle',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${fmt.format(_remaining)}',
                        style: AppTextStyles.h2.copyWith(color: AppColors.danger)),
                    Text('outstanding',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.lg),

            // ════════════════════════════════════════════════════════
            // STEP 1 — Choose
            // ════════════════════════════════════════════════════════
            if (_step == _Step.choose)
              psAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppDimensions.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => _noPaymentConfigured(isAdmin),
                data: (ps) {
                  if (!ps.hasAny) return _noPaymentConfigured(isAdmin);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount field — shared
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹) *',
                          prefixText: '₹',
                        ),
                      ),
                      const SizedBox(height: AppDimensions.lg),

                      // ── Razorpay (gateway) ─────────────────────
                      if (ps.hasRazorpay) ...[
                        Text('Pay Online',
                            style: AppTextStyles.labelLarge
                                .copyWith(color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(height: AppDimensions.sm),
                        _RazorpayButton(
                          isLoading: _isSubmitting,
                          onTap: () => _launchRazorpay(ps),
                        ),
                        if (ps.paymentNote?.isNotEmpty == true) ...[
                          const SizedBox(height: AppDimensions.sm),
                          _NoteBox(ps.paymentNote!),
                        ],
                        const SizedBox(height: AppDimensions.lg),
                      ],

                      // ── Manual UPI (shown when no gateway OR as fallback) ─
                      if (ps.hasUpi && !ps.hasRazorpay) ...[
                        Text('Pay via UPI',
                            style: AppTextStyles.labelLarge
                                .copyWith(color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(height: AppDimensions.sm),
                        _UpiIdCard(ps: ps),
                        const SizedBox(height: AppDimensions.md),
                        if (ps.paymentNote?.isNotEmpty == true)
                          _NoteBox(ps.paymentNote!),
                        const SizedBox(height: AppDimensions.md),
                        Text('Open in:',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textMuted)),
                        const SizedBox(height: AppDimensions.sm),
                        if (_loadingUpiApps)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: AppDimensions.sm),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if ((_upiApps ?? const []).isEmpty)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _UpiAppChip(
                                  label: 'Any UPI App',
                                  icon: Icons.account_balance_wallet_rounded,
                                  color: AppColors.primary,
                                  onTap: _isSubmitting ? () {} : () => _launchUpiFallbackDeepLink(ps),
                                ),
                              ],
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _UpiAppChip(
                                  label: 'Any UPI App',
                                  icon: Icons.account_balance_wallet_rounded,
                                  color: AppColors.primary,
                                  onTap: _isSubmitting ? () {} : () => _launchUpiIntent(ps),
                                ),
                                const SizedBox(width: AppDimensions.sm),
                                ...(_upiApps ?? const []).take(6).expand((a) sync* {
                                  yield _UpiAppChip(
                                    label: a.name,
                                    icon: Icons.payment_rounded,
                                    color: AppColors.textSecondary,
                                    onTap: _isSubmitting ? () {} : () => _launchUpiIntent(ps, app: a),
                                  );
                                  yield const SizedBox(width: AppDimensions.sm);
                                }),
                              ],
                            ),
                          ),
                        const SizedBox(height: AppDimensions.lg),
                      ],

                      // ── Admin manual section ───────────────────
                      if (isAdmin) ...[
                        const Row(children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: AppDimensions.sm),
                            child: Text('Admin: record offline payment',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textMuted)),
                          ),
                          Expanded(child: Divider()),
                        ]),
                        const SizedBox(height: AppDimensions.lg),
                        AppSearchableDropdown<String>(
                          label: 'Payment Method',
                          value: _manualMethod,
                          items: _adminManualMethods
                              .map((m) => AppDropdownItem(
                                  value: m, label: m.replaceAll('_', ' ')))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _manualMethod = v);
                            }
                          },
                        ),
                        const SizedBox(height: AppDimensions.md),
                        TextField(
                          controller: _manualNotesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Reference / Notes (Optional)',
                          ),
                        ),
                        const SizedBox(height: AppDimensions.lg),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _isSubmitting ? null : _submitManual,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.edit_note_rounded),
                            label: const Text('Record Offline Payment'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusMd)),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: AppDimensions.sm),
                    ],
                  );
                },
              ),

            // ════════════════════════════════════════════════════════
            // STEP 2 — Manual UPI launched, waiting for user to confirm
            // ════════════════════════════════════════════════════════
            if (_step == _Step.upiLaunched)
              AppCard(
                backgroundColor: AppColors.primarySurface,
                child: Column(
                  children: [
                    const SizedBox(height: AppDimensions.md),
                    const Icon(Icons.open_in_new_rounded,
                        color: AppColors.primary, size: 40),
                    const SizedBox(height: AppDimensions.md),
                    Text('Complete payment in your UPI app',
                        style: AppTextStyles.h3
                            .copyWith(color: AppColors.primary)),
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      'Pay ₹${NumberFormat('#,##0').format(double.tryParse(_amountCtrl.text) ?? _remaining)} '
                      'then come back and tap the button below.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () =>
                            setState(() => _step = _Step.upiConfirm),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary),
                        child: const Text('I have paid — Enter details'),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _step = _Step.choose),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                  ],
                ),
              ),

            // ════════════════════════════════════════════════════════
            // STEP 3 — Enter UTR and confirm (manual UPI only)
            // ════════════════════════════════════════════════════════
            if (_step == _Step.upiConfirm) ...[
              AppCard(
                backgroundColor: AppColors.successSurface,
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        color: AppColors.success, size: 20),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(
                        'Payment done in UPI app — enter your transaction details below.',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.successText),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount Paid (₹) *',
                  prefixText: '₹',
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              TextField(
                controller: _utrCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'UPI Transaction ID / UTR *',
                  hintText: 'e.g. 402912345678',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
              ),
              const SizedBox(height: AppDimensions.xs),
              Text(
                'Find it in your UPI app → Transactions → Transaction ID',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppDimensions.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() => _step = _Step.choose),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submitUpi,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMd)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Confirm Payment'),
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
            const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                SizedBox(width: AppDimensions.sm),
                Text('Payment not set up yet',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.warningText)),
              ],
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'Payment details haven\'t been configured yet. '
              'Please contact your society admin.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.warningText),
            ),
          ],
        ),
      );
    }

    // Admin — show manual recording directly
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          backgroundColor: AppColors.warningSurface,
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  'No payment method configured. Go to Settings → Payment Settings.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.warningText),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.lg),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Amount (₹)', prefixText: '₹'),
        ),
        const SizedBox(height: AppDimensions.md),
        AppSearchableDropdown<String>(
          label: 'Payment Method',
          value: _manualMethod,
          items: _adminManualMethods
              .map((m) => AppDropdownItem(value: m, label: m.replaceAll('_', ' ')))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _manualMethod = v);
          },
        ),
        const SizedBox(height: AppDimensions.md),
        TextField(
          controller: _manualNotesCtrl,
          decoration:
              const InputDecoration(labelText: 'Reference / Notes (Optional)'),
        ),
        const SizedBox(height: AppDimensions.xl),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submitManual,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Record Payment'),
          ),
        ),
      ],
    );
  }
}

// ─── Razorpay pay button ──────────────────────────────────────────────────────

class _RazorpayButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _RazorpayButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2D81F7), Color(0xFF1565C0)],
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pay with Razorpay',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  Text('UPI · Cards · Net Banking · Wallets',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12)),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
            else
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─── UPI ID display card ──────────────────────────────────────────────────────

class _UpiIdCard extends StatelessWidget {
  final PaymentSettings ps;
  const _UpiIdCard({required this.ps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.qr_code_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ps.upiName?.isNotEmpty == true ? ps.upiName! : 'Society UPI',
                  style: AppTextStyles.labelMedium,
                ),
                Text(ps.upiId!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textMuted),
            tooltip: 'Copy UPI ID',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: ps.upiId!));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('UPI ID copied'),
                duration: Duration(seconds: 1),
              ));
            },
          ),
        ],
      ),
    );
  }
}

// ─── Note box ────────────────────────────────────────────────────────────────

class _NoteBox extends StatelessWidget {
  final String note;
  const _NoteBox(this.note);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(note,
                style: AppTextStyles.caption.copyWith(color: AppColors.warningText)),
          ),
        ],
      ),
    );
  }
}

// ─── UPI app launch chip ──────────────────────────────────────────────────────

class _UpiAppChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _UpiAppChip(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md, vertical: AppDimensions.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.labelMedium.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
