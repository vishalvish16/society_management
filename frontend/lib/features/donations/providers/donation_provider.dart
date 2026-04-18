import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:dio/dio.dart';

final donationCampaignsProvider = FutureProvider<List<dynamic>>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) return [];
  
  final dio = ref.watch(dioProvider);
  final response = await dio.get('donations/campaigns');
  return response.data['data'] ?? [];
});

final donationsProvider =
    StateNotifierProvider<DonationsNotifier, AsyncValue<Map<String, dynamic>>>((ref) {
  return DonationsNotifier(ref);
});

class DonationsNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final Ref ref;
  DonationsNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchDonations();
  }

  int _page = 1;
  static const int _limit = 20;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  Future<void> fetchDonations({bool refresh = true, String? campaignId}) async {
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) {
      state = const AsyncValue.data({'donations': [], 'total': 0});
      return;
    }
    if (refresh) {
      _page = 1;
      _hasMore = true;
      state = const AsyncValue.loading();
    }
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('donations', queryParameters: {
        'page': _page,
        'limit': _limit,
        'campaignId': campaignId,
      });
      if (response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        final list = data['donations'] as List? ?? [];
        _hasMore = list.length >= _limit;
        if (refresh) {
          state = AsyncValue.data(data);
        } else {
          final prev = (state.value?['donations'] as List?) ?? [];
          state = AsyncValue.data({...data, 'donations': [...prev, ...list]});
        }
        if (_hasMore) _page++;
      }
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
    }
  }

  Future<String?> makeDonation(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('donations', data: data);
      if (response.data['success'] == true) {
        fetchDonations();
        return null;
      }
      return response.data['message'] ?? 'Failed to record donation';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to record donation';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> createCampaign(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('donations/campaigns', data: data);
      if (response.data['success'] == true) {
        ref.invalidate(donationCampaignsProvider);
        return null;
      }
      return response.data['message'] ?? 'Failed to create campaign';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Failed to create campaign';
    } catch (e) {
      return e.toString();
    }
  }
}
