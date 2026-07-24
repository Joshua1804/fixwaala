import 'package:flutter/widgets.dart';

/// Whether the user has requested reduced motion at the OS/browser level.
///
/// Safe to read from `initState` (no `BuildContext` needed) as well as
/// `build`, so looping `AnimationController`s can skip `repeat()` entirely
/// instead of animating and then trying to suppress the result.
bool get prefersReducedMotion => WidgetsBinding
    .instance
    .platformDispatcher
    .accessibilityFeatures
    .disableAnimations;
