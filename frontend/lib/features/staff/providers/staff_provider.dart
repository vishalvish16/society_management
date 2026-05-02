import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/auth_provider.dart';

class StaffAttendanceSummaryQuery {
  /// Provide either (month) OR (from,to). Dates are ISO strings.
  final String? month; // "2026-04" or "2026-04-01"
  final String? from; // "2026-04-01"
  final String? to; // "2026-04-30"
  final bool paidLeave;
  final double halfDayFactor;
  /// calendar | working
  final String divisorMode;
  final bool excludeSundays;
  final bool excludeSaturdays;
  /// Comma-separated YYYY-MM-DD list
  final String? holidays;

  const StaffAttendanceSummaryQuery({
    this.month,
    this.from,
    this.to,
    this.paidLeave = false,
    this.halfDayFactor = 0.5,
    this.divisorMode = 'calendar',
    this.excludeSundays = false,
    this.excludeSaturdays = false,
    this.holidays,
  });

  Map<String, dynamic> toQueryParams() {
    final p = <String, dynamic>{
      'paidLeave': paidLeave,
      'halfDayFactor': halfDayFactor,
      'divisorMode': divisorMode,
      'excludeSundays': excludeSundays,
      'excludeSaturdays': excludeSaturdays,
    };
    if (holidays != null && holidays!.trim().isNotEmpty) {
      p['holidays'] = holidays!.trim();
    }
    if (from != null || to != null) {
      p['from'] = from;
      p['to'] = to;
    } else {
      p['month'] = month;
    }
    return p;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffAttendanceSummaryQuery &&
          runtimeType == other.runtimeType &&
          month == other.month &&
          from == other.from &&
          to == other.to &&
          paidLeave == other.paidLeave &&
          halfDayFactor == other.halfDayFactor &&
          divisorMode == other.divisorMode &&
          excludeSundays == other.excludeSundays &&
          excludeSaturdays == other.excludeSaturdays &&
          holidays == other.holidays;

  @override
  int get hashCode =>
      Object.hash(month, from, to, paidLeave, halfDayFactor, divisorMode,
          excludeSundays, excludeSaturdays, holidays);
}

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

class StaffAttendanceSummary {
  final String staffId;
  final String name;
  final String role;
  /// Period metadata (returned by API).
  final String periodType; // MONTH | RANGE
  final String? periodMonth; // YYYY-MM (only for MONTH)
  final DateTime? from;
  final DateTime? to;
  final int divisorDays;
  final int present;
  final int halfDay;
  final int absent;
  final int leave;
  final double payableDays;
  final double monthlySalary;
  final double perDayRate;
  final double salaryPayable;
  final StaffSalaryPayment? payment;

  const StaffAttendanceSummary({
    required this.staffId,
    required this.name,
    required this.role,
    required this.periodType,
    this.periodMonth,
    this.from,
    this.to,
    required this.divisorDays,
    required this.present,
    required this.halfDay,
    required this.absent,
    required this.leave,
    required this.payableDays,
    required this.monthlySalary,
    required this.perDayRate,
    required this.salaryPayable,
    this.payment,
  });

  factory StaffAttendanceSummary.fromJson(Map<String, dynamic> j) {
    final counts = (j['counts'] as Map?)?.cast<String, dynamic>() ?? const {};
    final period = (j['period'] as Map?)?.cast<String, dynamic>() ?? const {};
    final payment = j['payment'] is Map
        ? StaffSalaryPayment.fromJson((j['payment'] as Map).cast<String, dynamic>())
        : null;
    return StaffAttendanceSummary(
      staffId: j['staffId']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      role: j['role']?.toString() ?? '',
      periodType: period['type']?.toString() ?? '',
      periodMonth: period['month']?.toString(),
      from: period['from'] != null ? DateTime.tryParse(period['from'].toString()) : null,
      to: period['to'] != null ? DateTime.tryParse(period['to'].toString()) : null,
      divisorDays: int.tryParse(period['divisorDays']?.toString() ?? '') ?? 0,
      present: int.tryParse(counts['present']?.toString() ?? '') ?? 0,
      halfDay: int.tryParse(counts['halfDay']?.toString() ?? '') ?? 0,
      absent: int.tryParse(counts['absent']?.toString() ?? '') ?? 0,
      leave: int.tryParse(counts['leave']?.toString() ?? '') ?? 0,
      payableDays: double.tryParse(j['payableDays']?.toString() ?? '0') ?? 0,
      monthlySalary: double.tryParse(j['monthlySalary']?.toString() ?? '0') ?? 0,
      perDayRate: double.tryParse(j['perDayRate']?.toString() ?? '0') ?? 0,
      salaryPayable: double.tryParse(j['salaryPayable']?.toString() ?? '0') ?? 0,
      payment: payment,
    );
  }
}

class StaffSalaryPayment {
  final String id;
  final double amount;
  final String paymentMethod; // CASH | BANK | UPI | ONLINE | RAZORPAY
  final String? note;
  final DateTime? paidAt;

