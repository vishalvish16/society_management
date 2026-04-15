import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/auth_provider.dart';

class GatePassState {
  final List<Map<String, dynamic>> passes;
  final bool isLoading;
  final String? error;
  const GatePassState({this.passes = const [], this.isLoading = false, this.error});
  GatePassState copyWith({List<Map<String, dynamic>>? passes, bool? isLoading, String? error}) =>
      GatePassState(passes: passes ?? this.passes, isLoading: isLoading ?? this.isLoading, error: error);
}

class GatePassNotifier extends StateNotifier<GatePassState> {
  final Ref ref;
  GatePassNotifier(this.ref) : super(const GatePassState()) {
    _init();
  }

  void _init() {
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      loadPasses();
    }
  }

  Future<void> loadPasses() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('gatepasses');
      final data = res.data['data'];
      state = state.copyWith(
        isLoading: false,
        passes: List<Map<String, dynamic>>.from(data['passes'] ?? []),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createPass(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('gatepasses', data: data);
      if (res.data['success'] == true) {
        loadPasses();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> cancelPass(String id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('gatepasses/$id/cancel');
      loadPasses();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final gatePassProvider =
    StateNotifierProvider<GatePassNotifier, GatePassState>((ref) => GatePassNotifier(ref));
