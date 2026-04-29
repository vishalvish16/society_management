import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../providers/visitors_provider.dart';
import '../providers/visitor_config_provider.dart';
import '../../../shared/widgets/unit_picker_field.dart';
import 'visitor_qr_pass_screen.dart';
import '../../../shared/widgets/app_page_header.dart';


class VisitorsScreen extends ConsumerStatefulWidget {
  const VisitorsScreen({super.key});

  @override
  ConsumerState<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends ConsumerState<VisitorsScreen> {
  String _scope = 'all'; // all | approvals (unit member approvals)
  String _filter = 'all';
  String _approvalFilter = 'awaiting'; // awaiting | approved | denied | all (watchman gate list)

  Color _borderColor(String status) {
    switch (status) {
      case 'valid':
      case 'pending':
        return AppColors.warning;
      case 'approved':
      case 'used':
        return AppColors.success;
      case 'expired':
      case 'denied':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  /// DB status plus QR time window (`qrExpiresAt`) so expired invites show as **expired** in the list.
  String _effectiveVisitorStatus(Map<String, dynamic> v) {
    // Walk-in approval flow: never show these as "expired" while awaiting approval.
    final approvalStatus = (v['approvalStatus'] as String?)?.toLowerCase();
    if (approvalStatus == 'awaiting') return 'pending';
    if (approvalStatus == 'approved') return 'approved';
    if (approvalStatus == 'denied') return 'denied';

    final status = (v['status'] as String? ?? 'pending').toLowerCase();
    if (status == 'used' || status == 'expired' || status == 'denied') {
      return status;
    }
    final raw = v['qrExpiresAt'];
    if (raw != null) {
      try {
        if (DateTime.parse(raw as String).isBefore(DateTime.now())) {
          return 'expired';
        }
      } catch (_) {}
    }
    if (status == 'valid' || status == 'pending') return 'pending';
    return status;
  }

  @override
  Widget build(BuildContext context) {
    final visitorsAsync = ref.watch(visitorsProvider);
    final role = (ref.watch(authProvider).user?.role ?? '').toUpperCase();
    final isWatchman = role == 'WATCHMAN';
    final isReceiver = !isWatchman; // unit members/residents who receive approval request

    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? AppBar(
              backgroundColor: AppColors.primary,
              title: Text('Visitors', style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
              actions: [
                if (isWatchman) ...[
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.textOnPrimary),
                    onPressed: () => _showScanSheet(context),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                ],
              ],
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.textOnPrimary),
        label: Text('Log Visitor', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary)),
      ),
      body: Column(
        children: [
          AppPageHeader(
            title: 'Visitors',
            icon: Icons.person_pin_circle_rounded,
            actions: [
              if (isWatchman)
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  tooltip: 'Scan QR',
                  onPressed: () => _showScanSheet(context),
                ),
            ],
          ),
          // ── Resident/Member: Permanent "Gate Approvals" tab (received requests) ──
          if (isReceiver)
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.screenPadding,
                AppDimensions.sm,
                AppDimensions.screenPadding,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ScopeTab(
                      label: 'Gate Approvals',
                      icon: Icons.verified_user_rounded,
                      selected: _scope == 'approvals',
                      onTap: () => setState(() => _scope = 'approvals'),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: _ScopeTab(
                      label: 'All Visitors',
                      icon: Icons.people_alt_rounded,
                      selected: _scope == 'all',
                      onTap: () => setState(() => _scope = 'all'),
                    ),
                  ),
                ],
              ),
            ),

          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.screenPadding, vertical: AppDimensions.sm),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (!isReceiver || _scope == 'all')
                    for (final s in ['all', 'pending', 'used', 'expired'])
                      Padding(
                        padding: const EdgeInsets.only(right: AppDimensions.sm),
                        child: ChoiceChip(
                          label: Text(s == 'all' ? 'All' : s == 'pending' ? 'Upcoming' : s[0].toUpperCase() + s.substring(1)),
                          selected: _filter == s,
                          selectedColor: AppColors.primarySurface,
                          labelStyle: AppTextStyles.labelMedium.copyWith(
                            color: _filter == s ? AppColors.primary : AppColors.textMuted,
                          ),
                          onSelected: (_) => setState(() => _filter = s),
                        ),
                      ),

                  if (isWatchman && _scope == 'approvals')
                    for (final s in ['awaiting', 'approved', 'denied', 'all'])
                      Padding(
                        padding: const EdgeInsets.only(right: AppDimensions.sm),
                        child: ChoiceChip(
                          label: Text(
                            s == 'awaiting'
                                ? 'Awaiting'
                                : s == 'approved'
                                    ? 'Approved'
                                    : s == 'denied'
                                        ? 'Denied'
                                        : 'All',
                          ),
                          selected: _approvalFilter == s,
                          selectedColor: AppColors.primarySurface,
                          labelStyle: AppTextStyles.labelMedium.copyWith(
                            color: _approvalFilter == s ? AppColors.primary : AppColors.textMuted,
                          ),
                          onSelected: (_) => setState(() => _approvalFilter = s),
                        ),
                      ),
                ],
              ),
            ),
          ),
          Expanded(
            child: (isReceiver && _scope == 'approvals')
                ? _ReceivedApprovalsList(
                    onOpenDetails: (v) => _showVisitorDetails(context, v),
                  )
                : visitorsAsync.when(
              loading: () => const AppLoadingShimmer(),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.screenPadding),
                  child: AppCard(
                    backgroundColor: AppColors.dangerSurface,
                    child: Text('Error: $e',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText)),
                  ),
                ),
              ),
              data: (visitors) {
                final base = visitors.map((e) => Map<String, dynamic>.from(e as Map)).toList();

                List<Map<String, dynamic>> filtered;
                if (isWatchman && _scope == 'approvals') {
                  filtered = base
                      .where((v) => (v['entryPhotoUrl'] as String?) != null && v['approvalStatus'] != null)
                      .toList();
                  if (_approvalFilter != 'all') {
                    filtered = filtered.where((v) {
                      final a = (v['approvalStatus'] as String? ?? '').toLowerCase();
                      return a == _approvalFilter;
                    }).toList();
                  }
                } else {
                  filtered = _filter == 'all'
                      ? base
                      : base.where((v) => _effectiveVisitorStatus(v) == _filter).toList();
                }

                if (filtered.isEmpty) {
                  return AppEmptyState(
                    emoji: '🚪',
                    title: 'No Visitors',
                    subtitle: 'No visitors match the selected filter.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(visitorsProvider.notifier).fetchVisitors(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppDimensions.screenPadding),
                    itemCount: filtered.length,
                    separatorBuilder: (_, index) => const SizedBox(height: AppDimensions.sm),
                    itemBuilder: (_, i) {
                      final v = filtered[i];
                      final status = _effectiveVisitorStatus(v);
                      final unitCode = v['unit'] is Map ? v['unit']['fullCode'] : (v['unit'] ?? '-');
                      final isPending = status == 'pending';
                      final qrToken = v['qrToken'] as String?;
                      final currentUser = ref.read(authProvider).user;
                      final currentUserId = currentUser?.id ?? '';
                      final currentRole = currentUser?.role.toUpperCase() ?? '';
                      final inviterId = v['invitedById'] as String? ?? (v['inviter'] is Map ? v['inviter']['id'] : null);
                      final inviterName = v['inviter'] is Map ? (v['inviter']['name'] as String?) : null;
                      final isAdmin = ['PRAMUKH', 'CHAIRMAN', 'SECRETARY'].contains(currentRole);
                      final canEdit = isPending && (isAdmin || inviterId == currentUserId);

                      final isGateApprovalCard = isWatchman && _scope == 'approvals';
                      final approvalStatus = (v['approvalStatus'] as String?)?.toLowerCase();
                      final approvalChip = isGateApprovalCard
                          ? _ApprovalChip(status: approvalStatus ?? '')
                          : AppStatusChip(status: status);

                      return InkWell(
                        onTap: () => _showVisitorDetails(context, v),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        child: AppCard(
                          leftBorderColor: isGateApprovalCard
                              ? (approvalStatus == 'approved'
                                  ? AppColors.success
                                  : approvalStatus == 'denied'
                                      ? AppColors.danger
                                      : AppColors.warning)
                              : _borderColor(status),
                          padding: const EdgeInsets.all(AppDimensions.md),
                          child: Row(
                            children: [
                              _LeadingAvatarOrPhoto(visitor: v),
                              const SizedBox(width: AppDimensions.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(v['visitorName'] as String? ?? '-', style: AppTextStyles.h3),
                                    const SizedBox(height: AppDimensions.xs),
                                    Text(
                                      'Unit $unitCode'
                                      '${v['numberOfAdults'] != null && v['numberOfAdults'] > 1 ? ' • ${v['numberOfAdults']} Adults' : ''}'
                                      '${v['description'] != null ? ' • ${v['description']}' : ''}',
                                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                                    ),
                                    if (inviterName != null && !isGateApprovalCard)
                                      Text(
                                        'Invited by $inviterName',
                                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                                      ),
                                    if (v['noteForWatchman'] != null)
                                      Text(
                                        v['noteForWatchman'],
                                        style: AppTextStyles.caption
                                            .copyWith(color: AppColors.textMuted, fontStyle: FontStyle.italic),
                                      ),
                                  ],
                                ),
                              ),
                              // ── QR button (pending with a token) ────────
                              if (!isGateApprovalCard && isPending && qrToken != null) ...[
                                _actionIcon(
                                  icon: Icons.qr_code_rounded,
                                  color: AppColors.primary,
                                  bgColor: AppColors.primarySurface,
                                  tooltip: 'View / Download QR Pass',
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => VisitorQrPassScreen(visitor: v),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.sm),
                              ],
                              // ── Edit button (pending + owner or admin) ──
                              if (!isGateApprovalCard && canEdit) ...[
                                _actionIcon(
                                  icon: Icons.edit_rounded,
                                  color: AppColors.warning,
                                  bgColor: AppColors.warningSurface,
                                  tooltip: 'Edit visitor',
                                  onTap: () => _showEditVisitorSheet(context, v),
                                ),
                                const SizedBox(width: AppDimensions.sm),
                              ],
                              approvalChip,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showVisitorDetails(BuildContext context, Map<String, dynamic> v) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => _VisitorDetailsSheet(visitor: v),
    );
  }

  void _showScanSheet(BuildContext context) {
    final role = (ref.read(authProvider).user?.role ?? '').toUpperCase();
    final isWatchman = role == 'WATCHMAN';
    if (!isWatchman) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR scan is available for watchman only.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => const _ScanSheet(),
    );
  }

  void _showLogDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => const _LogVisitorForm(),
    );
  }

  void _showEditVisitorSheet(BuildContext context, Map<String, dynamic> visitor) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => _EditVisitorForm(visitor: visitor),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ScopeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? AppColors.textOnPrimary : AppColors.textMuted),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: selected ? AppColors.textOnPrimary : AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceivedApprovalsList extends ConsumerWidget {
  final void Function(Map<String, dynamic> visitor) onOpenDetails;
  const _ReceivedApprovalsList({required this.onOpenDetails});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvalsAsync = ref.watch(pendingWalkinApprovalsProvider);
    return approvalsAsync.when(
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
      data: (list) {
        final visitors = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (visitors.isEmpty) {
          return const AppEmptyState(
            emoji: '✅',
            title: 'No Gate Approvals',
            subtitle: 'Visitors awaiting your approval will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(pendingWalkinApprovalsProvider.notifier).fetch(),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            itemCount: visitors.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.sm),
            itemBuilder: (_, i) => _ReceivedApprovalCard(
              visitor: visitors[i],
              onOpenDetails: onOpenDetails,
            ),
          ),
        );
      },
    );
  }
}

