import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? leftBorderColor;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.leftBorderColor,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (leftBorderColor != null) {
      // Use ClipRRect + Row to avoid Flutter's restriction on borderRadius with non-uniform border colors
      content = ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: leftBorderColor),
                Expanded(
                  child: Padding(
                    padding: padding ?? const EdgeInsets.all(AppDimensions.lg),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      content = Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppDimensions.lg),
          child: child,
        ),
      );
    }

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: content,
        ),
      );
    }
    return content;
  }
}
