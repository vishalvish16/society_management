import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../providers/wall_provider.dart';

class WallScreen extends ConsumerStatefulWidget {
  const WallScreen({super.key});

  @override
  ConsumerState<WallScreen> createState() => _WallScreenState();
}

class _WallScreenState extends ConsumerState<WallScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(wallProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(wallProvider);
    final user = ref.watch(authProvider).user;
    final myId = user?.id ?? '';
    final isAdmin = ref.read(wallProvider.notifier).isAdmin;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Society Wall',
            style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.read(wallProvider.notifier).refresh(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(wallProvider.notifier).refresh(),
        child: st.isLoading
            ? const AppLoadingShimmer()
            : st.error != null && st.posts.isEmpty
                ? Center(
                    child: AppCard(
                      leftBorderColor: AppColors.danger,
                      child: Text(st.error!,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.danger)),
                    ),
                  )
                : st.posts.isEmpty
                    ? const AppEmptyState(
                        emoji: '📋',
                        title: 'Nothing posted yet',
                        subtitle:
                            'Be the first to share something with your society!',
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppDimensions.md,
                            horizontal: AppDimensions.sm),
                        itemCount:
                            st.posts.length + (st.isLoadingMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == st.posts.length) {
                            return const Padding(
                              padding: EdgeInsets.all(AppDimensions.md),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _PostCard(
                            post: st.posts[i],
                            myId: myId,
                            isAdmin: isAdmin,
                          );
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('New Post'),
        onPressed: () => _showCreatePostSheet(context),
      ),
    );
  }

  void _showCreatePostSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreatePostSheet(),
    );
  }
}

// ── Create Post Sheet ──────────────────────────────────────────────────────────

class _CreatePostSheet extends ConsumerStatefulWidget {
  const _CreatePostSheet();

