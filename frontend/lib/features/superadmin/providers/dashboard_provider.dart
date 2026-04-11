import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';

class DashboardStats {
  final int totalSocieties;
  final int totalUsers;
  final int totalUnits;
  final int activeSubscriptions;
  final int trialSubscriptions;
  final int expiredSubscriptions;
  final double mrr;
  final double arr;
  final List<PlanDistribution> planDistribution;

  DashboardStats({
    required this.totalSocieties,
    required this.totalUsers,
    required this.totalUnits,
    required this.activeSubscriptions,
    required this.trialSubscriptions,
    required this.expiredSubscriptions,
    required this.mrr,
    required this.arr,
    required this.planDistribution,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalSocieties: json['totalSocieties'] ?? 0,
      totalUsers: json['totalUsers'] ?? 0,
      totalUnits: json['totalUnits'] ?? 0,
      activeSubscriptions: json['activeSubscriptions'] ?? 0,
      trialSubscriptions: json['trialSubscriptions'] ?? 0,
      expiredSubscriptions: json['expiredSubscriptions'] ?? 0,
      mrr: (json['mrr'] ?? 0).toDouble(),
      arr: (json['arr'] ?? 0).toDouble(),
      planDistribution: (json['planDistribution'] as List? ?? [])
          .map((e) => PlanDistribution.fromJson(e))
          .toList(),
    );
  }
}

class PlanDistribution {
  final String planName;
  final String planCode;
  final int count;

  PlanDistribution({required this.planName, required this.planCode, required this.count});

  factory PlanDistribution.fromJson(Map<String, dynamic> json) {
    return PlanDistribution(
      planName: json['planName'] ?? '',
      planCode: json['planCode'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

final dashboardProvider = FutureProvider<DashboardStats>((ref) async {
  final response = await DioClient().dio.get('/superadmin/dashboard');
  return DashboardStats.fromJson(response.data['data']);
});

final recentSocietiesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await DioClient().dio.get('/superadmin/societies/recent');
  return List<Map<String, dynamic>>.from(response.data['data'] ?? []);
});
