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
  static const int _limit = 50;
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

  /// Refresh first page without switching state to loading.
  /// This prevents UI sheets from falling back to stale snapshots.
  Future<void> refreshUnitsSoft() async {
    if (!authState.isAuthenticated) return;
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('units', queryParameters: {
        'page': 1,
        'limit': _limit,
      });
      if (response.data['success'] == true) {
        final data = response.data['data'];
        final List newUnits = data['units'] ?? [];
        final total = data['total'] ?? 0;
        state = AsyncValue.data(newUnits);
        _currentPage = 1;
        _hasMore = (newUnits.length) < total;
        if (_hasMore) _currentPage++;
      }
    } catch (_) {
      // Keep existing state on soft refresh failure.
    }
  }

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
        final data = response.data['data'];
        final List newUnits = data['units'] ?? [];
        final total = data['total'] ?? 0;
        
        if (refresh) {
          state = AsyncValue.data(newUnits);
        } else {
          final currentUnits = state.value ?? [];
          state = AsyncValue.data([...currentUnits, ...newUnits]);
        }
        
        _hasMore = (state.value?.length ?? 0) < total;
        
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
        if (state.hasValue) {
          state = AsyncValue.data(state.value!);
        }
      }
      // Automagically load more if the first page didn't fill enough space
      // This is a helper for large screens where 1 batch < screen height
      if (refresh && _hasMore) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (ref.read(unitsProvider.notifier)._hasMore) {
             // The scroll controller in the UI will handle the actual check
          }
        });
      }
    }
  }

  Future<void> fetchNextPage() async {
    if (!_hasMore || _isLoadingMore || state.isLoading) return;
    await fetchUnits(refresh: false);
  }

  Future<String?> bulkCreate(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('units/bulk', data: data);
      if (response.data['success'] == true) {
        fetchUnits();
        return null;
      }
      return response.data['message'] ?? 'Failed to create units';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to create units';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> createUnit(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('units', data: data);
      if (response.data['success'] == true) {
        fetchUnits();
        return null;
      }
      return response.data['message'] ?? 'Failed to create unit';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to create unit';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateUnit(String id, Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.patch('units/$id', data: data);
      if (response.data['success'] == true) {
        fetchUnits();
        return null;
      }
      return response.data['message'] ?? 'Failed to update unit';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update unit';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> assignResident(
    String unitId,
    String userId, {
    bool isOwner = false,
    bool isStaying = true,
  }) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        'units/$unitId/residents',
        data: {'userId': userId, 'isOwner': isOwner, 'isStaying': isStaying},
      );
      if (response.data['success'] == true) {
        await refreshUnitsSoft();
        return null;
      }
      return response.data['message'] ?? 'Failed to assign resident';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to assign resident';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> removeResident(String unitId, String userId) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.delete('units/$unitId/residents/$userId');
      if (response.data['success'] == true) {
        await refreshUnitsSoft();
        return null;
      }
      return response.data['message'] ?? 'Failed to remove resident';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to remove resident';
    } catch (e) {
      return e.toString();
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

  Future<String?> deleteUnit(String id) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.delete('units/$id');
      if (response.data['success'] == true) {
        fetchUnits();
        return null;
      }
      return response.data['message'] ?? 'Failed to delete unit';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to delete unit';
    } catch (e) {
      return e.toString();
    }
  }
}
