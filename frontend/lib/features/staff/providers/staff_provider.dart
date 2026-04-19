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
  final String? userId; // linked User account (watchman only)
  /// DAY | NIGHT | FULL
  final String shift;
  final String? gateId;
  final String? gateName;
  final String? gateCode;
  final List<String> assignedWingCodes;

  const StaffMember({
    required this.id,
    required this.name,
    required this.role,
    this.phone,
    required this.salary,
    this.joiningDate,
    required this.isActive,
    this.lastAttendanceStatus,
    this.userId,
    this.shift = 'FULL',
    this.gateId,
    this.gateName,
    this.gateCode,
    this.assignedWingCodes = const [],
  });

  bool get hasLoginAccount => userId != null;

  String get shiftLabel {
    switch (shift.toUpperCase()) {
      case 'DAY':
        return 'Day shift';
      case 'NIGHT':
        return 'Night shift';
      default:
        return 'Full day';
    }
  }

  String? get gateDisplay {
    if (gateName == null || gateName!.isEmpty) return null;
    final c = gateCode?.trim();
    if (c != null && c.isNotEmpty) return '$c · $gateName';
    return gateName;
  }

  static List<String> _wingList(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }

  static String _shift(dynamic s) {
    final t = (s ?? 'FULL').toString().toUpperCase();
    if (t == 'DAY' || t == 'NIGHT' || t == 'FULL') return t;
    return 'FULL';
  }

  factory StaffMember.fromJson(Map<String, dynamic> j) {
    final attendance = (j['attendance'] as List?)?.isNotEmpty == true
        ? j['attendance'][0]
        : null;
    final gate = j['gate'] as Map<String, dynamic>?;
    return StaffMember(
      id: j['id'] ?? '',
      name: j['name'] ?? '',
      role: j['role'] ?? '',
      phone: j['phone'],
      salary: double.tryParse(j['salary']?.toString() ?? '0') ?? 0.0,
      joiningDate: j['joiningDate'] != null ? DateTime.tryParse(j['joiningDate']) : null,
      isActive: j['isActive'] ?? true,
      lastAttendanceStatus: attendance?['status'],
      userId: j['user']?['id'],
      shift: _shift(j['shift']),
      gateId: gate?['id']?.toString(),
      gateName: gate?['name']?.toString(),
      gateCode: gate?['code']?.toString(),
      assignedWingCodes: _wingList(j['assignedWingCodes']),
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

  Future<String?> createStaff(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('staff', data: data);
      if (response.data['success'] == true) {
        await loadStaff();
        return null;
      }
      return response.data['message'] ?? 'Failed to add staff';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to add staff';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateStaff(String id, Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.patch('staff/$id', data: data);
      if (response.data['success'] == true) {
        await loadStaff();
        return null;
      }
      return response.data['message'] ?? 'Failed to update staff';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update staff';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteStaff(String id) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.delete('staff/$id');
      if (response.data['success'] == true) {
        await loadStaff();
        return null;
      }
      return response.data['message'] ?? 'Failed to deactivate staff';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to deactivate staff';
    } catch (e) {
      return e.toString();
    }
  }

  /// Returns null on success, or an error message string.
  Future<String?> resetWatchmanPassword(String staffId, String newPassword) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('staff/$staffId/reset-password',
          data: {'password': newPassword});
      if (response.data['success'] == true) return null;
      return response.data['message'] ?? 'Failed';
    } on DioException catch (e) {
      return e.response?.data?['message'] ?? e.message ?? 'Network error';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> markAttendance(String staffId, String date, String status) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('staff/$staffId/attendance', data: {
        'date': date,
        'status': status,
      });
      if (response.data['success'] == true) {
        await loadStaff();
        return null;
      }
      return response.data['message'] ?? 'Failed to mark attendance';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to mark attendance';
    } catch (e) {
      return e.toString();
    }
  }
}

final staffProvider =
    StateNotifierProvider<StaffNotifier, AsyncValue<List<StaffMember>>>((ref) {
  final authState = ref.watch(authProvider);
  return StaffNotifier(ref, authState);
});
