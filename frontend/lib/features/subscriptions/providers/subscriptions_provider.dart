import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import '../../superadmin/providers/dashboard_provider.dart';

class SubscriptionsState {
  final List<Map<String, dynamic>> subscriptions;
  final int total;
  final int page;
  final bool isLoading;
  final String? error;

  const SubscriptionsState({
    this.subscriptions = const [],
    this.total = 0,
    this.page = 1,
    this.isLoading = false,
    this.error,
  });

  SubscriptionsState copyWith({
    List<Map<String, dynamic>>? subscriptions,
    int? total,
    int? page,
    bool? isLoading,
    String? error,
  }) {
    return SubscriptionsState(
      subscriptions: subscriptions ?? this.subscriptions,
      total: total ?? this.total,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SubscriptionsNotifier extends StateNotifier<SubscriptionsState> {
  final Ref _ref;
  SubscriptionsNotifier(this._ref) : super(const SubscriptionsState());

  final _client = DioClient();

  void _invalidateDashboard() {
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(recentSocietiesProvider);
  }

  Future<void> loadSubscriptions({int page = 1, String? status, String? societyId}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{'page': page, 'limit': 20};
      if (status != null) params['status'] = status;
      if (societyId != null) params['societyId'] = societyId;

      final response = await _client.dio.get('/subscriptions', queryParameters: params);
      final data = response.data['data'];

      state = state.copyWith(
        subscriptions: List<Map<String, dynamic>>.from(data['subscriptions'] ?? []),
        total: data['total'] ?? 0,
        page: page,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load subscriptions');
    }
  }

  Future<bool> assignPlan(Map<String, dynamic> data) async {
    try {
      await _client.dio.post('/subscriptions', data: data);
      await loadSubscriptions(page: state.page);
      _invalidateDashboard();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> renewSubscription(String id, Map<String, dynamic> data) async {
    try {
      await _client.dio.post('/subscriptions/$id/renew', data: data);
      await loadSubscriptions(page: state.page);
      _invalidateDashboard();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancelSubscription(String id, String? reason) async {
    try {
      await _client.dio.post('/subscriptions/$id/cancel', data: {'reason': reason});
      await loadSubscriptions(page: state.page);
      _invalidateDashboard();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final subscriptionsProvider = StateNotifierProvider<SubscriptionsNotifier, SubscriptionsState>((ref) {
  return SubscriptionsNotifier(ref);
});
