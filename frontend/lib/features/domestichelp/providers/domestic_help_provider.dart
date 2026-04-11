import 'package:flutter_riverpod/flutter_riverpod.dart';

final domesticHelpProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 400));
  return [
    {'name': 'Sunita Bai', 'type': 'maid', 'unit': 'A-101', 'status': 'active'},
    {'name': 'Ramesh Cook', 'type': 'cook', 'unit': 'B-202', 'status': 'active'},
    {'name': 'Mohan Driver', 'type': 'driver', 'unit': 'C-303', 'status': 'suspended'},
  ];
});
