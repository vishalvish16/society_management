import 'package:flutter/material.dart';

/// A safe, reusable pull-to-refresh wrapper.
///
/// - If [child] is already scrollable, it is wrapped directly.
/// - If not, it is put inside an always-scrollable `SingleChildScrollView`
///   so the pull gesture works on "static" pages too.
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

  bool _isScrollable(Widget w) {
    return w is ScrollView;
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
      onRefresh: onRefresh,
      child: scrollChild,
    );
  }
}

