import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../api/dio_client.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';

class AuthState {
  final UserModel? user;
  final String? token;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    UserModel? user,
    String? token,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  AuthNotifier(this.ref) : super(const AuthState(isLoading: true));

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
      await _applyLoginData(data);
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
        await _applyLoginData(response.data['data'] as Map<String, dynamic>);
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
        await _applyLoginData(response.data['data'] as Map<String, dynamic>);
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

  Future<void> _applyLoginData(Map<String, dynamic> data) async {
    final token = data['accessToken'] as String;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

    await _client.storage.write(key: 'accessToken', value: token);
    await _client.storage.write(key: 'userRole', value: user.role);
    await _client.storage.write(key: 'userId', value: user.id);

    state = AuthState(user: user, token: token, isAuthenticated: true);
    ref.read(notificationServiceProvider).registerTokenAfterLogin();
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

  Future<void> logout() async {
    try {
      final token = await _client.storage.read(key: 'accessToken');
      if (token != null) {
        await _client.dio.post('auth/logout');
      }
    } catch (_) {}

    // Clear session keys. Also clear the remembered identifier so a
    // different user logging in next doesn't see the previous user's phone.
    await Future.wait([
      _client.storage.delete(key: 'accessToken'),
      _client.storage.delete(key: 'userRole'),
      _client.storage.delete(key: 'userId'),
      _client.storage.delete(key: 'remember_me_identifier'),
      _client.storage.write(key: 'remember_me', value: 'false'),
    ]);

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
        state = state.copyWith(user: user);
        return true;
      }
    } catch (_) {}
    return false;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
