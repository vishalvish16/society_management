import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';

/// Society-admin stats (PRAMUKH, CHAIRMAN, VICE_CHAIRMAN, SECRETARY, etc.)
final societyDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('dashboard/stats');
  return response.data['data'] ?? {};
});

/// Resident personal stats
final residentDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('dashboard/stats');
  return response.data['data'] ?? {};
});

/// Watchman gate stats
final watchmanDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('dashboard/stats');
  return response.data['data'] ?? {};
});

/// Member dashboard (same as society admin stats but shown with member-focused UI)
final memberDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('dashboard/stats');
  return response.data['data'] ?? {};
});
