import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import 'package:dio/dio.dart';

class ComplaintsState {
  final List<Map<String, dynamic>> complaints;
  final bool isLoading;
  final String? error;
  final String? activeStatus; // null = all
  const ComplaintsState({
    this.complaints = const [],
    this.isLoading = false,
    this.error,
    this.activeStatus,
  });
  ComplaintsState copyWith({
    List<Map<String, dynamic>>? complaints,
    bool? isLoading,
    String? error,
    Object? activeStatus = _sentinel,
  }) =>
      ComplaintsState(
        complaints: complaints ?? this.complaints,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        activeStatus: activeStatus == _sentinel ? this.activeStatus : activeStatus as String?,
      );
  static const _sentinel = Object();
}

class ComplaintsNotifier extends StateNotifier<ComplaintsState> {
  ComplaintsNotifier() : super(const ComplaintsState()) {
    loadComplaints();
  }

  final _client = DioClient();

  String? _normalizeStatus(String? status) {
    final s = status?.trim();
    if (s == null || s.isEmpty) return null;
    final lower = s.toLowerCase();
    if (lower == 'all' || lower == 'null') return null;
    return s;
  }

  Future<void> loadComplaints({String? status}) async {
    final normalizedStatus = _normalizeStatus(status);
    state =
        state.copyWith(isLoading: true, error: null, activeStatus: normalizedStatus);
    try {
      final params = <String, dynamic>{};
      if (normalizedStatus != null) params['status'] = normalizedStatus;
      final res = await _client.dio.get('/complaints', queryParameters: params);
      final data = res.data['data'];
      final list = List<Map<String, dynamic>>.from(data['complaints'] ?? []);
      state = state.copyWith(isLoading: false, complaints: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String?> createComplaint(Map<String, dynamic> data, {List<dynamic>? attachments}) async {
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
      final res = await _client.dio.post('/complaints', data: postData);
      if (res.data['success'] == true) {
        await loadComplaints(status: state.activeStatus);
        return null;
      }
      return res.data['message'] ?? 'Failed to create complaint';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to create complaint';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateComplaint(String id, Map<String, dynamic> data) async {
    try {
      final res = await _client.dio.patch('/complaints/$id', data: data);
      if (res.data['success'] == true) {
        await loadComplaints(status: state.activeStatus);
        return null;
      }
      return res.data['message'] ?? 'Failed to update complaint';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update complaint';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteComplaint(String id) async {
    try {
      final res = await _client.dio.delete('/complaints/$id');
      if (res.data['success'] == true) {
        // Optimistically remove from local list immediately, then reload
        state = state.copyWith(
          complaints: state.complaints.where((c) => c['id'] != id).toList(),
        );
        await loadComplaints(status: state.activeStatus);
        return null;
      }
      return res.data['message'] ?? 'Failed to delete complaint';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to delete complaint';
    } catch (e) {
      return e.toString();
    }
  }
}

final complaintsProvider =
    StateNotifierProvider<ComplaintsNotifier, ComplaintsState>((ref) => ComplaintsNotifier());
