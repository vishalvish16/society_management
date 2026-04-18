import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import 'package:dio/dio.dart';

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

  Future<String?> logDelivery(Map<String, dynamic> data) async {
    try {
      final res = await _client.dio.post('/deliveries', data: data);
      if (res.data['success'] == true) {
        await loadDeliveries();
        return null;
      }
      return res.data['message'] ?? 'Failed to log delivery';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to log delivery';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> markCollected(String id) async {
    try {
      final res = await _client.dio.patch('/deliveries/$id/collect');
      if (res.data['success'] == true) {
        await loadDeliveries();
        return null;
      }
      return res.data['message'] ?? 'Failed to mark as collected';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to mark as collected';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> respondDelivery(String id, String action) async {
    try {
      final res = await _client.dio.patch('/deliveries/$id/respond', data: {'action': action});
      if (res.data['success'] == true) {
        await loadDeliveries();
        return null;
      }
      return res.data['message'] ?? 'Failed to respond to delivery';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to respond to delivery';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> markReturned(String id) async {
    try {
      final res = await _client.dio.patch('/deliveries/$id/return');
      if (res.data['success'] == true) {
        await loadDeliveries();
        return null;
      }
      return res.data['message'] ?? 'Failed to mark as returned';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to mark as returned';
    } catch (e) {
      return e.toString();
    }
  }
}

final deliveryProvider =
    StateNotifierProvider<DeliveryNotifier, DeliveryState>(
        (ref) => DeliveryNotifier());
