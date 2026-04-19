import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/search_result_model.dart';
import 'dio_provider.dart';

/// Shared link so the search field (in the header) and the results dropdown (above
/// the rest of the dashboard) stay composited together while painting the dropdown last.
final dashboardSearchLayerLinkProvider = Provider<LayerLink>((ref) => LayerLink());

class GlobalSearchState {
  final String query;
  final bool isLoading;
  final String? error;
  final List<GlobalSearchResult> results;

  const GlobalSearchState({
    required this.query,
    required this.isLoading,
    required this.results,
    this.error,
  });

  const GlobalSearchState.idle()
      : query = '',
        isLoading = false,
        results = const [],
        error = null;

  GlobalSearchState copyWith({
    String? query,
    bool? isLoading,
    String? error,
    List<GlobalSearchResult>? results,
  }) {
    return GlobalSearchState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      results: results ?? this.results,
    );
  }
}

class GlobalSearchNotifier extends StateNotifier<GlobalSearchState> {
  final Ref ref;
  Timer? _debounce;
  int _seq = 0;

  GlobalSearchNotifier(this.ref) : super(const GlobalSearchState.idle());

  void setQuery(String q) {
    final query = q.trim();
    state = state.copyWith(query: query, error: null);
    _debounce?.cancel();

    if (query.length < 2) {
      state = state.copyWith(isLoading: false, results: const []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    final dio = ref.read(dioProvider);
    final mySeq = ++_seq;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await dio.get('search', queryParameters: {'q': query});
      if (mySeq != _seq) return; // stale response
      final data = res.data;

      List rawList = const [];
      if (data is Map) {
        final dataField = data['data'];
        if (dataField is Map && dataField['results'] is List) {
          rawList = dataField['results'] as List;
        } else if (data['results'] is List) {
          rawList = data['results'] as List;
        }
      }

      final results = rawList
          .where((e) => e is Map)
          .map((e) => GlobalSearchResult.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
      state = state.copyWith(isLoading: false, results: results);
    } on DioException catch (e) {
      if (mySeq != _seq) return;
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message']?.toString() ?? e.message,
        results: const [],
      );
    } catch (e) {
      if (mySeq != _seq) return;
      state = state.copyWith(isLoading: false, error: e.toString(), results: const []);
    }
  }

  void clear() {
    _debounce?.cancel();
    state = const GlobalSearchState.idle();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final globalSearchProvider =
    StateNotifierProvider<GlobalSearchNotifier, GlobalSearchState>((ref) {
  return GlobalSearchNotifier(ref);
});

