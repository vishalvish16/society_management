import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/auth_provider.dart';

// ─── Providers ──────────────────────────────────────────────────────

final unitsProvider = StateNotifierProvider<UnitsNotifier, AsyncValue<List<dynamic>>>((ref) {
  final authState = ref.watch(authProvider);
  return UnitsNotifier(ref, authState);
});

final unitFiltersProvider = StateProvider<Map<String, dynamic>>((ref) => {
  'page': 1,
  'limit': 20,
});

// ─── Notifier ────────────────────────────────────────────────────────

class UnitsNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  final Ref ref;
  final AuthState authState;

  int _currentPage = 1;
  static const int _limit = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  UnitsNotifier(this.ref, this.authState) : super(const AsyncValue.loading()) {
    if (authState.isAuthenticated) {
      fetchUnits();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> fetchUnits({bool refresh = true}) async {
    if (!authState.isAuthenticated) return;
    
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      state = const AsyncValue.loading();
    }

    if (_isLoadingMore && !refresh) return;
    
    if (!refresh) {
      _isLoadingMore = true;
      // We don't change the state to loading for "load more" 
      // to keep current items visible
    }

    try {
      final dio = ref.read(dioProvider);
      
      final response = await dio.get('units', queryParameters: {
        'page': _currentPage,
        'limit': _limit,
      });
      
      if (response.data['success'] == true) {
        final List newUnits = response.data['data']['units'] ?? [];
        _hasMore = newUnits.length >= _limit;
        
        if (refresh) {
          state = AsyncValue.data(newUnits);
        } else {
          final currentUnits = state.value ?? [];
          state = AsyncValue.data([...currentUnits, ...newUnits]);
        }
        
        if (_hasMore) {
          _currentPage++;
        }
      } else {
        if (refresh) {
          state = AsyncValue.error(response.data['message'] ?? 'Failed to fetch units', StackTrace.current);
        }
      }
    } on DioException catch (e) {
      if (refresh) {
        state = AsyncValue.error(e.response?.data['message'] ?? e.message ?? 'Network error', StackTrace.current);
      }
    } catch (e) {
      if (refresh) {
        state = AsyncValue.error(e.toString(), StackTrace.current);
      }
    } finally {
      if (!refresh) {
        _isLoadingMore = false;
        // Trigger UI update if needed (Riverpod should handle it via state change)
        if (state.hasValue) {
          state = AsyncValue.data(state.value!);
        }
      }
    }
  }

  Future<void> fetchNextPage() async {
    if (!_hasMore || _isLoadingMore || state.isLoading) return;
    await fetchUnits(refresh: false);
  }

  Future<bool> bulkCreate(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('units/bulk', data: data);
      if (response.data['success'] == true) {
        fetchUnits();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> createUnit(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('units', data: data);
      if (response.data['success'] == true) {
        fetchUnits(); // Refresh list
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateUnit(String id, Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.patch('units/$id', data: data);
      if (response.data['success'] == true) {
        fetchUnits();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> assignResident(String unitId, String userId, {bool isOwner = false}) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('units/$unitId/residents', data: {'userId': userId, 'isOwner': isOwner});
      if (response.data['success'] == true) {
        fetchUnits();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeResident(String unitId, String userId) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.delete('units/$unitId/residents/$userId');
      if (response.data['success'] == true) {
        fetchUnits();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> searchMembers(String query) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('members', queryParameters: {'search': query, 'limit': 20});
      if (response.data['success'] == true) {
        final members = response.data['data']['members'] as List? ?? [];
        return members.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteUnit(String id) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.delete('units/$id');
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
