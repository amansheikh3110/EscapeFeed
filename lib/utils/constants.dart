import 'package:flutter/material.dart';

// ── Raw palette ───────────────────────────────────────────────────────────────
// Dark
const _dBg      = Color(0xFF09090B); // zinc-950
const _dSurface = Color(0xFF111113); // just above black
const _dCard    = Color(0xFF1C1C1E); // iOS dark card
const _dBorder  = Color(0xFF2C2C2E); // subtle divider
const _dText    = Color(0xFFF2F2F7); // iOS primary label
const _dTextSub = Color(0xFF8E8E93); // iOS secondary label
const _dTextMut = Color(0xFF3A3A3C); // iOS tertiary label
const _dAccent  = Color(0xFFA78BFA); // violet-400 — vivid on dark

// Light
const _lBg      = Color(0xFFF2F2F7); // iOS grouped background
const _lSurface = Color(0xFFFFFFFF);
const _lCard    = Color(0xFFFFFFFF);
const _lBorder  = Color(0xFFE5E5EA); // iOS separator
const _lText    = Color(0xFF000000);
const _lTextSub = Color(0xFF6C6C70); // iOS secondary
const _lTextMut = Color(0xFFAEAEB2); // iOS tertiary
const _lAccent  = Color(0xFF7C3AED); // violet-700 — readable on light

// Semantic (mode-independent)
const kColorSuccess = Color(0xFF34C759); // iOS green
const kColorWarning = Color(0xFFFF9500); // iOS orange
const kColorDanger  = Color(0xFFFF3B30); // iOS red

// ── Theme extension ───────────────────────────────────────────────────────────
@immutable
class CtrlColors extends ThemeExtension<CtrlColors> {
  final Color bg;
  final Color surface;
  final Color card;
  final Color border;
  final Color text;
  final Color textSub;
  final Color textMuted;
  final Color accent;

  const CtrlColors({
    required this.bg,
    required this.surface,
    required this.card,
    required this.border,
    required this.text,
    required this.textSub,
    required this.textMuted,
    required this.accent,
  });

  // Derived
  Color get accentSurface => accent.withValues(alpha: 0.13);
  Color get accentBorder  => accent.withValues(alpha: 0.35);
  Color get shadow        => Colors.black.withValues(alpha: 0.18);
  Color get successSurface => kColorSuccess.withValues(alpha: 0.12);
  Color get warningSurface => kColorWarning.withValues(alpha: 0.12);
  Color get dangerSurface  => kColorDanger.withValues(alpha: 0.12);

  // Named constructors
  static const dark = CtrlColors(
    bg: _dBg, surface: _dSurface, card: _dCard, border: _dBorder,
    text: _dText, textSub: _dTextSub, textMuted: _dTextMut, accent: _dAccent,
  );
  static const light = CtrlColors(
    bg: _lBg, surface: _lSurface, card: _lCard, border: _lBorder,
    text: _lText, textSub: _lTextSub, textMuted: _lTextMut, accent: _lAccent,
  );

  static CtrlColors of(BuildContext context) =>
      Theme.of(context).extension<CtrlColors>()!;

  @override
  CtrlColors copyWith({
    Color? bg, Color? surface, Color? card, Color? border,
    Color? text, Color? textSub, Color? textMuted, Color? accent,
  }) => CtrlColors(
    bg: bg ?? this.bg, surface: surface ?? this.surface,
    card: card ?? this.card, border: border ?? this.border,
    text: text ?? this.text, textSub: textSub ?? this.textSub,
    textMuted: textMuted ?? this.textMuted, accent: accent ?? this.accent,
  );

  @override
  CtrlColors lerp(CtrlColors? other, double t) {
    if (other == null) return this;
    return CtrlColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSub: Color.lerp(textSub, other.textSub, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

// ── Back-compat shim (used nowhere in new code, kept for safety) ──────────────
class AppColors {
  static const Color bgDark = _dBg;
  static const Color cardDark = _dCard;
  static const Color cardHeaderDark = _dCard;
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentBlue = Color(0xFF3D8EF1);
  static const Color accentPurple = _dAccent;
  static const Color accentMagenta = Color(0xFFEA4C89);
  static const Color green = kColorSuccess;
  static const Color orange = kColorWarning;
  static const Color red = kColorDanger;
  static const Color textPrimary = _dText;
  static const Color textSecondary = _dTextSub;
  static const Color textMuted = _dTextMut;
  static const Color borderDark = _dBorder;
  static const Color glassBorder = Color(0x18FFFFFF);
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF3D8EF1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [_dAccent, Color(0xFFEA4C89)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient redGradient = LinearGradient(
    colors: [kColorDanger, Color(0xFFF87171)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x1AFFFFFF), Color(0x05FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppStyles {
  static const TextStyle heading1 = TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _dText);
  static const TextStyle heading2 = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _dText);
  static const TextStyle subheading = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _dTextSub);
  static const TextStyle body = TextStyle(fontSize: 14, color: _dText, height: 1.4);
  static const TextStyle caption = TextStyle(fontSize: 12, color: _dTextMut);
  static const TextStyle captionBold = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _dTextSub);
  static const TextStyle statNumber = TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _dText);
  static const TextStyle cardTitle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _dText);
}

// Keep legacy NexusColors alias so nothing else breaks
class NexusColors {
  static const Color void_ = _dBg;
  static const Color surface = _dSurface;
  static const Color elevated = _dCard;
  static const Color overlay = _dBorder;
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonBlue = Color(0xFF3D8EF1);
  static const Color neonPurple = _dAccent;
  static const Color neonPink = Color(0xFFEA4C89);
  static const Color success = kColorSuccess;
  static const Color warning = kColorWarning;
  static const Color danger = kColorDanger;
  static const Color textBright = _dText;
  static const Color textPrimary = _dText;
  static const Color textSecondary = _dTextSub;
  static const Color textDim = _dTextMut;
  static const Color glassBg = Color(0x10FFFFFF);
  static const Color glassBorder = Color(0x18FFFFFF);
  static const LinearGradient cyberGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF3D8EF1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [_dAccent, Color(0xFFEA4C89)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient dangerGradient = LinearGradient(
    colors: [kColorDanger, Color(0xFFF87171)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient warningGradient = LinearGradient(
    colors: [kColorWarning, Color(0xFFFCD34D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient successGradient = LinearGradient(
    colors: [kColorSuccess, Color(0xFF4ADE80)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
