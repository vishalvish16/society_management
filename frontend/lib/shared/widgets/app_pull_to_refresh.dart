import 'package:flutter/material.dart';

/// A safe, reusable pull-to-refresh wrapper.
///
/// - If [child] is already scrollable, it is wrapped directly.
/// - If not, it is put inside an always-scrollable `SingleChildScrollView`
///   so the pull gesture works on "static" pages too.
/// - If a bottom sheet (or any modal route) is open when the user pulls down,
///   it is dismissed first and the refresh is skipped for that gesture.
class AppPullToRefresh extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final bool enabled;

  const AppPullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.enabled = true,
  });

  bool _isScrollable(Widget w) => w is ScrollView;

  /// Returns true when a bottom sheet, dialog, or any other [PopupRoute] is
  /// currently displayed on top of the current screen.
  bool _hasOpenPopup(BuildContext context) {
    bool found = false;
    Navigator.of(context, rootNavigator: true).popUntil((route) {
      if (route is PopupRoute) found = true;
      return true; // never actually pop — just inspect
    });
    return found;
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final Widget scrollChild;
    if (_isScrollable(child)) {
      scrollChild = child;
    } else {
      scrollChild = LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              // IMPORTANT: give the child a *finite* height.
              //
              // If the child builds a Scaffold (even indirectly), it cannot be
              // laid out with unbounded height (common when wrapped by a scroll view).
              constraints: BoxConstraints.tightFor(height: constraints.maxHeight),
              child: child,
            ),
          );
        },
      );
    }

    return RefreshIndicator.adaptive(
      onRefresh: () async {
        // If a bottom sheet or dialog is open (a PopupRoute sits on top),
        // dismiss it and skip the refresh for this gesture.
        if (context.mounted && _hasOpenPopup(context)) {
          Navigator.of(context, rootNavigator: true).pop();
          return;
        }
        await onRefresh();
      },
      child: scrollChild,
    );
  }
}

