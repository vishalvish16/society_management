import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import 'package:dio/dio.dart';
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

  Future<String?> createPass(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('gatepasses', data: data);
      if (res.data['success'] == true) {
        loadPasses();
        return null;
      }
      return res.data['message'] ?? 'Failed to create gate pass';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to create gate pass';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> cancelPass(String id) async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.patch('gatepasses/$id/cancel');
      if (res.data['success'] == true) {
        loadPasses();
        return null;
      }
      return res.data['message'] ?? 'Failed to cancel gate pass';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to cancel gate pass';
    } catch (e) {
      return e.toString();
    }
  }
}

final gatePassProvider =
    StateNotifierProvider<GatePassNotifier, GatePassState>((ref) => GatePassNotifier(ref));
