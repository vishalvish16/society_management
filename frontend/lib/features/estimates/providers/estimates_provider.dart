import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/dio_client.dart';

class AcceptedUnlinkedEstimatesResult {
  final List<Map<String, dynamic>> estimates;
  final String? error;

  const AcceptedUnlinkedEstimatesResult({required this.estimates, this.error});
}

class EstimatesState {
  final List<Map<String, dynamic>> estimates;
  final int total;
  final int page;
  final bool isLoading;
  final String? error;

  const EstimatesState({
    this.estimates = const [],
    this.total = 0,
    this.page = 1,
    this.isLoading = false,
    this.error,
  });

  EstimatesState copyWith({
    List<Map<String, dynamic>>? estimates,
    int? total,
    int? page,
    bool? isLoading,
    String? error,
  }) {
    return EstimatesState(
      estimates: estimates ?? this.estimates,
      total: total ?? this.total,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class EstimatesNotifier extends StateNotifier<EstimatesState> {
  EstimatesNotifier() : super(const EstimatesState());

  final _client = DioClient();

  Future<void> loadEstimates({int page = 1, String? status, String? search}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{'page': page, 'limit': 20};
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final response = await _client.dio.get('/estimates', queryParameters: params);
      final data = response.data['data'];
      state = state.copyWith(
        estimates: List<Map<String, dynamic>>.from(data['estimates'] ?? []),
        total: data['total'] ?? 0,
        page: page,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load estimates');
    }
  }

  Future<Map<String, dynamic>?> createEstimate(Map<String, dynamic> data) async {
    try {
      final response = await _client.dio.post('/estimates', data: data);
      await loadEstimates(page: state.page);
      return response.data['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateEstimate(String id, Map<String, dynamic> data) async {
    try {
      await _client.dio.patch('/estimates/$id', data: data);
      await loadEstimates(page: state.page);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendEstimate(String id) async {
    try {
      await _client.dio.post('/estimates/$id/send');
      await loadEstimates(page: state.page);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> acceptEstimate(String id) async {
    try {
      await _client.dio.post('/estimates/$id/accept');
      await loadEstimates(page: state.page);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> closeEstimate(String id, String reason, {String status = 'CLOSED'}) async {
    try {
      await _client.dio.post('/estimates/$id/close', data: {
        'closeReason': reason,
        'status': status,
      });
      await loadEstimates(page: state.page);
      return null;
    } on DioException catch (e) {
      return (e.response?.data?['message'] as String?) ?? 'Failed to close estimate';
    } catch (_) {
      return 'Failed to close estimate';
    }
  }

  /// Fetch accepted, unlinked estimates for society creation picker.
  Future<AcceptedUnlinkedEstimatesResult> fetchAcceptedUnlinked() async {
    try {
      final response = await _client.dio.get('/estimates/accepted-unlinked');
      final items = List<Map<String, dynamic>>.from(response.data['data'] ?? []);
      return AcceptedUnlinkedEstimatesResult(estimates: items);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final serverMessage = (data is Map ? data['message'] : null)?.toString();

      String message;
      if (status == 401) message = 'Unauthorized. Please login again.';
      else if (status == 403) message = serverMessage ?? 'Access denied.';
      else if (status == 404) message = 'Estimates API not found (404).';
      else message = serverMessage ?? 'Failed to load accepted estimates.';

      return AcceptedUnlinkedEstimatesResult(estimates: const [], error: message);
    } catch (_) {
      return const AcceptedUnlinkedEstimatesResult(
        estimates: [],
        error: 'Failed to load accepted estimates.',
      );
    }
  }
}

final estimatesProvider =
    StateNotifierProvider<EstimatesNotifier, EstimatesState>((ref) => EstimatesNotifier());
