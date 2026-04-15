import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';

class VehiclesState {
  final List<Map<String, dynamic>> vehicles;
  final bool isLoading;
  final String? error;
  const VehiclesState({this.vehicles = const [], this.isLoading = false, this.error});
  VehiclesState copyWith({List<Map<String, dynamic>>? vehicles, bool? isLoading, String? error}) =>
      VehiclesState(vehicles: vehicles ?? this.vehicles, isLoading: isLoading ?? this.isLoading, error: error);
}

class VehiclesNotifier extends StateNotifier<VehiclesState> {
  VehiclesNotifier() : super(const VehiclesState()) { loadVehicles(); }
  final _client = DioClient();

  Future<void> loadVehicles() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _client.dio.get('/vehicles');
      final data = res.data['data'];
      state = state.copyWith(
        isLoading: false,
        vehicles: List<Map<String, dynamic>>.from(data['vehicles'] ?? []),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createVehicle(Map<String, dynamic> data) async {
    try {
      await _client.dio.post('/vehicles', data: data);
      await loadVehicles();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateVehicle(String id, Map<String, dynamic> data) async {
    try {
      await _client.dio.patch('/vehicles/$id', data: data);
      await loadVehicles();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteVehicle(String id) async {
    try {
      await _client.dio.delete('/vehicles/$id');
      await loadVehicles();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final vehiclesProvider =
    StateNotifierProvider<VehiclesNotifier, VehiclesState>((ref) => VehiclesNotifier());