class _ReceivedApprovalCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> visitor;
  final void Function(Map<String, dynamic> visitor) onOpenDetails;
  const _ReceivedApprovalCard({required this.visitor, required this.onOpenDetails});

  @override
  ConsumerState<_ReceivedApprovalCard> createState() => _ReceivedApprovalCardState();
}

class _ReceivedApprovalCardState extends ConsumerState<_ReceivedApprovalCard> {
  bool _loading = false;
  String? _error;

  Future<void> _respond(String action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final id = widget.visitor['id'] as String;
    final error = await ref.read(pendingWalkinApprovalsProvider.notifier).approve(id, action);
    if (mounted) {
      if (error != null) {
        setState(() {
          _loading = false;
          _error = error;
        });
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
    final v = widget.visitor;
    final name = v['visitorName'] as String? ?? '-';
    final phone = v['visitorPhone'] as String? ?? '';
    final unitCode = v['unit'] is Map ? (v['unit'] as Map)['fullCode']?.toString() ?? '-' : '-';
    final photoUrl = AppConstants.uploadUrlFromPath(v['entryPhotoUrl'] as String?);

    return InkWell(
      onTap: () => widget.onOpenDetails(v),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: AppCard(
        leftBorderColor: AppColors.warning,
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (photoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    child: Image.network(
                      photoUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.person_rounded, color: AppColors.primary),
                    ),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.person_rounded, color: AppColors.primary),
                  ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.h3),
                      const SizedBox(height: 2),
                      Text(phone, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                      const SizedBox(height: 2),
                      Text('Unit $unitCode', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const _ApprovalChip(status: 'awaiting'),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimensions.sm),
              Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.dangerText)),
            ],
            const SizedBox(height: AppDimensions.sm),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _respond('APPROVED'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Allow'),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _respond('DENIED'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Deny'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _LeadingAvatarOrPhoto extends StatelessWidget {
  final Map<String, dynamic> visitor;
  const _LeadingAvatarOrPhoto({required this.visitor});

  @override
  Widget build(BuildContext context) {
    final name = (visitor['visitorName'] as String?) ?? '-';
    final photoUrl = AppConstants.uploadUrlFromPath(visitor['entryPhotoUrl'] as String?);
    if (photoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Image.network(
          photoUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _avatar(name),
        ),
      );
    }
    return _avatar(name);
  }

  Widget _avatar(String name) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
        ),
      );
}

