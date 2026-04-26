import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import 'package:dio/dio.dart';

class SuggestionsState {
  final List<Map<String, dynamic>> suggestions;
  final bool isLoading;
  final String? error;
  const SuggestionsState({this.suggestions = const [], this.isLoading = false, this.error});
  SuggestionsState copyWith({List<Map<String, dynamic>>? suggestions, bool? isLoading, String? error}) =>
      SuggestionsState(
        suggestions: suggestions ?? this.suggestions,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class SuggestionsNotifier extends StateNotifier<SuggestionsState> {
  SuggestionsNotifier() : super(const SuggestionsState()) {
    loadSuggestions();
  }

  final _client = DioClient();

  Future<void> loadSuggestions({String? status}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{};
      if (status != null && status.isNotEmpty) params['status'] = status;
      final res = await _client.dio.get('/suggestions', queryParameters: params);
      final data = res.data['data'];
      state = state.copyWith(
        isLoading: false,
        suggestions: List<Map<String, dynamic>>.from(data['suggestions'] ?? []),
      );
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
        await loadSuggestions();
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
        await loadSuggestions();
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
        await loadSuggestions();
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

