import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/show_app_sheet.dart';
import '../providers/polls_provider.dart';

class PollsScreen extends ConsumerWidget {
  const PollsScreen({super.key});

  static const _adminRoles = {'PRAMUKH', 'CHAIRMAN', 'SECRETARY'};

  bool _isAdmin(String? role) => _adminRoles.contains((role ?? '').toUpperCase());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).user?.role;
    final isAdmin = _isAdmin(role);
    final st = ref.watch(pollsProvider);
    final isWide = MediaQuery.of(context).size.width >= 768;

    final tabs = <Tab>[
      const Tab(text: 'Inbox'),
      if (isAdmin) const Tab(text: 'Created'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: isWide
            ? AppBar(
                backgroundColor: AppColors.primary,
                title: Text('Polls',
                    style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
                bottom: TabBar(
                  tabs: tabs,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.8),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => ref.read(pollsProvider.notifier).refreshAll(),
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  ),
                  if (isAdmin)
                    IconButton(
                      tooltip: 'Create poll',
                      onPressed: () => _showCreatePollSheet(context, ref),
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                    ),
                  const SizedBox(width: 8),
                ],
              )
            : AppBar(
                backgroundColor: AppColors.primary,
                title: const Text('Polls', style: TextStyle(color: Colors.white)),
                bottom: TabBar(
                  tabs: tabs,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.8),
                ),
                actions: [
                  if (isAdmin)
                    IconButton(
                      onPressed: () => _showCreatePollSheet(context, ref),
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                    ),
                ],
              ),
        body: st.isLoading
            ? const AppLoadingShimmer()
            : st.error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.screenPadding),
                      child: AppCard(
                        backgroundColor: AppColors.dangerSurface,
                        child: Text('Error: ${st.error}',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText)),
                      ),
                    ),
                  )
                : TabBarView(
                    children: [
                      _PollList(
                        polls: st.inbox,
                        emptyEmoji: '🗳️',
                        emptyTitle: 'No polls',
                        emptySubtitle: 'No polls have been assigned to you.',
                        onOpen: (id) => context.go('/polls/$id'),
                        onRefresh: () => ref.read(pollsProvider.notifier).refreshAll(),
                        showResultsPreview: true,
                        shouldShowResultsPreview: (p) {
                          final status = (p['status']?.toString() ?? '').toUpperCase();
                          final myVote = p['myVote'];
                          final voted =
                              myVote is Map && (myVote['optionId']?.toString().isNotEmpty ?? false);
                          return status == 'CLOSED' || voted;
                        },
                      ),
                      if (isAdmin)
                        _PollList(
                          polls: st.created,
                          emptyEmoji: '📊',
                          emptyTitle: 'No created polls',
                          emptySubtitle: 'Create a poll and send it to members.',
                          onOpen: (id) => context.go('/polls/$id?tab=results'),
                          onRefresh: () => ref.read(pollsProvider.notifier).refreshAll(),
                          showResultsPreview: true,
                        ),
                    ],
                  ),
      ),
    );
  }

  void _showCreatePollSheet(BuildContext context, WidgetRef ref) {
    showAppSheet(
      context: context,
      builder: (ctx) => _CreatePollSheet(
        onSubmit: (title, description, options, recipientIds, recipientRoles, closesAt) async {
          return await ref.read(pollsProvider.notifier).createPoll(
                title: title,
                description: description,
                options: options,
                recipientIds: recipientIds,
                recipientRoles: recipientRoles,
                closesAt: closesAt,
              );
        },
        loadRecipients: () => ref.read(pollsProvider.notifier).listRecipients(),
      ),
    );
  }
}

class _PollList extends StatelessWidget {
  final List<Map<String, dynamic>> polls;
  final String emptyEmoji;
  final String emptyTitle;
  final String emptySubtitle;
  final void Function(String id) onOpen;
  final Future<void> Function()? onRefresh;
  final bool showResultsPreview;
  final bool Function(Map<String, dynamic> poll)? shouldShowResultsPreview;

  const _PollList({
    required this.polls,
    required this.emptyEmoji,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onOpen,
    this.onRefresh,
    this.showResultsPreview = false,
    this.shouldShowResultsPreview,
  });

