import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../api/dio_client.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../../features/settings/providers/permissions_provider.dart';

// Re-export so router can import from one place.
export '../api/dio_client.dart' show suspensionSignal;

/// Secure storage key: phone/email last used in a successful login on this device.
const kAuthStorageLastLoginIdentifier = 'last_login_identifier';

/// After [AuthNotifier.logout], the login screen must not auto-open the biometric
/// sheet. Cleared only on a new app process (cold start), so the next app open
/// can auto-prompt if biometrics are enabled. Users can still tap "Use Biometrics".
bool authSuppressLoginBiometricAuto = false;

class AuthState {
  final UserModel? user;
  final String? token;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  /// True when the backend returns SOCIETY_SUSPENDED — router redirects to suspended screen.
  final bool isSuspended;
  /// Bumped whenever we want all avatar images to re-fetch.
  final int avatarRevision;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.isSuspended = false,
    this.avatarRevision = 0,
  });

  AuthState copyWith({
    UserModel? user,
    String? token,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    bool? isSuspended,
    int? avatarRevision,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isSuspended: isSuspended ?? this.isSuspended,
      avatarRevision: avatarRevision ?? this.avatarRevision,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  AuthNotifier(this.ref) : super(const AuthState(isLoading: true)) {
    // Listen to global suspension signal emitted by Dio interceptor.
    suspensionSignal.addListener(_onSuspensionSignal);
  }

  @override
  void dispose() {
    suspensionSignal.removeListener(_onSuspensionSignal);
    super.dispose();
  }

  void _onSuspensionSignal() {
    if (state.isAuthenticated && !state.isSuspended) {
      state = state.copyWith(isSuspended: true);
    }
  }

  /// Called directly when we know the society is suspended (e.g. from login response).
  void markSuspended() => _onSuspensionSignal();

  final _client = DioClient();
  DioClient get client => _client;

  String _dioErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    if (data is String && data.trim().isNotEmpty) return data;
    return 'Connection failed. Please try again.';
  }

  /// Step 1: validate credentials and check how many societies this identifier belongs to.
  /// Returns:
  ///   - `null`  → invalid credentials (error set on state)
  ///   - `[]`    → single society, login complete (state is authenticated)
  ///   - list    → multiple societies; caller should show picker then call [loginWithUserId]
  Future<List<Map<String, dynamic>>?> checkSocieties(
      String identifier, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.dio.post(
        'auth/check-societies',
        data: {'identifier': identifier, 'password': password},
      );
      final data = response.data['data'] as Map<String, dynamic>;

      if (data['requiresSocietySelection'] == true) {
        state = state.copyWith(isLoading: false);
        return List<Map<String, dynamic>>.from(data['societies'] ?? []);
      }

      // Single society — complete login immediately
      await _applyLoginData(data, identifier: identifier);
      return []; // empty list = login done
    } on DioException catch (e) {
      final msg = _dioErrorMessage(e);
      state = state.copyWith(isLoading: false, error: msg);
      return null;
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'An unexpected error occurred');
      return null;
    }
  }

  /// Step 2 (multi-society): complete login for the selected userId.
  Future<bool> loginWithUserId(
      String identifier, String password, String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.dio.post(
        'auth/login',
        data: {'identifier': identifier, 'password': password, 'userId': userId},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        await _applyLoginData(
          response.data['data'] as Map<String, dynamic>,
          identifier: identifier,
        );
        return true;
      }
      state = state.copyWith(
          isLoading: false,
          error: response.data['message'] ?? 'Login failed');
      return false;
    } on DioException catch (e) {
      final msg = _dioErrorMessage(e);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'An unexpected error occurred');
      return false;
    }
  }

  Future<bool> login(String identifier, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.dio.post(
        'auth/login',
        data: {'identifier': identifier, 'password': password},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        await _applyLoginData(
          response.data['data'] as Map<String, dynamic>,
          identifier: identifier,
        );
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: response.data['message'] ?? 'Login failed',
      );
      return false;
    } on DioException catch (e) {
      final msg = _dioErrorMessage(e);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'An unexpected error occurred');
      return false;
    }
  }

  Future<void> _applyLoginData(
    Map<String, dynamic> data, {
    String? identifier,
  }) async {
    final token = data['accessToken'] as String;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

    await _client.storage.write(key: 'accessToken', value: token);
    await _client.storage.write(key: 'userRole', value: user.role);
    await _client.storage.write(key: 'userId', value: user.id);
    final normalizedIdentifier = identifier?.trim();
    if (normalizedIdentifier != null && normalizedIdentifier.isNotEmpty) {
      await _client.storage.write(
        key: kAuthStorageLastLoginIdentifier,
        value: normalizedIdentifier,
      );
    }

    // Set initial auth state immediately, then hydrate full profile (incl. society plan features)
    // from `GET users/me`. This fixes cases where the login payload is missing/partial.
    state = AuthState(user: user, token: token, isAuthenticated: true, isLoading: false);
    ref.read(notificationServiceProvider).registerTokenAfterLogin();

    // Best-effort refresh; don't fail login if this request fails.
    await refreshProfileFromServer();

    // Best-effort hydrate role permissions so sidebar can hide restricted features.
    // This endpoint is readable by any authenticated user.
    try {
      await ref.read(rolePermissionsProvider.notifier).fetch();
    } catch (_) {}
  }

  Future<String?> forgotPassword(String phone) async {
    try {
      final response = await _client.dio.post(
        'auth/forgot-password',
        data: {'phone': phone},
      );
      return response.data['message'];
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) return data['message'] as String;
      if (data is String && data.trim().isNotEmpty) return data;
      return 'Failed to send OTP';
    }
  }

  Future<bool> verifyOtpAndReset(String phone, String otp, String newPassword) async {
    try {
      final response = await _client.dio.post(
        'auth/verify-otp',
        data: {'phone': phone, 'otp': otp, 'newPassword': newPassword},
      );
      return response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> changePassword(String currentPassword, String newPassword) async {
    try {
      final response = await _client.dio.post(
        'auth/change-password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
      if (response.data['success'] == true) {
        return null; // Success
      }
      return response.data['message'] ?? 'Failed to change password';
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) return data['message'] as String;
      if (data is String && data.trim().isNotEmpty) return data;
      return 'Failed to change password';
    } catch (_) {
      return 'An unexpected error occurred';
    }
  }

  /// [suppressLoginBiometricAuto] — when true (default), the login screen will not
  /// auto-open biometrics until the next cold start. Use false for involuntary
  /// session clears (e.g. 401) so users can still use quick biometric sign-in.
  Future<void> logout({bool suppressLoginBiometricAuto = true}) async {
    try {
      final token = await _client.storage.read(key: 'accessToken');
      if (token != null) {
        await _client.dio.post('auth/logout');
      }
    } catch (_) {}

    // Clear session keys only. "Remember me" is a login-form preference and
    // should not be tied to session lifecycle (users often want it to persist
    // even after logging out).
    await Future.wait([
      _client.storage.delete(key: 'accessToken'),
      _client.storage.delete(key: 'userRole'),
      _client.storage.delete(key: 'userId'),
    ]);

    if (suppressLoginBiometricAuto) {
      authSuppressLoginBiometricAuto = true;
    }
    state = const AuthState();
  }

  Future<void> tryAutoLogin() async {
    final token = await _client.storage.read(key: 'accessToken');
    if (token == null) {
      state = state.copyWith(isLoading: false, isAuthenticated: false);
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      final response = await _client.dio.get('users/me');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final user = UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
        state = AuthState(user: user, token: token, isAuthenticated: true, isLoading: false);
        // Re-register FCM token on auto-login (token may have rotated)
        ref.read(notificationServiceProvider).registerTokenAfterLogin();

        // Best-effort hydrate role permissions for UI gating.
        try {
          await ref.read(rolePermissionsProvider.notifier).fetch();
        } catch (_) {}
      } else {
        throw Exception('Me failed');
      }
    } catch (_) {
      await _client.storage.delete(key: 'accessToken');
      await _client.storage.delete(key: 'userRole');
      await _client.storage.delete(key: 'userId');
      state = const AuthState(isLoading: false, isAuthenticated: false);
    }
  }

  /// Reloads the signed-in user from `GET users/me` (e.g. after profile edits).
  Future<bool> refreshProfileFromServer() async {
    if (!state.isAuthenticated) return false;
    try {
      final response = await _client.dio.get('users/me');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final user = UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
        state = state.copyWith(
          user: user,
          avatarRevision: state.avatarRevision + 1,
        );
        return true;
      }
    } catch (_) {}
    return false;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
