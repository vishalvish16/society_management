import 'package:flutter_riverpod/flutter_riverpod.dart';

final gatePassProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 400));
  return [
    {'visitor': 'Ramesh Sharma', 'unit': 'A-101', 'validTill': '2024-04-05', 'status': 'active'},
    {'visitor': 'Delivery Agent', 'unit': 'B-202', 'validTill': '2024-04-01', 'status': 'used'},
    {'visitor': 'Priya Nair', 'unit': 'C-303', 'validTill': '2024-03-30', 'status': 'expired'},
  ];
});
