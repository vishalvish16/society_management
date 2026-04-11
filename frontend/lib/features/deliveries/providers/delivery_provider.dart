import 'package:flutter_riverpod/flutter_riverpod.dart';

final deliveryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 400));
  return [
    {'courier': 'Amazon', 'unit': 'A-101', 'time': 'Today 10:30 AM', 'status': 'pending'},
    {'courier': 'Flipkart', 'unit': 'B-202', 'time': 'Today 11:00 AM', 'status': 'collected'},
    {'courier': 'Zomato', 'unit': 'C-303', 'time': 'Yesterday 7:00 PM', 'status': 'collected'},
  ];
});
