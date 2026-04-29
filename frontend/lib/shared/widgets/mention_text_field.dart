import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/dio_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Fetches society members for mention suggestions.
/// Returns list of {id, name, role}.
final _membersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final dio = ref.read(dioProvider);
    final res = await dio.get('users',
        queryParameters: {'isActive': true, 'limit': 200});
    final data = res.data['data'] as Map<String, dynamic>? ?? {};
    final list = (data['users'] as List?) ?? [];
    return List<Map<String, dynamic>>.from(list);
  } catch (_) {
    return [];
  }
});

/// A TextField that intercepts `@` typing and shows a floating suggestion
/// overlay of society members. When a member is selected, their name is
/// inserted as `@Name ` and [onMentionAdded] is called with the userId.
///
/// Usage:
///   MentionTextField(
///     controller: _ctrl,
///     hintText: 'Write something...',
///     onMentionAdded: (userId) { ... },
///   )
class MentionTextField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final int minLines;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;
  final void Function(String userId)? onMentionAdded;
  final InputDecoration? decoration;

  const MentionTextField({
    super.key,
    required this.controller,
    this.hintText = '',
    this.maxLines = 5,
    this.minLines = 1,
    this.textInputAction,
    this.onSubmitted,
    this.onMentionAdded,
    this.decoration,
  });

  @override
  ConsumerState<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends ConsumerState<MentionTextField> {
  final _focusNode = FocusNode();
  OverlayEntry? _overlay;
  final _layerLink = LayerLink();

  // The @query currently being typed (null = not in mention mode)
  String? _query;
  // Offset of the `@` character that started the current mention
  int _mentionStart = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _removeOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    if (cursor < 0) {
      _exitMentionMode();
      return;
    }

    // Find the last `@` before cursor on the same "word" (no space between @ and cursor)
    final beforeCursor = text.substring(0, cursor);
    final atIdx = beforeCursor.lastIndexOf('@');

    if (atIdx == -1) {
      _exitMentionMode();
      return;
    }

    final fragment = beforeCursor.substring(atIdx + 1); // text after @
    // If there's a space in the fragment, the user has moved past the mention
    if (fragment.contains(' ') || fragment.contains('\n')) {
      _exitMentionMode();
      return;
    }

    _mentionStart = atIdx;
    final newQuery = fragment.toLowerCase();
    if (newQuery != _query) {
      setState(() => _query = newQuery);
      _showOverlay();
    }
  }

  void _exitMentionMode() {
    if (_query != null) {
      setState(() => _query = null);
      _mentionStart = -1;
    }
    _removeOverlay();
  }

  void _onMemberSelected(Map<String, dynamic> member) {
    final name = member['name'] as String? ?? '';
    final userId = member['id'] as String? ?? '';

    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;

    // Replace from @mentionStart to cursor with @Name
    final before = text.substring(0, _mentionStart);
    final after = cursor < text.length ? text.substring(cursor) : '';
    final inserted = '@$name ';
    final newText = '$before$inserted$after';
    final newCursor = before.length + inserted.length;

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    widget.onMentionAdded?.call(userId);
    _exitMentionMode();
  }

  void _showOverlay() {
    _removeOverlay();
    _overlay = OverlayEntry(builder: (_) => _SuggestionOverlay(
      link: _layerLink,
      query: _query ?? '',
      onSelected: _onMemberSelected,
    ));
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Pre-fetch members so the overlay loads instantly
    ref.watch(_membersProvider);

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted != null ? (_) => widget.onSubmitted!() : null,
        style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurface),
        cursorColor: scheme.primary,
        decoration: widget.decoration ??
            InputDecoration(
              hintText: widget.hintText,
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
      ),
    );
  }
}

// ── Suggestion Overlay ────────────────────────────────────────────────────────

class _SuggestionOverlay extends ConsumerWidget {
  final LayerLink link;
  final String query;
  final void Function(Map<String, dynamic>) onSelected;

  const _SuggestionOverlay({
    required this.link,
    required this.query,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final membersAsync = ref.watch(_membersProvider);

    return membersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, st) => const SizedBox.shrink(),
      data: (all) {
        final filtered = query.isEmpty
            ? all.take(8).toList()
            : all
                .where((m) => (m['name'] as String? ?? '')
                    .toLowerCase()
                    .contains(query))
                .take(8)
                .toList();

        if (filtered.isEmpty) return const SizedBox.shrink();

        return Positioned(
          width: 260,
          child: CompositedTransformFollower(
            link: link,
            showWhenUnlinked: false,
            offset: const Offset(0, -8),
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomLeft,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(10),
              color: scheme.surface,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final m = filtered[i];
                      final name = m['name'] as String? ?? '';
                      final role = m['role'] as String? ?? '';
                      final initial =
                          name.isNotEmpty ? name[0].toUpperCase() : '?';
                      return InkWell(
                        onTap: () => onSelected(m),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.15),
                                child: Text(initial,
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: scheme.onSurface)),
                                    Text(_roleLabel(role),
                                        style: AppTextStyles.caption.copyWith(
                                            color: scheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _roleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'PRAMUKH':   return 'Pramukh';
      case 'CHAIRMAN':  return 'Chairman';
      case 'SECRETARY': return 'Secretary';
      case 'MEMBER':    return 'Member';
      case 'RESIDENT':  return 'Resident';
      case 'WATCHMAN':  return 'Watchman';
      default:          return role;
    }
  }
}
