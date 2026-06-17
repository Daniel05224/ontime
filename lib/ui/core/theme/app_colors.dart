import 'package:flutter/material.dart';

/// Semantic color tokens for the VibeTime design system.
///
/// Style direction: "Vibrant & Block-based" on a true-dark canvas.
/// A violet → pink duotone carries the brand, cyan + neon-green add energy.
/// Components should reference these tokens instead of raw hex values.
abstract final class AppColors {
  // ── Canvas & surfaces ────────────────────────────────────────────────
  /// App background. Near-black, slightly cool.
  static const canvas = Color(0xFF0B0B12);

  /// Default card / surface.
  static const surface = Color(0xFF15151F);

  /// Elevated surface (inputs, chips, nested cards).
  static const surfaceElevated = Color(0xFF1E1E2C);

  /// Highest surface (selected chips, hovered tiles).
  static const surfaceHigh = Color(0xFF2A2A3C);

  // ── Brand ────────────────────────────────────────────────────────────
  static const primary = Color(0xFF9480FF); // soft neon violet
  static const primaryBright = Color(0xFFBBA9FF);
  static const secondary = Color(0xFFFF72A8); // soft neon pink
  static const accent = Color(0xFF44D4F0); // soft neon cyan

  /// Live / online presence.
  static const live = Color(0xFF3DFFC0); // soft neon mint

  // ── Text ─────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFF4F4F8);
  static const textSecondary = Color(0xFFA6A6BE);
  static const textTertiary = Color(0xFF6B6B83);

  // ── Lines ────────────────────────────────────────────────────────────
  static const border = Color(0x14FFFFFF); // white @ 8%
  static const borderStrong = Color(0x26FFFFFF); // white @ 15%

  static const danger = Color(0xFFFF5470);

  // ── Signature gradients ──────────────────────────────────────────────
  /// Primary brand gradient (violet → pink). The duotone signature.
  static const brandGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const violetGradient = LinearGradient(
    colors: [primary, primaryBright],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Returns a soft two-stop gradient from any seed color.
  static LinearGradient duotone(Color color) => LinearGradient(
        colors: [color, Color.lerp(color, secondary, 0.35)!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // ── Period palette (Morning / Afternoon / Evening / Night) ──────────────
  static const morning = Color(0xFFFFCC70);   // soft neon amber
  static const afternoon = Color(0xFF44D4F0); // soft neon cyan
  static const evening = Color(0xFF9480FF);   // soft neon violet
  static const night = Color(0xFF7088FF);     // soft neon indigo

  static LinearGradient periodGradient(Color seed) => LinearGradient(
        colors: [seed, Color.lerp(seed, const Color(0xFF0B0B12), 0.45)!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
