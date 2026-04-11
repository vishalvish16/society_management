import 'package:flutter_riverpod/flutter_riverpod.dart';

final staffProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 400));
  return [
    {'name': 'Raju Guard', 'role': 'watchman', 'shift': 'Day', 'status': 'present'},
    {'name': 'Meena Maid', 'role': 'housekeeping', 'shift': 'Morning', 'status': 'absent'},
    {'name': 'Suresh Driver', 'role': 'driver', 'shift': 'Day', 'status': 'present'},
  ];
});
