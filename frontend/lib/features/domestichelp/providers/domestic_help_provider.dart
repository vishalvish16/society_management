import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import 'package:dio/dio.dart';

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

  Future<String?> addHelper(Map<String, dynamic> data) async {
    try {
      final res = await _client.dio.post('/domestichelp', data: data);
      if (res.data['success'] == true) {
        await loadHelpers();
        return null;
      }
      return res.data['message'] ?? 'Failed to add helper';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to add helper';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateHelper(String id, Map<String, dynamic> data) async {
    try {
      final res = await _client.dio.patch('/domestichelp/$id', data: data);
      if (res.data['success'] == true) {
        await loadHelpers();
        return null;
      }
      return res.data['message'] ?? 'Failed to update helper';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update helper';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> suspendHelper(String id) async {
    try {
      final res = await _client.dio.patch('/domestichelp/$id/suspend');
      if (res.data['success'] == true) {
        await loadHelpers();
        return null;
      }
      return res.data['message'] ?? 'Failed to suspend helper';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to suspend helper';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> removeHelper(String id) async {
    try {
      final res = await _client.dio.patch('/domestichelp/$id/remove');
      if (res.data['success'] == true) {
        await loadHelpers();
        return null;
      }
      return res.data['message'] ?? 'Failed to remove helper';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to remove helper';
    } catch (e) {
      return e.toString();
    }
  }
}

final domesticHelpProvider =
    StateNotifierProvider<DomesticHelpNotifier, DomesticHelpState>(
        (ref) => DomesticHelpNotifier());
