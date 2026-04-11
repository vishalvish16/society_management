import 'package:flutter_riverpod/flutter_riverpod.dart';

final noticesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 400));
  return [
    {'title': 'Society AGM Meeting', 'preview': 'Annual General Meeting scheduled for 10th April at clubhouse', 'category': 'Meeting', 'date': '2024-04-01', 'author': 'Secretary'},
    {'title': 'Water Supply Disruption', 'preview': 'Water supply will be disrupted on 5th April from 10AM to 2PM', 'category': 'Maintenance', 'date': '2024-04-02', 'author': 'Admin'},
  ];
});
