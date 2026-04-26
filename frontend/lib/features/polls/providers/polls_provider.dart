import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/dio_provider.dart';

class PollsState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> inbox;
  final List<Map<String, dynamic>> created;

  const PollsState({
    this.isLoading = false,
    this.error,
    this.inbox = const [],
    this.created = const [],
  });

  PollsState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? inbox,
    List<Map<String, dynamic>>? created,
  }) {
    return PollsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      inbox: inbox ?? this.inbox,
      created: created ?? this.created,
    );
  }
}

class PollsNotifier extends StateNotifier<PollsState> {
  final Ref ref;
  final AuthState auth;
  PollsNotifier(this.ref, this.auth) : super(const PollsState()) {
    if (auth.isAuthenticated) {
      refreshAll();
    }
  }

  bool get _isAdmin {
    final r = auth.user?.role.toUpperCase() ?? '';
    return r == 'PRAMUKH' || r == 'CHAIRMAN' || r == 'SECRETARY';
  }

  Dio get _dio => ref.read(dioProvider);

  Future<void> refreshAll() async {
    if (!auth.isAuthenticated) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final inboxRes = await _dio.get('polls/inbox');
      final inboxData = (inboxRes.data['data'] as List?) ?? const [];
      final inbox = List<Map<String, dynamic>>.from(inboxData);

      List<Map<String, dynamic>> created = state.created;
      if (_isAdmin) {
        final createdRes = await _dio.get('polls/created');
        final createdData = (createdRes.data['data'] as List?) ?? const [];
        created = List<Map<String, dynamic>>.from(createdData);
      }

      state = state.copyWith(isLoading: false, inbox: inbox, created: created);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message']?.toString() ?? e.message ?? 'Failed to load polls',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> getPoll(String id) async {
    try {
      final res = await _dio.get('polls/$id');
      return res.data['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> vote({required String pollId, required String optionId}) async {
    try {
      final res = await _dio.post('polls/$pollId/vote', data: {'optionId': optionId});
      if (res.data['success'] == true) {
        await refreshAll();
        return null;
      }
      return res.data['message']?.toString() ?? 'Vote failed';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Vote failed';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> closePoll(String pollId) async {
    try {
      final res = await _dio.post('polls/$pollId/close');
      if (res.data['success'] == true) {
        await refreshAll();
        return null;
      }
      return res.data['message']?.toString() ?? 'Failed to close poll';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to close poll';
    } catch (e) {
      return e.toString();
    }
  }

  Future<Map<String, dynamic>?> getResults(String pollId) async {
    try {
      final res = await _dio.get('polls/$pollId/results');
      return res.data['data'] as Map<String, dynamic>?;
    } on DioException catch (e) {
      return {
        '_error': e.response?.data?['message']?.toString() ?? e.message ?? 'Failed to load results',
      };
    } catch (e) {
      return {
        '_error': e.toString(),
      };
    }
  }

  Future<List<Map<String, dynamic>>> listRecipients() async {
    // Use backend /users listing which is admin-guarded.
    final res = await _dio.get('users', queryParameters: {'isActive': true, 'limit': 200});
    final data = res.data['data'] as Map<String, dynamic>? ?? {};
    final list = (data['users'] as List?) ?? const [];
    return List<Map<String, dynamic>>.from(list);
  }

  Future<String?> createPoll({
    required String title,
    String? description,
    required List<String> options,
    required List<String> recipientIds,
    List<String>? recipientRoles,
    DateTime? closesAt,
  }) async {
    try {
      final res = await _dio.post('polls', data: {
        'title': title,
        'description': description,
        'options': options,
        'recipientIds': recipientIds,
        if (recipientRoles != null && recipientRoles.isNotEmpty) 'recipientRoles': recipientRoles,
        if (closesAt != null) 'closesAt': closesAt.toIso8601String(),
      });
      if (res.data['success'] == true) {
        await refreshAll();
        return null;
      }
      return res.data['message']?.toString() ?? 'Failed to create poll';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to create poll';
    } catch (e) {
      return e.toString();
    }
  }
}

final pollsProvider = StateNotifierProvider<PollsNotifier, PollsState>((ref) {
  final auth = ref.watch(authProvider);
  return PollsNotifier(ref, auth);
});

