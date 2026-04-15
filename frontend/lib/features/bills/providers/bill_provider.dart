import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:dio/dio.dart';

final billsProvider = StateNotifierProvider<BillsNotifier, AsyncValue<List<dynamic>>>((ref) {
  final authState = ref.watch(authProvider);
  return BillsNotifier(ref, authState);
});

class BillsNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  final Ref ref;
  final AuthState authState;

  int _currentPage = 1;
  static const int _limit = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  BillsNotifier(this.ref, this.authState) : super(const AsyncValue.loading()) {
    if (authState.isAuthenticated) {
      fetchBills();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  bool get _isAdmin {
    final role = authState.user?.role.toUpperCase() ?? '';
    return role == 'PRAMUKH' || role == 'CHAIRMAN' || role == 'SECRETARY';
  }

  Future<void> fetchBills({bool refresh = true, String? unitId, String? status, String? month}) async {
    if (!authState.isAuthenticated) return;
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      state = const AsyncValue.loading();
    }

    if (_isLoadingMore && !refresh) return;
    if (!refresh) _isLoadingMore = true;

    try {
      final dio = ref.read(dioProvider);

      // Admins see all bills; everyone else sees only their own unit bills
      final endpoint = _isAdmin ? 'bills' : 'bills/mine';
      final response = await dio.get(endpoint, queryParameters: {
        'page': _currentPage,
        'limit': _limit,
        'unitId': unitId,
        'status': status,
        'month': month,
      });

      if (response.data['success'] == true) {
        final raw = response.data['data'];
        final List list = (raw is Map ? raw['bills'] : raw) ?? [];
        _hasMore = list.length >= _limit;

        if (refresh) {
          state = AsyncValue.data(list);
        } else {
          final current = state.value ?? [];
          state = AsyncValue.data([...current, ...list]);
        }
        if (_hasMore) _currentPage++;
      } else {
        if (refresh) {
          state = AsyncValue.error(
              response.data['message'] ?? 'Failed to load bills', StackTrace.current);
        }
      }
    } catch (e) {
      if (refresh) {
        state = AsyncValue.error(
            e is DioException
                ? (e.response?.data['message'] ?? e.message)
                : e.toString(),
            StackTrace.current);
      }
    } finally {
      if (!refresh) {
        _isLoadingMore = false;
        if (state.hasValue) state = AsyncValue.data(state.value!);
      }
    }
  }

  Future<void> loadNextPage() async {
    if (!_hasMore || _isLoadingMore || state.isLoading) return;
    await fetchBills(refresh: false);
  }

  Future<String?> bulkGenerate(DateTime month, double amount, DateTime dueDate) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('bills/generate', data: {
        'month': month.toIso8601String(),
        'defaultAmount': amount,
        'dueDate': dueDate.toIso8601String(),
      });
      if (response.data['success'] == true) {
        fetchBills();
        return null;
      }
      return response.data['message'] ?? 'Failed to generate bills';
    } catch (e) {
      if (e is DioException) return e.response?.data['message'] ?? e.message;
      return e.toString();
    }
  }

  /// Returns null on success, error message on failure.
  Future<String?> payBill(String billId, double amount, String paymentMethod, {String? notes}) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('bills/$billId/pay', data: {
        'paidAmount': amount,
        'paymentMethod': paymentMethod,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      if (response.data['success'] == true) {
        fetchBills();
        return null;
      }
      return response.data['message'] ?? 'Payment failed';
    } catch (e) {
      if (e is DioException) return e.response?.data['message'] ?? e.message;
      return e.toString();
    }
  }
}
