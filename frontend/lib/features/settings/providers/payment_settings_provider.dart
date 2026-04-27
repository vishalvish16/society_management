import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import 'package:dio/dio.dart';

class PaymentSettings {
  final String? upiId;
  final String? upiName;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String? accountHolderName;
  final String? paymentNote;
  // Gateway
  final String? activeGateway;   // 'razorpay' | null
  final String? razorpayKeyId;   // public key only — secret never leaves backend

  const PaymentSettings({
    this.upiId,
    this.upiName,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.accountHolderName,
    this.paymentNote,
    this.activeGateway,
    this.razorpayKeyId,
  });

  bool get hasUpi => upiId != null && upiId!.isNotEmpty;
  bool get hasBank => accountNumber != null && accountNumber!.isNotEmpty;
  bool get hasRazorpay =>
      activeGateway == 'razorpay' &&
      razorpayKeyId != null &&
      razorpayKeyId!.isNotEmpty;
  bool get hasAny => hasUpi || hasBank || hasRazorpay;

  factory PaymentSettings.fromJson(Map<String, dynamic> json) => PaymentSettings(
        upiId: json['upiId'] as String?,
        upiName: json['upiName'] as String?,
        bankName: json['bankName'] as String?,
        accountNumber: json['accountNumber'] as String?,
        ifscCode: json['ifscCode'] as String?,
        accountHolderName: json['accountHolderName'] as String?,
        paymentNote: json['paymentNote'] as String?,
        activeGateway: json['activeGateway'] as String?,
        razorpayKeyId: json['razorpayKeyId'] as String?,
      );
}

class PaymentSettingsNotifier
    extends StateNotifier<AsyncValue<PaymentSettings>> {
  final Ref ref;

  PaymentSettingsNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch({bool showLoading = true}) async {
    if (showLoading) state = const AsyncValue.loading();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('settings/payment');
      if (res.data['success'] == true) {
        state = AsyncValue.data(
            PaymentSettings.fromJson(res.data['data'] as Map<String, dynamic>));
      } else {
        state = AsyncValue.error(
            res.data['message'] ?? 'Failed', StackTrace.current);
      }
    } catch (e) {
      state = AsyncValue.error(
          e is DioException
              ? (e.response?.data['message'] ?? e.message)
              : e.toString(),
          StackTrace.current);
    }
  }

  /// Returns null on success, error message on failure.
  Future<String?> save(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.patch('settings/payment', data: data);
      if (res.data['success'] == true) {
        state = AsyncValue.data(
            PaymentSettings.fromJson(res.data['data'] as Map<String, dynamic>));
        return null;
      }
      return res.data['message'] ?? 'Failed to save';
    } catch (e) {
      if (e is DioException) return e.response?.data['message'] ?? e.message;
      return e.toString();
    }
  }
}

final paymentSettingsProvider =
    StateNotifierProvider<PaymentSettingsNotifier, AsyncValue<PaymentSettings>>(
        (ref) => PaymentSettingsNotifier(ref));
