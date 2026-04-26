import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/providers/dio_provider.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class ParkingState {
  final List<Map<String, dynamic>> slots;
  final Map<String, dynamic>? dashboard;
  final bool isLoading;
  final String? error;

  const ParkingState({
    this.slots = const [],
    this.dashboard,
    this.isLoading = false,
    this.error,
  });

  ParkingState copyWith({
    List<Map<String, dynamic>>? slots,
    Map<String, dynamic>? dashboard,
    bool? isLoading,
    String? error,
  }) =>
      ParkingState(
        slots: slots ?? this.slots,
        dashboard: dashboard ?? this.dashboard,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ParkingNotifier extends StateNotifier<ParkingState> {
  final Ref ref;
  ParkingNotifier(this.ref) : super(const ParkingState()) {
    load();
  }

  Dio get _dio => ref.read(dioProvider);

  Future<List<Map<String, dynamic>>> fetchVehiclesByUnit(String unitId) async {
    try {
      final res = await _dio.get('vehicles', queryParameters: {'unitId': unitId, 'limit': 200});
      final data = res.data['data'];
      if (data is Map) {
        return List<Map<String, dynamic>>.from(data['vehicles'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _dio.get('parking/slots', queryParameters: {'limit': 200, 'includeInactive': 'true'}),
        _dio.get('parking/dashboard'),
      ]);

      final slotsRaw = results[0].data['data'];
      final slots = slotsRaw is Map
          ? List<Map<String, dynamic>>.from(slotsRaw['slots'] ?? [])
          : List<Map<String, dynamic>>.from(slotsRaw ?? []);

      final dashboard = results[1].data['data'] as Map<String, dynamic>?;

      state = state.copyWith(isLoading: false, slots: slots, dashboard: dashboard);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Slot CRUD ──────────────────────────────────────────────────────────────

  Future<String?> createSlot(Map<String, dynamic> data) async {
    try {
      await _dio.post('parking/slots', data: data);
      await load();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to create slot';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateSlot(String id, Map<String, dynamic> data) async {
    try {
      await _dio.patch('parking/slots/$id', data: data);
      await load();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update slot';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteSlot(String id) async {
    try {
      await _dio.delete('parking/slots/$id');
      await load();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to remove slot';
    } catch (e) {
      return e.toString();
    }
  }

  Future<List<Map<String, dynamic>>> fetchAvailableSlots({String? type}) async {
    try {
      final res = await _dio.get('parking/slots/available',
          queryParameters: type != null ? {'type': type} : null);
      final data = res.data['data'];
      return data is List ? List<Map<String, dynamic>>.from(data) : [];
    } catch (_) {
      return [];
    }
  }

  // ── Allotments ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchAllotments({String? status}) async {
    try {
      final res = await _dio.get('parking/allotments',
          queryParameters: status != null ? {'status': status} : null);
      final data = res.data['data'];
      return data is Map
          ? List<Map<String, dynamic>>.from(data['allotments'] ?? [])
          : [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchUnitAllotments(String unitId) async {
    try {
      final res = await _dio.get('parking/allotments/unit/$unitId');
      final data = res.data['data'];
      return data is List ? List<Map<String, dynamic>>.from(data) : [];
    } catch (_) {
      return [];
    }
  }

  Future<String?> createAllotment(Map<String, dynamic> data) async {
    try {
      await _dio.post('parking/allotments', data: data);
      await load();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to create allotment';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> releaseAllotment(String id, {String? reason}) async {
    try {
      await _dio.patch('parking/allotments/$id/release',
          data: reason != null ? {'releaseReason': reason} : {});
      await load();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to release allotment';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> transferAllotment(String id, Map<String, dynamic> data) async {
    try {
      await _dio.patch('parking/allotments/$id/transfer', data: data);
      await load();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to transfer allotment';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> suspendAllotment(String id) async {
    try {
      await _dio.patch('parking/allotments/$id/suspend');
      await load();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to suspend allotment';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> reinstateAllotment(String id) async {
    try {
      await _dio.patch('parking/allotments/$id/reinstate');
      await load();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to reinstate allotment';
    } catch (e) {
      return e.toString();
    }
  }

  // ── Sessions ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchSessions({String? status}) async {
    try {
      final res = await _dio.get('parking/sessions',
          queryParameters: status != null ? {'status': status} : null);
      final data = res.data['data'];
      return data is Map
          ? List<Map<String, dynamic>>.from(data['sessions'] ?? [])
          : [];
    } catch (_) {
      return [];
    }
  }

  Future<String?> logEntry(Map<String, dynamic> data) async {
    try {
      await _dio.post('parking/sessions', data: data);
      await load();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to log entry';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> logExit(String sessionId) async {
    try {
      await _dio.patch('parking/sessions/$sessionId/exit', data: {});
      await load();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to log exit';
    } catch (e) {
      return e.toString();
    }
  }

  // ── Charges ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchCharges({bool? isPaid}) async {
    try {
      final res = await _dio.get('parking/charges',
          queryParameters: isPaid != null ? {'isPaid': isPaid.toString()} : null);
      final data = res.data['data'];
      return data is Map
          ? List<Map<String, dynamic>>.from(data['charges'] ?? [])
          : [];
    } catch (_) {
      return [];
    }
  }

  Future<String?> payCharge(String id, {String? paymentMethod}) async {
    try {
      await _dio.patch('parking/charges/$id/pay',
          data: paymentMethod != null ? {'paymentMethod': paymentMethod} : {});
      await load();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to mark charge paid';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> generateMonthlyCharges(Map<String, dynamic> data) async {
    try {
      await _dio.post('parking/charges/generate', data: data);
      await load();
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to generate charges';
    } catch (e) {
      return e.toString();
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final parkingProvider = StateNotifierProvider<ParkingNotifier, ParkingState>(
  (ref) => ParkingNotifier(ref),
);

final parkingAllotmentsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String?>((ref, status) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('parking/allotments',
      queryParameters: status != null ? {'status': status, 'limit': 100} : {'limit': 100});
  final data = res.data['data'];
  return data is Map ? List<Map<String, dynamic>>.from(data['allotments'] ?? []) : [];
});

final parkingSessionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('parking/sessions', queryParameters: {'status': 'ACTIVE', 'limit': 100});
  final data = res.data['data'];
  return data is Map ? List<Map<String, dynamic>>.from(data['sessions'] ?? []) : [];
});

final parkingChargesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, bool?>((ref, isPaid) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('parking/charges',
      queryParameters: isPaid != null ? {'isPaid': isPaid.toString(), 'limit': 100} : {'limit': 100});
  final data = res.data['data'];
  return data is Map ? List<Map<String, dynamic>>.from(data['charges'] ?? []) : [];
});

bool isParkingAdmin(String role) {
  const adminRoles = {
    'PRAMUKH',
    'CHAIRMAN',
    'VICE_CHAIRMAN',
    'SECRETARY',
    'ASSISTANT_SECRETARY',
    'TREASURER',
    'ASSISTANT_TREASURER',
  };
  return adminRoles.contains(role.toUpperCase());
}

bool isParkingStaff(String role) =>
    isParkingAdmin(role) || role.toUpperCase() == 'WATCHMAN';
