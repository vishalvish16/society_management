import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/auth_provider.dart';

class StaffMember {
  final String id;
  final String name;
  final String role;
  final String? phone;
  final double salary;
  final DateTime? joiningDate;
  final bool isActive;
  final String? lastAttendanceStatus;

  const StaffMember({
    required this.id,
    required this.name,
    required this.role,
    this.phone,
    required this.salary,
    this.joiningDate,
    required this.isActive,
    this.lastAttendanceStatus,
  });

  factory StaffMember.fromJson(Map<String, dynamic> j) {
    final attendance = (j['attendance'] as List?)?.isNotEmpty == true
        ? j['attendance'][0]
        : null;
    return StaffMember(
      id: j['id'] ?? '',
      name: j['name'] ?? '',
      role: j['role'] ?? '',
      phone: j['phone'],
      salary: double.tryParse(j['salary']?.toString() ?? '0') ?? 0.0,
      joiningDate: j['joiningDate'] != null ? DateTime.tryParse(j['joiningDate']) : null,
      isActive: j['isActive'] ?? true,
      lastAttendanceStatus: attendance?['status'],
    );
  }
}

class StaffNotifier extends StateNotifier<AsyncValue<List<StaffMember>>> {
  final Ref ref;
  final AuthState authState;

  StaffNotifier(this.ref, this.authState) : super(const AsyncValue.loading()) {
    if (authState.isAuthenticated) {
      loadStaff();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> loadStaff() async {
    if (!authState.isAuthenticated) return;
    state = const AsyncValue.loading();
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('staff');
      if (response.data['success'] == true) {
        final List list = response.data['data']['staff'] ?? [];
        state = AsyncValue.data(list.map((e) => StaffMember.fromJson(e)).toList());
      } else {
        state = AsyncValue.error(
          response.data['message'] ?? 'Failed to load staff',
          StackTrace.current,
        );
      }
    } on DioException catch (e) {
      state = AsyncValue.error(
        e.response?.data['message'] ?? e.message ?? 'Network error',
        StackTrace.current,
      );
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
    }
  }

  Future<bool> createStaff(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('staff', data: data);
      if (response.data['success'] == true) {
        await loadStaff();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateStaff(String id, Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.patch('staff/$id', data: data);
      if (response.data['success'] == true) {
        await loadStaff();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteStaff(String id) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.delete('staff/$id');
      if (response.data['success'] == true) {
        await loadStaff();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAttendance(String staffId, String date, String status) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('staff/$staffId/attendance', data: {
        'date': date,
        'status': status,
      });
      if (response.data['success'] == true) {
        await loadStaff();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

final staffProvider =
    StateNotifierProvider<StaffNotifier, AsyncValue<List<StaffMember>>>((ref) {
  final authState = ref.watch(authProvider);
  return StaffNotifier(ref, authState);
});
