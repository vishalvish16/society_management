import 'package:flutter_riverpod/flutter_riverpod.dart';

class Member {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String role;
  final String unit;

  const Member({required this.id, required this.name, required this.phone,
    this.email, required this.role, required this.unit});

  factory Member.fromJson(Map<String, dynamic> j) => Member(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    phone: j['phone'] ?? '',
    email: j['email'],
    role: j['role'] ?? 'resident',
    unit: (j['unitResidents'] as List?)?.isNotEmpty == true
        ? (j['unitResidents'][0]['unit']?['fullCode'] ?? '')
        : '',
  );
}

final membersProvider = FutureProvider<List<Member>>((ref) async {
  // TODO: wire to DioClient
  await Future.delayed(const Duration(milliseconds: 500));
  return [
    Member(id: '1', name: 'Rajesh Kumar', phone: '9876543210', role: 'resident', unit: 'A-101'),
    Member(id: '2', name: 'Priya Sharma', phone: '9876543211', role: 'resident', unit: 'B-202'),
    Member(id: '3', name: 'Amit Patel', phone: '9876543212', role: 'secretary', unit: 'C-303'),
  ];
});
