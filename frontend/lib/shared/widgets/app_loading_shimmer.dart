import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_dimensions.dart';

class AppLoadingShimmer extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const AppLoadingShimmer({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8EAF6),
      highlightColor: const Color(0xFFF5F7FA),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        itemCount: itemCount,
        itemBuilder: (context, index) => Container(
          height: itemHeight,
          margin: const EdgeInsets.only(bottom: AppDimensions.md),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
        ),
      ),
    );
  }
}

class AppLoadingShimmerInline extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;

  const AppLoadingShimmerInline({
    super.key,
    this.height = 16,
    this.width,
    this.radius = AppDimensions.radiusSm,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8EAF6),
      highlightColor: const Color(0xFFF5F7FA),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
