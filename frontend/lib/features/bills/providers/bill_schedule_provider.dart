import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';

final billSchedulesProvider = StateNotifierProvider<BillSchedulesNotifier,
    AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return BillSchedulesNotifier(ref);
});

class BillSchedulesNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref ref;
  BillSchedulesNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchSchedules();
  }

  Future<void> fetchSchedules() async {
    try {
      state = const AsyncValue.loading();
      final dio = ref.read(dioProvider);
      final response = await dio.get('bills/schedules');
      if (response.data['success'] == true) {
        final raw = response.data['data'];
        final List list = raw is List ? raw : (raw ?? const []);
        state = AsyncValue.data(
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        );
        return;
      }
      state = AsyncValue.error(
        response.data['message'] ?? 'Failed to load bill schedules',
        StackTrace.current,
      );
    } catch (e) {
      state = AsyncValue.error(
        e is DioException ? (e.response?.data['message'] ?? e.message) : e.toString(),
        StackTrace.current,
      );
    }
  }

  /// Returns null on success, error message on failure.
  Future<String?> upsertSchedule({
    required DateTime billingMonth,
    required DateTime scheduledFor,
    required double defaultAmount,
    required DateTime dueDate,
    bool isActive = true,
    String category = 'MAINTENANCE',
  }) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('bills/schedules', data: {
        'billingMonth': billingMonth.toIso8601String(),
        'scheduledFor': scheduledFor.toIso8601String(),
        'defaultAmount': defaultAmount,
        'dueDate': dueDate.toIso8601String(),
        'isActive': isActive,
        'category': category,
      });

      if (response.data['success'] == true) {
        await fetchSchedules();
        return null;
      }
      return response.data['message'] ?? 'Failed to save schedule';
    } catch (e) {
      if (e is DioException) return e.response?.data['message'] ?? e.message;
      return e.toString();
    }
  }
}

