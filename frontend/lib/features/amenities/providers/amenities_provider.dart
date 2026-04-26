import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/providers/dio_provider.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class AmenitiesState {
  final List<Map<String, dynamic>> amenities;
  final bool isLoading;
  final String? error;
  const AmenitiesState({this.amenities = const [], this.isLoading = false, this.error});
  AmenitiesState copyWith({List<Map<String, dynamic>>? amenities, bool? isLoading, String? error}) =>
      AmenitiesState(
        amenities: amenities ?? this.amenities,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AmenitiesNotifier extends StateNotifier<AmenitiesState> {
  final Ref ref;
  AmenitiesNotifier(this.ref) : super(const AmenitiesState()) {
    loadAmenities();
  }

  Dio get _dio => ref.read(dioProvider);

  Future<void> loadAmenities() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _dio.get('amenities');
      final raw = res.data['data'];
      final list = raw is List ? raw : (raw is Map ? (raw['amenities'] ?? []) : []);
      state = state.copyWith(isLoading: false, amenities: List<Map<String, dynamic>>.from(list));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String?> createAmenity(Map<String, dynamic> data) async {
    try {
      await _dio.post('amenities', data: data);
      await loadAmenities();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to create amenity';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateAmenity(String id, Map<String, dynamic> data) async {
    try {
      await _dio.patch('amenities/$id', data: data);
      await loadAmenities();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update amenity';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteAmenity(String id) async {
    try {
      await _dio.delete('amenities/$id');
      await loadAmenities();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to delete amenity';
    } catch (e) {
      return e.toString();
    }
  }

  Future<Map<String, dynamic>?> fetchSlots(String amenityId, String date) async {
    try {
      final res = await _dio.get('amenities/$amenityId/slots', queryParameters: {'date': date});
      return res.data['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchCalendar(String amenityId, String month) async {
    try {
      final res = await _dio.get('amenities/$amenityId/calendar', queryParameters: {'month': month});
      return res.data['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Returns created booking payload (may include `billId`) on success.
  Future<Map<String, dynamic>?> createBooking(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('amenities/bookings', data: data);
      if (res.data['success'] == true) {
        final created = res.data['data'];
        return created is Map<String, dynamic>
            ? created
            : (created is Map ? Map<String, dynamic>.from(created) : <String, dynamic>{});
      }
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        error: res.data['message'] ?? 'Failed to create booking',
        type: DioExceptionType.badResponse,
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to create booking');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<List<dynamic>> fetchMyBookings() async {
    try {
      final res = await _dio.get('amenities/bookings/mine');
      final data = res.data['data'];
      return data is Map ? (data['bookings'] ?? []) : [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> fetchBookings({
    String? status,
    int page = 1,
    int limit = 30,
    String? amenityId,
  }) async {
    try {
      final res = await _dio.get(
        'amenities/bookings',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (status != null && status.isNotEmpty) 'status': status,
          if (amenityId != null && amenityId.isNotEmpty) 'amenityId': amenityId,
        },
      );
      final data = res.data['data'];
      return data is Map ? (data['bookings'] ?? []) : [];
    } catch (_) {
      return [];
    }
  }

  Future<String?> cancelBooking(String bookingId) async {
    try {
      await _dio.patch('amenities/bookings/$bookingId/status', data: {'status': 'CANCELLED'});
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to cancel booking';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateBookingStatus(String bookingId, String status) async {
    try {
      await _dio.patch('amenities/bookings/$bookingId/status', data: {'status': status});
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update booking';
    } catch (e) {
      return e.toString();
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final amenitiesProvider = StateNotifierProvider<AmenitiesNotifier, AmenitiesState>(
  (ref) => AmenitiesNotifier(ref),
);

/// FutureProvider for my bookings list (invalidated after booking/cancel)
final myAmenityBookingsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('amenities/bookings/mine');
  final data = res.data['data'];
  return data is Map ? List<dynamic>.from(data['bookings'] ?? []) : [];
});

/// Admin all-bookings list
final allAmenityBookingsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('amenities/bookings');
  final data = res.data['data'];
  return data is Map ? List<dynamic>.from(data['bookings'] ?? []) : [];
});

/// Admin pending-approvals list (server-side filter)
final pendingAmenityBookingsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final dio = ref.read(dioProvider);
    final res = await dio.get('amenities/bookings', queryParameters: {
      'status': 'PENDING',
      'page': 1,
      'limit': 50,
    });
    final data = res.data['data'];
    return data is Map ? List<dynamic>.from(data['bookings'] ?? []) : [];
  } catch (_) {
    return [];
  }
});

bool isAmenityAdmin(String role) {
  const adminRoles = {
    'PRAMUKH', 'CHAIRMAN', 'VICE_CHAIRMAN', 'SECRETARY',
    'ASSISTANT_SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER',
  };
  return adminRoles.contains(role.toUpperCase());
}
