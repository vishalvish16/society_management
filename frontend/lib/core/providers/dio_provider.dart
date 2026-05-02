import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import 'auth_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  final authState = ref.watch(authProvider);
  
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        print('[DEBUG] Request to ${options.path} - Token present: ${authState.token != null}');
        if (authState.token != null) {
          options.headers['Authorization'] = 'Bearer ${authState.token}';
        }
        return handler.next(options);
      },
      onError: (e, handler) {
        if (e.response?.statusCode == 401) {
          // Token expired or invalid — allow biometric auto on login after this.
          ref.read(authProvider.notifier).logout(suppressLoginBiometricAuto: false);
        }
        return handler.next(e);
      },
    ),
  );

  return dio;
});
