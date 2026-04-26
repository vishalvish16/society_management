import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/auth_provider.dart';

class RentalMember {
  final String? id;
  final String name;
  final String relation;
  final int? age;
  final String? gender;
  final String? phone;
  final bool isAdult;
  final String? aadhaarNumber;

  const RentalMember({
    this.id,
    required this.name,
    required this.relation,
    this.age,
    this.gender,
    this.phone,
    this.isAdult = true,
    this.aadhaarNumber,
  });

  factory RentalMember.fromJson(Map<String, dynamic> j) => RentalMember(
        id: j['id'],
        name: j['name'] ?? '',
        relation: j['relation'] ?? 'OTHER',
        age: j['age'],
        gender: j['gender'],
        phone: j['phone'],
        isAdult: j['isAdult'] ?? true,
        aadhaarNumber: j['aadhaarNumber'],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'relation': relation,
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        'isAdult': isAdult,
        if (aadhaarNumber != null && aadhaarNumber!.isNotEmpty) 'aadhaarNumber': aadhaarNumber,
      };

  String get relationLabel {
    switch (relation) {
      case 'SELF': return 'Self (Tenant)';
      case 'SPOUSE': return 'Spouse';
      case 'CHILD': return 'Child';
      case 'PARENT': return 'Parent';
      case 'SIBLING': return 'Sibling';
      default: return 'Other';
    }
  }
}

class RentalDocument {
  final String id;
  final String docType;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String fileUrl;

  const RentalDocument({
    required this.id,
    required this.docType,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.fileUrl,
  });

  factory RentalDocument.fromJson(Map<String, dynamic> j) => RentalDocument(
        id: j['id'] ?? '',
        docType: j['docType'] ?? 'OTHER',
        fileName: j['fileName'] ?? '',
        fileType: j['fileType'] ?? '',
        fileSize: j['fileSize'] ?? 0,
        fileUrl: j['fileUrl'] ?? '',
      );

  String get docTypeLabel {
    switch (docType) {
      case 'AADHAAR': return 'Aadhaar Card';
      case 'RENT_AGREEMENT': return 'Rent Agreement';
      case 'POLICE_VERIFICATION': return 'Police Verification';
      case 'ID_PROOF': return 'ID Proof';
      default: return 'Other Document';
    }
  }
}

class RentalRecord {
  final String id;
  final String unitId;
  final String unitCode;
  final String? portion;
  final String tenantName;
  final String tenantPhone;
  final String? tenantEmail;
  final String? tenantAadhaar;
  final int membersCount;
  final String? ownerName;
  final String? ownerPhone;
  final String agreementType;
  final double? rentAmount;
  final double? securityDeposit;
  final DateTime agreementStartDate;
  final DateTime? agreementEndDate;
  final String? agreementDocUrl;
  final bool policeVerification;
  final String? nokName;
  final String? nokPhone;
  final String? notes;
  final bool isActive;
  final List<RentalDocument> documents;
  final List<RentalMember> members;

  const RentalRecord({
    required this.id,
    required this.unitId,
    required this.unitCode,
    this.portion,
    required this.tenantName,
    required this.tenantPhone,
    this.tenantEmail,
    this.tenantAadhaar,
    required this.membersCount,
    this.ownerName,
    this.ownerPhone,
    required this.agreementType,
    this.rentAmount,
    this.securityDeposit,
    required this.agreementStartDate,
    this.agreementEndDate,
    this.agreementDocUrl,
    required this.policeVerification,
    this.nokName,
    this.nokPhone,
    this.notes,
    required this.isActive,
    this.documents = const [],
    this.members = const [],
  });

  factory RentalRecord.fromJson(Map<String, dynamic> j) {
    final unit = j['unit'] as Map<String, dynamic>?;
    final owner = j['ownerUser'] as Map<String, dynamic>?;
    final docs = (j['documents'] as List?)
        ?.map((d) => RentalDocument.fromJson(d))
        .toList() ?? [];
    final mems = (j['members'] as List?)
        ?.map((m) => RentalMember.fromJson(m))
        .toList() ?? [];

    return RentalRecord(
      id: j['id'] ?? '',
      unitId: j['unitId'] ?? '',
      unitCode: unit?['fullCode'] ?? '',
      portion: j['portion'],
      tenantName: j['tenantName'] ?? '',
      tenantPhone: j['tenantPhone'] ?? '',
      tenantEmail: j['tenantEmail'],
      tenantAadhaar: j['tenantAadhaar'],
      membersCount: j['membersCount'] ?? 1,
      ownerName: owner?['name'],
      ownerPhone: owner?['phone'],
      agreementType: j['agreementType'] ?? 'RENT',
      rentAmount: _parseDouble(j['rentAmount']),
      securityDeposit: _parseDouble(j['securityDeposit']),
      agreementStartDate: DateTime.parse(
        j['agreementStartDate'] ?? DateTime.now().toIso8601String(),
      ),
      agreementEndDate: j['agreementEndDate'] != null
          ? DateTime.parse(j['agreementEndDate'])
          : null,
      agreementDocUrl: j['agreementDocUrl'],
      policeVerification: j['policeVerification'] ?? false,
      nokName: j['nokName'],
      nokPhone: j['nokPhone'],
      notes: j['notes'],
      isActive: j['isActive'] ?? true,
      documents: docs,
      members: mems,
    );
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  bool get hasAadhaar => documents.any((d) => d.docType == 'AADHAAR');
  bool get hasAgreement => documents.any((d) => d.docType == 'RENT_AGREEMENT');
}

class RentalsNotifier extends StateNotifier<AsyncValue<List<RentalRecord>>> {
  final Ref ref;
  final AuthState authState;

