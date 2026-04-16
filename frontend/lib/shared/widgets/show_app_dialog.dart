import 'package:flutter/material.dart';

/// Shows a centered dialog with a max width of 520px.
/// Use this for complex forms on admin screens that are better as centered popups.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  double maxWidth = 560,
  EdgeInsets insetPadding = const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
  Color barrierColor = const Color(0x99000000),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, anim1, anim2) {
      return SafeArea(
        child: Padding(
          padding: insetPadding,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: builder(ctx),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
