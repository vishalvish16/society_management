import 'dart:io';
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

  /// Update a pending visitor invitation.
  Future<String?> updateVisitor(String id, Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.patch('visitors/$id', data: data);
      if (response.data['success'] == true) {
        fetchVisitors();
        return null;
      }
      return response.data['message'] ?? 'Failed to update visitor';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update visitor';
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
        fetchVisitors();
        return null;
      }
      return response.data['message'] ?? 'Invalid QR';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Network error';
    } catch (e) {
      return e.toString();
    }
  }

  /// Walk-in log with optional photo file (multipart).
  Future<String?> logVisitorWithPhoto(Map<String, dynamic> fields, File? photo) async {
    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap({
        ...fields,
        if (photo != null)
          'photo': await MultipartFile.fromFile(photo.path, filename: 'entry.jpg'),
      });
      final response = await dio.post('visitors/log-entry', data: formData);
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

  /// Approve or deny a walk-in that is awaiting unit member approval.
  Future<String?> approveWalkin(String visitorId, String action) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.patch('visitors/$visitorId/approve', data: {'action': action});
      if (response.data['success'] == true) {
        fetchVisitors();
        return null;
      }
      return response.data['message'] ?? 'Failed to respond';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to respond';
    } catch (e) {
      return e.toString();
    }
  }
}

// ─── Pending approvals provider (for unit members) ───────────────────────────

final pendingWalkinApprovalsProvider =
    StateNotifierProvider<PendingApprovalsNotifier, AsyncValue<List<dynamic>>>((ref) {
  final authState = ref.watch(authProvider);
  return PendingApprovalsNotifier(ref, authState);
});

class PendingApprovalsNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  final Ref ref;
  final AuthState authState;
  bool _fetchedOnce = false;

  PendingApprovalsNotifier(this.ref, this.authState) : super(const AsyncValue.loading()) {
    if (authState.isAuthenticated) {
      // If token isn't ready yet (common when app opens via notification),
      // wait for auth token then fetch. This prevents a false "Network error".
      ref.listen<AuthState>(authProvider, (prev, next) {
        if (!_fetchedOnce && next.isAuthenticated && next.token != null) {
          fetch();
        }
      });
      if (authState.token != null) {
        fetch();
      }
    } else {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> fetch() async {
    if (!authState.isAuthenticated) return;
    if (ref.read(authProvider).token == null) return;
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('visitors/pending-approvals');
      if (response.data['success'] == true) {
        _fetchedOnce = true;
        state = AsyncValue.data(List<dynamic>.from(response.data['data'] ?? []));
      } else {
        _fetchedOnce = true;
        state = AsyncValue.data([]);
      }
    } on DioException catch (e) {
      state = AsyncValue.error(e.response?.data['message'] ?? 'Network error', StackTrace.current);
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
    }
  }

  Future<String?> approve(String visitorId, String action) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.patch('visitors/$visitorId/approve', data: {'action': action});
      if (response.data['success'] == true) {
        fetch();
        return null;
      }
      return response.data['message'] ?? 'Failed to respond';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to respond';
    } catch (e) {
      return e.toString();
    }
  }
}
