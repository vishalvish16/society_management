import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';

final billsProvider = StateNotifierProvider<BillsNotifier, AsyncValue<List<dynamic>>>((ref) {
  return BillsNotifier(ref);
});

class BillsNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  final Ref ref;
  BillsNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchBills();
  }

  Future<void> fetchBills({String? unitId, String? status, String? month}) async {
    state = const AsyncValue.loading();
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/bills', queryParameters: {
        'unitId': ?unitId,
        'status': ?status,
        'month': ?month,
      });
      
      if (response.data['success'] == true) {
        state = AsyncValue.data(response.data['data']['bills'] ?? []);
      } else {
        state = AsyncValue.error(response.data['message'], StackTrace.current);
      }
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
    }
  }

  Future<bool> bulkGenerate(DateTime month, double amount, DateTime dueDate) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/bills/generate', data: {
        'month': month.toIso8601String(),
        'defaultAmount': amount,
        'dueDate': dueDate.toIso8601String(),
      });
      if (response.data['success'] == true) {
        fetchBills();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
