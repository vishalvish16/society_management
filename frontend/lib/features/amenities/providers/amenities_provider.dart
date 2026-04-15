import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';

class AmenitiesState {
  final List<Map<String, dynamic>> amenities;
  final bool isLoading;
  final String? error;
  const AmenitiesState({this.amenities = const [], this.isLoading = false, this.error});
  AmenitiesState copyWith({List<Map<String, dynamic>>? amenities, bool? isLoading, String? error}) =>
      AmenitiesState(amenities: amenities ?? this.amenities, isLoading: isLoading ?? this.isLoading, error: error);
}

class AmenitiesNotifier extends StateNotifier<AmenitiesState> {
  AmenitiesNotifier() : super(const AmenitiesState()) { loadAmenities(); }
  final _client = DioClient();

  Future<void> loadAmenities() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _client.dio.get('/amenities');
      final raw = res.data['data'];
      final list = raw is List ? raw : (raw is Map ? (raw['amenities'] ?? []) : []);
      state = state.copyWith(isLoading: false, amenities: List<Map<String, dynamic>>.from(list));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createAmenity(Map<String, dynamic> data) async {
    try {
      await _client.dio.post('/amenities', data: data);
      await loadAmenities();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> updateAmenity(String id, Map<String, dynamic> data) async {
    try {
      await _client.dio.patch('/amenities/$id', data: data);
      await loadAmenities();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> deleteAmenity(String id) async {
    try {
      await _client.dio.delete('/amenities/$id');
      await loadAmenities();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> bookAmenity(Map<String, dynamic> data) async {
    try {
      await _client.dio.post('/amenities/bookings', data: data);
      return true;
    } catch (_) { return false; }
  }
}

final amenitiesProvider = StateNotifierProvider<AmenitiesNotifier, AmenitiesState>((ref) => AmenitiesNotifier());
