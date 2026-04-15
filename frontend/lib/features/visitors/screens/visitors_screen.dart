import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../units/providers/unit_provider.dart';
import '../../../shared/widgets/app_searchable_dropdown.dart';

class VisitorsScreen extends ConsumerStatefulWidget {
  const VisitorsScreen({super.key});

  @override
  ConsumerState<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends ConsumerState<VisitorsScreen> {
  String _filter = 'all';

  Color _borderColor(String status) {
    switch (status) {
      case 'valid': return AppColors.success;
      case 'expired':
      case 'denied': return AppColors.danger;
      default: return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitorsAsync = ref.watch(visitorsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Visitors', style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.textOnPrimary),
            onPressed: () {},
          ),
          const SizedBox(width: AppDimensions.sm),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.textOnPrimary),
        label: Text('Log Visitor', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary)),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.screenPadding, vertical: AppDimensions.sm),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in ['all', 'valid', 'used', 'expired'])
                    Padding(
                      padding: const EdgeInsets.only(right: AppDimensions.sm),
                      child: ChoiceChip(
                        label: Text(s == 'all' ? 'All' : s[0].toUpperCase() + s.substring(1)),
                        selected: _filter == s,
                        selectedColor: AppColors.primarySurface,
                        labelStyle: AppTextStyles.labelMedium.copyWith(
                          color: _filter == s ? AppColors.primary : AppColors.textMuted,
                        ),
                        onSelected: (_) => setState(() => _filter = s),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: visitorsAsync.when(
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
                final filtered = _filter == 'all'
                    ? visitors
                    : visitors.where((v) => v['status'] == _filter).toList();
                if (filtered.isEmpty) {
                  return const AppEmptyState(
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
                      final status = v['status'] as String? ?? 'pending';
                      final unitCode = v['unit'] is Map ? v['unit']['fullCode'] : (v['unit'] ?? '-');
                      
                      return AppCard(
                        leftBorderColor: _borderColor(status),
                        padding: const EdgeInsets.all(AppDimensions.md),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                              ),
                              child: const Icon(Icons.person_rounded,
                                  color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: AppDimensions.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(v['visitorName'] as String? ?? '-', style: AppTextStyles.h3),
                                  const SizedBox(height: AppDimensions.xs),
                                  Text(
                                    'Unit $unitCode${v['noteForWatchman'] != null ? ' • ${v['noteForWatchman']}' : ''}',
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            AppStatusChip(status: status),
                          ],
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

  void _showLogDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => const _LogVisitorForm(),
    );
  }
}

class _LogVisitorForm extends ConsumerStatefulWidget {
  const _LogVisitorForm();

  @override
  ConsumerState<_LogVisitorForm> createState() => _LogVisitorFormState();
}

class _LogVisitorFormState extends ConsumerState<_LogVisitorForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController  = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _noteController  = TextEditingController();
  String? _selectedUnitId;
  bool _lockUnit  = false;
  bool _isLoading = false;

  /// true → Send Invite (QR via WhatsApp + email)
  /// false → Walk-in log (immediate entry, no QR)
  bool _isInviteMode = true;

  /// How many hours the QR should be valid — null means use platform default.
  int? _expiryHours;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _lockUnit = user?.isUnitLocked ?? false;
    if (_lockUnit) _selectedUnitId = user?.unitId;

    // Watchmen default to walk-in mode (they log physical entries)
    final role = user?.role.toUpperCase() ?? '';
    if (role == 'WATCHMAN') _isInviteMode = false;

    // Pre-fetch the platform config so the picker has data immediately
    ref.read(visitorConfigProvider.future).ignore();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedUnitId == null) {
      if (_selectedUnitId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a unit')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    bool success;
    if (_isInviteMode) {
      // Invite — QR will be generated and sent via WhatsApp + email
      final payload = <String, dynamic>{
        'visitorName':  _nameController.text.trim(),
        'visitorPhone': _phoneController.text.trim(),
        'unitId':       _selectedUnitId,
        'noteForWatchman': _noteController.text.trim(),
        if (_expiryHours != null) 'expiryHours': _expiryHours,
      };
      final email = _emailController.text.trim();
      if (email.isNotEmpty) payload['visitorEmail'] = email;

      success = await ref.read(visitorsProvider.notifier).inviteVisitor(payload);
    } else {
      // Walk-in log — immediate entry
      success = await ref.read(visitorsProvider.notifier).logVisitor({
        'visitorName':  _nameController.text.trim(),
        'visitorPhone': _phoneController.text.trim(),
        'unitId':       _selectedUnitId,
        'noteForWatchman': _noteController.text.trim(),
      });
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isInviteMode
                ? 'Invitation sent! QR delivered via WhatsApp & email.'
                : 'Visitor entry logged successfully.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isInviteMode
                ? 'Failed to send invitation'
                : 'Failed to log visitor'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitsAsync = ref.watch(unitsProvider);
    final user       = ref.watch(authProvider).user;
    final role       = user?.role.toUpperCase() ?? '';
    final canInvite  = role != 'WATCHMAN'; // watchmen only do walk-in

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppDimensions.screenPadding,
          AppDimensions.lg,
          AppDimensions.screenPadding,
          MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ────────────────────────────────────────────
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

            // ── Title + mode toggle ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isInviteMode ? 'Invite Visitor' : 'Log Walk-in',
                    style: AppTextStyles.h1,
                  ),
                ),
                if (canInvite)
                  _ModeToggle(
                    isInviteMode: _isInviteMode,
                    onChanged: (val) => setState(() => _isInviteMode = val),
                  ),
              ],
            ),

            // ── Mode hint banner ───────────────────────────────────────
            if (canInvite) ...[
              const SizedBox(height: AppDimensions.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md, vertical: AppDimensions.sm),
                decoration: BoxDecoration(
                  color: _isInviteMode
                      ? AppColors.primarySurface
                      : AppColors.warningSurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isInviteMode
                          ? Icons.qr_code_2_rounded
                          : Icons.login_rounded,
                      size: 16,
                      color: _isInviteMode
                          ? AppColors.primary
                          : AppColors.warningText,
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(
                        _isInviteMode
                            ? 'QR pass will be sent to visitor via WhatsApp & email'
                            : 'Records immediate entry — no QR is sent',
                        style: AppTextStyles.caption.copyWith(
                          color: _isInviteMode
                              ? AppColors.primary
                              : AppColors.warningText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.lg),

            // ── Visitor Name ───────────────────────────────────────────
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Visitor Name *',
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: AppDimensions.md),

            // ── Phone ──────────────────────────────────────────────────
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                prefixIcon: Icon(Icons.phone),
                hintText: '10-digit mobile number',
              ),
              keyboardType: TextInputType.phone,
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: AppDimensions.md),

            // ── Email (invite mode only) ───────────────────────────────
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
                  if (val.isEmpty) return null; // optional
                  final emailRe = RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
                  return emailRe.hasMatch(val) ? null : 'Enter a valid email';
                },
              ),
              const SizedBox(height: AppDimensions.md),
            ],

            // ── Unit selector ──────────────────────────────────────────
            if (_lockUnit)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(
                    color: _selectedUnitId != null
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Select Unit *',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(
                            ref.read(authProvider).user?.unitCode ??
                                'No unit assigned',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.lock_outline_rounded,
                        color: AppColors.primary.withValues(alpha: 0.6),
                        size: 18),
                  ],
                ),
              )
            else
              unitsAsync.when(
                data: (units) => AppSearchableDropdown<String?>(
                  label: 'Select Unit *',
                  value: _selectedUnitId,
                  items: units
                      .map((u) => AppDropdownItem(
                          value: u['id'] as String?,
                          label: u['fullCode'] ?? '-'))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedUnitId = val),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading units: $e',
                    style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: AppDimensions.md),

            // ── Note ───────────────────────────────────────────────────
            TextFormField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: _isInviteMode
                    ? 'Purpose of Visit (Optional)'
                    : 'Note for Watchman (Optional)',
                prefixIcon: const Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: AppDimensions.md),

            // ── QR Expiry picker (invite mode only) ────────────────────
            if (_isInviteMode)
              _ExpiryPicker(
                selectedHours: _expiryHours,
                onChanged: (hrs) => setState(() => _expiryHours = hrs),
              ),
            const SizedBox(height: AppDimensions.xl),

            // ── Submit ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Icon(
                        _isInviteMode
                            ? Icons.send_rounded
                            : Icons.login_rounded,
                        size: 18,
                      ),
                label: Text(
                  _isLoading
                      ? 'Please wait…'
                      : _isInviteMode
                          ? 'Send Invite & QR'
                          : 'Log Entry',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
              ),
            ),
          ],
        ),
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
