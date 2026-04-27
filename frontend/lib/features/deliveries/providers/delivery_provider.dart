import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/providers/auth_provider.dart';
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
  DeliveryNotifier(this.ref) : super(const DeliveryState()) {
    loadDeliveries();
  }

  final Ref ref;
  final _client = DioClient();

  bool _useMineEndpoint() {
    final role = (ref.read(authProvider).user?.role ?? '').toUpperCase();
    return role == 'RESIDENT' || role == 'MEMBER';
  }

  Future<void> loadDeliveries() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final path = _useMineEndpoint() ? '/deliveries/mine' : '/deliveries';
      final res = await _client.dio.get(path);
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

  /// Watchman uploads a parcel photo for a LEFT_AT_GATE delivery.
  Future<String?> uploadDropPhoto(String id, File photo) async {
    try {
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(photo.path, filename: 'parcel.jpg'),
      });
      final res = await _client.dio.patch('/deliveries/$id/drop-photo', data: formData);
      if (res.data['success'] == true) {
        await loadDeliveries();
        return null;
      }
      return res.data['message'] ?? 'Failed to upload photo';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to upload photo';
    } catch (e) {
      return e.toString();
    }
  }

  /// Resident confirms they received the parcel from watchman (optional proof photo).
  Future<String?> markReceived(String id, {File? photo}) async {
    try {
      final data = photo == null
          ? null
          : FormData.fromMap({
              'photo': await MultipartFile.fromFile(photo.path, filename: 'received.jpg'),
            });
      final res = await _client.dio.patch('/deliveries/$id/received', data: data);
      if (res.data['success'] == true) {
        await loadDeliveries();
        return null;
      }
      return res.data['message'] ?? 'Failed to mark as received';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to mark as received';
    } catch (e) {
      return e.toString();
    }
  }
}

final deliveryProvider =
    StateNotifierProvider<DeliveryNotifier, DeliveryState>(
        (ref) => DeliveryNotifier(ref));
