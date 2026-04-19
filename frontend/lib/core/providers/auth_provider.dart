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

  Future<bool> login(String identifier, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.dio.post(
        'auth/login',
        data: {'identifier': identifier, 'password': password},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final token = data['accessToken'] as String;
        final user = UserModel.fromJson(data['user']);

        await _client.storage.write(key: 'accessToken', value: token);
        await _client.storage.write(key: 'userRole', value: user.role);
        await _client.storage.write(key: 'userId', value: user.id);

        state = AuthState(
          user: user,
          token: token,
          isAuthenticated: true,
        );

        // Register FCM token now that we have a valid auth token
        ref.read(notificationServiceProvider).registerTokenAfterLogin();

        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: response.data['message'] ?? 'Login failed',
      );
      return false;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Connection failed. Please try again.';
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'An unexpected error occurred');
      return false;
    }
  }

  Future<String?> forgotPassword(String phone) async {
    try {
      final response = await _client.dio.post(
        'auth/forgot-password',
        data: {'phone': phone},
      );
      return response.data['message'];
    } on DioException catch (e) {
      return e.response?.data?['message'] ?? 'Failed to send OTP';
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
      return e.response?.data?['message'] ?? 'Failed to change password';
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
    
    // Selectively delete only session-related keys, NOT 'Remember Me' or Biometric settings
    await _client.storage.delete(key: 'accessToken');
    await _client.storage.delete(key: 'userRole');
    await _client.storage.delete(key: 'userId');
    
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
        final user = UserModel.fromJson(response.data['data']);
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
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
