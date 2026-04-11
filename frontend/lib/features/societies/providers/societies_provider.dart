import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';

class SocietiesState {
  final List<Map<String, dynamic>> societies;
  final int total;
  final int page;
  final bool isLoading;
  final String? error;

  const SocietiesState({
    this.societies = const [],
    this.total = 0,
    this.page = 1,
    this.isLoading = false,
    this.error,
  });

  SocietiesState copyWith({
    List<Map<String, dynamic>>? societies,
    int? total,
    int? page,
    bool? isLoading,
    String? error,
  }) {
    return SocietiesState(
      societies: societies ?? this.societies,
      total: total ?? this.total,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SocietiesNotifier extends StateNotifier<SocietiesState> {
  SocietiesNotifier() : super(const SocietiesState());

  final _client = DioClient();

  Future<void> loadSocieties({int page = 1, String? search, String? status}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{'page': page, 'limit': 20};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (status != null && status.isNotEmpty) params['status'] = status;

      final response = await _client.dio.get('/societies', queryParameters: params);
      final data = response.data['data'];

      state = state.copyWith(
        societies: List<Map<String, dynamic>>.from(data['societies'] ?? []),
        total: data['total'] ?? 0,
        page: page,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load societies');
    }
  }

  Future<Map<String, dynamic>?> getSociety(String id) async {
    try {
      final response = await _client.dio.get('/societies/$id');
      return response.data['data'];
    } catch (_) {
      return null;
    }
  }

  Future<bool> createSociety(Map<String, dynamic> data) async {
    try {
      await _client.dio.post('/societies', data: data);
      await loadSocieties();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deactivateSociety(String id) async {
    try {
      await _client.dio.delete('/societies/$id');
      await loadSocieties(page: state.page);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateSociety(String id, Map<String, dynamic> data) async {
    try {
      await _client.dio.patch('/societies/$id', data: data);
      await loadSocieties(page: state.page);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleStatus(String id) async {
    try {
      await _client.dio.patch('/societies/$id/toggle-status');
      await loadSocieties(page: state.page);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resetPassword(String id, String password) async {
    try {
      await _client.dio.post('/societies/$id/reset-password', data: {'password': password});
      return true;
    } catch (_) {
      return false;
    }
  }
}

final societiesProvider = StateNotifierProvider<SocietiesNotifier, SocietiesState>((ref) {
  return SocietiesNotifier();
});
