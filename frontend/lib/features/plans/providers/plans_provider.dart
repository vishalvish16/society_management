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

  List<Map<String, dynamic>> _canonicalizePlans(List<dynamic> raw) {
    final items = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    const canonical = {'basic', 'standard', 'premium'};

    // Keep only canonical lowercase plan names and active plans.
    final filtered = items.where((p) {
      final name = (p['name'] ?? '').toString();
      return canonical.contains(name) && name == name.toLowerCase() && p['isActive'] == true;
    }).toList();

    // Stable order: Basic, Standard, Premium
    int rank(String name) {
      if (name == 'basic') return 0;
      if (name == 'standard') return 1;
      return 2;
    }

    filtered.sort((a, b) => rank(a['name']?.toString() ?? '').compareTo(rank(b['name']?.toString() ?? '')));
    return filtered;
  }

  Future<void> loadPlans() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.dio.get('/plans');
      state = state.copyWith(
        plans: _canonicalizePlans((response.data['data'] ?? []) as List),
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
