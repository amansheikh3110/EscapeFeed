import 'package:flutter/material.dart';

class NexusColors {
  // ── Core backgrounds ──────────────────────────────────────────────────────
  static const Color void_ = Color(0xFF02081A);      // Deepest bg
  static const Color surface = Color(0xFF080E1C);    // Card surface
  static const Color elevated = Color(0xFF0F1726);   // Elevated elements
  static const Color overlay = Color(0xFF192035);    // Overlays / track bg

  // ── Neon accents ──────────────────────────────────────────────────────────
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonBlue = Color(0xFF3D8EF1);
  static const Color neonPurple = Color(0xFF9B59FF);
  static const Color neonPink = Color(0xFFEA4C89);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // ── Text hierarchy ────────────────────────────────────────────────────────
  static const Color textBright = Color(0xFFF0F6FC);
  static const Color textPrimary = Color(0xFFCDD9E5);
  static const Color textSecondary = Color(0xFF768390);
  static const Color textDim = Color(0xFF3D4451);

  // ── Glass ─────────────────────────────────────────────────────────────────
  static const Color glassBg = Color(0x10FFFFFF);       // ~6% white
  static const Color glassBorder = Color(0x18FFFFFF);   // ~10% white
  static const Color glassHighlight = Color(0x06FFFFFF); // ~2% white

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient cyberGradient = LinearGradient(
    colors: [neonCyan, neonBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [neonPurple, neonPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFF87171)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFCD34D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ── Legacy aliases so no other file breaks ────────────────────────────────
class AppColors {
  static const Color bgDark = NexusColors.void_;
  static const Color cardDark = NexusColors.surface;
  static const Color cardHeaderDark = NexusColors.elevated;
  static const Color accentCyan = NexusColors.neonCyan;
  static const Color accentBlue = NexusColors.neonBlue;
  static const Color accentPurple = NexusColors.neonPurple;
  static const Color accentMagenta = NexusColors.neonPink;
  static const Color green = NexusColors.success;
  static const Color orange = NexusColors.warning;
  static const Color red = NexusColors.danger;
  static const Color textPrimary = NexusColors.textBright;
  static const Color textSecondary = NexusColors.textSecondary;
  static const Color textMuted = NexusColors.textDim;
  static const Color borderDark = NexusColors.overlay;
  static const Color glassBorder = NexusColors.glassBorder;
  static const LinearGradient primaryGradient = NexusColors.cyberGradient;
  static const LinearGradient purpleGradient = NexusColors.purpleGradient;
  static const LinearGradient redGradient = NexusColors.dangerGradient;
  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x1AFFFFFF), Color(0x05FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppStyles {
  static const TextStyle heading1 = TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: NexusColors.textBright, letterSpacing: -0.5);
  static const TextStyle heading2 = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: NexusColors.textBright, letterSpacing: -0.2);
  static const TextStyle subheading = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: NexusColors.textSecondary);
  static const TextStyle body = TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: NexusColors.textPrimary, height: 1.4);
  static const TextStyle caption = TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: NexusColors.textDim);
  static const TextStyle captionBold = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: NexusColors.textSecondary);
  static const TextStyle statNumber = TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: NexusColors.textBright, letterSpacing: -1.0);
  static const TextStyle cardTitle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: NexusColors.textBright);
}
