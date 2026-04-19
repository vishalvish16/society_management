import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
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
import '../../units/providers/unit_provider.dart';
import '../../../shared/widgets/app_searchable_dropdown.dart';
import 'visitor_qr_pass_screen.dart';

class VisitorsScreen extends ConsumerStatefulWidget {
  const VisitorsScreen({super.key});

  @override
  ConsumerState<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends ConsumerState<VisitorsScreen> {
  String _filter = 'all';

  Color _borderColor(String status) {
    switch (status) {
      case 'valid':
      case 'pending':
        return AppColors.warning;
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

    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isWide
          ? AppBar(
              backgroundColor: AppColors.primary,
              title: Text('Visitors', style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.textOnPrimary),
                  onPressed: () => _showScanSheet(context),
                ),
                const SizedBox(width: AppDimensions.sm),
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
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.screenPadding, vertical: AppDimensions.sm),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
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
                    : visitors
                        .where((v) =>
                            _effectiveVisitorStatus(Map<String, dynamic>.from(v as Map)) ==
                            _filter)
                        .toList();
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
                      final v = Map<String, dynamic>.from(filtered[i] as Map);
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
                                    'Unit $unitCode'
                                    '${v['numberOfAdults'] != null && v['numberOfAdults'] > 1 ? ' • ${v['numberOfAdults']} Adults' : ''}'
                                    '${v['description'] != null ? ' • ${v['description']}' : ''}',
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                                  ),
                                  if (inviterName != null)
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
                            if (isPending && qrToken != null) ...[
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
                            if (canEdit) ...[
                              _actionIcon(
                                icon: Icons.edit_rounded,
                                color: AppColors.warning,
                                bgColor: AppColors.warningSurface,
                                tooltip: 'Edit visitor',
                                onTap: () => _showEditVisitorSheet(context, v),
                              ),
                              const SizedBox(width: AppDimensions.sm),
                            ],
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

  void _showScanSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => const _ScanSheet(),
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

  void _showEditVisitorSheet(BuildContext context, Map<String, dynamic> visitor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
  final _formKey = GlobalKey<FormState>();
  final _nameController  = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _adultsController = TextEditingController(text: '1');
  final _descriptionController = TextEditingController();
  final _noteController  = TextEditingController();
  String? _selectedUnitId;
  bool _lockUnit  = false;
  bool _isLoading = false;

  /// true → Send Invite (QR via WhatsApp + email)
  /// false → Walk-in log (immediate entry, no QR)
  bool _isInviteMode = true;

  /// How many hours the QR should be valid — null means use platform default.
  int? _expiryHours;
  String? _errorMsg;

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
    _adultsController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMsg = null);
    if (!_formKey.currentState!.validate() || _selectedUnitId == null) {
      if (_selectedUnitId == null) {
        setState(() => _errorMsg = 'Please select a unit');
      }
      return;
    }

    setState(() => _isLoading = true);

    String? error;
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
      payload['numberOfAdults'] = int.tryParse(_adultsController.text) ?? 1;
      payload['description'] = _descriptionController.text.trim();

      error = await ref.read(visitorsProvider.notifier).inviteVisitor(payload);
    } else {
      // Walk-in log — immediate entry
      error = await ref.read(visitorsProvider.notifier).logVisitor({
        'visitorName':  _nameController.text.trim(),
        'visitorPhone': _phoneController.text.trim(),
        'unitId':       _selectedUnitId,
        'numberOfAdults': int.tryParse(_adultsController.text) ?? 1,
        'description': _descriptionController.text.trim(),
        'noteForWatchman': _noteController.text.trim(),
      });
    }

    if (mounted) {
      if (error == null) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isInviteMode
                ? 'Invitation sent! QR delivered via WhatsApp & email.'
                : 'Visitor entry logged successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMsg = error;
        });
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
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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

            // ── Adults & Description ──────────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _adultsController,
                    decoration: const InputDecoration(
                      labelText: 'Adults *',
                      prefixIcon: Icon(Icons.people_outline),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final val = int.tryParse(v ?? '') ?? 0;
                      return val < 1 ? 'Min 1' : null;
                    },
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle No / Desc',
                      prefixIcon: Icon(Icons.directions_car_outlined),
                      hintText: 'e.g. GJ01AB1234',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
              ],
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

            if (_errorMsg != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.sm),
                margin: const EdgeInsets.only(bottom: AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.dangerSurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Text(
                  _errorMsg!,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText),
                ),
              ),
            ],

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
