import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';

class PlansState {
  final List<Map<String, dynamic>> plans;
  final bool isLoading;
  final String? error;

  const PlansState({this.plans = const [], this.isLoading = false, this.error});

  PlansState copyWith({List<Map<String, dynamic>>? plans, bool? isLoading, String? error}) {
    return PlansState(
      plans: plans ?? this.plans,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PlansNotifier extends StateNotifier<PlansState> {
  PlansNotifier() : super(const PlansState());

  final _client = DioClient();

  Future<void> loadPlans() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.dio.get('/plans');
      state = state.copyWith(
        plans: List<Map<String, dynamic>>.from(response.data['data'] ?? []),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load plans');
    }
  }

  Future<bool> createPlan(Map<String, dynamic> data) async {
    try {
      await _client.dio.post('/plans', data: data);
      await loadPlans();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updatePlan(String id, Map<String, dynamic> data) async {
    try {
      await _client.dio.patch('/plans/$id', data: data);
      await loadPlans();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deactivatePlan(String id) async {
    try {
      await _client.dio.delete('/plans/$id');
      await loadPlans();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final plansProvider = StateNotifierProvider<PlansNotifier, PlansState>((ref) {
  return PlansNotifier();
});
