import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/dio_client.dart';
import '../../superadmin/providers/dashboard_provider.dart';

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
  final Ref _ref;
  SocietiesNotifier(this._ref) : super(const SocietiesState());

  final _client = DioClient();

  String? _mapStatusForApi(String? status) {
    if (status == null || status.isEmpty) return null;
    // Backend expects: active | inactive
    if (status.toUpperCase() == 'ACTIVE') return 'active';
    if (status.toUpperCase() == 'SUSPENDED') return 'inactive';
    return status;
  }

  void _invalidateDashboard() {
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(recentSocietiesProvider);
  }

  Future<void> loadSocieties({int page = 1, String? search, String? status}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{'page': page, 'limit': 20};
      if (search != null && search.isNotEmpty) params['search'] = search;
      final apiStatus = _mapStatusForApi(status);
      if (apiStatus != null && apiStatus.isNotEmpty) params['status'] = apiStatus;

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

  Future<String?> createSociety(Map<String, dynamic> data) async {
    try {
      await _client.dio.post('/societies', data: data);
      await loadSocieties();
      _invalidateDashboard();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to create society';
    } catch (e) {
      return e.toString();
    }
  }

  /// Create a society and return its id (used for step-by-step registration flow).
  /// Does not auto-refresh list to keep the sheet responsive; caller can refresh at the end.
  Future<(String? id, String? error)> createSocietyWithId(Map<String, dynamic> data) async {
    try {
      final res = await _client.dio.post('/societies', data: data);
      final payload = res.data['data'];
      final society = payload is Map ? payload['society'] : null;
      final id = society is Map ? society['id'] : null;
      return (id is String ? id : null, null);
    } on DioException catch (e) {
      return (null, (e.response?.data['message'] ?? 'Failed to create society') as String?);
    } catch (e) {
      return (null, e.toString() as String?);
    }
  }

  Future<String?> deactivateSociety(String id) async {
    try {
      await _client.dio.delete('/societies/$id');
      await loadSocieties(page: state.page);
      _invalidateDashboard();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to deactivate society';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateSociety(String id, Map<String, dynamic> data) async {
    try {
      await _client.dio.patch('/societies/$id', data: data);
      await loadSocieties(page: state.page);
      _invalidateDashboard();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update society';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> upsertChairman(String societyId, Map<String, dynamic> chairman) async {
    try {
      await _client.dio.post('/societies/$societyId/chairman', data: chairman);
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update chairman';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> toggleStatus(String id) async {
    try {
      await _client.dio.patch('/societies/$id/toggle-status');
      await loadSocieties(page: state.page);
      _invalidateDashboard();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to toggle status';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> resetPassword(String id, String? password,
      {String? name, String mode = 'manual'}) async {
    try {
      final data = <String, dynamic>{};
      if (password != null && password.isNotEmpty) data['password'] = password;
      if (name != null && name.isNotEmpty) data['name'] = name;
      data['mode'] = mode;
      
      await _client.dio.post('/societies/$id/reset-password', data: data);
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to reset password';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateSettings(String id, Map<String, dynamic> settings) async {
    try {
      await _client.dio.patch('/societies/$id/settings', data: settings);
      // Refresh local list to show updated settings in detail dialogs etc.
      await loadSocieties(page: state.page);
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update settings';
    } catch (e) {
      return e.toString();
    }
  }
}

final societiesProvider = StateNotifierProvider<SocietiesNotifier, SocietiesState>((ref) {
  return SocietiesNotifier(ref);
});