class _ApprovalChip extends StatelessWidget {
  final String status; // awaiting | approved | denied
  const _ApprovalChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final label = s == 'approved'
        ? 'APPROVED'
        : s == 'denied'
            ? 'DENIED'
            : 'AWAITING';
    final bg = s == 'approved'
        ? AppColors.successSurface
        : s == 'denied'
            ? AppColors.dangerSurface
            : AppColors.warningSurface;
    final fg = s == 'approved'
        ? AppColors.successText
        : s == 'denied'
            ? AppColors.dangerText
            : AppColors.warningText;
    final border = s == 'approved'
        ? AppColors.success
        : s == 'denied'
            ? AppColors.danger
            : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: fg, fontWeight: FontWeight.w800, letterSpacing: 0.3),
      ),
    );
  }
}

class _VisitorDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> visitor;
  const _VisitorDetailsSheet({required this.visitor});

  String _fmtTs(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('d MMM yyyy, h:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (visitor['visitorName'] as String?) ?? '-';
    final phone = (visitor['visitorPhone'] as String?) ?? '';
    final unitCode = visitor['unit'] is Map ? (visitor['unit'] as Map)['fullCode']?.toString() ?? '-' : '-';
    final adults = (visitor['numberOfAdults'] as num?)?.toInt() ?? 1;
    final note = visitor['noteForWatchman'] as String?;
    final desc = visitor['description'] as String?;
    final approval = (visitor['approvalStatus'] as String?)?.toLowerCase();
    final createdAt = _fmtTs(visitor['createdAt'] as String?);
    final approvedAt = _fmtTs(visitor['approvedAt'] as String?);

    final photoUrl = AppConstants.uploadUrlFromPath(visitor['entryPhotoUrl'] as String?);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.screenPadding,
        AppDimensions.lg,
        AppDimensions.screenPadding,
        MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
            Text('Visitor Details', style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.md),

            if (photoUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                child: Image.network(
                  photoUrl,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 220,
                    color: AppColors.background,
                    alignment: Alignment.center,
                    child: Icon(Icons.image_not_supported_rounded, color: AppColors.textMuted.withValues(alpha: 0.7)),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.md),
            ],

            AppCard(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name, style: AppTextStyles.h2)),
                      if (approval != null) _ApprovalChip(status: approval),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _detailRow(Icons.phone_rounded, 'Phone', phone.isNotEmpty ? phone : '-'),
                  _detailRow(Icons.apartment_rounded, 'Unit', unitCode),
                  _detailRow(Icons.people_outline_rounded, 'Adults', adults.toString()),
                  if (desc != null && desc.trim().isNotEmpty)
                    _detailRow(Icons.directions_car_rounded, 'Vehicle / Desc', desc.trim()),
                  if (note != null && note.trim().isNotEmpty)
                    _detailRow(Icons.notes_rounded, 'Note', note.trim()),
                  if (createdAt.isNotEmpty) _detailRow(Icons.schedule_rounded, 'Logged at', createdAt),
                  if (approvedAt.isNotEmpty) _detailRow(Icons.verified_rounded, 'Responded at', approvedAt),
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.lg),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── QR Scan Sheet ────────────────────────────────────────────────────────────