  @override
  ConsumerState<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<_CreatePostSheet> {
  final _bodyCtrl = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _selectedMedia = [];
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final remaining = 10 - _selectedMedia.length;
    if (remaining <= 0) return;
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty && mounted) {
      setState(() => _selectedMedia.addAll(picked.take(remaining)));
    }
  }

  Future<void> _submit() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty && _selectedMedia.isEmpty) {
      setState(() => _error = 'Add some text or pick at least one photo.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final err = await ref.read(wallProvider.notifier).createPost(
          body: body.isEmpty ? null : body,
          media: _selectedMedia,
        );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _submitting = false;
        _error = err;
      });
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Post shared!'),
            backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(AppDimensions.md, AppDimensions.sm,
          AppDimensions.md, AppDimensions.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: AppDimensions.md),
          Text('New Post', style: AppTextStyles.h3),
          const SizedBox(height: AppDimensions.sm),
          TextField(
            controller: _bodyCtrl,
            maxLines: 5,
            minLines: 3,
            decoration: InputDecoration(
              hintText: "What's on your mind?",
              hintStyle: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd)),
              contentPadding: const EdgeInsets.all(AppDimensions.sm),
            ),
          ),
          if (_selectedMedia.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sm),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedMedia.length,
                separatorBuilder: (_, idx) => const SizedBox(width: 8),
                itemBuilder: (context, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _selectedMedia[i].path,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) => Container(
                          width: 80,
                          height: 80,
                          color: AppColors.surface,
                          child: const Icon(Icons.image_rounded,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedMedia.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(_error!,
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _selectedMedia.length < 10 ? _pickMedia : null,
                icon: const Icon(Icons.photo_library_rounded),
                label: Text(
                    'Photo${_selectedMedia.isNotEmpty ? ' (${_selectedMedia.length})' : ''}'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Post'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Post Card ─────────────────────────────────────────────────────────────────

class _PostCard extends ConsumerWidget {
  final Map<String, dynamic> post;
  final String myId;
  final bool isAdmin;

  const _PostCard(
      {required this.post, required this.myId, required this.isAdmin});

  bool get _isMyPost => post['authorId'] == myId;
  bool get _canManage => _isMyPost || isAdmin;
  bool get _isHidden => post['isHidden'] == true;

  String _avatarInitial(Map<String, dynamic>? author) {
    final name = (author?['name'] as String? ?? '?').trim();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = post['author'] as Map<String, dynamic>?;
    final media =
        (post['media'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final commentCount =
        (post['_count'] as Map?)?['comments'] as int? ?? 0;
    final likeCount = (post['_count'] as Map?)?['likes'] as int? ?? 0;
    final likedByMe = post['likedByMe'] == true;
    final body = post['body'] as String?;
    final baseUrl = AppConstants.uploadsBaseUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: Opacity(
        opacity: _isHidden ? 0.55 : 1.0,
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.15),
                    child: Text(_avatarInitial(author),
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(author?['name'] as String? ?? 'Unknown',
                            style: AppTextStyles.bodyMedium
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text(
                            _timeAgo(post['createdAt'] as String?),
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (_isHidden)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Hidden',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.warning)),
                    ),
                  if (_canManage)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded,
                          color: AppColors.textSecondary),
                      onSelected: (v) =>
                          _onMenuAction(context, ref, v),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'hide',
                          child: ListTile(
                            leading: Icon(
                              _isHidden
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              size: 20,
                            ),
                            title: Text(
                                _isHidden ? 'Unhide Post' : 'Hide Post'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete_rounded,
                                size: 20, color: AppColors.danger),
                            title: Text('Delete Post',
                                style:
                                    TextStyle(color: AppColors.danger)),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              // Body text
              if (body != null && body.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.sm),
                Text(body, style: AppTextStyles.bodyMedium),
              ],

              // Media grid
              if (media.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.sm),
                _MediaGrid(media: media, baseUrl: baseUrl),
              ],

              const Divider(height: AppDimensions.lg),

              // Like + Comment row
              Row(
                children: [
                  // Like button
                  InkWell(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    onTap: () => ref.read(wallProvider.notifier).toggleLike(post['id'] as String),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        children: [
                          Icon(
                            likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 18,
                            color: likedByMe ? AppColors.danger : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            likeCount > 0 ? '$likeCount' : 'Like',
                            style: AppTextStyles.caption.copyWith(
                              color: likedByMe ? AppColors.danger : AppColors.textSecondary,
                              fontWeight: likedByMe ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  // Comment button
                  InkWell(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    onTap: () => _showComments(context, ref),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded,
                              size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            commentCount == 0
                                ? 'Comment'
                                : '$commentCount comment${commentCount == 1 ? '' : 's'}',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onMenuAction(
      BuildContext context, WidgetRef ref, String action) async {
    final notifier = ref.read(wallProvider.notifier);
    if (action == 'hide') {
      final err =
          await notifier.toggleHidePost(post['id'] as String);
      if (err != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(err),
                backgroundColor: AppColors.danger));
      }
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Post'),
          content: const Text(
              'Are you sure you want to delete this post? This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      );
      if (confirm == true) {
        final err =
            await notifier.deletePost(post['id'] as String);
        if (err != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(err),
                  backgroundColor: AppColors.danger));
        }
      }
    }
  }

  void _showComments(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        postId: post['id'] as String,
        isAdmin: isAdmin,
        myId: myId,
        postAuthorId: post['authorId'] as String? ?? '',
      ),
    );
  }
}

// ── Media Grid ────────────────────────────────────────────────────────────────

class _MediaGrid extends StatelessWidget {
  final List<Map<String, dynamic>> media;
  final String baseUrl;
  const _MediaGrid({required this.media, required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    if (media.length == 1) {
      return _MediaTile(item: media[0], baseUrl: baseUrl, height: 220);
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 4,
      mainAxisSpacing: 4,
      children: media.take(4).toList().asMap().entries.map((e) {
        final isOverflow = e.key == 3 && media.length > 4;
        return Stack(
          fit: StackFit.expand,
          children: [
            _MediaTile(item: e.value, baseUrl: baseUrl, height: 120),
            if (isOverflow)
              Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: Text(
                  '+${media.length - 3}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        );
      }).toList(),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final String baseUrl;
  final double height;
  const _MediaTile(
      {required this.item, required this.baseUrl, required this.height});

  @override
  Widget build(BuildContext context) {
    final url = '$baseUrl${item['url']}';
    final isVideo =
        (item['mediaType'] as String? ?? '') == 'VIDEO';
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: isVideo
          ? Container(
              height: height,
              color: Colors.black87,
              alignment: Alignment.center,
              child: const Icon(Icons.play_circle_fill_rounded,
                  color: Colors.white, size: 48),
            )
          : Image.network(
              url,
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => Container(
                height: height,
                color: AppColors.surface,
                child: const Icon(Icons.broken_image_rounded,
                    color: AppColors.textSecondary),
              ),
            ),
    );
  }
}

// ── Comments Sheet ────────────────────────────────────────────────────────────

class _CommentsSheet extends ConsumerStatefulWidget {
  final String postId;
  final bool isAdmin;
  final String myId;
  final String postAuthorId;
  const _CommentsSheet({
    required this.postId,
    required this.isAdmin,
    required this.myId,
    required this.postAuthorId,
  });

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result =
        await ref.read(wallProvider.notifier).loadComments(widget.postId);
    if (!mounted) return;
    if (result.containsKey('_error')) {
      setState(() {
        _loading = false;
        _error = result['_error'] as String;
      });
    } else {
      setState(() {
        _loading = false;
        _comments = List<Map<String, dynamic>>.from(
            result['comments'] as List? ?? []);
      });
    }
  }

  Future<void> _submit() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _submitting = true);
    final err = await ref
        .read(wallProvider.notifier)
        .addComment(widget.postId, body);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(err),
              backgroundColor: AppColors.danger));
      setState(() => _submitting = false);
    } else {
      _ctrl.clear();
      setState(() => _submitting = false);
      await _load();
    }
  }

  Future<void> _onCommentMenu(
      Map<String, dynamic> comment, String action) async {
    final notifier = ref.read(wallProvider.notifier);
    final commentId = comment['id'] as String;
    if (action == 'hide') {
      final err = await notifier.toggleHideComment(
          widget.postId, commentId);
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(err),
                backgroundColor: AppColors.danger));
      } else {
        await _load();
      }
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Comment'),
          content: const Text('Delete this comment?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      );
      if (confirm == true) {
        final err = await notifier.deleteComment(
            widget.postId, commentId);
        if (err != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(err),
                  backgroundColor: AppColors.danger));
        } else {
          await _load();
        }
      }
    }
  }

  bool _canManageComment(Map<String, dynamic> c) =>
      widget.isAdmin ||
      c['authorId'] == widget.myId ||
      widget.postAuthorId == widget.myId;

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.sm),
            child: Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.sm),
            child: Text('Comments', style: AppTextStyles.h3),
          ),
          const Divider(height: 1),

          // Comment list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.danger)))
                    : _comments.isEmpty
                        ? const Center(
                            child: Text(
                                'No comments yet. Be the first!'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppDimensions.sm,
                                horizontal: AppDimensions.md),
                            itemCount: _comments.length,
                            itemBuilder: (_, i) {
                              final c = _comments[i];
                              final isHidden =
                                  c['isHidden'] == true;
                              final author = c['author']
                                  as Map<String, dynamic>?;
                              final name =
                                  author?['name'] as String? ??
                                      'Unknown';
                              final initial = name.isNotEmpty
                                  ? name[0].toUpperCase()
                                  : '?';
                              return Opacity(
                                opacity: isHidden ? 0.5 : 1.0,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: AppDimensions.sm),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AppColors
                                            .primary
                                            .withValues(alpha: 0.15),
                                        child: Text(
                                          initial,
                                          style: AppTextStyles.caption
                                              .copyWith(
                                            color: AppColors.primary,
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 12,
                                              vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius:
                                                BorderRadius.circular(
                                                    AppDimensions
                                                        .radiusMd),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    name,
                                                    style: AppTextStyles
                                                        .caption
                                                        .copyWith(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600),
                                                  ),
                                                  const SizedBox(
                                                      width: 6),
                                                  Text(
                                                    _timeAgo(c[
                                                            'createdAt']
                                                        as String?),
                                                    style: AppTextStyles
                                                        .caption
                                                        .copyWith(
                                                            color: AppColors
                                                                .textSecondary),
                                                  ),
                                                  if (isHidden) ...[
                                                    const SizedBox(
                                                        width: 6),
                                                    Text(
                                                      '· Hidden',
                                                      style: AppTextStyles
                                                          .caption
                                                          .copyWith(
                                                              color: AppColors
                                                                  .warning),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(
                                                  height: 2),
                                              Text(
                                                c['body']
                                                        as String? ??
                                                    '',
                                                style: AppTextStyles
                                                    .bodyMedium,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (_canManageComment(c))
                                        PopupMenuButton<String>(
                                          icon: const Icon(
                                              Icons.more_vert_rounded,
                                              size: 18,
                                              color: AppColors
                                                  .textSecondary),
                                          onSelected: (v) =>
                                              _onCommentMenu(c, v),
                                          itemBuilder: (_) => [
                                            PopupMenuItem(
                                              value: 'hide',
                                              child: Text(isHidden
                                                  ? 'Unhide'
                                                  : 'Hide'),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete',
                                                  style: TextStyle(
                                                      color: AppColors
                                                          .danger)),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),

          // Input bar
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppDimensions.md,
                AppDimensions.sm, AppDimensions.md, AppDimensions.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'Write a comment…',
                      hintStyle: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _submitting
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                            strokeWidth: 2))
                    : IconButton(
                        onPressed: _submit,
                        icon: const Icon(Icons.send_rounded,
                            color: AppColors.primary),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
