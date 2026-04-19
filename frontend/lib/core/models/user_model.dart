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

  final String? profilePhotoUrl;
  final DateTime? dateOfBirth;
  final int? householdMemberCount;
  final String? bio;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

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
    this.profilePhotoUrl,
    this.dateOfBirth,
    this.householdMemberCount,
    this.bio,
    this.emergencyContactName,
    this.emergencyContactPhone,
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

    DateTime? dob;
    final rawDob = json['dateOfBirth'];
    if (rawDob is String && rawDob.isNotEmpty) {
      dob = DateTime.tryParse(rawDob);
    }

    int? members;
    final rawM = json['householdMemberCount'];
    if (rawM is int) {
      members = rawM;
    } else if (rawM is num) {
      members = rawM.toInt();
    }

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
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      dateOfBirth: dob,
      householdMemberCount: members,
      bio: json['bio'] as String?,
      emergencyContactName: json['emergencyContactName'] as String?,
      emergencyContactPhone: json['emergencyContactPhone'] as String?,
    );
  }

  /// Rough completeness score (0–100) for nudging users to fill their profile.
  int get profileCompletenessPercent {
    int filled = 0;
    const int slots = 7;
    if (name.trim().isNotEmpty) filled++;
    if (phone.trim().isNotEmpty) filled++;
    if (email != null && email!.trim().isNotEmpty) filled++;
    if (profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty) filled++;
    if (dateOfBirth != null) filled++;
    if (householdMemberCount != null && householdMemberCount! > 0) filled++;
    if ((bio != null && bio!.trim().isNotEmpty) ||
        (emergencyContactName != null && emergencyContactName!.trim().isNotEmpty) ||
        (emergencyContactPhone != null && emergencyContactPhone!.trim().isNotEmpty)) {
      filled++;
    }
    return ((filled / slots) * 100).round();
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
