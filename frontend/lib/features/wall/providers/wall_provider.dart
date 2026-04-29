import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/dio_provider.dart';

class WallState {
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final List<Map<String, dynamic>> posts;
  final String? nextCursor;

  const WallState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.posts = const [],
    this.nextCursor,
  });

  WallState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    List<Map<String, dynamic>>? posts,
    String? nextCursor,
    bool clearError = false,
    bool clearCursor = false,
  }) {
    return WallState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      posts: posts ?? this.posts,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
    );
  }
}

class WallNotifier extends StateNotifier<WallState> {
  final Ref ref;
  final AuthState auth;
  WallNotifier(this.ref, this.auth) : super(const WallState()) {
    if (auth.isAuthenticated) refresh();
  }

  bool get isAdmin {
    final r = auth.user?.role.toUpperCase() ?? '';
    return r == 'PRAMUKH' || r == 'CHAIRMAN' || r == 'SECRETARY' || r == 'SUPER_ADMIN';
  }

  Dio get _dio => ref.read(dioProvider);

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true, clearCursor: true);
    try {
      final res = await _dio.get('wall', queryParameters: {'limit': 20});
      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      final posts = List<Map<String, dynamic>>.from(data['posts'] as List? ?? []);
      final cursor = data['nextCursor'] as String?;
      state = state.copyWith(isLoading: false, posts: posts, nextCursor: cursor, clearCursor: cursor == null);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.response?.data?['message']?.toString() ?? 'Failed to load wall');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.nextCursor == null) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final res = await _dio.get('wall', queryParameters: {'limit': 20, 'cursor': state.nextCursor});
      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      final more = List<Map<String, dynamic>>.from(data['posts'] as List? ?? []);
      final cursor = data['nextCursor'] as String?;
      state = state.copyWith(
        isLoadingMore: false,
        posts: [...state.posts, ...more],
        nextCursor: cursor,
        clearCursor: cursor == null,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.response?.data?['message']?.toString() ?? 'Failed to load more');
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<String?> createPost({String? body, List<XFile> media = const []}) async {
    try {
      FormData formData;
      if (media.isEmpty) {
        formData = FormData.fromMap({'body': body ?? ''});
      } else {
        final mediaFiles = <MultipartFile>[];
        for (final f in media) {
          mediaFiles.add(await MultipartFile.fromFile(f.path, filename: f.name));
        }
        formData = FormData.fromMap({
          if (body != null && body.isNotEmpty) 'body': body,
          'media': mediaFiles,
        });
      }
      final res = await _dio.post('wall', data: formData,
          options: Options(contentType: 'multipart/form-data'));
      if (res.data['success'] == true) {
        final newPost = res.data['data'] as Map<String, dynamic>;
        state = state.copyWith(posts: [newPost, ...state.posts]);
        return null;
      }
      return res.data['message']?.toString() ?? 'Failed to create post';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to create post';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> toggleHidePost(String postId) async {
    try {
      final res = await _dio.patch('wall/$postId/hide');
      if (res.data['success'] == true) {
        final updated = res.data['data'] as Map<String, dynamic>;
        state = state.copyWith(
          posts: state.posts.map((p) => p['id'] == postId ? updated : p).toList(),
        );
        return null;
      }
      return res.data['message']?.toString() ?? 'Failed';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deletePost(String postId) async {
    try {
      final res = await _dio.delete('wall/$postId');
      if (res.data['success'] == true) {
        state = state.copyWith(posts: state.posts.where((p) => p['id'] != postId).toList());
        return null;
      }
      return res.data['message']?.toString() ?? 'Failed to delete';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to delete';
    } catch (e) {
      return e.toString();
    }
  }

  // ── Who liked ────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLikes(String postId) async {
    try {
      final res = await _dio.get('wall/$postId/likes');
      return List<Map<String, dynamic>>.from(res.data['data'] as List? ?? []);
    } catch (_) {
      return [];
    }
  }

  // ── Likes ─────────────────────────────────────────────────────────────────

  Future<String?> toggleLike(String postId) async {
    // Optimistic update
    state = state.copyWith(
      posts: state.posts.map((p) {
        if (p['id'] != postId) return p;
        final liked = p['likedByMe'] == true;
        final count = ((p['_count'] as Map?)?['likes'] as int? ?? 0);
        final updated = Map<String, dynamic>.from(p);
        updated['likedByMe'] = !liked;
        updated['_count'] = {
          ...(p['_count'] as Map? ?? {}),
          'likes': liked ? (count - 1).clamp(0, 9999) : count + 1,
        };
        return updated;
      }).toList(),
    );
    try {
      final res = await _dio.post('wall/$postId/like');
      if (res.data['success'] == true) {
        final data = res.data['data'] as Map<String, dynamic>;
        // Sync with server truth
        state = state.copyWith(
          posts: state.posts.map((p) {
            if (p['id'] != postId) return p;
            final updated = Map<String, dynamic>.from(p);
            updated['likedByMe'] = data['likedByMe'];
            updated['_count'] = {
              ...(p['_count'] as Map? ?? {}),
              'likes': data['likeCount'],
            };
            return updated;
          }).toList(),
        );
        return null;
      }
      return res.data['message']?.toString() ?? 'Failed';
    } on DioException catch (e) {
      await refresh(); // revert optimistic on error
      return e.response?.data?['message']?.toString() ?? 'Failed';
    } catch (e) {
      await refresh();
      return e.toString();
    }
  }

  // ── Comments ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> loadComments(String postId, {String? cursor}) async {
    try {
      final res = await _dio.get('wall/$postId/comments',
          queryParameters: {'limit': 50, 'cursor': cursor});
      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      return {
        'comments': List<Map<String, dynamic>>.from(data['comments'] as List? ?? []),
        'nextCursor': data['nextCursor'],
      };
    } on DioException catch (e) {
      return {'_error': e.response?.data?['message']?.toString() ?? 'Failed to load comments'};
    } catch (e) {
      return {'_error': e.toString()};
    }
  }

  Future<String?> addComment(String postId, String body) async {
    try {
      final res = await _dio.post('wall/$postId/comments', data: {'body': body});
      if (res.data['success'] == true) return null;
      return res.data['message']?.toString() ?? 'Failed to comment';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to comment';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> toggleHideComment(String postId, String commentId) async {
    try {
      final res = await _dio.patch('wall/$postId/comments/$commentId/hide');
      if (res.data['success'] == true) return null;
      return res.data['message']?.toString() ?? 'Failed';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteComment(String postId, String commentId) async {
    try {
      final res = await _dio.delete('wall/$postId/comments/$commentId');
      if (res.data['success'] == true) return null;
      return res.data['message']?.toString() ?? 'Failed to delete comment';
    } on DioException catch (e) {
      return e.response?.data?['message']?.toString() ?? 'Failed to delete comment';
    } catch (e) {
      return e.toString();
    }
  }
}

final wallProvider = StateNotifierProvider<WallNotifier, WallState>((ref) {
  final auth = ref.watch(authProvider);
  return WallNotifier(ref, auth);
});
