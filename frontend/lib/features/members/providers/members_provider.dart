import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/auth_provider.dart';

class HouseholdMember {
  final String? id;
  final String name;
  final String relation;
  final int? age;
  final String? gender;
  final String? phone;
  final bool isAdult;

  const HouseholdMember({
    this.id,
    required this.name,
    required this.relation,
    this.age,
    this.gender,
    this.phone,
    this.isAdult = true,
  });

  factory HouseholdMember.fromJson(Map<String, dynamic> j) => HouseholdMember(
        id: j['id'],
        name: j['name'] ?? '',
        relation: j['relation'] ?? 'OTHER',
        age: j['age'],
        gender: j['gender'],
        phone: j['phone'],
        isAdult: j['isAdult'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'relation': relation,
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        'isAdult': isAdult,
      };
}

class Member {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String role;
  final String? unitId;
  final String unitCode;
  final bool isActive;
  final int? householdMemberCount;
  final List<HouseholdMember> householdMembers;

  const Member({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    this.unitId,
    required this.unitCode,
    required this.isActive,
    this.householdMemberCount,
    this.householdMembers = const [],
  });

  factory Member.fromJson(Map<String, dynamic> j) {
    final unitResident = (j['unitResidents'] as List?)?.isNotEmpty == true
        ? j['unitResidents'][0]
        : null;
    final hh = (j['householdMembers'] as List?)
            ?.map((e) => HouseholdMember.fromJson(e))
            .toList() ??
        const <HouseholdMember>[];
    return Member(
      id: j['id'] ?? '',
      name: j['name'] ?? '',
      phone: j['phone'] ?? '',
      email: j['email'],
      role: j['role'] ?? 'RESIDENT',
      unitId: unitResident?['unit']?['id'],
      unitCode: unitResident?['unit']?['fullCode'] ?? '',
      isActive: j['isActive'] ?? true,
      householdMemberCount: j['householdMemberCount'],
      householdMembers: hh,
    );
  }
}

class MembersNotifier extends StateNotifier<AsyncValue<List<Member>>> {
  final Ref ref;
  final AuthState authState;

  int _currentPage = 1;
  static const int _limit = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  MembersNotifier(this.ref, this.authState) : super(const AsyncValue.loading()) {
    if (authState.isAuthenticated) {
      loadMembers();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> loadMembers({bool refresh = true, String? role}) async {
    if (!authState.isAuthenticated) return;
    
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      state = const AsyncValue.loading();
    }

    if (_isLoadingMore && !refresh) return;
    
    if (!refresh) {
      _isLoadingMore = true;
    }

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('members', queryParameters: {
        'page': _currentPage,
        'limit': _limit,
        if (role != null && role != 'All') 'role': role.toUpperCase(),
      });
      
      if (response.data['success'] == true) {
        final data = response.data['data'];
        final List list = data['members'] ?? [];
        final total = data['total'] ?? 0;
        final List<Member> members = list.map((e) => Member.fromJson(e)).toList();
        
        if (refresh) {
          state = AsyncValue.data(members);
        } else {
          final current = state.value ?? [];
          state = AsyncValue.data([...current, ...members]);
        }
        
        _hasMore = (state.value?.length ?? 0) < total;
        
        if (_hasMore) {
          _currentPage++;
        }
      } else {
        if (refresh) {
          state = AsyncValue.error(response.data['message'] ?? 'Failed to load members', StackTrace.current);
        }
      }
    } on DioException catch (e) {
      if (refresh) {
        state = AsyncValue.error(e.response?.data['message'] ?? e.message ?? 'Network error', StackTrace.current);
      }
    } catch (e) {
      if (refresh) {
        state = AsyncValue.error(e.toString(), StackTrace.current);
      }
    } finally {
      if (!refresh) {
        _isLoadingMore = false;
        if (state.hasValue) {
          state = AsyncValue.data(state.value!);
        }
      }
    }
  }

  Future<void> loadNextPage() async {
    if (!_hasMore || _isLoadingMore || state.isLoading) return;
    await loadMembers(refresh: false);
  }

  Future<String?> createMember(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      if (data['householdMembers'] is List) {
        data['householdMembers'] = jsonEncode(data['householdMembers']);
      }
      final response = await dio.post('members', data: data);
      if (response.data['success'] == true) {
        loadMembers();
        return null;
      }
      return response.data['message'] ?? 'Failed to create member';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to create member';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateMember(String id, Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      if (data['householdMembers'] is List) {
        data['householdMembers'] = jsonEncode(data['householdMembers']);
      }
      final response = await dio.patch('members/$id', data: data);
      if (response.data['success'] == true) {
        loadMembers();
        return null;
      }
      return response.data['message'] ?? 'Failed to update member';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to update member';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> resetPassword(String id, String password) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('members/$id/reset-password', data: {'password': password});
      if (response.data['success'] == true) {
        return null;
      }
      return response.data['message'] ?? 'Failed to reset password';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to reset password';
    } catch (e) {
      return e.toString();
    }
  }
}

final membersProvider = StateNotifierProvider<MembersNotifier, AsyncValue<List<Member>>>((ref) {
  final authState = ref.watch(authProvider);
  return MembersNotifier(ref, authState);
});
