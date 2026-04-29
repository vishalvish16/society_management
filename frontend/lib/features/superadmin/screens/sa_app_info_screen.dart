import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../settings/providers/app_info_provider.dart';

class SaAppInfoScreen extends ConsumerStatefulWidget {
  const SaAppInfoScreen({super.key});

  @override
  ConsumerState<SaAppInfoScreen> createState() => _SaAppInfoScreenState();
}

class _SaAppInfoScreenState extends ConsumerState<SaAppInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _taglineCtrl;
  late final TextEditingController _versionCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _termsCtrl;

  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taglineCtrl.dispose();
    _versionCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _termsCtrl.dispose();
    super.dispose();
  }

  void _initControllers(AppInfo info) {
    if (_initialized) return;
    _nameCtrl    = TextEditingController(text: info.appName);
    _taglineCtrl = TextEditingController(text: info.appTagline);
    _versionCtrl = TextEditingController(text: info.appVersion);
    _emailCtrl   = TextEditingController(text: info.supportEmail);
    _phoneCtrl   = TextEditingController(text: info.supportPhone);
    _termsCtrl   = TextEditingController(text: info.termsAndConditions);
    _initialized = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final updated = AppInfo(
      appName:            _nameCtrl.text.trim(),
      appTagline:         _taglineCtrl.text.trim(),
      appVersion:         _versionCtrl.text.trim(),
      supportEmail:       _emailCtrl.text.trim(),
      supportPhone:       _phoneCtrl.text.trim(),
      termsAndConditions: _termsCtrl.text,
    );

    final err = await ref.read(saAppInfoProvider.notifier).save(updated);

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'App info saved successfully'),
        backgroundColor: err == null ? AppColors.success : AppColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final infoAsync = ref.watch(saAppInfoProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('App Info', style: AppTextStyles.displayMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Configure the app name, tagline, support details and Terms & Conditions shown to all users',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh',
                    onPressed: () {
                      _initialized = false;
                      ref.invalidate(saAppInfoProvider);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],

          // ── Body ────────────────────────────────────────────────────
          Expanded(
            child: infoAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: e.toString(),
                onRetry: () {
                  _initialized = false;
                  ref.invalidate(saAppInfoProvider);
                },
              ),
              data: (info) {
                _initControllers(info);
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.xxl),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── General Info ───────────────────────────
                        _SectionHeader(
                          icon: Icons.info_outline_rounded,
                          title: 'General Info',
                          subtitle: 'Shown on the App Info screen for all users',
                        ),
                        const SizedBox(height: AppDimensions.md),
                        AppCard(
                          padding: const EdgeInsets.all(AppDimensions.lg),
                          child: Column(
                            children: [
                              _field(
                                controller: _nameCtrl,
                                label: 'App Name',
                                hint: 'e.g. SocietyPro',
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                              ),
                              const SizedBox(height: AppDimensions.md),
                              _field(
                                controller: _taglineCtrl,
                                label: 'Tagline',
                                hint: 'e.g. Smart society management',
                              ),
                              const SizedBox(height: AppDimensions.md),
                              _field(
                                controller: _versionCtrl,
                                label: 'App Version',
                                hint: 'e.g. 1.0.0',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.xl),

                        // ── Support ────────────────────────────────
                        _SectionHeader(
                          icon: Icons.support_agent_rounded,
                          title: 'Support',
                          subtitle: 'Contact details shown to users',
                        ),
                        const SizedBox(height: AppDimensions.md),
                        AppCard(
                          padding: const EdgeInsets.all(AppDimensions.lg),
                          child: Column(
                            children: [
                              _field(
                                controller: _emailCtrl,
                                label: 'Support Email',
                                hint: 'support@example.com',
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: AppDimensions.md),
                              _field(
                                controller: _phoneCtrl,
                                label: 'Support Phone',
                                hint: '+91 98765 43210',
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.xl),

                        // ── Terms & Conditions ─────────────────────
                        _SectionHeader(
                          icon: Icons.description_outlined,
                          title: 'Terms & Conditions',
                          subtitle:
                              'Enter HTML. Supports headings (<h1>–<h3>), paragraphs (<p>), lists (<ul>/<ol>/<li>), bold (<b>/<strong>), italic (<i>/<em>), links (<a href="...">), and line breaks (<br>).',
                        ),
                        const SizedBox(height: AppDimensions.md),
                        AppCard(
                          padding: const EdgeInsets.all(AppDimensions.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // HTML tag quick-insert chips
                              Wrap(
                                spacing: AppDimensions.xs,
                                runSpacing: AppDimensions.xs,
                                children: [
                                  _HtmlChip(label: '<h1>', insert: '<h1></h1>', ctrl: _termsCtrl),
                                  _HtmlChip(label: '<h2>', insert: '<h2></h2>', ctrl: _termsCtrl),
                                  _HtmlChip(label: '<h3>', insert: '<h3></h3>', ctrl: _termsCtrl),
                                  _HtmlChip(label: '<p>', insert: '<p></p>', ctrl: _termsCtrl),
                                  _HtmlChip(label: '<b>', insert: '<b></b>', ctrl: _termsCtrl),
                                  _HtmlChip(label: '<i>', insert: '<i></i>', ctrl: _termsCtrl),
                                  _HtmlChip(label: '<ul>/<li>', insert: '<ul>\n  <li></li>\n</ul>', ctrl: _termsCtrl),
                                  _HtmlChip(label: '<ol>/<li>', insert: '<ol>\n  <li></li>\n</ol>', ctrl: _termsCtrl),
                                  _HtmlChip(label: '<br>', insert: '<br>', ctrl: _termsCtrl),
                                  _HtmlChip(label: '<a>', insert: '<a href=""></a>', ctrl: _termsCtrl),
                                ],
                              ),
                              const SizedBox(height: AppDimensions.md),
                              TextFormField(
                                controller: _termsCtrl,
                                maxLines: 20,
                                minLines: 10,
                                keyboardType: TextInputType.multiline,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      '<h1>Terms &amp; Conditions</h1>\n<p>Enter your terms here...</p>',
                                  hintStyle: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.textMuted),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusMd),
                                    borderSide:
                                        const BorderSide(color: AppColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusMd),
                                    borderSide:
                                        const BorderSide(color: AppColors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusMd),
                                    borderSide:
                                        const BorderSide(color: AppColors.primary),
                                  ),
                                  contentPadding: const EdgeInsets.all(
                                      AppDimensions.md),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.xxl),

                        // ── Save button ────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(_saving ? 'Saving…' : 'Save App Info'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textOnPrimary,
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppDimensions.md),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusMd),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.xxxl),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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
}

// ─── HTML tag quick-insert chip ───────────────────────────────────────────────

class _HtmlChip extends StatelessWidget {
  final String label;
  final String insert;
  final TextEditingController ctrl;

  const _HtmlChip(
      {required this.label, required this.insert, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColors.background,
      side: const BorderSide(color: AppColors.border),
      onPressed: () {
        final text = ctrl.text;
        final sel = ctrl.selection;
        final start = sel.start < 0 ? text.length : sel.start;
        final end = sel.end < 0 ? text.length : sel.end;
        final newText = text.replaceRange(start, end, insert);
        ctrl.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start + insert.length),
        );
      },
    );
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
      crossAxisAlignment: CrossAxisAlignment.start,
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
                foregroundColor: AppColors.textOnPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
