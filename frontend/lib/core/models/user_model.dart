class UserModel {
  final String id;
  final String name;
  final String? email;
  final String phone;
  final String role;
  final String? societyId;
  final bool isActive;
  final String? unitId;
  final String? unitCode;

  final String? profilePhotoUrl;
  final DateTime? dateOfBirth;
  final int? householdMemberCount;
  final String? bio;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  /// Feature flags from the society's active plan.
  /// Keys match the backend planConfig.js FEATURE_DEFAULTS.
  /// null = plan data not yet loaded (treat as no access).
  final Map<String, dynamic>? planFeatures;

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
    this.planFeatures,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
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

    // planFeatures may come from:
    //   login response: json['planFeatures']
    //   me response:    json['society']['plan']['features']
    Map<String, dynamic>? features;
    final directFeatures = json['planFeatures'];
    if (directFeatures is Map) {
      features = Map<String, dynamic>.from(directFeatures);
    } else {
      final society = json['society'] as Map<String, dynamic>?;
      final plan = society?['plan'] as Map<String, dynamic>?;
      final f = plan?['features'];
      if (f is Map) features = Map<String, dynamic>.from(f);
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
      planFeatures: features,
    );
  }

  /// Returns true if the society plan includes this feature.
  /// - SUPER_ADMIN always returns true.
  /// - Once planFeatures is loaded, key must be explicitly true to grant access.
  bool hasFeature(String key) {
    if (role == 'SUPER_ADMIN') return true;
    if (planFeatures == null) return false; // deny-by-default until loaded
    final v = planFeatures![key];
    if (v == true) return true;
    if (v is num) return v == 1;
    if (v is String) return v.toLowerCase() == 'true' || v == '1';
    return false;
  }

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

  static const _memberOnlyRoles = {
    'MEMBER',
    'RESIDENT',
    'VICE_CHAIRMAN',
    'ASSISTANT_SECRETARY',
    'TREASURER',
    'ASSISTANT_TREASURER',
  };

  bool get isUnitLocked => _memberOnlyRoles.contains(role.toUpperCase());
}
