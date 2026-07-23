import 'package:flutter/material.dart';

/// Fixwaala brand color palette.
///
/// Primary: deep teal family — conveys trust, professionalism.
/// Accent: warm amber/gold  — draws attention to CTAs.
/// Surfaces: translucent whites for glassmorphism.
class AppColors {
  AppColors._();

  // ── Primary teal gradient ──────────────────────────────────────────
  static const Color primary = Color(0xFF0A6E5A);
  static const Color primaryLight = Color(0xFF12A085);
  static const Color primaryDark = Color(0xFF064D3E);
  static const Color primarySurface = Color(0xFFE8F5F1);

  // ── Accent amber/gold ─────────────────────────────────────────────
  static const Color accent = Color(0xFFF5A623);
  static const Color accentLight = Color(0xFFFFCC02);
  static const Color accentDark = Color(0xFFD4881A);

  // ── Neutrals ──────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color background = Color(0xFFF8FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color scaffoldDark = Color(0xFF0F1923);
  static const Color surfaceDark = Color(0xFF1A2634);
  static const Color cardDark = Color(0xFF223344);

  // ── Semantic ──────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Glassmorphism helpers ─────────────────────────────────────────
  static Color glassWhite = Colors.white.withValues(alpha: 0.15);
  static Color glassBorder = Colors.white.withValues(alpha: 0.25);
  static Color glassWhiteDark = Colors.white.withValues(alpha: 0.08);
  static Color glassBorderDark = Colors.white.withValues(alpha: 0.12);

  // ── Gradients ─────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF064D3E), Color(0xFF0A6E5A), Color(0xFF12A085)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentLight],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0F1923), Color(0xFF1A2634)],
  );

  // ── Category-specific colors ──────────────────────────────────────
  static const Color plumbing = Color(0xFF3B82F6);
  static const Color electrical = Color(0xFFF59E0B);
  static const Color carpentry = Color(0xFF8B5CF6);
  static const Color otherCat = Color(0xFF6B7280);
}
