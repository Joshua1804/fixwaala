/// Centralized animation durations so motion feels consistent app-wide.
class AppDurations {
  AppDurations._();

  /// Tap-down press feedback (buttons, category tiles).
  static const Duration pressScale = Duration(milliseconds: 120);

  /// Hover feedback on interactive surfaces (web/desktop).
  static const Duration hover = Duration(milliseconds: 200);

  /// Section/card fade-slide entrance.
  static const Duration entrance = Duration(milliseconds: 350);

  /// Delay between staggered entrances of items in a list/grid.
  static const Duration staggerStep = Duration(milliseconds: 60);

  /// Category/chip selected-state color transition.
  static const Duration selection = Duration(milliseconds: 220);

  /// Pulsing loading indicator cadence.
  static const Duration loadingPulse = Duration(milliseconds: 1200);

  /// Shimmer skeleton sweep cadence.
  static const Duration shimmerSweep = Duration(milliseconds: 1500);

  /// Gentle carousel/offer transitions.
  static const Duration carousel = Duration(milliseconds: 400);
}
