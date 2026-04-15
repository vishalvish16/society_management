import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';

class DomesticHelpState {
  final List<Map<String, dynamic>> helpers;
  final bool isLoading;
  final String? error;
  const DomesticHelpState({
    this.helpers = const [],
    this.isLoading = false,
    this.error,
  });
  DomesticHelpState copyWith({
    List<Map<String, dynamic>>? helpers,
    bool? isLoading,
    String? error,
  }) =>
      DomesticHelpState(
        helpers: helpers ?? this.helpers,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class DomesticHelpNotifier extends StateNotifier<DomesticHelpState> {
  DomesticHelpNotifier() : super(const DomesticHelpState()) {
    loadHelpers();
  }

  final _client = DioClient();

  Future<void> loadHelpers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _client.dio.get('/domestichelp');
      final data = res.data['data'];
      final rawList = data['items'] ?? data['helpers'] ?? [];
      state = state.copyWith(
        isLoading: false,
        helpers: List<Map<String, dynamic>>.from(rawList),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> addHelper(Map<String, dynamic> data) async {
    try {
      await _client.dio.post('/domestichelp', data: data);
      await loadHelpers();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateHelper(String id, Map<String, dynamic> data) async {
    try {
      await _client.dio.patch('/domestichelp/$id', data: data);
      await loadHelpers();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> suspendHelper(String id) async {
    try {
      await _client.dio.patch('/domestichelp/$id/suspend');
      await loadHelpers();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeHelper(String id) async {
    try {
      await _client.dio.patch('/domestichelp/$id/remove');
      await loadHelpers();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final domesticHelpProvider =
    StateNotifierProvider<DomesticHelpNotifier, DomesticHelpState>(
        (ref) => DomesticHelpNotifier());
