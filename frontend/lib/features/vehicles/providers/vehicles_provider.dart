import 'package:flutter_riverpod/flutter_riverpod.dart';

final vehiclesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 400));
  return [
    {'plate': 'MH 01 AB 1234', 'type': 'car', 'unit': 'A-101', 'slot': 'P-01'},
    {'plate': 'MH 02 CD 5678', 'type': 'two_wheeler', 'unit': 'B-202', 'slot': 'P-15'},
    {'plate': 'MH 03 EF 9012', 'type': 'car', 'unit': 'C-303', 'slot': 'P-22'},
  ];
});
