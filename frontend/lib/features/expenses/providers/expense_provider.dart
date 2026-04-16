import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

final expensesProvider = StateNotifierProvider<ExpensesNotifier, AsyncValue<List<dynamic>>>((ref) {
  final authState = ref.watch(authProvider);
  return ExpensesNotifier(ref, authState);
});

class ExpensesNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  final Ref ref;
  final AuthState authState;
  
  int _currentPage = 1;
  static const int _limit = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  ExpensesNotifier(this.ref, this.authState) : super(const AsyncValue.loading()) {
    if (authState.isAuthenticated) {
      fetchExpenses();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> fetchExpenses({bool refresh = true, String? category, String? status}) async {
    if (!authState.isAuthenticated) return;
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      state = const AsyncValue.loading();
    }

    if (_isLoadingMore && !refresh) return;
    
    if (!refresh) {
      _isLoadingMore = true;
    }

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('expenses', queryParameters: {
        'page': _currentPage,
        'limit': _limit,
        'category': category,
        'status': status,
      });
      
      if (response.data['success'] == true) {
        final List list = response.data['data']['expenses'] ?? [];
        _hasMore = list.length >= _limit;
        
        if (refresh) {
          state = AsyncValue.data(list);
        } else {
          final current = state.value ?? [];
          state = AsyncValue.data([...current, ...list]);
        }
        
        if (_hasMore) {
          _currentPage++;
        }
      } else {
        if (refresh) {
          state = AsyncValue.error(response.data['message'] ?? 'Failed to load expenses', StackTrace.current);
        }
      }
    } catch (e) {
      if (refresh) {
        state = AsyncValue.error(e.toString(), StackTrace.current);
      }
    } finally {
      if (!refresh) {
        _isLoadingMore = false;
        if (state.hasValue) {
          state = AsyncValue.data(state.value!);
        }
      }
    }
  }

  Future<void> loadNextPage() async {
    if (!_hasMore || _isLoadingMore || state.isLoading) return;
    await fetchExpenses(refresh: false);
  }

  Future<String?> createExpense(Map<String, dynamic> data, {List<XFile>? attachments}) async {
    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap(data);

      if (attachments != null && attachments.isNotEmpty) {
        for (var file in attachments) {
          final bytes = await file.readAsBytes();
          final extension = file.name.split('.').last.toLowerCase();
          String mimeType = 'application/octet-stream';
          if (extension == 'pdf') mimeType = 'application/pdf';
          else if (extension == 'jpg' || extension == 'jpeg') mimeType = 'image/jpeg';
          else if (extension == 'png') mimeType = 'image/png';

          formData.files.add(MapEntry(
            'attachments',
            MultipartFile.fromBytes(
              bytes,
              filename: file.name,
              contentType: MediaType.parse(mimeType),
            ),
          ));
        }
      }

      final response = await dio.post('expenses', data: formData);
      
      if (response.data['success'] == true) {
        fetchExpenses();
        return null;
      }
      return response.data['message'] ?? 'Failed to create expense';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to create expense';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateExpense(String id, Map<String, dynamic> data, {List<XFile>? attachments}) async {
    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap(data);

      if (attachments != null && attachments.isNotEmpty) {
        for (var file in attachments) {
          final bytes = await file.readAsBytes();
          final extension = file.name.split('.').last.toLowerCase();
          String mimeType = 'application/octet-stream';
          if (extension == 'pdf') { mimeType = 'application/pdf'; }
          else if (extension == 'jpg' || extension == 'jpeg') { mimeType = 'image/jpeg'; }
          else if (extension == 'png') { mimeType = 'image/png'; }
          formData.files.add(MapEntry(
            'attachments',
            MultipartFile.fromBytes(bytes, filename: file.name, contentType: MediaType.parse(mimeType)),
          ));
        }
      }

      final response = await dio.put('expenses/$id', data: formData);
      if (response.data['success'] == true) {
        fetchExpenses();
        return null;
      }
      return response.data['message'] ?? 'Failed to update expense';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update expense';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateStatus(String id, String status, {String? reason}) async {
    try {
      final dio = ref.read(dioProvider);
      final endpoint = status == 'approved'
          ? 'expenses/$id/approve'
          : 'expenses/$id/reject';
      final response = await dio.patch(endpoint, data: {
        if (status == 'rejected' && reason != null) 'rejectionReason': reason,
      });
      if (response.data['success'] == true) {
        fetchExpenses();
        return null;
      }
      return response.data['message'] ?? 'Failed to update status';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update status';
    } catch (e) {
      return e.toString();
    }
  }
}
