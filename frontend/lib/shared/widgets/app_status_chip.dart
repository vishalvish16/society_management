import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';

class AppStatusChip extends StatelessWidget {
  final String status;
  final String? label;

  const AppStatusChip({
    super.key,
    required this.status,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final (bg, fg) = _resolveColors(normalized);
    final displayLabel = label ?? _formatLabel(normalized);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Text(
        displayLabel,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  static (Color bg, Color fg) _resolveColors(String s) {
    const successSet = {
      'paid', 'valid', 'approved', 'confirmed', 'active', 'completed',
    };
    const dangerSet = {
      'overdue', 'invalid', 'rejected', 'expired', 'cancelled', 'denied', 'disabled',
    };
    const warningSet = {
      'pending', 'partial', 'in_progress', 'assigned', 'open', 'dues_cleared',
    };

    if (successSet.contains(s)) {
      return (AppColors.successSurface, AppColors.successText);
    } else if (dangerSet.contains(s)) {
      return (AppColors.dangerSurface, AppColors.dangerText);
    } else if (warningSet.contains(s)) {
      return (AppColors.warningSurface, AppColors.warningText);
    }
    return (AppColors.infoSurface, AppColors.info);
  }

  static String _formatLabel(String s) {
    return s.replaceAll('_', ' ').toUpperCase();
  }
}
