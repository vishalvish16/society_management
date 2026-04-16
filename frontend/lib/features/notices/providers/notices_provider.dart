import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import 'package:dio/dio.dart';

class NoticesState {
  final List<Map<String, dynamic>> notices;
  final bool isLoading;
  final String? error;
  const NoticesState({this.notices = const [], this.isLoading = false, this.error});
  NoticesState copyWith({List<Map<String, dynamic>>? notices, bool? isLoading, String? error}) =>
      NoticesState(notices: notices ?? this.notices, isLoading: isLoading ?? this.isLoading, error: error);
}

class NoticesNotifier extends StateNotifier<NoticesState> {
  NoticesNotifier() : super(const NoticesState()) { loadNotices(); }
  final _client = DioClient();

  Future<void> loadNotices() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _client.dio.get('/notices');
      final data = res.data['data'];
      state = state.copyWith(isLoading: false, notices: List<Map<String, dynamic>>.from(data['notices'] ?? []));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String?> createNotice(Map<String, dynamic> data) async {
    try {
      final res = await _client.dio.post('/notices', data: data);
      if (res.data['success'] == true) {
        await loadNotices();
        return null;
      }
      return res.data['message'] ?? 'Failed to create notice';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to create notice';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateNotice(String id, Map<String, dynamic> data) async {
    try {
      final res = await _client.dio.patch('/notices/$id', data: data);
      if (res.data['success'] == true) {
        await loadNotices();
        return null;
      }
      return res.data['message'] ?? 'Failed to update notice';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update notice';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteNotice(String id) async {
    try {
      final res = await _client.dio.delete('/notices/$id');
      if (res.data['success'] == true) {
        await loadNotices();
        return null;
      }
      return res.data['message'] ?? 'Failed to delete notice';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to delete notice';
    } catch (e) {
      return e.toString();
    }
  }
}

final noticesProvider = StateNotifierProvider<NoticesNotifier, NoticesState>((ref) => NoticesNotifier());
