import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_info_copy_card.dart';

class AppSuccessDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final String referenceText;
  final String doneLabel;
  final IconData icon;

  const AppSuccessDialog({
    super.key,
    required this.title,
    this.subtitle = '',
    this.referenceText = '',
    this.doneLabel = 'Done',
    this.icon = Icons.check_circle_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.lg,
            AppDimensions.lg,
            AppDimensions.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.successSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.success, size: 36),
              ),
              const SizedBox(height: AppDimensions.md),
              Text(title, style: AppTextStyles.h2, textAlign: TextAlign.center),
              if (subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: AppDimensions.xs),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
              if (referenceText.trim().isNotEmpty) ...[
                const SizedBox(height: AppDimensions.md),
                AppInfoCopyCard(
                  text: referenceText,
                  copiedMessage: 'Reference copied',
                ),
              ],
              const SizedBox(height: AppDimensions.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                  ),
                  child: Text(doneLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

