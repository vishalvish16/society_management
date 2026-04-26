import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../providers/polls_provider.dart';

class PollDetailScreen extends ConsumerStatefulWidget {
  final String pollId;
  final bool openResults;
  const PollDetailScreen({super.key, required this.pollId, this.openResults = false});

  @override
  ConsumerState<PollDetailScreen> createState() => _PollDetailScreenState();
}

class _PollDetailScreenState extends ConsumerState<PollDetailScreen> {
  Map<String, dynamic>? _poll;
  bool _loading = true;
  String? _error;
  int _selectedTab = 0;

  bool get _isAdmin {
    final r = ref.read(authProvider).user?.role.toUpperCase() ?? '';
    return r == 'PRAMUKH' || r == 'CHAIRMAN' || r == 'SECRETARY';
  }

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.openResults ? 1 : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await ref.read(pollsProvider.notifier).getPoll(widget.pollId);
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _loading = false;
        _error = 'Failed to load poll';
      });
      return;
    }
    setState(() {
      _poll = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    final p = _poll;
    final title = p?['title']?.toString() ?? 'Poll';
    final status = (p?['status']?.toString() ?? '').toUpperCase();
    final isClosed = status == 'CLOSED';
    final myVote = p?['myVote'];
    final voted = myVote is Map && (myVote['optionId']?.toString().isNotEmpty ?? false);

    void goBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/polls');
      }
    }

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            goBack();
            return null;
          }),
        },
        child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: isWide
          ? AppBar(
              backgroundColor: AppColors.primary,
              leading: IconButton(
                tooltip: 'Back',
                onPressed: goBack,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              title: Text(title, style: AppTextStyles.h2.copyWith(color: Colors.white)),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
                if (_isAdmin && p != null && !isClosed)
                  IconButton(
                    tooltip: 'Close poll',
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final err = await ref.read(pollsProvider.notifier).closePoll(widget.pollId);
                      if (!mounted) return;
                      if (err == null) {
                        await _load();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Poll closed.'), backgroundColor: AppColors.success),
                        );
                      } else {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text(err), backgroundColor: AppColors.danger),
                        );
                      }
                    },
                    icon: const Icon(Icons.lock_rounded, color: Colors.white),
                  ),
                const SizedBox(width: 8),
              ],
            )
          : AppBar(
              backgroundColor: AppColors.primary,
              title: Text(title, style: const TextStyle(color: Colors.white)),
            ),
      body: _loading
          ? const AppLoadingShimmer()
          : _error != null
              ? Center(child: Text(_error!))
              : p == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        if (_isAdmin)
                          Container(
                            color: AppColors.surface,
                            child: Row(
                              children: [
                                _TabButton(
                                  label: 'Vote',
                                  selected: _selectedTab == 0,
                                  onTap: () => setState(() => _selectedTab = 0),
                                ),
                                _TabButton(
                                  label: 'Results',
                                  selected: _selectedTab == 1,
                                  onTap: () => setState(() => _selectedTab = 1),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(AppDimensions.screenPadding),
                            child: _isAdmin && _selectedTab == 1
                                ? _ResultsPanel(pollId: widget.pollId)
                                : _VotePanel(
                                    poll: p,
                                    voted: voted,
                                    isClosed: isClosed,
                                    onVote: (optionId) async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      final err = await ref
                                          .read(pollsProvider.notifier)
                                          .vote(pollId: widget.pollId, optionId: optionId);
                                      if (!mounted) return;
                                      if (err == null) {
                                        await _load();
                                        if (!mounted) return;
                                        messenger.showSnackBar(
                                          const SnackBar(
                                              content: Text('Vote submitted.'), backgroundColor: AppColors.success),
                                        );
                                      } else {
                                        if (!mounted) return;
                                        messenger.showSnackBar(
                                          SnackBar(content: Text(err), backgroundColor: AppColors.danger),
                                        );
                                      }
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: 2),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VotePanel extends StatelessWidget {
  final Map<String, dynamic> poll;
  final bool voted;
  final bool isClosed;
  final Future<void> Function(String optionId) onVote;

  const _VotePanel({
    required this.poll,
    required this.voted,
    required this.isClosed,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final title = poll['title']?.toString() ?? '-';
    final description = poll['description']?.toString();
    final options = (poll['options'] as List?) ?? const [];
    final myVote = poll['myVote'];
    final votedOptionId = (myVote is Map) ? myVote['optionId']?.toString() : null;

    return ListView(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.h2),
              if (description != null && description.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(description, style: AppTextStyles.bodySmallMuted),
              ],
              const SizedBox(height: AppDimensions.md),
              if (isClosed)
                _Pill(text: 'Closed', color: AppColors.textMuted)
              else if (voted)
                _Pill(text: 'You voted', color: AppColors.success)
              else
                _Pill(text: 'Open', color: AppColors.primary),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        ...options.map((o) {
          final id = (o as Map)['id']?.toString() ?? '';
          final text = o['text']?.toString() ?? '-';
          final selected = votedOptionId == id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: (isClosed || voted) ? null : () => onVote(id),
              leftBorderColor: selected ? AppColors.success : AppColors.border,
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: selected ? AppColors.success : AppColors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
                  if (!isClosed && !voted)
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                ],
              ),
            ),
          );
        }),
        if (!isClosed && !voted)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Tap an option to vote.', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
          ),
        if (voted)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('You can vote only once.', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
          ),
      ],
    );
  }
}

class _ResultsPanel extends ConsumerWidget {
  final String pollId;
  const _ResultsPanel({required this.pollId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: ref.read(pollsProvider.notifier).getResults(pollId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const AppLoadingShimmer(itemCount: 4, itemHeight: 80);
        }
        final data = snap.data;
        if (data == null) {
          return const Center(child: Text('Failed to load results'));
        }
        if (data['_error'] != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.screenPadding),
              child: AppCard(
                backgroundColor: AppColors.dangerSurface,
                child: Text(
                  data['_error']?.toString() ?? 'Failed to load results',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText),
                ),
              ),
            ),
          );
        }

        final poll = data['poll'] as Map?;
        final options = (data['options'] as List?) ?? const [];
        final totalVotes = data['totalVotes'] ?? 0;
        final totalRecipients = data['totalRecipients'] ?? 0;

        return ListView(
          children: [
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(poll?['title']?.toString() ?? 'Results', style: AppTextStyles.h2),
                        const SizedBox(height: 4),
                        Text('$totalVotes votes · $totalRecipients recipients',
                            style: AppTextStyles.bodySmallMuted),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/polls'),
                    child: const Text('All polls'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            ...options.map((o) {
              final m = o as Map;
              final text = m['text']?.toString() ?? '-';
              final votes = int.tryParse(m['votes']?.toString() ?? '0') ?? 0;
              final pct = totalVotes > 0 ? (votes / totalVotes) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
                          Text('$votes', style: AppTextStyles.h3),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: AppColors.borderLight,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('${(pct * 100).toStringAsFixed(0)}%',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }
}

