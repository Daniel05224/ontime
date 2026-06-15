import 'package:flutter/material.dart';

/// Motion tokens — one global rhythm so every animation feels related.
///
/// Guidance applied (UI/UX Pro Max §7):
/// micro-interactions 150–300ms, exit faster than enter, spring/ease-out
/// curves, staggered list entrance, and respect for reduced-motion.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 420);

  /// Exit ~65% of enter duration so dismissals feel responsive.
  static const exit = Duration(milliseconds: 180);

  /// Per-item delay for staggered list/grid entrances.
  static const stagger = Duration(milliseconds: 45);

  static const enterCurve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;
  static const emphasized = Curves.easeOutBack;

  /// True when the OS asks for reduced motion. Callers should fall back to
  /// instant / opacity-only transitions when this is set.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}

/// Spacing scale (4 / 8 dp rhythm).
abstract final class Insets {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

/// Corner-radius scale.
abstract final class Radii {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const pill = 999.0;
}
