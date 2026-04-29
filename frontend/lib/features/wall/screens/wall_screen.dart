import 'dart:io';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/mention_text_field.dart';
import '../providers/wall_provider.dart';

// ── Wall Screen ───────────────────────────────────────────────────────────────

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
                              isAdmin: isAdmin);
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('New Post'),
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _CreatePostSheet(),
        ),
      ),
    );
  }
}

// ── Create Post Sheet ─────────────────────────────────────────────────────────

class _CreatePostSheet extends ConsumerStatefulWidget {
  const _CreatePostSheet();

  @override
  ConsumerState<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<_CreatePostSheet> {
  final _bodyCtrl = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _selectedMedia = [];  // images + videos together
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  bool _isVideo(XFile f) {
    final ext = f.name.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', '3gp', 'webm'].contains(ext);
  }

  Future<void> _pickImages() async {
    final remaining = 10 - _selectedMedia.length;
    if (remaining <= 0) return;
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty && mounted) {
      setState(() => _selectedMedia.addAll(picked.take(remaining)));
    }
  }

  Future<void> _pickCamera() async {
    if (_selectedMedia.length >= 10) return;
    final xfile = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 85);
    if (xfile != null && mounted) {
      setState(() => _selectedMedia.add(xfile));
    }
  }

  Future<void> _pickCameraVideo() async {
    if (_selectedMedia.length >= 10) return;
    final xfile = await _picker.pickVideo(source: ImageSource.camera);
    if (xfile != null && mounted) {
      setState(() => _selectedMedia.add(xfile));
    }
  }

  Future<void> _pickVideo() async {
    final remaining = 10 - _selectedMedia.length;
    if (remaining <= 0) return;
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty && mounted) {
      final path = result.files.first.path;
      if (path != null) {
        setState(() => _selectedMedia.add(XFile(path)));
      }
    }
  }

  Future<void> _submit() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty && _selectedMedia.isEmpty) {
      setState(() => _error = 'Add some text or pick at least one photo/video.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    final err = await ref.read(wallProvider.notifier).createPost(
          body: body.isEmpty ? null : body,
          media: _selectedMedia,
        );
    if (!mounted) return;
    if (err != null) {
      setState(() { _submitting = false; _error = err; });
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Post shared!'), backgroundColor: AppColors.success));
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
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.md, AppDimensions.sm, AppDimensions.md, AppDimensions.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: AppDimensions.md),
          Text('New Post', style: AppTextStyles.h3),
          const SizedBox(height: AppDimensions.sm),
          MentionTextField(
            controller: _bodyCtrl,
            hintText: "What's on your mind? Use @ to mention someone",
            maxLines: 5,
            minLines: 3,
          ),
          if (_selectedMedia.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sm),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedMedia.length,
                separatorBuilder: (_, idx) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final isVid = _isVideo(_selectedMedia[i]);
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isVid
                            ? Container(
                                width: 90, height: 90,
                                color: Colors.black87,
                                alignment: Alignment.center,
                                child: const Icon(Icons.videocam_rounded,
                                    color: Colors.white, size: 32),
                              )
                            : Image.file(
                                File(_selectedMedia[i].path),
                                width: 90, height: 90, fit: BoxFit.cover,
                                errorBuilder: (ctx, err, st) => Container(
                                  width: 90, height: 90,
                                  color: AppColors.surface,
                                  child: const Icon(Icons.image_rounded,
                                      color: AppColors.textSecondary),
                                ),
                              ),
                      ),
                      Positioned(
                        top: 2, right: 2,
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
                  );
                },
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(_error!,
                style: AppTextStyles.caption.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: AppDimensions.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _MediaBtn(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: _selectedMedia.length < 10 ? _pickImages : null,
                ),
                const SizedBox(width: 8),
                _MediaBtn(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: _selectedMedia.length < 10 ? _pickCamera : null,
                ),
                const SizedBox(width: 8),
                _MediaBtn(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  onTap: _selectedMedia.length < 10 ? _pickVideo : null,
                ),
                const SizedBox(width: 8),
                _MediaBtn(
                  icon: Icons.video_camera_back_rounded,
                  label: 'Rec Video',
                  onTap: _selectedMedia.length < 10 ? _pickCameraVideo : null,
                ),
                if (_selectedMedia.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('${_selectedMedia.length}/10',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              const Spacer(),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary),
                child: _submitting
                    ? const SizedBox(
                        width: 18, height: 18,
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
              // ── Header ────────────────────────────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
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
                        Text(_timeAgo(post['createdAt'] as String?),
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary)),
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
                      onSelected: (v) => _onMenuAction(context, ref, v),
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
                                style: TextStyle(color: AppColors.danger)),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              // ── Body text ─────────────────────────────────────────────────
              if (body != null && body.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.sm),
                Text(body, style: AppTextStyles.bodyMedium),
              ],

              // ── Media grid (tappable) ─────────────────────────────────────
              if (media.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.sm),
                _MediaGrid(
                  media: media,
                  baseUrl: baseUrl,
                  onTap: (index) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _MediaViewerScreen(
                          media: media, baseUrl: baseUrl, initialIndex: index),
                    ),
                  ),
                ),
              ],

              const Divider(height: AppDimensions.lg),

              // ── Like + Comment row ────────────────────────────────────────
              Row(
                children: [
                  // Like button
                  InkWell(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSm),
                    onTap: () => ref
                        .read(wallProvider.notifier)
                        .toggleLike(post['id'] as String),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 2),
                      child: Row(
                        children: [
                          Icon(
                            likedByMe
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                            color: likedByMe
                                ? AppColors.danger
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            likeCount > 0 ? '$likeCount' : 'Like',
                            style: AppTextStyles.caption.copyWith(
                              color: likedByMe
                                  ? AppColors.danger
                                  : AppColors.textSecondary,
                              fontWeight: likedByMe
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Who liked — tap on like count to see who
                  if (likeCount > 0) ...[
                    const SizedBox(width: 2),
                    InkWell(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSm),
                      onTap: () => _showWhoLiked(context, ref),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 4),
                        child: Text('· See all',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                decoration: TextDecoration.underline)),
                      ),
                    ),
                  ],
                  const SizedBox(width: AppDimensions.md),
                  // Comment button
                  InkWell(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSm),
                    onTap: () => _showComments(context, ref),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 2),
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
      final err = await notifier.toggleHidePost(post['id'] as String);
      if (err != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(err), backgroundColor: AppColors.danger));
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
        final err = await notifier.deletePost(post['id'] as String);
        if (err != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(err), backgroundColor: AppColors.danger));
        }
      }
    }
  }

  void _showWhoLiked(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _WhoLikedSheet(postId: post['id'] as String),
    );
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
  final void Function(int index) onTap;

  const _MediaGrid(
      {required this.media, required this.baseUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (media.length == 1) {
      return GestureDetector(
        onTap: () => onTap(0),
        child: _MediaTile(item: media[0], baseUrl: baseUrl, height: 220),
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 4,
      mainAxisSpacing: 4,
      children: media.take(4).toList().asMap().entries.map((e) {
        final isOverflow = e.key == 3 && media.length > 4;
        return GestureDetector(
          onTap: () => onTap(e.key),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _MediaTile(item: e.value, baseUrl: baseUrl, height: 120),
              if (isOverflow)
                Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: Text('+${media.length - 3}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
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
    final isVideo = (item['mediaType'] as String? ?? '') == 'VIDEO';
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: isVideo
          ? Container(
              height: height,
              color: Colors.black87,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(color: Colors.black87, width: double.infinity, height: height),
                  const Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white, size: 48),
                ],
              ),
            )
          : Image.network(
              url, height: height, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => Container(
                height: height, color: AppColors.surface,
                child: const Icon(Icons.broken_image_rounded,
                    color: AppColors.textSecondary),
              ),
            ),
    );
  }
}

// ── Fullscreen Media Viewer ───────────────────────────────────────────────────

class _MediaViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> media;
  final String baseUrl;
  final int initialIndex;

  const _MediaViewerScreen(
      {required this.media,
      required this.baseUrl,
      required this.initialIndex});

  @override
  State<_MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<_MediaViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _current => widget.media[_currentIndex];
  String get _url => '${widget.baseUrl}${_current['url']}';

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final dir = await getTemporaryDirectory();
      final fileName = _current['fileName'] as String? ??
          'wall_media_$_currentIndex';
      final savePath = '${dir.path}/$fileName';
      final dioInst = dio_pkg.Dio();
      await dioInst.download(_url, savePath);
      await OpenFilex.open(savePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: $e'),
                backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.media.length > 1
            ? Text('${_currentIndex + 1} / ${widget.media.length}',
                style: const TextStyle(color: Colors.white))
            : null,
        actions: [
          if (_downloading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else
            IconButton(
              tooltip: 'Download',
              icon: const Icon(Icons.download_rounded, color: Colors.white),
              onPressed: _download,
            ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.media.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, i) {
          final item = widget.media[i];
          final url = '${widget.baseUrl}${item['url']}';
          final isVid = (item['mediaType'] as String? ?? '') == 'VIDEO';
          if (isVid) {
            return _VideoPlayerWidget(url: url);
          }
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: Image.network(url,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, st) => const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white,
                      size: 64)),
            ),
          );
        },
      ),
    );
  }
}

