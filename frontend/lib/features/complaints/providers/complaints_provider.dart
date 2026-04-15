import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';

class ComplaintsState {
  final List<Map<String, dynamic>> complaints;
  final bool isLoading;
  final String? error;
  const ComplaintsState({this.complaints = const [], this.isLoading = false, this.error});
  ComplaintsState copyWith({List<Map<String, dynamic>>? complaints, bool? isLoading, String? error}) =>
      ComplaintsState(complaints: complaints ?? this.complaints, isLoading: isLoading ?? this.isLoading, error: error);
}

class ComplaintsNotifier extends StateNotifier<ComplaintsState> {
  ComplaintsNotifier() : super(const ComplaintsState()) { loadComplaints(); }
  final _client = DioClient();

  Future<void> loadComplaints({String? status}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{};
      if (status != null && status.isNotEmpty) params['status'] = status;
      final res = await _client.dio.get('/complaints', queryParameters: params);
      final data = res.data['data'];
      state = state.copyWith(isLoading: false, complaints: List<Map<String, dynamic>>.from(data['complaints'] ?? []));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createComplaint(Map<String, dynamic> data) async {
    try {
      await _client.dio.post('/complaints', data: data);
      await loadComplaints();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> updateComplaint(String id, Map<String, dynamic> data) async {
    try {
      await _client.dio.patch('/complaints/$id', data: data);
      await loadComplaints();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> deleteComplaint(String id) async {
    try {
      await _client.dio.delete('/complaints/$id');
      await loadComplaints();
      return true;
    } catch (_) { return false; }
  }
}

final complaintsProvider = StateNotifierProvider<ComplaintsNotifier, ComplaintsState>((ref) => ComplaintsNotifier());