  const StaffSalaryPayment({
    required this.id,
    required this.amount,
    required this.paymentMethod,
    this.note,
    this.paidAt,
  });

  factory StaffSalaryPayment.fromJson(Map<String, dynamic> j) {
    return StaffSalaryPayment(
      id: j['id']?.toString() ?? '',
      amount: double.tryParse(j['amount']?.toString() ?? '0') ?? 0,
      paymentMethod: j['paymentMethod']?.toString() ?? 'CASH',
      note: j['note']?.toString(),
      paidAt: j['paidAt'] != null ? DateTime.tryParse(j['paidAt'].toString()) : null,
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

class StaffAttendanceSheetRow {
  final String staffId;
  final String name;
  final String role;
  final String? phone;
  final double salary;
  final String? status; // PRESENT | ABSENT | HALF_DAY | LEAVE

  const StaffAttendanceSheetRow({
    required this.staffId,
    required this.name,
    required this.role,
    this.phone,
    required this.salary,
    this.status,
  });

  factory StaffAttendanceSheetRow.fromJson(Map<String, dynamic> j) {
    return StaffAttendanceSheetRow(
      staffId: j['staffId']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      role: j['role']?.toString() ?? '',
      phone: j['phone']?.toString(),
      salary: double.tryParse(j['salary']?.toString() ?? '0') ?? 0,
      status: j['status']?.toString(),
    );
  }
}

final staffAttendanceSheetProvider =
    FutureProvider.family<List<StaffAttendanceSheetRow>, String>((ref, date) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return const [];
  final dio = ref.read(dioProvider);
  final res = await dio.get('staff/attendance-sheet', queryParameters: {'date': date});
  if (res.data['success'] == true) {
    final List list = res.data['data']?['rows'] ?? const [];
    return list
        .map((e) => StaffAttendanceSheetRow.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
  throw (res.data['message'] ?? 'Failed to load attendance sheet').toString();
});

final staffBulkAttendanceSubmitProvider =
    Provider<Future<String?> Function(String date, List<Map<String, dynamic>> records)>((ref) {
  return (String date, List<Map<String, dynamic>> records) async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('staff/attendance-bulk', data: {
        'date': date,
        'records': records,
      });
      if (res.data['success'] == true) return null;
      return res.data['message']?.toString() ?? 'Failed';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? e.message ?? 'Network error';
    } catch (e) {
      return e.toString();
    }
  };
});

final staffMarkSalaryPaidProvider =
    Provider<Future<String?> Function(Map<String, dynamic> payload)>((ref) {
  return (Map<String, dynamic> payload) async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('staff/salary-payments', data: payload);
      if (res.data['success'] == true) return null;
      return res.data['message']?.toString() ?? 'Failed';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? e.message ?? 'Network error';
    } catch (e) {
      return e.toString();
    }
  };
});

final staffMarkSalaryPaidBulkProvider =
    Provider<Future<String?> Function(Map<String, dynamic> payload)>((ref) {
  return (Map<String, dynamic> payload) async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('staff/salary-payments/bulk', data: payload);
      if (res.data['success'] == true) return null;
      return res.data['message']?.toString() ?? 'Failed';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? e.message ?? 'Network error';
    } catch (e) {
      return e.toString();
    }
  };
});

class StaffSalaryPaymentHistoryItem {
  final String id;
  final String staffId;
  final String staffName;
  final String staffRole;
  final String? staffPhone;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final double amount;
  final String paymentMethod;
  final String? note;
  final DateTime paidAt;
  final String? paidByName;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final String? cancelledByName;

  const StaffSalaryPaymentHistoryItem({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.staffRole,
    this.staffPhone,
    this.periodFrom,
    this.periodTo,
    required this.amount,
    required this.paymentMethod,
    this.note,
    required this.paidAt,
    this.paidByName,
    this.cancelledAt,
    this.cancelReason,
    this.cancelledByName,
  });