// ── Video Player Widget ───────────────────────────────────────────────────────

class _VideoPlayerWidget extends StatefulWidget {
  final String url;
  const _VideoPlayerWidget({required this.url});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.url))
          ..initialize().then((_) {
            if (mounted) setState(() => _initialized = true);
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying
              ? _controller.pause()
              : _controller.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          if (!_controller.value.isPlaying)
            const Icon(Icons.play_circle_fill_rounded,
                color: Colors.white70, size: 64),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                  playedColor: AppColors.primary,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Who Liked Sheet ───────────────────────────────────────────────────────────

class _WhoLikedSheet extends ConsumerStatefulWidget {
  final String postId;
  const _WhoLikedSheet({required this.postId});

  @override
  ConsumerState<_WhoLikedSheet> createState() => _WhoLikedSheetState();
}

class _WhoLikedSheetState extends ConsumerState<_WhoLikedSheet> {
  List<Map<String, dynamic>> _likers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result =
        await ref.read(wallProvider.notifier).getLikes(widget.postId);
    if (mounted) setState(() { _likers = result; _loading = false; });
  }

  String _initial(String? name) {
    final n = (name ?? '?').trim();
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }

  String _roleLabel(String? role) {
    switch ((role ?? '').toUpperCase()) {
      case 'PRAMUKH':   return 'Pramukh';
      case 'CHAIRMAN':  return 'Chairman';
      case 'SECRETARY': return 'Secretary';
      case 'MEMBER':    return 'Member';
      case 'RESIDENT':  return 'Resident';
      default:          return role ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.sm),
            child: Center(
              child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.sm),
            child: Row(
              children: [
                const Icon(Icons.favorite_rounded,
                    color: AppColors.danger, size: 18),
                const SizedBox(width: 6),
                Text(
                  _loading
                      ? 'Likes'
                      : '${_likers.length} Like${_likers.length == 1 ? '' : 's'}',
                  style: AppTextStyles.h3,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _loading
              ? const Padding(
                  padding: EdgeInsets.all(AppDimensions.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _likers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AppDimensions.xl),
                      child: Center(child: Text('No likes yet')),
                    )
                  : Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppDimensions.sm),
                        itemCount: _likers.length,
                        itemBuilder: (_, i) {
                          final u = _likers[i];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                _initial(u['name'] as String?),
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(u['name'] as String? ?? 'Unknown',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(fontWeight: FontWeight.w600)),
                            subtitle: Text(_roleLabel(u['role'] as String?),
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary)),
                            trailing: const Icon(Icons.favorite_rounded,
                                color: AppColors.danger, size: 16),
                          );
                        },
                      ),
                    ),
        ],
      ),
    );
  }
}

