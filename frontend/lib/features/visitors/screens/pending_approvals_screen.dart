import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../providers/visitors_provider.dart';

class PendingApprovalsScreen extends ConsumerWidget {
  const PendingApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvalsAsync = ref.watch(pendingWalkinApprovalsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Gate Approvals', style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textOnPrimary),
            onPressed: () => ref.read(pendingWalkinApprovalsProvider.notifier).fetch(),
          ),
        ],
      ),
      body: approvalsAsync.when(
        loading: () => const AppLoadingShimmer(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            child: AppCard(
              backgroundColor: AppColors.dangerSurface,
              child: Text('Error: $e', style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText)),
            ),
          ),
        ),
        data: (visitors) {
          if (visitors.isEmpty) {
            return const AppEmptyState(
              emoji: '✅',
              title: 'No Pending Approvals',
              subtitle: 'Walk-in visitors awaiting your approval will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(pendingWalkinApprovalsProvider.notifier).fetch(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppDimensions.screenPadding),
              itemCount: visitors.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.md),
              itemBuilder: (_, i) {
                final v = Map<String, dynamic>.from(visitors[i] as Map);
                return _ApprovalCard(visitor: v);
              },
            ),
          );
        },
      ),
    );
  }
}

class _ApprovalCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> visitor;
  const _ApprovalCard({required this.visitor});

  @override
  ConsumerState<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends ConsumerState<_ApprovalCard> {
  bool _loading = false;
  String? _error;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    final raw = widget.visitor['createdAt'] as String?;
    if (raw != null) {
      final created = DateTime.tryParse(raw)?.toLocal();
      if (created != null) {
        _elapsed = DateTime.now().difference(created);
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
        });
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _elapsedLabel {
    final m = _elapsed.inMinutes;
    final s = _elapsed.inSeconds % 60;
    return m > 0 ? '${m}m ${s}s waiting' : '${s}s waiting';
  }

  // Retry every 3 min, auto-deny after 3 retries = 9 min max
  String get _urgencyLabel {
    final retryCount = (widget.visitor['retryCount'] as int?) ?? 0;
    final remaining = 3 - retryCount;
    if (remaining <= 0) return 'Auto-deny imminent!';
    final nextRetryMin = 3 - (_elapsed.inSeconds % 180) ~/ 60;
    return '$remaining reminder(s) left · next in ~${nextRetryMin}m';
  }

  Color get _urgencyColor {
    final retryCount = (widget.visitor['retryCount'] as int?) ?? 0;
    if (retryCount >= 2) return AppColors.danger;
    if (retryCount >= 1) return AppColors.warning;
    return AppColors.textMuted;
  }

  Future<void> _respond(String action) async {
    setState(() { _loading = true; _error = null; });
    final id = widget.visitor['id'] as String;
    final error = await ref.read(pendingWalkinApprovalsProvider.notifier).approve(id, action);
    if (mounted) {
      if (error != null) {
        setState(() { _loading = false; _error = error; });
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'APPROVED' ? 'Visitor allowed entry.' : 'Visitor denied entry.'),
          backgroundColor: action == 'APPROVED' ? AppColors.success : AppColors.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v         = widget.visitor;
    final name      = v['visitorName'] as String? ?? '-';
    final phone     = v['visitorPhone'] as String? ?? '';
    final unitCode  = v['unit'] is Map ? (v['unit'] as Map)['fullCode'] ?? '-' : '-';
    final adults    = v['numberOfAdults'] ?? 1;
    final note      = v['noteForWatchman'] as String?;
    final photoUrl  = v['entryPhotoUrl'] as String?;
    final baseUrl   = AppConstants.uploadsBaseUrl;

    return AppCard(
      leftBorderColor: AppColors.warning,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Photo + header ───────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Visitor photo or avatar
              if (photoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  child: Image.network(
                    '$baseUrl$photoUrl',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _avatarPlaceholder(name),
                  ),
                )
              else
                _avatarPlaceholder(name),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.warningSurface,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: AppColors.warningText),
                          const SizedBox(width: 4),
                          Text('Awaiting approval', style: AppTextStyles.caption.copyWith(color: AppColors.warningText)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: AppDimensions.xs),
                    Text(name, style: AppTextStyles.h3),
                    const SizedBox(height: 2),
                    Text(phone, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.apartment_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('Unit $unitCode', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                      const SizedBox(width: AppDimensions.md),
                      const Icon(Icons.people_outline_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('$adults adult${adults > 1 ? 's' : ''}',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.timer_outlined, size: 12, color: _urgencyColor),
                      const SizedBox(width: 4),
                      Flexible(child: Text(_elapsedLabel,
                          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted))),
                      const SizedBox(width: AppDimensions.sm),
                      Flexible(child: Text(_urgencyLabel,
                          style: AppTextStyles.caption.copyWith(color: _urgencyColor))),
                    ]),
                  ],
                ),
              ),
            ],
          ),

          // ── Note ─────────────────────────────────────────────────────
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.sm),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                const Icon(Icons.notes_rounded, size: 14, color: AppColors.textMuted),
                const SizedBox(width: AppDimensions.sm),
                Expanded(child: Text(note,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))),
              ]),
            ),
          ],

          // ── Error ─────────────────────────────────────────────────────
          if (_error != null) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.dangerText)),
          ],

          const SizedBox(height: AppDimensions.md),

          // ── Allow / Deny buttons ──────────────────────────────────────
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _respond('APPROVED'),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Allow Entry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                    padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _respond('DENIED'),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Deny'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                    padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                  ),
                ),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder(String name) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: AppTextStyles.h1.copyWith(color: AppColors.primary),
      ),
    );
  }
}
