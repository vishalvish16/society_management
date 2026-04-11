class UserModel {
  final String id;
  final String name;
  final String? email;
  final String phone;
  final String role;
  final String? societyId;
  final bool isActive;

  UserModel({
    required this.id,
    required this.name,
    this.email,
    required this.phone,
    required this.role,
    this.societyId,
    this.isActive = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'],
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      societyId: json['societyId'],
      isActive: json['isActive'] ?? true,
    );
  }

  bool get isSuperAdmin => role == 'SUPER_ADMIN';
  bool get isPramukh => role == 'PRAMUKH';
  bool get isSecretary => role == 'SECRETARY';
}
