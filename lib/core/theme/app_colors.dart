import 'package:flutter/material.dart';

/// Fixwaala brand color palette.
///
/// A calm, premium deep-green and sage system with a warm gold accent —
/// conveys trust and professionalism for a home-repair marketplace.
/// Warm neutral surfaces dominate (60%), deep green anchors structure (30%),
/// gold and sage carry accents and highlights (10%).
class AppColors {
  AppColors._();

  // ── Primary (deep green) ───────────────────────────────────────────
  static const Color primary = Color(0xFF0F2515);
  static const Color primaryHover = Color(0xFF183321);

  /// Mid-tint of primary, used for icon foregrounds and as the dark-theme
  /// "primary" (needs to read lighter against a near-black background).
  static const Color primaryLight = Color(0xFF355E3B);

  /// Darkest anchor, used for splash/gradient stops and dark-mode surfaces.
  static const Color primaryDark = Color(0xFF0A1A10);
  static const Color primarySurface = Color(0xFFE6F0E7);

  // ── Secondary (sage) ────────────────────────────────────────────────
  static const Color secondary = Color(0xFF8FAF93);

  // ── Accent (gold) ───────────────────────────────────────────────────
  static const Color accent = Color(0xFFC8A96A);
  static const Color accentLight = Color(0xFFDDC28E);
  static const Color accentDark = Color(0xFFA98A4F);

  // ── Neutrals ────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F2515);
  static const Color textSecondary = Color(0xFF666D69);
  static const Color textHint = Color(0xFF8C9389);
  static const Color divider = Color(0xFFD8D4D1);
  static const Color background = Color(0xFFF2F0EF);
  static const Color surface = Color(0xFFFFFFFF);

  /// Warm off-white surface reserved for general content cards, distinct
  /// from pure white (which is reserved for search fields/dialogs/sheets).
  static const Color card = Color(0xFFFBF8F5);

  static const Color scaffoldDark = Color(0xFF0A1610);
  static const Color surfaceDark = Color(0xFF13251A);
  static const Color cardDark = Color(0xFF1B3323);

  // ── Semantic ────────────────────────────────────────────────────────
  static const Color success = Color(0xFF3D8B5E);
  static const Color warning = Color(0xFFD8A441);
  static const Color error = Color(0xFFC85A5A);
  static const Color info = Color(0xFF4C8AB8);

  // ── Glassmorphism helpers (palette-agnostic alpha overlays) ────────
  static Color glassWhite = Colors.white.withValues(alpha: 0.15);
  static Color glassBorder = Colors.white.withValues(alpha: 0.25);
  static Color glassWhiteDark = Colors.white.withValues(alpha: 0.08);
  static Color glassBorderDark = Colors.white.withValues(alpha: 0.12);

  // ── Gradients ───────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryHover],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryDark, primary, primaryHover],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentLight],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [scaffoldDark, surfaceDark],
  );

  // ── Category icon containers ───────────────────────────────────────
  static const Color categoryIconBg = Color(0xFFE6F0E7);
  static const Color categoryIconBorder = Color(0xFF8FAF93);
  static const Color categoryIconFg = Color(0xFF355E3B);
  static const Color categoryIconSelectedBg = Color(0xFF0F2515);
  static const Color categoryIconSelectedFg = Colors.white;

  // ── Chips ───────────────────────────────────────────────────────────
  static const Color chipAvailableBg = Color(0xFFE6F0E7);
  static const Color chipAvailableFg = Color(0xFF355E3B);
  static const Color chipPopularBg = Color(0xFFFFF5E2);
  static const Color chipPopularFg = Color(0xFFC8A96A);
  static const Color chipPremiumBg = Color(0xFF0F2515);
  static const Color chipPremiumFg = Colors.white;

  // ── Offer cards ─────────────────────────────────────────────────────
  static const Color offerCardBg = Color(0xFF5D7A5D);
  static const Color offerCardFg = Colors.white;
  static const Color offerBadgeBg = Color(0xFFC8A96A);

  // ── Category-specific colors ────────────────────────────────────────
  // Retained for screens (e.g. provider skill-selection chips) that need
  // per-category visual distinction; the customer-facing category grid
  // uses the single consistent [categoryIconBg]/[categoryIconFg] treatment
  // above via ServiceCategoryUi instead of per-category hues.
  static const Color plumbing = Color(0xFF4C8AB8);
  static const Color electrical = Color(0xFFD8A441);
  static const Color carpentry = Color(0xFF8B6F47);
  static const Color otherCat = Color(0xFF666D69);
}
