import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle get displayLarge => GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textMain);
  static TextStyle get displayMedium => GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textMain);
  static TextStyle get titleLarge => GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textMain);
  static TextStyle get title => GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textMain);
  static TextStyle get headlineLarge => GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textMain);
  static TextStyle get h3 => GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMain);
  static TextStyle get bodyLarge => GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textMain);
  static TextStyle get bodyMedium => GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textMuted);
  static TextStyle get bodySmall => GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textMuted);
  static TextStyle get body1 => GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMain);
  static TextStyle get caption => GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textMuted);
  static TextStyle get buttonLarge => GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white);
  static TextStyle get buttonSmall => GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white);
  static TextStyle get labelMedium => GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted);
}