class _ScanSheet extends ConsumerStatefulWidget {
  const _ScanSheet();

  @override
  ConsumerState<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends ConsumerState<_ScanSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  // null = idle, 'valid' | 'used' | 'expired' | 'invalid' = result
  String? _result;
  String? _visitorName;
  String? _unitCode;
  String? _scannedAt;
  String? _scannedBy;
  String? _errorMsg;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    final token = _ctrl.text.trim();
    if (token.isEmpty) return;
    setState(() { _loading = true; _result = null; _errorMsg = null; });

    try {
      final resp = await DioClient().dio.post('/visitors/validate', data: {'qrToken': token});
      final data = resp.data['data'] as Map<String, dynamic>? ?? {};
      setState(() {
        _loading = false;
        _result = 'valid';
        _visitorName = data['name'] as String? ?? '-';
        _unitCode    = data['unit'] as String? ?? '-';
      });
      ref.read(visitorsProvider.notifier).fetchVisitors();
    } on Exception catch (e) {
      String result = 'invalid';
      String? scannedAt, scannedBy, msg;

      try {
        final dioException = e as dynamic;
        final respData = dioException.response?.data as Map<String, dynamic>?;
        result    = (respData?['data']?['result'] as String? ?? 'invalid').toLowerCase();
        scannedAt = respData?['data']?['scannedAt'] as String?;
        scannedBy = respData?['data']?['scannedBy'] as String?;
        msg       = respData?['message'] as String?;
      } catch (_) {
        msg = e.toString();
      }

      setState(() {
        _loading   = false;
        _result    = result.toLowerCase();
        _scannedAt = scannedAt;
        _scannedBy = scannedBy;
        _errorMsg  = msg;
      });
    }
  }

  String _fmtTs(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('d MMM yyyy, h:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.screenPadding, AppDimensions.lg,
        AppDimensions.screenPadding,
        MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: AppDimensions.lg),
          Text('Scan Visitor QR', style: AppTextStyles.h1),
          const SizedBox(height: AppDimensions.sm),
          Text('Enter or paste the visitor QR token to validate entry.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppDimensions.lg),

          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  labelText: 'QR Token *',
                  prefixIcon: Icon(Icons.qr_code_rounded),
                  hintText: 'Paste or type token here',
                ),
                onFieldSubmitted: (_) => _validate(),
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _validate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Verify'),
              ),
            ),
          ]),

          if (_result != null) ...[
            const SizedBox(height: AppDimensions.lg),
            _ResultCard(
              result: _result!,
              visitorName: _visitorName,
              unitCode: _unitCode,
              scannedAt: _fmtTs(_scannedAt),
              scannedBy: _scannedBy,
              errorMsg: _errorMsg,
            ),
          ],

          const SizedBox(height: AppDimensions.md),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String result;
  final String? visitorName;
  final String? unitCode;
  final String? scannedAt;
  final String? scannedBy;
  final String? errorMsg;

  const _ResultCard({
    required this.result,
    this.visitorName,
    this.unitCode,
    this.scannedAt,
    this.scannedBy,
    this.errorMsg,
  });

  @override
  Widget build(BuildContext context) {
    switch (result) {
      case 'valid':
        return _card(
          color: AppColors.successSurface,
          borderColor: AppColors.success,
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.success,
          title: 'Access Granted',
          titleColor: AppColors.successText,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('Visitor', visitorName ?? '-'),
              _row('Unit', unitCode ?? '-'),
            ],
          ),
        );
      case 'used':
        return _card(
          color: AppColors.dangerSurface,
          borderColor: AppColors.danger,
          icon: Icons.cancel_rounded,
          iconColor: AppColors.danger,
          title: 'Already Scanned',
          titleColor: AppColors.dangerText,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This pass has already been used and is no longer valid.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText)),
              if (scannedAt != null && scannedAt!.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.sm),
                _row('Scanned at', scannedAt!),
                if (scannedBy != null && scannedBy!.isNotEmpty)
                  _row('Scanned by', scannedBy!),
              ],
            ],
          ),
        );
      case 'expired':
        return _card(
          color: AppColors.warningSurface,
          borderColor: AppColors.warning,
          icon: Icons.timer_off_rounded,
          iconColor: AppColors.warning,
          title: 'Pass Expired',
          titleColor: AppColors.warningText,
          body: Text('This visitor pass has expired and is no longer valid.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.warningText)),
        );
      default:
        return _card(
          color: AppColors.dangerSurface,
          borderColor: AppColors.danger,
          icon: Icons.error_rounded,
          iconColor: AppColors.danger,
          title: 'Invalid Token',
          titleColor: AppColors.dangerText,
          body: Text(errorMsg ?? 'The token was not found or is invalid.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText)),
        );
    }
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Text('$label: ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
        Expanded(child: Text(value, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600))),
      ],
    ),
  );

  Widget _card({
    required Color color,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color titleColor,
    required Widget body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: AppDimensions.sm),
            Text(title, style: AppTextStyles.h3.copyWith(color: titleColor)),
          ]),
          const SizedBox(height: AppDimensions.sm),
          body,
        ],
      ),
    );
  }
}

