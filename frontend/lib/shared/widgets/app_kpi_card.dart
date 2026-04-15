import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_card.dart';

class AppKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? trend;
  final bool isAccent;

  const AppKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.trend,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isAccent ? AppColors.primary : null;
    final labelColor = isAccent ? AppColors.textOnPrimary : AppColors.textMuted;
    final valueColor = isAccent ? AppColors.textOnPrimary : AppColors.textPrimary;
    final trendColor = isAccent ? AppColors.textOnPrimary : AppColors.success;

    return AppCard(
      backgroundColor: bgColor,
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: labelColor),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            value,
            style: AppTextStyles.displayMedium.copyWith(color: valueColor),
          ),
          if (trend != null) ...[
            const SizedBox(height: AppDimensions.xs),
            Text(
              '▲ $trend',
              style: AppTextStyles.caption.copyWith(color: trendColor),
            ),
          ],
        ],
      ),
    );
  }
}
