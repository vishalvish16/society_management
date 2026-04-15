import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';

class DeliveryState {
  final List<Map<String, dynamic>> deliveries;
  final bool isLoading;
  final String? error;
  const DeliveryState({
    this.deliveries = const [],
    this.isLoading = false,
    this.error,
  });
  DeliveryState copyWith({
    List<Map<String, dynamic>>? deliveries,
    bool? isLoading,
    String? error,
  }) =>
      DeliveryState(
        deliveries: deliveries ?? this.deliveries,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class DeliveryNotifier extends StateNotifier<DeliveryState> {
  DeliveryNotifier() : super(const DeliveryState()) {
    loadDeliveries();
  }

  final _client = DioClient();

  Future<void> loadDeliveries() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _client.dio.get('/deliveries');
      final data = res.data['data'];
      state = state.copyWith(
        isLoading: false,
        deliveries: List<Map<String, dynamic>>.from(data['deliveries'] ?? []),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> logDelivery(Map<String, dynamic> data) async {
    try {
      await _client.dio.post('/deliveries', data: data);
      await loadDeliveries();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markCollected(String id) async {
    try {
      await _client.dio.patch('/deliveries/$id/collect');
      await loadDeliveries();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> respondDelivery(String id, String action) async {
    try {
      await _client.dio.patch('/deliveries/$id/respond', data: {'action': action});
      await loadDeliveries();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final deliveryProvider =
    StateNotifierProvider<DeliveryNotifier, DeliveryState>(
        (ref) => DeliveryNotifier());
