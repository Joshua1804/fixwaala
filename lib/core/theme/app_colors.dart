import 'package:flutter/material.dart';

/// Fixwaala brand color palette.
///
/// Primary: deep teal family — conveys trust, professionalism.
/// Accent: warm amber/gold  — draws attention to CTAs.
/// Surfaces: translucent whites for glassmorphism.
class AppColors {
  AppColors._();

  // ── Primary neon green/mint gradient ──────────────────────────────────────────
  static const Color primary = Color(0xFF00C9A7); // Emerald Mint
  static const Color primaryLight = Color(0xFF00E5A3); // Neon Mint
  static const Color primaryDark = Color(0xFF004B3E); // Deep Forest Green
  static const Color primarySurface = Color(0xFFE0F4F1);

  // ── Accent neon lime/gold ─────────────────────────────────────────────
  static const Color accent = Color(0xFF98EC2C); // Neon Lime
  static const Color accentLight = Color(0xFFC0FF68);
  static const Color accentDark = Color(0xFF659E15);

  // ── Neutrals ──────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0A1F1C); // Muted deep forest/charcoal
  static const Color textSecondary = Color(0xFF4C605D);
  static const Color textHint = Color(0xFF7F928F);
  static const Color divider = Color(0xFFE2EBE9);
  static const Color background = Color(0xFFF2F9F7); // Light mint off-white
  static const Color surface = Color(0xFFFFFFFF);
  static const Color scaffoldDark = Color(0xFF071211); // Very dark forest black
  static const Color surfaceDark = Color(0xFF0E1F1D);
  static const Color cardDark = Color(0xFF142B28);

  // ── Semantic ──────────────────────────────────────────────────────
  static const Color success = Color(0xFF00E5A3);
  static const Color warning = Color(0xFFFFB300);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF00B0FF);

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
    colors: [Color(0xFF004B3E), Color(0xFF00C9A7), Color(0xFF00E5A3)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentLight],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF071211), Color(0xFF0E1F1D)],
  );


  // ── Category-specific colors ──────────────────────────────────────
  static const Color plumbing = Color(0xFF3B82F6);
  static const Color electrical = Color(0xFFF59E0B);
  static const Color carpentry = Color(0xFF8B5CF6);
  static const Color otherCat = Color(0xFF6B7280);
}
