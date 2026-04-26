import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/dio_provider.dart';

class RulesState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> rules;

  const RulesState({
    this.isLoading = false,
    this.error,
    this.rules = const [],
  });

  RulesState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? rules,
  }) {
    return RulesState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      rules: rules ?? this.rules,
    );
  }
}

class RulesNotifier extends StateNotifier<RulesState> {
  final Ref ref;
  final AuthState auth;
  RulesNotifier(this.ref, this.auth) : super(const RulesState()) {
    if (auth.isAuthenticated) loadRules();
  }

  Dio get _dio => ref.read(dioProvider);

  Future<void> loadRules({String? category}) async {
    if (!auth.isAuthenticated) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{};
      if (category != null && category.isNotEmpty) params['category'] = category;
      final res = await _dio.get('rules', queryParameters: params);
      final data = (res.data['data'] as List?) ?? const [];
      final rules = List<Map<String, dynamic>>.from(data);
      state = state.copyWith(isLoading: false, rules: rules);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message']?.toString() ?? e.message ?? 'Failed to load rules',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String?> createRule({
    required String title,
    String? description,
    String category = 'GENERAL',
  }) async {
    try {
      final res = await _dio.post('rules', data: {
        'title': title,
        'description': description,
        'category': category,
      });
      if (res.data['success'] == true) {
        await loadRules();
        return null;
      }
      return res.data['message']?.toString() ?? 'Failed to create rule';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to create rule';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateRule({
    required String id,
    String? title,
    String? description,
    String? category,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (category != null) data['category'] = category;
      if (isActive != null) data['isActive'] = isActive;

      final res = await _dio.patch('rules/$id', data: data);
      if (res.data['success'] == true) {
        await loadRules();
        return null;
      }
      return res.data['message']?.toString() ?? 'Failed to update rule';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to update rule';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteRule(String id) async {
    try {
      final res = await _dio.delete('rules/$id');
      if (res.data['success'] == true) {
        await loadRules();
        return null;
      }
      return res.data['message']?.toString() ?? 'Failed to delete rule';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to delete rule';
    } catch (e) {
      return e.toString();
    }
  }
}

final rulesProvider = StateNotifierProvider<RulesNotifier, RulesState>((ref) {
  final auth = ref.watch(authProvider);
  return RulesNotifier(ref, auth);
});
