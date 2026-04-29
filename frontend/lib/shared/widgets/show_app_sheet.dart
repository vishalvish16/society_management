import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';

/// Shows a bottom sheet that slides up from the bottom — consistent with the
/// Expense add/edit sheet style. Use this for all Add / Edit / Form popups.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool useRootNavigator = true,
  bool enableDrag = true,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusXl),
      ),
    ),
    builder: (ctx) => _AppSheetSwipeDownToClose(
      enabled: isDismissible && enableDrag,
      child: builder(ctx),
    ),
  );
}

class _AppSheetSwipeDownToClose extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _AppSheetSwipeDownToClose({
    required this.child,
    required this.enabled,
  });

  @override
  State<_AppSheetSwipeDownToClose> createState() => _AppSheetSwipeDownToCloseState();
}

class _AppSheetSwipeDownToCloseState extends State<_AppSheetSwipeDownToClose> {
  // Accumulate "pull down past top" distance from any nested scrollable.
  double _pullDownDistance = 0;

  bool _handleScrollNotification(ScrollNotification n) {
    if (!widget.enabled) return false;

    if (n is OverscrollNotification) {
      // At the top boundary, pulling down produces negative overscroll.
      if (n.overscroll < 0) {
        _pullDownDistance += (-n.overscroll);
        if (_pullDownDistance >= 42) {
          Navigator.of(context).maybePop();
          _pullDownDistance = 0;
        }
      }
    } else if (n is ScrollUpdateNotification) {
      // Reset when user scrolls normally (not overscrolling).
      if (n.scrollDelta != null && (n.scrollDelta ?? 0) > 0) {
        _pullDownDistance = 0;
      }
    } else if (n is ScrollEndNotification) {
      _pullDownDistance = 0;
    }

    return false; // don't block scrolling
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: widget.child,
    );
  }
}

/// Shows a small confirmation bottom sheet (Yes / No).
/// Returns true if confirmed, false/null otherwise.
Future<bool> showConfirmSheet({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  Color confirmColor = AppColors.danger,
  bool useRootNavigator = true,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: false,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusXl),
      ),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.screenPadding,
        AppDimensions.lg,
        AppDimensions.screenPadding,
        AppDimensions.xxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
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
          Text(title,
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppDimensions.sm),
          Text(message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              )),
          const SizedBox(height: AppDimensions.xxl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(cancelLabel),
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: confirmColor),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(confirmLabel,
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