// ─── Edit Visitor Form ────────────────────────────────────────────────────────

class _EditVisitorForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> visitor;
  const _EditVisitorForm({required this.visitor});

  @override
  ConsumerState<_EditVisitorForm> createState() => _EditVisitorFormState();
}

class _EditVisitorFormState extends ConsumerState<_EditVisitorForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _adultsCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _noteCtrl;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final v = widget.visitor;
    _nameCtrl   = TextEditingController(text: v['visitorName']    as String? ?? '');
    _phoneCtrl  = TextEditingController(text: v['visitorPhone']   as String? ?? '');
    _emailCtrl  = TextEditingController(text: v['visitorEmail']   as String? ?? '');
    _adultsCtrl = TextEditingController(text: (v['numberOfAdults'] ?? 1).toString());
    _descCtrl   = TextEditingController(text: v['description']    as String? ?? '');
    _noteCtrl   = TextEditingController(text: v['noteForWatchman'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose();
    _adultsCtrl.dispose(); _descCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMsg = null; });

    final error = await ref.read(visitorsProvider.notifier).updateVisitor(
      widget.visitor['id'] as String,
      {
        'visitorName':      _nameCtrl.text.trim(),
        'visitorPhone':     _phoneCtrl.text.trim(),
        'visitorEmail':     _emailCtrl.text.trim(),
        'numberOfAdults':   int.tryParse(_adultsCtrl.text) ?? 1,
        'description':      _descCtrl.text.trim(),
        'noteForWatchman':  _noteCtrl.text.trim(),
      },
    );

    if (mounted) {
      if (error == null) {
        setState(() => _isLoading = false);
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(
          content: const Text('Visitor updated successfully'),
          backgroundColor: AppColors.success,
        ));
      } else {
        setState(() { _isLoading = false; _errorMsg = error; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.screenPadding, AppDimensions.lg,
        AppDimensions.screenPadding,
        MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(height: AppDimensions.lg),
              Text('Edit Visitor', style: AppTextStyles.h1),
              const SizedBox(height: AppDimensions.lg),

              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Visitor Name *', prefixIcon: Icon(Icons.person)),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: AppDimensions.md),

              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone Number *', prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: AppDimensions.md),

              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email (Optional)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppDimensions.md),

              Row(children: [
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _adultsCtrl,
                    decoration: const InputDecoration(labelText: 'Adults *', prefixIcon: Icon(Icons.people_outline)),
                    keyboardType: TextInputType.number,
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Min 1' : null,
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle No / Desc',
                      prefixIcon: Icon(Icons.directions_car_outlined),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
              ]),
              const SizedBox(height: AppDimensions.md),

              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Purpose / Note for Watchman',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: AppDimensions.md),

              if (_errorMsg != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.sm),
                  margin: const EdgeInsets.only(bottom: AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Text(_errorMsg!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText)),
                ),
              ],

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_isLoading ? 'Saving…' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
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

// ─── Log Visitor Form ─────────────────────────────────────────────────────────

class _LogVisitorForm extends ConsumerStatefulWidget {
  const _LogVisitorForm();

  @override
  ConsumerState<_LogVisitorForm> createState() => _LogVisitorFormState();
}

