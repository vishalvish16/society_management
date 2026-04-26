import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import 'package:dio/dio.dart';

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
        await loadComplaints();
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
        await loadComplaints();
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
        await loadComplaints();
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

final complaintsProvider = StateNotifierProvider<ComplaintsNotifier, ComplaintsState>((ref) => ComplaintsNotifier());
