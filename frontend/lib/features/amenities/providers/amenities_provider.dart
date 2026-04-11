import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final amenitiesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 400));
  return [
    {'name': 'Gym', 'status': 'active', 'icon': Icons.fitness_center_rounded},
    {'name': 'Swimming Pool', 'status': 'active', 'icon': Icons.pool_rounded},
    {'name': 'Clubhouse', 'status': 'active', 'icon': Icons.meeting_room_rounded},
    {'name': 'Tennis Court', 'status': 'under_maintenance', 'icon': Icons.sports_tennis_rounded},
    {'name': 'Garden', 'status': 'active', 'icon': Icons.local_florist_rounded},
    {'name': 'Library', 'status': 'inactive', 'icon': Icons.menu_book_rounded},
  ];
});
