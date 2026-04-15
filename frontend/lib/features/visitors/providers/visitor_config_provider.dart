import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';

/// Fetches platform-level visitor config from GET /visitors/config.
/// Returns the maximum QR expiry hours the SA has configured.
final visitorConfigProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio      = ref.read(dioProvider);
  final response = await dio.get('visitors/config');
  return (response.data['data'] as Map<String, dynamic>?) ?? {};
});

/// Convenience — just the max hrs integer (defaults to 3 on error).
final visitorQrMaxHrsProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(visitorConfigProvider).whenData(
    (data) => (data['visitorQrMaxHrs'] as num?)?.toInt() ?? 3,
  );
});
