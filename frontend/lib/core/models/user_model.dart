class UserModel {
  final String id;
  final String name;
  final String? email;
  final String phone;
  final String role;
  final String? societyId;
  final bool isActive;
  // Unit the member belongs to (populated from login/me API)
  final String? unitId;
  final String? unitCode;

  UserModel({
    required this.id,
    required this.name,
    this.email,
    required this.phone,
    required this.role,
    this.societyId,
    this.isActive = true,
    this.unitId,
    this.unitCode,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // The login API returns `unit: {id, fullCode}` and /me returns
    // `unitResidents: [{unit: {id, fullCode, ...}}]`
    final unitMap = json['unit'] as Map<String, dynamic>?;
    final unitResidents = json['unitResidents'] as List?;
    final firstUnit = unitResidents?.isNotEmpty == true
        ? (unitResidents![0] as Map<String, dynamic>)['unit'] as Map<String, dynamic>?
        : null;
    final resolvedUnit = unitMap ?? firstUnit;

    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'],
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      societyId: json['societyId'],
      isActive: json['isActive'] ?? true,
      unitId: resolvedUnit?['id'] as String?,
      unitCode: resolvedUnit?['fullCode'] as String?,
    );
  }

  bool get isSuperAdmin => role == 'SUPER_ADMIN';
  bool get isChairman => role == 'PRAMUKH' || role == 'CHAIRMAN';
  bool get isSecretary => role == 'SECRETARY';
  bool get isManager => role == 'MANAGER';

  /// Returns true for roles that should have their unit locked to their own
  /// unit and should NOT be able to pick a different unit in forms.
  static const _memberOnlyRoles = {
    'MEMBER',
    'RESIDENT',
    'VICE_CHAIRMAN',
    'ASSISTANT_SECRETARY',
    'TREASURER',
    'ASSISTANT_TREASURER',
  };

  /// True when the logged-in user is a regular member/resident who cannot
  /// change the unit field — it should be auto-selected and locked.
  bool get isUnitLocked => _memberOnlyRoles.contains(role.toUpperCase());
}
