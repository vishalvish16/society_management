import 'package:flutter_riverpod/flutter_riverpod.dart';

final visitorsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 400));
  return [
    {'name': 'Ramesh Gupta', 'unit': 'A-101', 'purpose': 'Personal', 'status': 'valid'},
    {'name': 'Delivery Boy', 'unit': 'B-202', 'purpose': 'Delivery', 'status': 'used'},
    {'name': 'Suresh Kumar', 'unit': 'C-303', 'purpose': 'Work', 'status': 'expired'},
  ];
});