// ── Media Button ─────────────────────────────────────────────────────────────

class _MediaBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _MediaBtn({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    setState(() { _loading = true; _error = null; });
    final result =
        await ref.read(wallProvider.notifier).loadComments(widget.postId);
    if (!mounted) return;
    if (result.containsKey('_error')) {
      setState(() { _loading = false; _error = result['_error'] as String; });
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
          SnackBar(content: Text(err), backgroundColor: AppColors.danger));
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
      final err =
          await notifier.toggleHideComment(widget.postId, commentId);
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: AppColors.danger));
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
        final err =
            await notifier.deleteComment(widget.postId, commentId);
        if (err != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(err), backgroundColor: AppColors.danger));
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
                  width: 40, height: 4,
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
                            child: Text('No comments yet. Be the first!'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppDimensions.sm,
                                horizontal: AppDimensions.md),
                            itemCount: _comments.length,
                            itemBuilder: (_, i) {
                              final c = _comments[i];
                              final isHidden = c['isHidden'] == true;
                              final author =
                                  c['author'] as Map<String, dynamic>?;
                              final name =
                                  author?['name'] as String? ?? 'Unknown';
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
                                        backgroundColor: AppColors.primary
                                            .withValues(alpha: 0.15),
                                        child: Text(initial,
                                            style:
                                                AppTextStyles.caption.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                            )),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius:
                                                BorderRadius.circular(
                                                    AppDimensions.radiusMd),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(name,
                                                      style: AppTextStyles
                                                          .caption
                                                          .copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600)),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _timeAgo(c['createdAt']
                                                        as String?),
                                                    style: AppTextStyles
                                                        .caption
                                                        .copyWith(
                                                            color: AppColors
                                                                .textSecondary),
                                                  ),
                                                  if (isHidden) ...[
                                                    const SizedBox(width: 6),
                                                    Text('· Hidden',
                                                        style: AppTextStyles
                                                            .caption
                                                            .copyWith(
                                                                color: AppColors
                                                                    .warning)),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(c['body'] as String? ?? '',
                                                  style:
                                                      AppTextStyles.bodyMedium),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (_canManageComment(c))
                                        PopupMenuButton<String>(
                                          icon: const Icon(
                                              Icons.more_vert_rounded,
                                              size: 18,
                                              color:
                                                  AppColors.textSecondary),
                                          onSelected: (v) =>
                                              _onCommentMenu(c, v),
                                          itemBuilder: (_) => [
                                            PopupMenuItem(
                                                value: 'hide',
                                                child: Text(isHidden
                                                    ? 'Unhide'
                                                    : 'Hide')),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete',
                                                  style: TextStyle(
                                                      color:
                                                          AppColors.danger)),
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
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppDimensions.md,
                AppDimensions.sm, AppDimensions.md, AppDimensions.md),
            child: Row(
              children: [
                Expanded(
                  child: MentionTextField(
                    controller: _ctrl,
                    hintText: 'Write a comment… use @ to mention',
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _submit,
                    decoration: InputDecoration(
                      hintText: 'Write a comment… use @ to mention',
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
                        width: 36, height: 36,
                        child: CircularProgressIndicator(strokeWidth: 2))
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
