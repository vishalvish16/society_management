import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import 'package:dio/dio.dart';

class BillingSettings {
  /// NONE | FIXED | PER_DAY
  final String lateFeeType;
  /// For FIXED: fixed amount. For PER_DAY: amount per day.
  final double lateFeeAmount;
  /// Days after due date before fee starts.
  final int lateFeeGraceDays;

  const BillingSettings({
    required this.lateFeeType,
    required this.lateFeeAmount,
    required this.lateFeeGraceDays,
  });

  factory BillingSettings.fromJson(Map<String, dynamic> json) => BillingSettings(
        lateFeeType: (json['lateFeeType'] ?? 'NONE').toString().toUpperCase(),
        lateFeeAmount: (json['lateFeeAmount'] is num)
            ? (json['lateFeeAmount'] as num).toDouble()
            : double.tryParse(json['lateFeeAmount']?.toString() ?? '') ?? 0,
        lateFeeGraceDays: (json['lateFeeGraceDays'] is num)
            ? (json['lateFeeGraceDays'] as num).toInt()
            : int.tryParse(json['lateFeeGraceDays']?.toString() ?? '') ?? 0,
      );
}

class BillingSettingsNotifier extends StateNotifier<AsyncValue<BillingSettings>> {
  final Ref ref;
  BillingSettingsNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch({bool showLoading = true}) async {
    if (showLoading) state = const AsyncValue.loading();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('settings/billing');
      if (res.data['success'] == true) {
        state = AsyncValue.data(
          BillingSettings.fromJson(res.data['data'] as Map<String, dynamic>),
        );
      } else {
        state = AsyncValue.error(res.data['message'] ?? 'Failed', StackTrace.current);
      }
    } catch (e) {
      state = AsyncValue.error(
        e is DioException ? (e.response?.data['message'] ?? e.message) : e.toString(),
        StackTrace.current,
      );
    }
  }

  /// Returns null on success, error message on failure.
  Future<String?> save({
    required String lateFeeType,
    required double lateFeeAmount,
    required int lateFeeGraceDays,
  }) async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.patch('settings/billing', data: {
        'lateFeeType': lateFeeType,
        'lateFeeAmount': lateFeeAmount,
        'lateFeeGraceDays': lateFeeGraceDays,
      });
      if (res.data['success'] == true) {
        state = AsyncValue.data(
          BillingSettings.fromJson(res.data['data'] as Map<String, dynamic>),
        );
        return null;
      }
      return res.data['message'] ?? 'Failed to save';
    } catch (e) {
      if (e is DioException) return e.response?.data['message'] ?? e.message;
      return e.toString();
    }
  }
}

final billingSettingsProvider =
    StateNotifierProvider<BillingSettingsNotifier, AsyncValue<BillingSettings>>(
  (ref) => BillingSettingsNotifier(ref),
);

