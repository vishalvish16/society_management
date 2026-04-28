import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';

/// Consistent page-level header for every mobile screen.
///
/// On mobile: renders a compact gradient header with title, optional subtitle,
/// back button (if navigator can pop), and trailing [actions].
/// On web (width ≥ 720): hidden — screens keep their own AppBar.
///
/// Usage:
/// ```dart
/// AppPageHeader(
///   title: 'Complaints',
///   subtitle: 'Manage issues',
///   icon: Icons.report_problem_rounded,
///   actions: [
///     IconButton(icon: Icon(Icons.add), onPressed: _add),
///   ],
///   filterRow: AppFilterChipRow(options: [...], selected: ..., onSelected: ...),
/// )
/// ```
class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;
  final List<Widget> actions;
  final Widget? filterRow;
  final bool forceShow;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.actions = const [],
    this.filterRow,
    this.forceShow = false,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;
    if (isWide && !forceShow) return const SizedBox.shrink();

    final color = accentColor ?? AppColors.primary;
    final navigatorCanPop = Navigator.of(context).canPop();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.92),
            color.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppDimensions.radiusXl),
          bottomRight: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.lg,
                AppDimensions.md,
                AppDimensions.md,
                AppDimensions.md,
              ),
              child: Row(
                children: [
                  if (navigatorCanPop) ...[
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.md),
                  ] else if (icon != null) ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: AppDimensions.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.h1.copyWith(color: Colors.white),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...actions.map(_actionWrapper),
                ],
              ),
            ),
            if (filterRow != null) ...[
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.15)),
              filterRow!,
            ],
          ],
        ),
      ),
    );
  }

  static Widget _actionWrapper(Widget action) {
    if (action is IconButton) {
      return Container(
        margin: const EdgeInsets.only(left: AppDimensions.xs),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: IconButton(
          icon: action.icon,
          onPressed: action.onPressed,
          tooltip: action.tooltip,
          color: Colors.white,
          iconSize: action.iconSize ?? 22,
          padding: const EdgeInsets.all(AppDimensions.sm),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      );
    }
    return action;
  }
}

/// A filter option used by [AppFilterChipRow].
class FilterOption {
  final String value;
  final String label;
  const FilterOption(this.value, this.label);
}

/// Horizontal scrollable row of pill-style filter chips.
///
/// When placed inside [AppPageHeader.filterRow] the chips style themselves
/// against the gradient background (white selected, translucent unselected).
/// When used standalone below the header they style against a light surface.
class AppFilterChipRow extends StatelessWidget {
  final List<FilterOption> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final EdgeInsetsGeometry padding;
  final bool darkBackground;

  const AppFilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppDimensions.lg,
      vertical: AppDimensions.sm,
    ),
    this.darkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: options.map((o) {
          final isSelected = o.value == selected;
          return Padding(
            padding: const EdgeInsets.only(right: AppDimensions.sm),
            child: GestureDetector(
              onTap: () => onSelected(o.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md, vertical: 6),
                decoration: BoxDecoration(
                  color: darkBackground
                      ? (isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.15))
                      : (isSelected
                          ? AppColors.primary
                          : AppColors.surfaceVariant),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: darkBackground
                      ? Border.all(
                          color: Colors.white
                              .withValues(alpha: isSelected ? 1.0 : 0.3))
                      : Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border),
                ),
                child: Text(
                  o.label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: darkBackground
                        ? (isSelected ? AppColors.primary : Colors.white)
                        : (isSelected ? Colors.white : AppColors.textSecondary),
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
