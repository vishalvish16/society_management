import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import '../../../core/providers/auth_provider.dart';
import '../models/task_models.dart';

class TasksState {
  final List<TaskModel> tasks;
  final Map<String, TaskCategory> categories;
  final bool isLoading;
  final String? error;

  const TasksState({
    this.tasks = const [],
    this.categories = const {},
    this.isLoading = false,
    this.error,
  });

  TasksState copyWith({
    List<TaskModel>? tasks,
    Map<String, TaskCategory>? categories,
    bool? isLoading,
    String? error,
  }) {
    return TasksState(
      tasks: tasks ?? this.tasks,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class TasksNotifier extends StateNotifier<TasksState> {
  final Ref ref;
  TasksNotifier(this.ref) : super(const TasksState(isLoading: true)) {
    _init();
  }

  Dio get _dio => ref.read(authProvider.notifier).client.dio;

  Future<void> _init() async {
    await Future.wait([loadCategories(), loadTasks()]);
  }

  Future<void> loadCategories() async {
    try {
      final res = await _dio.get('tasks/categories');
      if (res.data['success'] == true) {
        final raw = res.data['data'] as Map<String, dynamic>;
        final cats = <String, TaskCategory>{};
        for (final entry in raw.entries) {
          cats[entry.key] = TaskCategory.fromEntry(entry);
        }
        state = state.copyWith(categories: cats);
      }
    } catch (_) {}
  }

  Future<void> loadTasks({String? status, String? category, String? priority, bool? assignedToMe}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, String>{};
      if (status != null) params['status'] = status;
      if (category != null) params['category'] = category;
      if (priority != null) params['priority'] = priority;
      if (assignedToMe == true) params['assignedToMe'] = 'true';

      final res = await _dio.get('tasks', queryParameters: params);
      if (res.data['success'] == true) {
        final list = (res.data['data'] as List).map((e) => TaskModel.fromJson(e)).toList();
        state = state.copyWith(tasks: list, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: res.data['message']);
      }
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _errMsg(e));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<TaskModel?> getTask(String id) async {
    try {
      final res = await _dio.get('tasks/$id');
      if (res.data['success'] == true) {
        return TaskModel.fromJson(res.data['data']);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> createTask({
    required String title,
    String? description,
    required String category,
    String? subCategory,
    required String priority,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> assigneeIds,
    List<XFile>? attachments,
  }) async {
    try {
      final formData = FormData.fromMap({
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        'category': category,
        if (subCategory != null) 'subCategory': subCategory,
        'priority': priority,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      });

      for (int i = 0; i < assigneeIds.length; i++) {
        formData.fields.add(MapEntry('assigneeIds[$i]', assigneeIds[i]));
      }

      if (attachments != null) {
        for (final file in attachments) {
          final bytes = await file.readAsBytes();
          formData.files.add(MapEntry(
            'attachments',
            MultipartFile.fromBytes(
              bytes,
              filename: file.name,
              contentType: MediaType.parse(file.mimeType ?? 'application/octet-stream'),
            ),
          ));
        }
      }

      final res = await _dio.post('tasks', data: formData);
      if (res.data['success'] == true) {
        await loadTasks();
        return true;
      }
      state = state.copyWith(error: res.data['message']);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(error: _errMsg(e));
      return false;
    }
  }

  Future<bool> updateTask(String id, Map<String, dynamic> data, {List<XFile>? newAttachments}) async {
    try {
      final formData = FormData();

      for (final entry in data.entries) {
        if (entry.value is List) {
          final list = entry.value as List;
          for (int i = 0; i < list.length; i++) {
            formData.fields.add(MapEntry('${entry.key}[$i]', list[i].toString()));
          }
        } else if (entry.value != null) {
          formData.fields.add(MapEntry(entry.key, entry.value.toString()));
        }
      }

      if (newAttachments != null) {
        for (final file in newAttachments) {
          final bytes = await file.readAsBytes();
          formData.files.add(MapEntry(
            'attachments',
            MultipartFile.fromBytes(
              bytes,
              filename: file.name,
              contentType: MediaType.parse(file.mimeType ?? 'application/octet-stream'),
            ),
          ));
        }
      }

      final res = await _dio.put('tasks/$id', data: formData);
      if (res.data['success'] == true) {
        await loadTasks();
        return true;
      }
      state = state.copyWith(error: res.data['message']);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(error: _errMsg(e));
      return false;
    }
  }

  Future<bool> updateStatus(String id, String status, {String? statusNote}) async {
    try {
      final res = await _dio.post('tasks/$id/status', data: {
        'status': status,
        if (statusNote != null) 'statusNote': statusNote,
      });
      if (res.data['success'] == true) {
        await loadTasks();
        return true;
      }
      return false;
    } on DioException catch (e) {
      state = state.copyWith(error: _errMsg(e));
      return false;
    }
  }

  Future<bool> addComment(String taskId, String body) async {
    try {
      final res = await _dio.post('tasks/$taskId/comments', data: {'body': body});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteTask(String id) async {
    try {
      final res = await _dio.delete('tasks/$id');
      if (res.data['success'] == true) {
        state = state.copyWith(tasks: state.tasks.where((t) => t.id != id).toList());
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  String _errMsg(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'];
    return 'Something went wrong';
  }
}

final tasksProvider = StateNotifierProvider<TasksNotifier, TasksState>((ref) {
  return TasksNotifier(ref);
});
