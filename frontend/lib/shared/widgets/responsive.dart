import 'package:flutter/material.dart';

/// Shared responsive breakpoints for consistent UX across screens.
class Responsive {
  static const double mobileMax = 600;
  static const double desktopMin = 1024;

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isMobile(BuildContext context) => width(context) < mobileMax;
  static bool isDesktop(BuildContext context) => width(context) >= desktopMin;
}

