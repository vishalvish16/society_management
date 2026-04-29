import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import 'package:dio/dio.dart';

class SuggestionsState {
  final List<Map<String, dynamic>> suggestions;
  final bool isLoading;
  final String? error;
  final String? activeStatus; // null = all
  const SuggestionsState({
    this.suggestions = const [],
    this.isLoading = false,
    this.error,
    this.activeStatus,
  });
  SuggestionsState copyWith({
    List<Map<String, dynamic>>? suggestions,
    bool? isLoading,
    String? error,
    Object? activeStatus = _sentinel,
  }) =>
      SuggestionsState(
        suggestions: suggestions ?? this.suggestions,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        activeStatus: activeStatus == _sentinel ? this.activeStatus : activeStatus as String?,
      );
  static const _sentinel = Object();
}

class SuggestionsNotifier extends StateNotifier<SuggestionsState> {
  SuggestionsNotifier() : super(const SuggestionsState()) {
    loadSuggestions();
  }

  final _client = DioClient();

  String? _normalizeStatus(String? status) {
    final s = status?.trim();
    if (s == null || s.isEmpty) return null;
    final lower = s.toLowerCase();
    if (lower == 'all' || lower == 'null') return null;
    return s;
  }

  Future<void> loadSuggestions({String? status}) async {
    final normalizedStatus = _normalizeStatus(status);
    state =
        state.copyWith(isLoading: true, error: null, activeStatus: normalizedStatus);
    try {
      final params = <String, dynamic>{};
      if (normalizedStatus != null) params['status'] = normalizedStatus;
      final res = await _client.dio.get('/suggestions', queryParameters: params);
      final data = res.data['data'];
      final list = List<Map<String, dynamic>>.from(data['suggestions'] ?? []);
      state = state.copyWith(isLoading: false, suggestions: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String?> createSuggestion(Map<String, dynamic> data, {List<dynamic>? attachments}) async {
    try {
      dynamic postData;
      if (attachments != null && attachments.isNotEmpty) {
        final formData = FormData.fromMap(data);
        for (final file in attachments) {
          final pf = file as PlatformFile;
          if (kIsWeb) {
            if (pf.bytes == null) continue;
            formData.files.add(MapEntry(
              'attachments',
              MultipartFile.fromBytes(pf.bytes!, filename: pf.name),
            ));
          } else if (pf.path != null && pf.path!.isNotEmpty) {
            formData.files.add(MapEntry(
              'attachments',
              await MultipartFile.fromFile(pf.path!, filename: pf.name),
            ));
          } else if (pf.bytes != null) {
            formData.files.add(MapEntry(
              'attachments',
              MultipartFile.fromBytes(pf.bytes!, filename: pf.name),
            ));
          }
        }
        postData = formData;
      } else {
        postData = data;
      }
      final res = await _client.dio.post('/suggestions', data: postData);
      if (res.data['success'] == true) {
        await loadSuggestions(status: state.activeStatus);
        return null;
      }
      return res.data['message'] ?? 'Failed to create suggestion';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to create suggestion';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateSuggestion(String id, Map<String, dynamic> data) async {
    try {
      final res = await _client.dio.patch('/suggestions/$id', data: data);
      if (res.data['success'] == true) {
        await loadSuggestions(status: state.activeStatus);
        return null;
      }
      return res.data['message'] ?? 'Failed to update suggestion';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update suggestion';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteSuggestion(String id) async {
    try {
      final res = await _client.dio.delete('/suggestions/$id');
      if (res.data['success'] == true) {
        // Optimistically remove from local list immediately, then reload
        state = state.copyWith(
          suggestions: state.suggestions.where((s) => s['id'] != id).toList(),
        );
        await loadSuggestions(status: state.activeStatus);
        return null;
      }
      return res.data['message'] ?? 'Failed to delete suggestion';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to delete suggestion';
    } catch (e) {
      return e.toString();
    }
  }
}

final suggestionsProvider =
    StateNotifierProvider<SuggestionsNotifier, SuggestionsState>((ref) => SuggestionsNotifier());