  factory StaffSalaryPaymentHistoryItem.fromJson(Map<String, dynamic> j) {
    final staff = (j['staff'] as Map?)?.cast<String, dynamic>() ?? const {};
    final paidBy = (j['paidBy'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cancelledBy = (j['cancelledBy'] as Map?)?.cast<String, dynamic>() ?? const {};
    return StaffSalaryPaymentHistoryItem(
      id: j['id']?.toString() ?? '',
      staffId: staff['id']?.toString() ?? j['staffId']?.toString() ?? '',
      staffName: staff['name']?.toString() ?? '',
      staffRole: staff['role']?.toString() ?? '',
      staffPhone: staff['phone']?.toString(),
      periodFrom: j['periodFrom'] != null ? DateTime.tryParse(j['periodFrom'].toString()) : null,
      periodTo: j['periodTo'] != null ? DateTime.tryParse(j['periodTo'].toString()) : null,
      amount: double.tryParse(j['amount']?.toString() ?? '0') ?? 0,
      paymentMethod: j['paymentMethod']?.toString() ?? 'CASH',
      note: j['note']?.toString(),
      paidAt: DateTime.tryParse(j['paidAt']?.toString() ?? '') ?? DateTime.now(),
      paidByName: paidBy['name']?.toString(),
      cancelledAt: j['cancelledAt'] != null ? DateTime.tryParse(j['cancelledAt'].toString()) : null,
      cancelReason: j['cancelReason']?.toString(),
      cancelledByName: cancelledBy['name']?.toString(),
    );
  }
}

class StaffPaymentHistoryQuery {
  final String month; // YYYY-MM
  final String? q;
  final int page;
  final int limit;
  final bool includeCancelled;

  const StaffPaymentHistoryQuery({
    required this.month,
    this.q,
    this.page = 1,
    this.limit = 50,
    this.includeCancelled = false,
  });

  Map<String, dynamic> toQueryParams() => {
        'month': month,
        'q': q,
        'page': page,
        'limit': limit,
        'includeCancelled': includeCancelled,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffPaymentHistoryQuery &&
          month == other.month &&
          q == other.q &&
          page == other.page &&
          limit == other.limit &&
          includeCancelled == other.includeCancelled;

  @override
  int get hashCode => Object.hash(month, q, page, limit, includeCancelled);
}

final staffPaymentHistoryProvider =
    FutureProvider.family<List<StaffSalaryPaymentHistoryItem>, StaffPaymentHistoryQuery>((ref, query) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return const [];
  final dio = ref.read(dioProvider);
  final res = await dio.get(
    'staff/salary-payments/history',
    queryParameters: query.toQueryParams(),
  );
  if (res.data['success'] == true) {
    final List list = res.data['data']?['payments'] ?? const [];
    return list
        .map((e) => StaffSalaryPaymentHistoryItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
  throw (res.data['message'] ?? 'Failed to load payment history').toString();
});

final staffCancelSalaryPaymentProvider =
    Provider<Future<String?> Function(String paymentId, {String? reason})>((ref) {
  return (String paymentId, {String? reason}) async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        'staff/salary-payments/$paymentId/cancel',
        data: {'reason': reason},
      );
      if (res.data['success'] == true) return null;
      return res.data['message']?.toString() ?? 'Failed';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? e.message ?? 'Network error';
    } catch (e) {
      return e.toString();
    }
  };
});

final staffCancelSalaryPaymentsBulkProvider =
    Provider<Future<String?> Function(List<String> ids, {String? reason})>((ref) {
  return (List<String> ids, {String? reason}) async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        'staff/salary-payments/cancel-bulk',
        data: {'ids': ids, 'reason': reason},
      );
      if (res.data['success'] == true) return null;
      return res.data['message']?.toString() ?? 'Failed';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? e.message ?? 'Network error';
    } catch (e) {
      return e.toString();
    }
  };
});

final staffProvider =
    StateNotifierProvider<StaffNotifier, AsyncValue<List<StaffMember>>>((ref) {
  final authState = ref.watch(authProvider);
  return StaffNotifier(ref, authState);
});

final staffAttendanceSummaryProvider =
    FutureProvider.family<List<StaffAttendanceSummary>, StaffAttendanceSummaryQuery>((ref, q) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return const [];
  final dio = ref.read(dioProvider);
  final res = await dio.get(
    'staff/attendance-summary',
    queryParameters: q.toQueryParams(),
  );
  if (res.data['success'] == true) {
    final List list = res.data['data']?['summaries'] ?? const [];
    return list
        .map((e) => StaffAttendanceSummary.fromJson(
            (e as Map).cast<String, dynamic>()))
        .toList();
  }
  throw (res.data['message'] ?? 'Failed to load attendance summary').toString();
});