  @override
  Widget build(BuildContext context) {
    if (polls.isEmpty) {
      return AppEmptyState(emoji: emptyEmoji, title: emptyTitle, subtitle: emptySubtitle);
    }

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView.separated(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        itemCount: polls.length,
        separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.sm),
        itemBuilder: (ctx, i) {
          final p = polls[i];
          final id = p['id']?.toString() ?? '';
          final title = p['title']?.toString() ?? '-';
          final status = (p['status']?.toString() ?? '').toUpperCase();
          final createdAt = p['createdAt']?.toString() ?? '';
          final myVote = p['myVote'];
          final voted = myVote is Map && (myVote['optionId']?.toString().isNotEmpty ?? false);
          final creatorName = (p['creator'] as Map?)?['name']?.toString() ?? '';
          final totalVotes = int.tryParse(p['totalVotes']?.toString() ?? '') ?? 0;
          final totalRecipients = int.tryParse(p['totalRecipients']?.toString() ?? '') ?? 0;
          final preview = (p['resultsPreview'] as List?) ?? const [];
          final showPreviewHere =
              showResultsPreview && preview.isNotEmpty && (shouldShowResultsPreview?.call(p) ?? true);

          return AppCard(
            onTap: () => onOpen(id),
            leftBorderColor: status == 'CLOSED'
                ? AppColors.textMuted
                : voted
                    ? AppColors.success
                    : AppColors.primary,
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: AppTextStyles.h3)),
                    _StatusPill(
                      label: status == 'CLOSED'
                          ? 'Closed'
                          : voted
                              ? 'Voted'
                              : 'Open',
                      color: status == 'CLOSED'
                          ? AppColors.textMuted
                          : voted
                              ? AppColors.success
                              : AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (creatorName.isNotEmpty)
                  Text('By $creatorName',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 8),
                if (showPreviewHere) ...[
                  Row(
                    children: [
                      const Icon(Icons.bar_chart_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        '$totalVotes votes · $totalRecipients recipients',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ResultsPreview(preview: preview, totalVotes: totalVotes),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ResultsPreview extends StatelessWidget {
  final List preview;
  final int totalVotes;
  const _ResultsPreview({required this.preview, required this.totalVotes});

  @override
  Widget build(BuildContext context) {
    final items = preview
        .whereType<Map>()
        .map((m) {
          final text = m['text']?.toString() ?? '-';
          final votes = int.tryParse(m['votes']?.toString() ?? '0') ?? 0;
          return {'text': text, 'votes': votes};
        })
        .toList();

    items.sort((a, b) => (b['votes'] as int).compareTo(a['votes'] as int));
    final top = items.take(3).toList();
    final denom = totalVotes > 0 ? totalVotes : (top.isEmpty ? 1 : top.map((e) => e['votes'] as int).fold<int>(0, (a, b) => a + b)).clamp(1, 1 << 30);

    return Column(
      children: top.map((e) {
        final text = e['text'] as String;
        final votes = e['votes'] as int;
        final pct = votes / denom;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmallMuted),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 7,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppColors.borderLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 42,
                child: Text(
                  '$votes',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.bodySmallMuted.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }
}

class _CreatePollSheet extends StatefulWidget {
  final Future<String?> Function(
    String title,
    String? description,
    List<String> options,
    List<String> recipientIds,
    List<String> recipientRoles,
    DateTime? closesAt,
  ) onSubmit;

  final Future<List<Map<String, dynamic>>> Function() loadRecipients;

  const _CreatePollSheet({required this.onSubmit, required this.loadRecipients});

  @override
  State<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<_CreatePollSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _optCtrls = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];

  String _recipientMode = 'CATEGORY'; // CATEGORY | CUSTOM
  bool _loadingUsers = true;
  List<Map<String, dynamic>> _users = const [];
  final Set<String> _selectedIds = {};
  final Set<String> _selectedRoles = {'ALL'};
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadingUsers = true);
    try {
      final users = await widget.loadRecipients();
      setState(() {
        _users = users;
        _loadingUsers = false;
      });
    } catch (_) {
      setState(() => _loadingUsers = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _optCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableRoles = <String>{
      'ALL',
      ..._users
          .map((u) => (u['role']?.toString() ?? '').trim())
          .where((r) => r.isNotEmpty)
          .map((r) => r.toUpperCase()),
    }.toList()
      ..sort((a, b) {
        if (a == 'ALL') return -1;
        if (b == 'ALL') return 1;
        return a.compareTo(b);
      });

    int computedCategoryCount() {
      if (_selectedRoles.contains('ALL')) {
        return _users.length;
      }
      final roles = _selectedRoles.map((r) => r.toUpperCase()).toSet();
      return _users.where((u) => roles.contains((u['role']?.toString() ?? '').toUpperCase())).length;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.screenPadding,
        AppDimensions.lg,
        AppDimensions.screenPadding,
        MediaQuery.of(context).viewInsets.bottom + AppDimensions.xxxl,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text('Create Poll', style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.lg),
            _label('Title'),
            const SizedBox(height: 6),
            _field(_titleCtrl, 'Poll question'),
            const SizedBox(height: AppDimensions.md),
            _label('Description (optional)'),
            const SizedBox(height: 6),
            _field(_descCtrl, 'Short context...', maxLines: 2),
            const SizedBox(height: AppDimensions.md),
            _label('Options'),
            const SizedBox(height: 6),
            ..._optCtrls.asMap().entries.map((e) {
              final i = e.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(child: _field(e.value, 'Option ${i + 1}')),
                    if (_optCtrls.length > 2)
                      IconButton(
                        onPressed: () => setState(() => _optCtrls.removeAt(i).dispose()),
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger),
                      ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: _optCtrls.length >= 10
                  ? null
                  : () => setState(() => _optCtrls.add(TextEditingController())),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add option'),
            ),
            const SizedBox(height: AppDimensions.md),
            _label('Send to'),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Category'),
                        selected: _recipientMode == 'CATEGORY',
                        onSelected: (_) => setState(() {
                          _recipientMode = 'CATEGORY';
                          _error = null;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('Custom'),
                        selected: _recipientMode == 'CUSTOM',
                        onSelected: (_) => setState(() {
                          _recipientMode = 'CUSTOM';
                          _error = null;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_recipientMode == 'CATEGORY') ...[
                    Text(
                      _loadingUsers
                          ? 'Loading categories...'
                          : 'Select categories (multiple) • Receivers: ${computedCategoryCount()}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    if (_loadingUsers)
                      const LinearProgressIndicator()
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableRoles.map((r) {
                          final selected = _selectedRoles.contains(r);
                          final label = r == 'ALL' ? 'All' : r;
                          return FilterChip(
                            label: Text(label),
                            selected: selected,
                            onSelected: (v) {
                              setState(() {
                                if (r == 'ALL') {
                                  _selectedRoles
                                    ..clear()
                                    ..add('ALL');
                                } else {
                                  _selectedRoles.remove('ALL');
                                  if (v == true) {
                                    _selectedRoles.add(r);
                                  } else {
                                    _selectedRoles.remove(r);
                                  }
                                  if (_selectedRoles.isEmpty) {
                                    _selectedRoles.add('ALL');
                                  }
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                  ] else ...[
                    Text(
                      'Select members (multiple)',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    if (_loadingUsers)
                      const LinearProgressIndicator()
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _users.length,
                            itemBuilder: (ctx, i) {
                              final u = _users[i];
                              final id = u['id']?.toString() ?? '';
                              final name = u['name']?.toString() ?? '-';
                              final role = u['role']?.toString() ?? '';
                              final checked = _selectedIds.contains(id);
                              return CheckboxListTile(
                                value: checked,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedIds.add(id);
                                    } else {
                                      _selectedIds.remove(id);
                                    }
                                  });
                                },
                                dense: true,
                                title: Text(name, style: AppTextStyles.bodyMedium),
                                subtitle: role.isEmpty ? null : Text(role, style: AppTextStyles.caption),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimensions.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.sm),
                decoration: BoxDecoration(
                  color: AppColors.dangerSurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText)),
              ),
            ],
            const SizedBox(height: AppDimensions.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create & Send'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String s) =>
      Text(s, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary));

  Widget _field(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final options = _optCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    final recipients = _recipientMode == 'CUSTOM' ? _selectedIds.toList() : <String>[];
    final recipientRoles =
        _recipientMode == 'CATEGORY' ? _selectedRoles.map((r) => r.toUpperCase()).toList() : <String>[];

    if (title.length < 3) {
      setState(() => _error = 'Title is required (min 3 chars).');
      return;
    }
    if (options.length < 2) {
      setState(() => _error = 'Provide at least 2 options.');
      return;
    }
    if (_recipientMode == 'CUSTOM' && recipients.isEmpty) {
      setState(() => _error = 'Select at least 1 receiver.');
      return;
    }
    if (_recipientMode == 'CATEGORY' && recipientRoles.isEmpty) {
      setState(() => _error = 'Select at least 1 category.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final err = await widget.onSubmit(
      title,
      _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      options,
      recipients,
      recipientRoles,
      null,
    );

    if (!mounted) return;
    if (err == null) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Poll created.'), backgroundColor: AppColors.success),
      );
    } else {
      setState(() {
        _submitting = false;
        _error = err;
      });
    }
  }
}

