import 'package:flutter/material.dart';
import '../../core/theme/app_dimensions.dart';

class AppCardGrid extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double maxCrossAxisExtent;
  final double childAspectRatio;

  const AppCardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.maxCrossAxisExtent = 400,
    this.childAspectRatio = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppDimensions.lg),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        mainAxisSpacing: AppDimensions.lg,
        crossAxisSpacing: AppDimensions.lg,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
