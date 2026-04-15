import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/providers/dio_provider.dart';

/// Represents a single platform setting row.
class PlatformSetting {
  final String key;
  final String value;
  final String label;
  final String dataType;

  const PlatformSetting({
    required this.key,
    required this.value,
    required this.label,
    required this.dataType,
  });

  factory PlatformSetting.fromJson(Map<String, dynamic> json) => PlatformSetting(
        key:      json['key']      as String,
        value:    json['value']    as String,
        label:    json['label']    as String,
        dataType: json['dataType'] as String? ?? 'string',
      );

  PlatformSetting copyWith({String? value}) =>
      PlatformSetting(key: key, value: value ?? this.value, label: label, dataType: dataType);
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final platformSettingsProvider =
    StateNotifierProvider<PlatformSettingsNotifier, AsyncValue<List<PlatformSetting>>>(
  (ref) => PlatformSettingsNotifier(ref),
);

class PlatformSettingsNotifier
    extends StateNotifier<AsyncValue<List<PlatformSetting>>> {
  final Ref _ref;

  PlatformSettingsNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final dio      = _ref.read(dioProvider);
      final response = await dio.get('superadmin/settings');
      if (response.data['success'] == true) {
        final list = (response.data['data'] as List)
            .map((e) => PlatformSetting.fromJson(e as Map<String, dynamic>))
            .toList();
        state = AsyncValue.data(list);
      } else {
        state = AsyncValue.error(
            response.data['message'] ?? 'Failed', StackTrace.current);
      }
    } on DioException catch (e) {
      state = AsyncValue.error(
          e.response?.data?['message'] ?? e.message ?? 'Network error',
          StackTrace.current);
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
    }
  }

  /// Update a single key, optimistically update local state, rollback on error.
  /// Returns null on success or an error message string.
  Future<String?> updateSetting(String key, String value) async {
    // Optimistic update
    final prev = state;
    state = state.whenData((list) => list
        .map((s) => s.key == key ? s.copyWith(value: value) : s)
        .toList());

    try {
      final dio      = _ref.read(dioProvider);
      final response = await dio.patch('superadmin/settings/$key',
          data: {'value': value});
      if (response.data['success'] == true) {
        return null; // success
      }
      state = prev; // rollback
      return response.data['message'] ?? 'Update failed';
    } on DioException catch (e) {
      state = prev;
      return e.response?.data?['message'] ?? e.message ?? 'Network error';
    } catch (e) {
      state = prev;
      return e.toString();
    }
  }
}
