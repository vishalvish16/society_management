import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const primary        = Color(0xFF2563EB);
  static const primaryLight   = Color(0xFF60A5FA);
  static const primaryDark    = Color(0xFF1D4ED8);
  static const primarySurface = Color(0xFFEFF6FF);
  static const primaryBorder  = Color(0xFFBFDBFE);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const success        = Color(0xFF10B981);
  static const successSurface = Color(0xFFECFDF5);
  static const successBorder  = Color(0xFFA7F3D0);
  static const successText    = Color(0xFF065F46);

  static const danger         = Color(0xFFEF4444);
  static const dangerSurface  = Color(0xFFFEF2F2);
  static const dangerBorder   = Color(0xFFFECACA);
  static const dangerText     = Color(0xFF991B1B);

  static const warning        = Color(0xFFF59E0B);
  static const warningSurface = Color(0xFFFFFBEB);
  static const warningBorder  = Color(0xFFFDE68A);
  static const warningText    = Color(0xFF92400E);

  static const info           = Color(0xFF8B5CF6);
  static const infoSurface    = Color(0xFFF5F3FF);
  static const infoBorder     = Color(0xFFDDD6FE);
  static const infoText       = Color(0xFF5B21B6);

  static const teal           = Color(0xFF14B8A6);
  static const tealSurface    = Color(0xFFF0FDFA);

  // ── Neutrals ───────────────────────────────────────────────────────────────
  static const background     = Color(0xFFF8FAFC);
  static const surface        = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF1F5F9);
  static const border         = Color(0xFFE2E8F0);
  static const borderLight    = Color(0xFFF1F5F9);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const textPrimary    = Color(0xFF0F172A);
  static const textSecondary  = Color(0xFF475569);
  static const textMuted      = Color(0xFF94A3B8);
  static const textOnPrimary  = Color(0xFFFFFFFF);

  // ── Sidebar (dark) ────────────────────────────────────────────────────────
  static const sidebarBg         = Color(0xFF0F172A);
  static const sidebarBorder     = Color(0xFF1E293B);
  static const sidebarText       = Color(0xFF94A3B8);
  static const sidebarTextActive = Color(0xFFFFFFFF);
  static const sidebarItemHover  = Color(0xFF1E293B);
  static const sidebarGroupLabel = Color(0xFF475569);

  // ── Gradients (non-const — use as static getters) ─────────────────────────
  static LinearGradient get gradientBlue => const LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get gradientGreen => const LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get gradientOrange => const LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get gradientPurple => const LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
