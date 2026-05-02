import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Global signal bus. Emitted when backend returns SOCIETY_SUSPENDED (403).
/// AuthNotifier listens to this in its constructor and flips isSuspended.
final suspensionSignal = ValueNotifier<int>(0);

class DioClient {
  static final DioClient _singleton = DioClient._internal();
  late final Dio dio;
  final storage = const FlutterSecureStorage();

  factory DioClient() => _singleton;

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Accept': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.read(key: 'accessToken');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 403) {
            final data = e.response?.data;
            if (data is Map && data['errorCode'] == 'SOCIETY_SUSPENDED') {
              // Increment to signal all listeners (router + auth notifier).
              suspensionSignal.value++;
            }
          }
          return handler.next(e);
        },
      ),
    );
  }
}
