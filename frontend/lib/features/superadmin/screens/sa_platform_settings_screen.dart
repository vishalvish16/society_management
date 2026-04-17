import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_loading_shimmer.dart';
import '../providers/platform_settings_provider.dart';

class SaPlatformSettingsScreen extends ConsumerWidget {
  const SaPlatformSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(platformSettingsProvider);
    final isWeb = MediaQuery.of(context).size.width >= 720;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page header ────────────────────────────────────────────
          if (!isMobile) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                AppDimensions.xxl,
                MediaQuery.of(context).padding.top + AppDimensions.lg,
                AppDimensions.xxl,
                AppDimensions.lg,
              ),
              color: AppColors.surface,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Platform Settings', style: AppTextStyles.displayMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Configure platform-wide defaults for all societies',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh',
                    onPressed: () => ref.invalidate(platformSettingsProvider),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],

          // ── Body ────────────────────────────────────────────────────
          Expanded(
            child: settingsAsync.when(
              loading: () =>
                  const AppLoadingShimmer(itemCount: 3, itemHeight: 80),
              error: (e, _) => _ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(platformSettingsProvider),
              ),
              data: (settings) => RefreshIndicator(
                onRefresh: () async =>
                    ref.read(platformSettingsProvider.notifier).fetch(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppDimensions.xxl),
                  child: isWeb
                      ? _WebLayout(settings: settings)
                      : _MobileLayout(settings: settings),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Web layout — card with table ─────────────────────────────────────────────

class _WebLayout extends StatelessWidget {
  final List<PlatformSetting> settings;
  const _WebLayout({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section: Visitor settings
        _SectionHeader(
          icon: Icons.qr_code_2_rounded,
          title: 'Visitor QR Settings',
          subtitle: 'Control how long visitor QR codes remain valid',
        ),
        const SizedBox(height: AppDimensions.md),
        AppCard(
          child: Column(
            children: [
              // Table header
              Container(
                color: AppColors.background,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.lg, vertical: AppDimensions.sm),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text('Setting',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textMuted)),
                    ),
                    Expanded(
                      child: Text('Current Value',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textMuted)),
                    ),
                    SizedBox(
                      width: 180,
                      child: Text('Update',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textMuted)),
                    ),
                  ],
                ),
              ),
              // Rows
              ...settings.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                return Container(
                  decoration: BoxDecoration(
                    border: i > 0
                        ? const Border(
                            top: BorderSide(color: AppColors.border))
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.lg,
                      vertical: AppDimensions.md),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.label, style: AppTextStyles.bodyMedium),
                            Text(s.key,
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _ValueBadge(setting: s),
                      ),
                      SizedBox(
                        width: 180,
                        child: _InlineEditor(setting: s),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Mobile layout — cards ────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final List<PlatformSetting> settings;
  const _MobileLayout({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.qr_code_2_rounded,
          title: 'Visitor QR Settings',
          subtitle: 'Control how long visitor QR codes remain valid',
        ),
        const SizedBox(height: AppDimensions.md),
        ...settings.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.md),
              child: _SettingCard(setting: s),
            )),
      ],
    );
  }
}

// ─── Setting card (mobile) ────────────────────────────────────────────────────

class _SettingCard extends StatelessWidget {
  final PlatformSetting setting;
  const _SettingCard({required this.setting});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(setting.label, style: AppTextStyles.h3),
                    const SizedBox(height: 2),
                    Text(setting.key,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              _ValueBadge(setting: setting),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          const Divider(height: 1),
          const SizedBox(height: AppDimensions.md),
          _InlineEditor(setting: setting),
        ],
      ),
    );
  }
}

// ─── Shared: current value badge ──────────────────────────────────────────────

class _ValueBadge extends StatelessWidget {
  final PlatformSetting setting;
  const _ValueBadge({required this.setting});

  @override
  Widget build(BuildContext context) {
    final display = setting.dataType == 'number'
        ? '${setting.value} ${_unitFor(setting.key)}'
        : setting.value;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Text(display,
          style: AppTextStyles.labelMedium
              .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
    );
  }

  String _unitFor(String key) {
    if (key == 'visitor_qr_max_hrs') return 'hr(s)';
    return '';
  }
}

// ─── Shared: inline editor ────────────────────────────────────────────────────

class _InlineEditor extends ConsumerStatefulWidget {
  final PlatformSetting setting;
  const _InlineEditor({required this.setting});

  @override
  ConsumerState<_InlineEditor> createState() => _InlineEditorState();
}

class _InlineEditorState extends ConsumerState<_InlineEditor> {
  late final TextEditingController _ctrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.setting.value);
  }

  @override
  void didUpdateWidget(_InlineEditor old) {
    super.didUpdateWidget(old);
    // Sync if the value was updated externally (optimistic update rollback)
    if (old.setting.value != widget.setting.value && !_saving) {
      _ctrl.text = widget.setting.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Cannot be empty');
      return;
    }
    if (widget.setting.dataType == 'number') {
      final n = int.tryParse(raw);
      if (n == null || n < 1) {
        setState(() => _error = 'Must be a positive integer');
        return;
      }
    }

    setState(() { _saving = true; _error = null; });

    final err = await ref
        .read(platformSettingsProvider.notifier)
        .updateSetting(widget.setting.key, raw);

    if (mounted) {
      setState(() => _saving = false);
      if (err != null) {
        setState(() => _error = err);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.setting.label} updated to $raw'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNumber = widget.setting.dataType == 'number';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                keyboardType: isNumber
                    ? TextInputType.number
                    : TextInputType.text,
                inputFormatters: isNumber
                    ? [FilteringTextInputFormatter.digitsOnly]
                    : null,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.md, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  errorText: _error,
                  suffixText: isNumber ? _unitFor(widget.setting.key) : null,
                  suffixStyle: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted),
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            SizedBox(
              height: 38,
              width: 72,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.md),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _unitFor(String key) {
    if (key == 'visitor_qr_max_hrs') return 'hrs';
    return '';
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionHeader(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: AppDimensions.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.h2),
              Text(subtitle,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
            const SizedBox(height: AppDimensions.md),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.dangerText)),
            const SizedBox(height: AppDimensions.lg),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
