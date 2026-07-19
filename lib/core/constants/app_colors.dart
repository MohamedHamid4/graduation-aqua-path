import 'package:flutter/material.dart';

/// AquaPath brand color system — White + Green theme.
/// Primary palette drawn directly from the AquaPath logo:
///   • "Aqua" → sky blue  (#2196F3)
///   • "Path" → lime green (#4CAF50)
///   • Water-drop outline → deep blue (#1565C0)
abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────
  static const aquaBlue = Color(0xFF2196F3);
  static const pathGreen = Color(0xFF4CAF50);
  static const deepBlue = Color(0xFF1565C0);
  static const Color bgCardHover = Color(0xFF2A3446);
  // ── Primary (Aqua blue) ───────────────────────────────────────────────
  static const primary = Color(0xFF2196F3);
  static const primaryDark = Color(0xFF1565C0);
  static const primaryLight = Color(0xFF64B5F6);

  // ── Success / Green (Path green) ──────────────────────────────────────
  static const success = Color(0xFF4CAF50);
  static const successDark = Color(0xFF388E3C);
  static const successLight = Color(0xFF81C784);

  // ── Semantic ──────────────────────────────────────────────────────────
  static const accent = Color(0xFF8BC34A); // yellow-green highlight
  static const danger = Color(0xFFEF5350);
  static const warning = Color(0xFFFF9800);
  static const info = Color(0xFF29B6F6); // light aqua

  // ── Backgrounds (White theme) ─────────────────────────────────────────
  static const bgPrimary = Color(0xFFFFFFFF); // pure white
  static const bgSecondary = Color(0xFFF5F9FF); // very light blue-white
  static const bgCard = Color(0xFFFFFFFF); // white cards
  static const bgTertiary = Color(0xFFF0F7FF); // slightly blue-tinted

  // ── Text ──────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFF1C2B3A);
  static const textSecondary = Color(0xFF4A5568);
  static const textMuted = Color(0xFF94A3B8);

  // ── Borders ───────────────────────────────────────────────────────────
  static const borderDefault = Color(0xFFE0EBF5);
  static const borderStrong = Color(0xFFB3CCE8);

  // ── Map ───────────────────────────────────────────────────────────────
  static const mapBg = Color(0xFFF0F7FF);

  // ── Gradients ─────────────────────────────────────────────────────────
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF2196F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const greenGradient = LinearGradient(
    colors: [Color(0xFF388E3C), Color(0xFF4CAF50)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF2196F3), Color(0xFF4CAF50)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    stops: [0.0, 0.5, 1.0],
  );

  static const splashGradient = LinearGradient(
    colors: [
      Color(0xFF0A3D6B),
      Color(0xFF1565C0),
      Color(0xFF2196F3),
      Color(0xFF4CAF50),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.3, 0.7, 1.0],
  );

  static const successGradient = LinearGradient(
    colors: [Color(0xFF388E3C), Color(0xFF66BB6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const emergencyGradient = LinearGradient(
    colors: [Color(0xFFEF5350), Color(0xFFE53935)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