  int _currentPage = 1;
  static const int _limit = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  RentalsNotifier(this.ref, this.authState)
      : super(const AsyncValue.loading()) {
    if (authState.isAuthenticated) {
      loadRentals();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> loadRentals({bool refresh = true, String? unitId}) async {
    if (!authState.isAuthenticated) return;

    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      state = const AsyncValue.loading();
    }

    if (_isLoadingMore && !refresh) return;
    if (!refresh) _isLoadingMore = true;

    try {
      final dio = ref.read(dioProvider);
      final params = <String, dynamic>{
        'page': _currentPage,
        'limit': _limit,
      };
      if (unitId != null) params['unitId'] = unitId;

      final response = await dio.get('rentals', queryParameters: params);

      if (response.data['success'] == true) {
        final data = response.data['data'];
        final List list = data['records'] ?? [];
        final total = data['total'] ?? 0;
        final records = list.map((e) => RentalRecord.fromJson(e)).toList();

        if (refresh) {
          state = AsyncValue.data(records);
        } else {
          final current = state.value ?? [];
          state = AsyncValue.data([...current, ...records]);
        }

        _hasMore = (state.value?.length ?? 0) < total;
        if (_hasMore) _currentPage++;
      } else {
        if (refresh) {
          state = AsyncValue.error(
            response.data['message'] ?? 'Failed to load rentals',
            StackTrace.current,
          );
        }
      }
    } on DioException catch (e) {
      if (refresh) {
        state = AsyncValue.error(
          e.response?.data['message'] ?? e.message ?? 'Network error',
          StackTrace.current,
        );
      }
    } catch (e) {
      if (refresh) {
        state = AsyncValue.error(e.toString(), StackTrace.current);
      }
    } finally {
      if (!refresh) {
        _isLoadingMore = false;
        if (state.hasValue) state = AsyncValue.data(state.value!);
      }
    }
  }

  Future<void> loadNextPage() async {
    if (!_hasMore || _isLoadingMore || state.isLoading) return;
    await loadRentals(refresh: false);
  }

  Future<String?> createRental(
    Map<String, dynamic> data, {
    List<XFile>? files,
    List<String>? docTypes,
    List<RentalMember>? members,
  }) async {
    try {
      final dio = ref.read(dioProvider);
      if (members != null && members.isNotEmpty) {
        data['members'] = jsonEncode(members.map((m) => m.toJson()).toList());
      }
      final formData = FormData.fromMap(data);

      if (files != null && files.isNotEmpty) {
        formData.fields.add(MapEntry('docTypes', (docTypes ?? []).join(',')));
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          final bytes = await file.readAsBytes();
          final ext = file.name.split('.').last.toLowerCase();
          String mime = 'application/octet-stream';
          if (ext == 'pdf') mime = 'application/pdf';
          else if (ext == 'jpg' || ext == 'jpeg') mime = 'image/jpeg';
          else if (ext == 'png') mime = 'image/png';

          formData.files.add(MapEntry(
            'documents',
            MultipartFile.fromBytes(bytes, filename: file.name, contentType: MediaType.parse(mime)),
          ));
        }
      }

      final response = await dio.post('rentals', data: formData);
      if (response.data['success'] == true) {
        loadRentals();
        return null;
      }
      return response.data['message'] ?? 'Failed to create rental';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to create rental';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateRental(
    String id,
    Map<String, dynamic> data, {
    List<XFile>? files,
    List<String>? docTypes,
  }) async {
    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap(data);

      if (files != null && files.isNotEmpty) {
        formData.fields.add(MapEntry('docTypes', (docTypes ?? []).join(',')));
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          final bytes = await file.readAsBytes();
          final ext = file.name.split('.').last.toLowerCase();
          String mime = 'application/octet-stream';
          if (ext == 'pdf') mime = 'application/pdf';
          else if (ext == 'jpg' || ext == 'jpeg') mime = 'image/jpeg';
          else if (ext == 'png') mime = 'image/png';

          formData.files.add(MapEntry(
            'documents',
            MultipartFile.fromBytes(bytes, filename: file.name, contentType: MediaType.parse(mime)),
          ));
        }
      }

      final response = await dio.patch('rentals/$id', data: formData);
      if (response.data['success'] == true) {
        loadRentals();
        return null;
      }
      return response.data['message'] ?? 'Failed to update rental';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update rental';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteDocument(String rentalId, String docId) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.delete('rentals/$rentalId/documents/$docId');
      if (response.data['success'] == true) {
        loadRentals();
        return null;
      }
      return response.data['message'] ?? 'Failed to delete document';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to delete document';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> endRental(String id) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.patch('rentals/$id/end');
      if (response.data['success'] == true) {
        loadRentals();
        return null;
      }
      return response.data['message'] ?? 'Failed to end rental';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to end rental';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> syncMembers(String rentalId, List<RentalMember> members) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.put('rentals/$rentalId/members', data: {
        'members': members.map((m) => m.toJson()).toList(),
      });
      if (response.data['success'] == true) {
        loadRentals();
        return null;
      }
      return response.data['message'] ?? 'Failed to update members';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update members';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteRental(String id) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.delete('rentals/$id');
      if (response.data['success'] == true) {
        loadRentals();
        return null;
      }
      return response.data['message'] ?? 'Failed to delete rental';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to delete rental';
    } catch (e) {
      return e.toString();
    }
  }
}

final rentalsProvider =
    StateNotifierProvider<RentalsNotifier, AsyncValue<List<RentalRecord>>>(
        (ref) {
  final authState = ref.watch(authProvider);
  return RentalsNotifier(ref, authState);
});
