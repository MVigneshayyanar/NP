import 'package:flutter/material.dart';

/// Sensory AI Design Tokens — Single source of truth for all colors.
/// Based on the Section 3 color theme specification.
class AppColors {
  AppColors._();

  // ── Primary / Accent (Exact Lime Green #9DD65D) ──
  static const Color primaryGreen = Color(0xFF9DD65D); // Exact user color code
  static const Color primaryGreenLight = Color(0xFFBBEB82);
  static const Color primaryGreenDark = Color(0xFF7CB838);
  static const Color primaryGreenSoft = Color(0xFFEBF8DB);


  // ── Backgrounds ──
  static const Color background = Color(0xFFF9FAFC);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // ── Text ──
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ── Borders & Dividers ──
  static const Color border = Color(0xFFF0F1F3);
  static const Color divider = Color(0xFFF0F1F3);
  static const Color inputBorder = Color(0xFFE5E7EB);

  // ── Status Colors ──
  static const Color success = Color(0xFF9BDD53);
  static const Color warning = Color(0xFFF59E0B);
  static const Color critical = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Disabled / Inactive ──
  static const Color disabled = Color(0xFFE5E7EB);
  static const Color disabledText = Color(0xFF9CA3AF);

  // ── Score Ring Colors ──
  static const Color ringBackground = Color(0xFFF0F1F3);
  static const Color ringFill = Color(0xFF00BBA7); // Teal arc on environment score card

  // ── Chat Bubbles ──
  static const Color chatUserBubble = primaryGreen;
  static const Color chatAIBubble = Color(0xFFF3F4F6);
  static const Color chatUserText = Colors.white;
  static const Color chatAIText = textPrimary;

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGreen, primaryGreenLight],
  );

  static const LinearGradient chartGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x669BDD53), // 40% opacity lime
      Color(0x009BDD53), // 0% opacity lime
    ],
  );

  // ── Splash Screen ──
  static const Color splashBackground = primaryGreen;

}
