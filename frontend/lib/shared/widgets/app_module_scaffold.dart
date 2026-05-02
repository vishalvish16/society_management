import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_page_header.dart';

/// Primary / secondary FABs matching the stacked module pattern (e.g. Bills:
/// optional green action on top, blue primary add below on mobile; extended
/// row on tablet).
class ModuleFabConfig {
  const ModuleFabConfig({
    required this.onPressed,
    required this.icon,
    this.backgroundColor = AppColors.primary,
    this.tooltip = '',
    this.wideExtendedLabel,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final Color backgroundColor;
  final String tooltip;

  /// On wide layouts, if non-null and non-empty, shows [FloatingActionButton.extended].
  final String? wideExtendedLabel;
}

/// Standard module page: blue curved header + optional filter row + body, with
/// optional wide [AppBar] and stacked FABs. Use this instead of repeating
/// [Scaffold] + [AppPageHeader] + [Column] + [Expanded] on every feature screen.
class AppModuleScaffold extends StatelessWidget {
  const AppModuleScaffold({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
    this.headerActions = const [],
    this.filterRow,
    this.wideAppBarBottom,
    this.wideAppBarActions,
    this.primaryFab,
    this.secondaryFab,
    this.fabHeroTagPrefix,
    this.floatingActionButtonOverride,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.floatingActionButtonLocation,
    this.belowHeader,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;
  final List<Widget> headerActions;
  final Widget? filterRow;
  final Widget child;

  /// Placed between [AppPageHeader] and the main [child] (e.g. stats strip on Tasks).
  final Widget? belowHeader;

  final PreferredSizeWidget? wideAppBarBottom;
  final List<Widget>? wideAppBarActions;

  final ModuleFabConfig? primaryFab;
  final ModuleFabConfig? secondaryFab;

  /// Prefix for [Hero] tags on FABs (defaults to [title]).
  final String? fabHeroTagPrefix;

  /// When set, replaces the built-in FAB column entirely (e.g. custom FAB logic).
  final Widget? floatingActionButtonOverride;

  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  static List<Widget> actionsForPrimaryAppBar(List<Widget> actions) {
    return [
      for (final w in actions)
        if (w is IconButton)
          IconButton(
            icon: _recolorIcon(w.icon, AppColors.textOnPrimary),
            onPressed: w.onPressed,
            tooltip: w.tooltip,
          )
        else
          w,
    ];
  }

  static Widget _recolorIcon(Widget? icon, Color color) {
    if (icon is Icon) {
      return Icon(icon.icon, color: color, size: icon.size, semanticLabel: icon.semanticLabel);
    }
    return icon ?? const SizedBox.shrink();
  }

  static Widget? buildFabStack(
    BuildContext context, {
    ModuleFabConfig? primaryFab,
    ModuleFabConfig? secondaryFab,
    String heroTagPrefix = 'fab',
  }) {
    if (primaryFab == null && secondaryFab == null) return null;
    // Keep in sync with [AppPageHeader] (hides mobile header when width ≥ 720).
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    Widget oneFab(ModuleFabConfig c, String tagSuffix, {required bool wide}) {
      final tag = '${heroTagPrefix}_$tagSuffix';
      if (wide &&
          c.wideExtendedLabel != null &&
          c.wideExtendedLabel!.trim().isNotEmpty) {
        return FloatingActionButton.extended(
          heroTag: tag,
          onPressed: c.onPressed,
          backgroundColor: c.backgroundColor,
          icon: Icon(c.icon, color: AppColors.textOnPrimary),
          label: Text(
            c.wideExtendedLabel!,
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary),
          ),
        );
      }
      return FloatingActionButton(
        heroTag: tag,
        onPressed: c.onPressed,
        backgroundColor: c.backgroundColor,
        tooltip: c.tooltip.isEmpty ? null : c.tooltip,
        child: Icon(c.icon, color: AppColors.textOnPrimary),
      );
    }

    if (isWide) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (secondaryFab != null) ...[
            oneFab(secondaryFab, 'secondary', wide: true),
            const SizedBox(height: AppDimensions.md),
          ],
          if (primaryFab != null) oneFab(primaryFab, 'primary', wide: true),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (secondaryFab != null) ...[
          oneFab(secondaryFab, 'secondary', wide: false),
          const SizedBox(height: AppDimensions.md),
        ],
        if (primaryFab != null) oneFab(primaryFab, 'primary', wide: false),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final prefix = fabHeroTagPrefix ?? title;

    final fab = floatingActionButtonOverride ??
        buildFabStack(
          context,
          primaryFab: primaryFab,
          secondaryFab: secondaryFab,
          heroTagPrefix: prefix.replaceAll(' ', '_'),
        );

    return Scaffold(
      backgroundColor: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButtonLocation:
          floatingActionButtonLocation ?? FloatingActionButtonLocation.endFloat,
      appBar: isWide
          ? AppBar(
              backgroundColor: AppColors.primary,
              title: Text(
                title,
                style: AppTextStyles.h2.copyWith(color: AppColors.textOnPrimary),
              ),
              actions: wideAppBarActions ?? actionsForPrimaryAppBar(headerActions),
              bottom: wideAppBarBottom,
            )
          : null,
      floatingActionButton: fab,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPageHeader(
            title: title,
            subtitle: subtitle,
            icon: icon,
            actions: headerActions,
            filterRow: filterRow,
          ),
          ?belowHeader,
          Expanded(child: child),
        ],
      ),
    );
  }
}
