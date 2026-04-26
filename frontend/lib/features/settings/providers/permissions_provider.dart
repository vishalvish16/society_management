import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/providers/dio_provider.dart';

class FeatureInfo {
  final String key;
  final String label;
  final String group;

  const FeatureInfo({required this.key, required this.label, required this.group});

  factory FeatureInfo.fromJson(Map<String, dynamic> json) => FeatureInfo(
        key: json['key'] as String,
        label: json['label'] as String,
        group: json['group'] as String,
      );
}

class RolePermissionsData {
  final Map<String, Map<String, bool>> rolePermissions;
  final List<FeatureInfo> features;
  final List<String> roles;

  const RolePermissionsData({
    required this.rolePermissions,
    required this.features,
    required this.roles,
  });

  factory RolePermissionsData.fromJson(Map<String, dynamic> json) {
    final rawPerms = json['rolePermissions'] as Map<String, dynamic>;
    final perms = <String, Map<String, bool>>{};
    for (final entry in rawPerms.entries) {
      final roleMap = entry.value as Map<String, dynamic>;
      perms[entry.key] = roleMap.map((k, v) => MapEntry(k, v == true));
    }

    final features = (json['features'] as List)
        .map((f) => FeatureInfo.fromJson(f as Map<String, dynamic>))
        .toList();
    final roles =
        (json['roles'] as List).map((r) => r as String).toList();

    return RolePermissionsData(
      rolePermissions: perms,
      features: features,
      roles: roles,
    );
  }

  RolePermissionsData copyWithToggle(String role, String featureKey, bool value) {
    final updated = Map<String, Map<String, bool>>.from(
      rolePermissions.map((k, v) => MapEntry(k, Map<String, bool>.from(v))),
    );
    updated[role]?[featureKey] = value;
    return RolePermissionsData(
      rolePermissions: updated,
      features: features,
      roles: roles,
    );
  }
}

class RolePermissionsNotifier extends StateNotifier<AsyncValue<RolePermissionsData>> {
  final Ref ref;

  RolePermissionsNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('settings/permissions');
      if (res.data['success'] == true) {
        state = AsyncValue.data(
          RolePermissionsData.fromJson(res.data['data'] as Map<String, dynamic>),
        );
      } else {
        state = AsyncValue.error(res.data['message'] ?? 'Failed', StackTrace.current);
      }
    } catch (e) {
      state = AsyncValue.error(
        e is DioException ? (e.response?.data['message'] ?? e.message) : e.toString(),
        StackTrace.current,
      );
    }
  }

  void toggle(String role, String featureKey, bool value) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWithToggle(role, featureKey, value));
  }

  Future<String?> save() async {
    final current = state.valueOrNull;
    if (current == null) return 'No data to save';
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.put('settings/permissions', data: {
        'rolePermissions': current.rolePermissions,
      });
      if (res.data['success'] == true) {
        state = AsyncValue.data(
          RolePermissionsData.fromJson(res.data['data'] as Map<String, dynamic>),
        );
        return null;
      }
      return res.data['message'] ?? 'Failed to save';
    } catch (e) {
      if (e is DioException) return e.response?.data['message'] ?? e.message;
      return e.toString();
    }
  }
}

final rolePermissionsProvider =
    StateNotifierProvider<RolePermissionsNotifier, AsyncValue<RolePermissionsData>>(
  (ref) => RolePermissionsNotifier(ref),
);
