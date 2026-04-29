import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/providers/dio_provider.dart';

class AppInfo {
  final String appName;
  final String appTagline;
  final String appVersion;
  final String supportEmail;
  final String supportPhone;
  final String termsAndConditions;

  const AppInfo({
    required this.appName,
    required this.appTagline,
    required this.appVersion,
    required this.supportEmail,
    required this.supportPhone,
    required this.termsAndConditions,
  });

  factory AppInfo.fromJson(Map<String, dynamic> json) => AppInfo(
        appName:            json['appName']            as String? ?? '',
        appTagline:         json['appTagline']         as String? ?? '',
        appVersion:         json['appVersion']         as String? ?? '',
        supportEmail:       json['supportEmail']       as String? ?? '',
        supportPhone:       json['supportPhone']       as String? ?? '',
        termsAndConditions: json['termsAndConditions'] as String? ?? '',
      );

  AppInfo copyWith({
    String? appName,
    String? appTagline,
    String? appVersion,
    String? supportEmail,
    String? supportPhone,
    String? termsAndConditions,
  }) =>
      AppInfo(
        appName:            appName            ?? this.appName,
        appTagline:         appTagline         ?? this.appTagline,
        appVersion:         appVersion         ?? this.appVersion,
        supportEmail:       supportEmail       ?? this.supportEmail,
        supportPhone:       supportPhone       ?? this.supportPhone,
        termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      );
}

// ─── Public provider (no auth) ───────────────────────────────────────────────

final appInfoProvider =
    StateNotifierProvider<AppInfoNotifier, AsyncValue<AppInfo>>(
  (ref) => AppInfoNotifier(ref),
);

class AppInfoNotifier extends StateNotifier<AsyncValue<AppInfo>> {
  final Ref _ref;

  AppInfoNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get('app-info');
      if (response.data['success'] == true) {
        state = AsyncValue.data(
            AppInfo.fromJson(response.data['data'] as Map<String, dynamic>));
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
}

// ─── SA provider (auth required, richer editing) ─────────────────────────────

final saAppInfoProvider =
    StateNotifierProvider<SaAppInfoNotifier, AsyncValue<AppInfo>>(
  (ref) => SaAppInfoNotifier(ref),
);

class SaAppInfoNotifier extends StateNotifier<AsyncValue<AppInfo>> {
  final Ref _ref;

  SaAppInfoNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get('superadmin/app-info');
      if (response.data['success'] == true) {
        state = AsyncValue.data(
            AppInfo.fromJson(response.data['data'] as Map<String, dynamic>));
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

  /// Returns null on success or an error message.
  Future<String?> save(AppInfo info) async {
    final prev = state;
    state = AsyncValue.data(info);
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.patch('superadmin/app-info', data: {
        'appName':            info.appName,
        'appTagline':         info.appTagline,
        'appVersion':         info.appVersion,
        'supportEmail':       info.supportEmail,
        'supportPhone':       info.supportPhone,
        'termsAndConditions': info.termsAndConditions,
      });
      if (response.data['success'] == true) {
        final updated = AppInfo.fromJson(
            response.data['data'] as Map<String, dynamic>);
        state = AsyncValue.data(updated);
        // Also invalidate the public provider so users see updates immediately
        _ref.invalidate(appInfoProvider);
        return null;
      }
      state = prev;
      return response.data['message'] ?? 'Save failed';
    } on DioException catch (e) {
      state = prev;
      return e.response?.data?['message'] ?? e.message ?? 'Network error';
    } catch (e) {
      state = prev;
      return e.toString();
    }
  }
}
