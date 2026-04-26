import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/dio_provider.dart';

class EventsState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> events;

  const EventsState({
    this.isLoading = false,
    this.error,
    this.events = const [],
  });

  EventsState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? events,
  }) {
    return EventsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      events: events ?? this.events,
    );
  }
}

class EventsNotifier extends StateNotifier<EventsState> {
  final Ref ref;
  final AuthState auth;

  EventsNotifier(this.ref, this.auth) : super(const EventsState()) {
    if (auth.isAuthenticated) refresh();
  }

  Dio get _dio => ref.read(dioProvider);

  Future<void> refresh({String? status}) async {
    if (!auth.isAuthenticated) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final query = <String, dynamic>{'limit': 100};
      if (status != null && status.isNotEmpty) query['status'] = status;
      final res = await _dio.get('events', queryParameters: query);
      final data = (res.data['data']?['events'] as List?) ?? const [];
      state = state.copyWith(
        isLoading: false,
        events: List<Map<String, dynamic>>.from(data),
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message']?.toString() ?? e.message ?? 'Failed to load events',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> getEvent(String id) async {
    try {
      final res = await _dio.get('events/$id');
      return res.data['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> createEvent({
    required String title,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    required String location,
    String? rules,
    required String organizerName,
    required String organizerContact,
    int maxMembersPerRegistration = 5,
    int? maxTotalRegistrations,
  }) async {
    try {
      final res = await _dio.post('events', data: {
        'title': title,
        'description': description,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'location': location,
        'rules': rules,
        'organizerName': organizerName,
        'organizerContact': organizerContact,
        'maxMembersPerRegistration': maxMembersPerRegistration,
        if (maxTotalRegistrations != null) 'maxTotalRegistrations': maxTotalRegistrations,
      });
      if (res.data['success'] == true) {
        await refresh();
        return null;
      }
      return res.data['message']?.toString() ?? 'Failed to create event';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to create event';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateEvent(String id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.patch('events/$id', data: data);
      if (res.data['success'] == true) {
        await refresh();
        return null;
      }
      return res.data['message']?.toString() ?? 'Failed to update event';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to update event';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteEvent(String id) async {
    try {
      final res = await _dio.delete('events/$id');
      if (res.data['success'] == true) {
        await refresh();
        return null;
      }
      return res.data['message']?.toString() ?? 'Failed to delete event';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to delete event';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> register({required String eventId, int memberCount = 1, String? notes}) async {
    try {
      final res = await _dio.post('events/$eventId/register', data: {
        'memberCount': memberCount,
        if (notes != null) 'notes': notes,
      });
      if (res.data['success'] == true) {
        await refresh();
        return null;
      }
      return res.data['message']?.toString() ?? 'Registration failed';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Registration failed';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> cancelRegistration(String eventId) async {
    try {
      final res = await _dio.delete('events/$eventId/register');
      if (res.data['success'] == true) {
        await refresh();
        return null;
      }
      return res.data['message']?.toString() ?? 'Failed to cancel registration';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to cancel registration';
    } catch (e) {
      return e.toString();
    }
  }

  Future<Map<String, dynamic>?> getRegistrations(String eventId) async {
    try {
      final res = await _dio.get('events/$eventId/registrations');
      return res.data['data'] as Map<String, dynamic>?;
    } on DioException catch (e) {
      return {'_error': e.response?.data?['message']?.toString() ?? 'Failed to load registrations'};
    } catch (e) {
      return {'_error': e.toString()};
    }
  }
}

final eventsProvider = StateNotifierProvider<EventsNotifier, EventsState>((ref) {
  final auth = ref.watch(authProvider);
  return EventsNotifier(ref, auth);
});
