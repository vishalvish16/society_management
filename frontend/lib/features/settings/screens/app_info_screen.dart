import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/app_info_provider.dart';

class AppInfoScreen extends ConsumerWidget {
  const AppInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(appInfoProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('App Info'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: infoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(appInfoProvider),
        ),
        data: (info) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          child: Column(
            children: [
              // ── App logo + name + tagline ──────────────────────────────
              const SizedBox(height: AppDimensions.xl),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, _) => const Icon(
                      Icons.apartment_rounded,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              Text(
                info.appName.isNotEmpty ? info.appName : 'SocietyPro',
                style: AppTextStyles.displayMedium,
                textAlign: TextAlign.center,
              ),
              if (info.appTagline.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.xs),
                Text(
                  info.appTagline,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
              if (info.appVersion.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.md, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Text(
                    'Version ${info.appVersion}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.primary),
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.xxl),

              // ── Support info ───────────────────────────────────────────
              if (info.supportEmail.isNotEmpty || info.supportPhone.isNotEmpty) ...[
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      if (info.supportEmail.isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.email_outlined,
                              color: AppColors.primary),
                          title: Text('Support Email',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textMuted)),
                          subtitle: Text(info.supportEmail,
                              style: AppTextStyles.bodyMedium),
                        ),
                      if (info.supportEmail.isNotEmpty &&
                          info.supportPhone.isNotEmpty)
                        const Divider(
                            height: 1,
                            indent: AppDimensions.lg,
                            endIndent: AppDimensions.lg),
                      if (info.supportPhone.isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.phone_outlined,
                              color: AppColors.primary),
                          title: Text('Support Phone',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textMuted)),
                          subtitle: Text(info.supportPhone,
                              style: AppTextStyles.bodyMedium),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),
              ],

              // ── Terms & Conditions button ──────────────────────────────
              if (info.termsAndConditions.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showTerms(context, info),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Terms & Conditions'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.md),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppDimensions.xxxl),
            ],
          ),
        ),
      ),
    );
  }

  void _showTerms(BuildContext context, AppInfo info) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TermsScreen(
          appName: info.appName,
          html: info.termsAndConditions,
        ),
      ),
    );
  }
}

// ─── Full-screen Terms & Conditions viewer ────────────────────────────────────

class _TermsScreen extends StatelessWidget {
  final String appName;
  final String html;

  const _TermsScreen({required this.appName, required this.html});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: Html(
          data: html,
          style: {
            'body': Style(
              fontSize: FontSize(14),
              color: Theme.of(context).colorScheme.onSurface,
            ),
            'h1': Style(fontSize: FontSize(20), fontWeight: FontWeight.bold),
            'h2': Style(fontSize: FontSize(17), fontWeight: FontWeight.bold),
            'h3': Style(fontSize: FontSize(15), fontWeight: FontWeight.w600),
            'a': Style(color: AppColors.primary),
            'p': Style(lineHeight: const LineHeight(1.6)),
          },
        ),
      ),
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
