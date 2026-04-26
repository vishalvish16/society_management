import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/dio_provider.dart';

class AssetsState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> assets;
  final int total;
  final Map<String, dynamic>? summary;

  const AssetsState({
    this.isLoading = false,
    this.error,
    this.assets = const [],
    this.total = 0,
    this.summary,
  });

  AssetsState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? assets,
    int? total,
    Map<String, dynamic>? summary,
  }) {
    return AssetsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      assets: assets ?? this.assets,
      total: total ?? this.total,
      summary: summary ?? this.summary,
    );
  }
}

class AssetsNotifier extends StateNotifier<AssetsState> {
  final Ref ref;
  final AuthState auth;
  AssetsNotifier(this.ref, this.auth) : super(const AssetsState()) {
    if (auth.isAuthenticated) refresh();
  }

  Dio get _dio => ref.read(dioProvider);

  bool get _isAdmin {
    final r = auth.user?.role.toUpperCase() ?? '';
    return {'PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'VICE_CHAIRMAN', 'TREASURER'}.contains(r);
  }

  Future<void> refresh({Map<String, String>? filters}) async {
    if (!auth.isAuthenticated) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _dio.get('assets', queryParameters: filters);
      final data = res.data['data'] as Map<String, dynamic>;
      final list = List<Map<String, dynamic>>.from(data['assets'] ?? []);
      final total = data['total'] as int? ?? list.length;

      Map<String, dynamic>? summary;
      if (_isAdmin) {
        try {
          final sRes = await _dio.get('assets/summary');
          summary = sRes.data['data'] as Map<String, dynamic>?;
        } catch (_) {}
      }

      state = state.copyWith(isLoading: false, assets: list, total: total, summary: summary);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message']?.toString() ?? e.message ?? 'Failed to load assets',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> getAsset(String id) async {
    try {
      final res = await _dio.get('assets/$id');
      return res.data['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> createAsset(Map<String, dynamic> data, {List<File>? files}) async {
    try {
      final formData = FormData.fromMap({
        ...data.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      });
      if (files != null) {
        for (final f in files) {
          final name = f.path.split(Platform.pathSeparator).last;
          final ext = name.split('.').last.toLowerCase();
          final mime = _mimeType(ext);
          formData.files.add(MapEntry(
            'attachments',
            await MultipartFile.fromFile(f.path, filename: name, contentType: MediaType.parse(mime)),
          ));
        }
      }
      final res = await _dio.post('assets', data: formData);
      if (res.data['success'] == true) {
        await refresh();
        return null;
      }
      return res.data['message']?.toString() ?? 'Failed to create asset';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to create asset';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateAsset(String id, Map<String, dynamic> data, {List<File>? files}) async {
    try {
      final formData = FormData.fromMap({
        ...data.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      });
      if (files != null) {
        for (final f in files) {
          final name = f.path.split(Platform.pathSeparator).last;
          final ext = name.split('.').last.toLowerCase();
          final mime = _mimeType(ext);
          formData.files.add(MapEntry(
            'attachments',
            await MultipartFile.fromFile(f.path, filename: name, contentType: MediaType.parse(mime)),
          ));
        }
      }
      final res = await _dio.put('assets/$id', data: formData);
      if (res.data['success'] == true) {
        await refresh();
        return null;
      }
      return res.data['message']?.toString() ?? 'Failed to update asset';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to update asset';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteAsset(String id) async {
    try {
      final res = await _dio.delete('assets/$id');
      if (res.data['success'] == true) {
        await refresh();
        return null;
      }
      return res.data['message']?.toString() ?? 'Failed to delete';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to delete';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteAttachment(String assetId, String attachmentId) async {
    try {
      await _dio.delete('assets/$assetId/attachments/$attachmentId');
      return null;
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to delete attachment';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> addMaintenanceLog(String assetId, Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('assets/$assetId/maintenance', data: data);
      if (res.data['success'] == true) return null;
      return res.data['message']?.toString() ?? 'Failed to add log';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to add log';
    } catch (e) {
      return e.toString();
    }
  }

  String _mimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}

final assetsProvider = StateNotifierProvider<AssetsNotifier, AssetsState>((ref) {
  final auth = ref.watch(authProvider);
  return AssetsNotifier(ref, auth);
});
