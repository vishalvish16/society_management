import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/providers/dio_provider.dart';

// ─── Providers ──────────────────────────────────────────────────────

final unitsProvider = StateNotifierProvider<UnitsNotifier, AsyncValue<List<dynamic>>>((ref) {
  return UnitsNotifier(ref);
});

final unitFiltersProvider = StateProvider<Map<String, dynamic>>((ref) => {
  'page': 1,
  'limit': 20,
});

// ─── Notifier ────────────────────────────────────────────────────────

class UnitsNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  final Ref ref;
  UnitsNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchUnits();
  }

  Future<void> fetchUnits() async {
    state = const AsyncValue.loading();
    try {
      final filters = ref.read(unitFiltersProvider);
      final dio = ref.read(dioProvider);
      
      final response = await dio.get('/units', queryParameters: filters);
      
      if (response.data['success'] == true) {
        state = AsyncValue.data(response.data['data']['units'] ?? []);
      } else {
        state = AsyncValue.error(response.data['message'] ?? 'Failed to fetch units', StackTrace.current);
      }
    } on DioException catch (e) {
      state = AsyncValue.error(e.response?.data['message'] ?? e.message ?? 'Network error', StackTrace.current);
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
    }
  }

  Future<bool> createUnit(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/units', data: data);
      if (response.data['success'] == true) {
        fetchUnits(); // Refresh list
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteUnit(String id) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.delete('/units/$id');
      if (response.data['success'] == true) {
        fetchUnits();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
