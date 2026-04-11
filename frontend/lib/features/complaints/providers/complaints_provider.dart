import 'package:flutter_riverpod/flutter_riverpod.dart';

class Complaint {
  final String id;
  final String title;
  final String unit;
  final String date;
  final String status;
  final String category;

  const Complaint({required this.id, required this.title, required this.unit,
    required this.date, required this.status, required this.category});

  factory Complaint.fromJson(Map<String, dynamic> j) => Complaint(
    id: j['id'] ?? '',
    title: j['title'] ?? '',
    unit: j['unit']?['fullCode'] ?? '',
    date: j['createdAt'] ?? '',
    status: j['status'] ?? 'open',
    category: j['category'] ?? 'other',
  );
}

final complaintsProvider = FutureProvider<List<Complaint>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 500));
  return [
    Complaint(id: '1', title: 'Water leakage in bathroom', unit: 'A-101', date: '2024-04-01', status: 'open', category: 'plumbing'),
    Complaint(id: '2', title: 'Lift not working', unit: 'B-202', date: '2024-04-02', status: 'in_progress', category: 'lift'),
    Complaint(id: '3', title: 'Parking issue', unit: 'C-303', date: '2024-04-03', status: 'resolved', category: 'parking'),
  ];
});