class _LogVisitorFormState extends ConsumerState<_LogVisitorForm> {
  final _formKey            = GlobalKey<FormState>();
  final _nameController     = TextEditingController();
  final _phoneController    = TextEditingController();
  final _emailController    = TextEditingController();
  final _adultsController   = TextEditingController(text: '1');
  final _descController     = TextEditingController();
  final _noteController     = TextEditingController();

  String? _selectedUnitId;
  String? _selectedUnitCode;
  bool    _lockUnit    = false;
  bool    _isInviteMode = true;
  int?    _expiryHours;
  bool    _isLoading   = false;
  String? _errorMsg;

  // Walk-in: unit search mode — 'unit' or 'member'
  String  _walkinSearchMode = 'unit';
  // Member search for walk-in
  final _memberSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _memberResults = [];
  bool _memberSearchLoading = false;

  // Camera / photo
  File?   _capturedPhoto;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _lockUnit = user?.isUnitLocked ?? false;
    if (_lockUnit) {
      _selectedUnitId   = user?.unitId;
      _selectedUnitCode = user?.unitCode;
    }
    final role = user?.role.toUpperCase() ?? '';
    if (role == 'WATCHMAN') _isInviteMode = false;
    ref.read(visitorConfigProvider.future).ignore();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _adultsController.dispose();
    _descController.dispose();
    _noteController.dispose();
    _memberSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchMembers(String q) async {
    if (q.trim().length < 2) {
      setState(() => _memberResults = []);
      return;
    }
    setState(() => _memberSearchLoading = true);
    try {
      final res = await DioClient().dio.get('/search', queryParameters: {'q': q, 'limit': 8});
      final results = res.data['data']?['results'] as List? ?? [];
      final members = results
          .where((r) => r['type'] == 'member')
          .map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r))
          .toList();
      setState(() { _memberResults = members; _memberSearchLoading = false; });
    } catch (_) {
      setState(() => _memberSearchLoading = false);
    }
  }

  Future<void> _capturePhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 75, maxWidth: 1024);
      if (picked != null) {
        setState(() => _capturedPhoto = File(picked.path));
      }
    } catch (_) {}
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppDimensions.md),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () { Navigator.pop(context); _capturePhoto(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () { Navigator.pop(context); _capturePhoto(ImageSource.gallery); },
            ),
            if (_capturedPhoto != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: const Text('Remove Photo'),
                onTap: () { Navigator.pop(context); setState(() => _capturedPhoto = null); },
              ),
            const SizedBox(height: AppDimensions.md),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _errorMsg = null);
    if (!_formKey.currentState!.validate() || _selectedUnitId == null) {
      if (_selectedUnitId == null) setState(() => _errorMsg = 'Please select a unit');
      return;
    }
    setState(() => _isLoading = true);

    String? error;
    if (_isInviteMode) {
      final payload = <String, dynamic>{
        'visitorName':     _nameController.text.trim(),
        'visitorPhone':    _phoneController.text.trim(),
        'unitId':          _selectedUnitId,
        'numberOfAdults':  int.tryParse(_adultsController.text) ?? 1,
        'description':     _descController.text.trim(),
        'noteForWatchman': _noteController.text.trim(),
        if (_expiryHours != null) 'expiryHours': _expiryHours,
      };
      final email = _emailController.text.trim();
      if (email.isNotEmpty) payload['visitorEmail'] = email;
      error = await ref.read(visitorsProvider.notifier).inviteVisitor(payload);
    } else {
      final fields = <String, dynamic>{
        'visitorName':     _nameController.text.trim(),
        'visitorPhone':    _phoneController.text.trim(),
        'unitId':          _selectedUnitId,
        'numberOfAdults':  int.tryParse(_adultsController.text) ?? 1,
        'description':     _descController.text.trim(),
        'noteForWatchman': _noteController.text.trim(),
      };
      error = await ref.read(visitorsProvider.notifier).logVisitorWithPhoto(fields, _capturedPhoto);
    }

    if (mounted) {
      if (error == null) {
        setState(() => _isLoading = false);
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(
          content: Text(_isInviteMode
              ? 'Invitation sent! QR delivered via WhatsApp & email.'
              : _capturedPhoto != null
                  ? 'Visitor logged — unit members notified for approval.'
                  : 'Visitor entry logged successfully.'),
          backgroundColor: AppColors.success,
        ));
      } else {
        setState(() { _isLoading = false; _errorMsg = error; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user      = ref.watch(authProvider).user;
    final role      = user?.role.toUpperCase() ?? '';
    final canInvite = role != 'WATCHMAN';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.screenPadding, AppDimensions.lg,
        AppDimensions.screenPadding,
        MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ──────────────────────────────────────────
              Center(child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: AppDimensions.lg),

              // ── Title + mode toggle ──────────────────────────────────
              Row(children: [
                Expanded(child: Text(
                  _isInviteMode ? 'Invite Visitor' : 'Log Walk-in',
                  style: AppTextStyles.h1,
                )),
                if (canInvite)
                  _ModeToggle(isInviteMode: _isInviteMode, onChanged: (v) => setState(() => _isInviteMode = v)),
              ]),

              // ── Mode hint banner ─────────────────────────────────────
              if (canInvite) ...[
                const SizedBox(height: AppDimensions.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.sm),
                  decoration: BoxDecoration(
                    color: _isInviteMode ? AppColors.primarySurface : AppColors.warningSurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Row(children: [
                    Icon(
                      _isInviteMode ? Icons.qr_code_2_rounded : Icons.login_rounded,
                      size: 16,
                      color: _isInviteMode ? AppColors.primary : AppColors.warningText,
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(child: Text(
                      _isInviteMode
                          ? 'QR pass will be sent to visitor via WhatsApp & email'
                          : 'Capture photo → unit member notified to Allow/Deny',
                      style: AppTextStyles.caption.copyWith(
                        color: _isInviteMode ? AppColors.primary : AppColors.warningText,
                      ),
                    )),
                  ]),
                ),
              ],
              const SizedBox(height: AppDimensions.lg),

              // ── Walk-in: unit search mode tabs ───────────────────────
              if (!_isInviteMode && !_lockUnit) ...[
                Row(children: [
                  _SearchModeTab(label: 'Search by Unit', icon: Icons.apartment_rounded,
                      selected: _walkinSearchMode == 'unit',
                      onTap: () => setState(() { _walkinSearchMode = 'unit'; _memberResults = []; })),
                  const SizedBox(width: AppDimensions.sm),
                  _SearchModeTab(label: 'Search by Member', icon: Icons.person_search_rounded,
                      selected: _walkinSearchMode == 'member',
                      onTap: () => setState(() => _walkinSearchMode = 'member')),
                ]),
                const SizedBox(height: AppDimensions.md),

                // Member search input
                if (_walkinSearchMode == 'member') ...[
                  TextFormField(
                    controller: _memberSearchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Search member name / phone',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _memberSearchLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : null,
                    ),
                    onChanged: _searchMembers,
                  ),
                  if (_memberResults.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.sm),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _memberResults.length,
                        itemBuilder: (_, i) {
                          final m = _memberResults[i];
                          final unitCode = (m['unitResidents'] as List?)?.isNotEmpty == true
                              ? (m['unitResidents'][0]['unit']?['fullCode'] ?? '-')
                              : '-';
                          final unitId = (m['unitResidents'] as List?)?.isNotEmpty == true
                              ? (m['unitResidents'][0]['unitId'] ?? '')
                              : '';
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primarySurface,
                              child: Text((m['name'] as String? ?? '?')[0].toUpperCase(),
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                            ),
                            title: Text(m['name'] as String? ?? '-', style: AppTextStyles.bodyMedium),
                            subtitle: Text('Unit $unitCode • ${m['phone'] ?? ''}',
                                style: AppTextStyles.caption),
                            trailing: _selectedUnitId == unitId
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18)
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedUnitId   = unitId.isNotEmpty ? unitId : null;
                                _selectedUnitCode = unitCode;
                                _memberSearchCtrl.text = '${m['name']} — Unit $unitCode';
                                _memberResults = [];
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppDimensions.md),
                  ],
                  if (_selectedUnitCode != null && _selectedUnitId != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: Row(children: [
                        const Icon(Icons.apartment_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: AppDimensions.sm),
                        Text('Unit $_selectedUnitCode selected',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() { _selectedUnitId = null; _selectedUnitCode = null; }),
                          child: const Icon(Icons.close_rounded, size: 16, color: AppColors.primary),
                        ),
                      ]),
                    ),
                    const SizedBox(height: AppDimensions.md),
                  ],
                ],

                // Unit picker
                if (_walkinSearchMode == 'unit') ...[
                  UnitPickerField(
                    selectedUnitId: _selectedUnitId,
                    selectedUnitCode: _selectedUnitCode,
                    onChanged: (id, code) => setState(() { _selectedUnitId = id; _selectedUnitCode = code; }),
                  ),
                  const SizedBox(height: AppDimensions.md),
                ],
              ],

              // Unit picker for invite mode (non-locked)
              if (_isInviteMode && !_lockUnit) ...[
                UnitPickerField(
                  selectedUnitId: _selectedUnitId,
                  selectedUnitCode: _selectedUnitCode,
                  onChanged: (id, code) => setState(() { _selectedUnitId = id; _selectedUnitCode = code; }),
                ),
                const SizedBox(height: AppDimensions.md),
              ],

              // ── Visitor Name ─────────────────────────────────────────
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Visitor Name *', prefixIcon: Icon(Icons.person)),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: AppDimensions.md),

              // ── Phone ────────────────────────────────────────────────
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *', prefixIcon: Icon(Icons.phone),
                  hintText: '10-digit mobile number',
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: AppDimensions.md),

              // ── Adults & Description ─────────────────────────────────
              Row(children: [
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _adultsController,
                    decoration: const InputDecoration(labelText: 'Adults *', prefixIcon: Icon(Icons.people_outline)),
                    keyboardType: TextInputType.number,
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Min 1' : null,
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle No / Desc',
                      prefixIcon: Icon(Icons.directions_car_outlined),
                      hintText: 'e.g. GJ01AB1234',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
              ]),
              const SizedBox(height: AppDimensions.md),

              // ── Email (invite only) ──────────────────────────────────
              if (_isInviteMode) ...[
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Visitor Email (Optional)',
                    prefixIcon: Icon(Icons.email_outlined),
                    hintText: 'QR will also be sent to this email',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final val = v?.trim() ?? '';
                    if (val.isEmpty) return null;
                    return RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(val) ? null : 'Enter a valid email';
                  },
                ),
                const SizedBox(height: AppDimensions.md),
              ],

              // ── Note ────────────────────────────────────────────────
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: _isInviteMode ? 'Purpose of Visit (Optional)' : 'Note for Watchman (Optional)',
                  prefixIcon: const Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: AppDimensions.md),

              // ── QR expiry (invite only) ──────────────────────────────
              if (_isInviteMode) ...[
                _ExpiryPicker(selectedHours: _expiryHours, onChanged: (h) => setState(() => _expiryHours = h)),
                const SizedBox(height: AppDimensions.md),
              ],

              // ── Photo capture (walk-in only) ─────────────────────────
              if (!_isInviteMode) ...[
                _PhotoCaptureTile(
                  photo: _capturedPhoto,
                  onTap: _showPhotoOptions,
                ),
                const SizedBox(height: AppDimensions.md),
              ],

              if (_errorMsg != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.sm),
                  margin: const EdgeInsets.only(bottom: AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Text(_errorMsg!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText)),
                ),
              ],

              // ── Submit ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Icon(_isInviteMode ? Icons.send_rounded : Icons.login_rounded, size: 18),
                  label: Text(_isLoading ? 'Please wait…' : _isInviteMode ? 'Send Invite & QR' : 'Log Entry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Search mode tab ──────────────────────────────────────────────────────────

class _SearchModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _SearchModeTab({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? AppColors.textOnPrimary : AppColors.textMuted),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.labelSmall.copyWith(
            color: selected ? AppColors.textOnPrimary : AppColors.textMuted,
          )),
        ]),
      ),
    );
  }
}

