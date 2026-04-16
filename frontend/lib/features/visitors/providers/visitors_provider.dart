import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/auth_provider.dart';

// ─── Providers ──────────────────────────────────────────────────────

final visitorsProvider = StateNotifierProvider<VisitorsNotifier, AsyncValue<List<dynamic>>>((ref) {
  final authState = ref.watch(authProvider);
  return VisitorsNotifier(ref, authState);
});

// ─── Notifier ────────────────────────────────────────────────────────

class VisitorsNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  final Ref ref;
  final AuthState authState;

  int _currentPage = 1;
  static const int _limit = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  VisitorsNotifier(this.ref, this.authState) : super(const AsyncValue.loading()) {
    if (authState.isAuthenticated) {
      fetchVisitors();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> fetchVisitors({bool refresh = true}) async {
    if (!authState.isAuthenticated) return;
    
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      state = const AsyncValue.loading();
    }

    if (_isLoadingMore && !refresh) return;
    
    if (!refresh) {
      _isLoadingMore = true;
    }

    try {
      final dio = ref.read(dioProvider);
      
      final response = await dio.get('visitors', queryParameters: {
        'page': _currentPage,
        'limit': _limit,
      });
      
      if (response.data['success'] == true) {
        final List newVisitors = response.data['data']['visitors'] ?? [];
        _hasMore = newVisitors.length >= _limit;
        
        if (refresh) {
          state = AsyncValue.data(newVisitors);
        } else {
          final currentVisitors = state.value ?? [];
          state = AsyncValue.data([...currentVisitors, ...newVisitors]);
        }
        
        if (_hasMore) {
          _currentPage++;
        }
      } else {
        if (refresh) {
          state = AsyncValue.error(response.data['message'] ?? 'Failed to fetch visitors', StackTrace.current);
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
    }
  }

  Future<void> fetchNextPage() async {
    if (!_hasMore || _isLoadingMore || state.isLoading) return;
    await fetchVisitors(refresh: false);
  }

  /// Walk-in log — no QR generated or sent.
  Future<String?> logVisitor(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('visitors/log-entry', data: data);
      if (response.data['success'] == true) {
        fetchVisitors();
        return null;
      }
      return response.data['message'] ?? 'Failed to log visitor';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to log visitor';
    } catch (e) {
      return e.toString();
    }
  }

  /// Invite visitor — generates QR and dispatches via WhatsApp + email.
  Future<String?> inviteVisitor(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('visitors/invite', data: data);
      if (response.data['success'] == true) {
        fetchVisitors();
        return null;
      }
      return response.data['message'] ?? 'Failed to send invitation';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to send invitation';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> validateVisitor(String qrToken) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('visitors/validate', data: {'qrToken': qrToken});
      if (response.data['success'] == true) {
        fetchVisitors(); // Refresh list
        return null;
      }
      return response.data['message'] ?? 'Invalid QR';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Network error';
    } catch (e) {
      return e.toString();
    }
  }
}
