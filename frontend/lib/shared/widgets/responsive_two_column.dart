import 'package:flutter/material.dart';
import '../../core/theme/app_dimensions.dart';
import 'responsive.dart';

/// A simple 1→2 column responsive wrapper:
/// - Mobile/tablet: single column (top then bottom)
/// - Desktop: two columns side-by-side
class ResponsiveTwoColumn extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double desktopGap;
  final double? desktopLeftFlex;
  final double? desktopRightFlex;

  const ResponsiveTwoColumn({
    super.key,
    required this.left,
    required this.right,
    this.desktopGap = AppDimensions.lg,
    this.desktopLeftFlex,
    this.desktopRightFlex,
  });

  @override
  Widget build(BuildContext context) {
    if (!Responsive.isDesktop(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          left,
          const SizedBox(height: AppDimensions.lg),
          right,
        ],
      );
    }

    final lf = desktopLeftFlex ?? 1;
    final rf = desktopRightFlex ?? 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: (lf * 1000).round(), child: left),
        SizedBox(width: desktopGap),
        Expanded(flex: (rf * 1000).round(), child: right),
      ],
    );
  }
}