// ─── Photo capture tile ───────────────────────────────────────────────────────

class _PhotoCaptureTile extends StatelessWidget {
  final File? photo;
  final VoidCallback onTap;
  const _PhotoCaptureTile({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: photo != null ? 180 : 80,
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(
            color: photo != null ? AppColors.primary : AppColors.border,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: photo != null
            ? Stack(fit: StackFit.expand, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd - 1),
                  child: Image.file(photo!, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.edit_rounded, size: 12, color: AppColors.textOnPrimary),
                      const SizedBox(width: 4),
                      Text('Change', style: AppTextStyles.caption.copyWith(color: AppColors.textOnPrimary)),
                    ]),
                  ),
                ),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.camera_alt_rounded, color: AppColors.textMuted, size: 28),
                const SizedBox(height: 4),
                Text('Tap to capture visitor photo (optional)',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                Text('Photo triggers unit member approval',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontSize: 10)),
              ]),
      ),
    );
  }
}

// ─── Mode toggle widget ───────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final bool isInviteMode;
  final ValueChanged<bool> onChanged;
  const _ModeToggle({required this.isInviteMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Tab(
            label: 'Invite',
            icon: Icons.qr_code_2_rounded,
            selected: isInviteMode,
            onTap: () => onChanged(true),
          ),
          _Tab(
            label: 'Walk-in',
            icon: Icons.login_rounded,
            selected: !isInviteMode,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Tab(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md, vertical: AppDimensions.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd - 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected
                    ? AppColors.textOnPrimary
                    : AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color:
                    selected ? AppColors.textOnPrimary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── QR Expiry picker ─────────────────────────────────────────────────────────

/// Lets the sender choose how long the QR should be valid.
/// Options are built from 1 hr up to the platform max (fetched via provider).
/// Selecting null means "use platform default (= max)".
class _ExpiryPicker extends ConsumerWidget {
  final int? selectedHours;
  final ValueChanged<int?> onChanged;

  const _ExpiryPicker({required this.selectedHours, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(visitorConfigProvider);

    final maxHrs = configAsync.when(
      data:    (d) => (d['visitorQrMaxHrs'] as num?)?.toInt() ?? 3,
      loading: () => 3,
      error:   (_, _) => 3,
    );

    final options = List.generate(maxHrs, (i) => i + 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.timer_outlined, size: 16, color: AppColors.textMuted),
            const SizedBox(width: AppDimensions.sm),
            Text(
              'QR Valid For',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
            ),
            const Spacer(),
            if (configAsync.isLoading)
              const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // "Default" chip — sends null so backend uses platform max
              _HourChip(
                label: 'Default (${maxHrs}h)',
                selected: selectedHours == null,
                onTap: () => onChanged(null),
              ),
              const SizedBox(width: AppDimensions.sm),
              ...options.map((h) => Padding(
                padding: const EdgeInsets.only(right: AppDimensions.sm),
                child: _HourChip(
                  label: h == 1 ? '1 hr' : '$h hrs',
                  selected: selectedHours == h,
                  onTap: () => onChanged(h),
                ),
              )),
            ],
          ),
        ),
        if (selectedHours != null) ...[
          const SizedBox(height: AppDimensions.xs),
          Text(
            'QR expires $selectedHours ${selectedHours == 1 ? 'hour' : 'hours'} after sending'
            ' · max ${maxHrs}h allowed',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _HourChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _HourChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md, vertical: AppDimensions.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: selected ? AppColors.textOnPrimary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
