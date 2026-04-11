import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';

final expensesProvider = StateNotifierProvider<ExpensesNotifier, AsyncValue<List<dynamic>>>((ref) {
  return ExpensesNotifier(ref);
});

class ExpensesNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  final Ref ref;
  ExpensesNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchExpenses();
  }

  Future<void> fetchExpenses({String? category, String? status}) async {
    state = const AsyncValue.loading();
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/expenses', queryParameters: {
        'category': ?category,
        'status': ?status,
      });
      
      if (response.data['success'] == true) {
        state = AsyncValue.data(response.data['data']['expenses'] ?? []);
      } else {
        state = AsyncValue.error(response.data['message'], StackTrace.current);
      }
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
    }
  }

  Future<bool> createExpense(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/expenses', data: data);
      if (response.data['success'] == true) {
        fetchExpenses();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateStatus(String id, String status, {String? reason}) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.patch('/expenses/$id/status', data: {
        'status': status,
        'rejectionReason': ?reason,
      });
      if (response.data['success'] == true) {
        fetchExpenses();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
