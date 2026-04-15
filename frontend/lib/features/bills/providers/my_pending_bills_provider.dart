import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:dio/dio.dart';

/// Always fetches the logged-in user's OWN pending/partial bills.
/// Used for the dashboard banner and quick-pay flow.
/// Separate from [billsProvider] so admins also see their personal dues.
///
/// Depends on [authProvider] so it auto-refreshes when auth state changes
/// (e.g. right after login).
final myPendingBillsProvider =
    StateNotifierProvider<MyPendingBillsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
        (ref) {
  // Watch authProvider so the notifier is recreated when auth changes
  final auth = ref.watch(authProvider);
  return MyPendingBillsNotifier(ref, auth);
});

class MyPendingBillsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref ref;
  final AuthState _auth;

  MyPendingBillsNotifier(this.ref, this._auth) : super(const AsyncValue.loading()) {
    if (_auth.isAuthenticated) {
      fetch();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final auth = ref.read(authProvider);
      if (!auth.isAuthenticated) {
        state = const AsyncValue.data([]);
        return;
      }
      final dio = ref.read(dioProvider);
      final res = await dio.get('bills/mine', queryParameters: {
        'limit': 50,
      });
      if (res.data['success'] == true) {
        final raw = res.data['data'];
        final List all = (raw is Map ? (raw['bills'] ?? []) : raw) ?? [];
        // Keep only unpaid bills
        final pending = all
            .whereType<Map>()
            .where((b) {
              final s = (b['status'] as String? ?? '').toUpperCase();
              return s == 'PENDING' || s == 'PARTIAL' || s == 'OVERDUE';
            })
            .map((b) => Map<String, dynamic>.from(b))
            .toList();
        state = AsyncValue.data(pending);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e) {
      // Silently fall back to empty — don't break dashboard
      state = const AsyncValue.data([]);
    }
  }

  Future<String?> payBill(
      String billId, double amount, String paymentMethod, String? notes) async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('bills/$billId/pay', data: {
        'paidAmount': amount,
        'paymentMethod': paymentMethod,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      if (res.data['success'] == true) {
        await fetch(); // refresh pending list
        return null;
      }
      return res.data['message'] ?? 'Payment failed';
    } catch (e) {
      if (e is DioException) return e.response?.data['message'] ?? e.message;
      return e.toString();
    }
  }
}
