import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';

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

  Future<bool> createNotice(Map<String, dynamic> data) async {
    try {
      await _client.dio.post('/notices', data: data);
      await loadNotices();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> updateNotice(String id, Map<String, dynamic> data) async {
    try {
      await _client.dio.patch('/notices/$id', data: data);
      await loadNotices();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> deleteNotice(String id) async {
    try {
      await _client.dio.delete('/notices/$id');
      await loadNotices();
      return true;
    } catch (_) { return false; }
  }
}

final noticesProvider = StateNotifierProvider<NoticesNotifier, NoticesState>((ref) => NoticesNotifier());
