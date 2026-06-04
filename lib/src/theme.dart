import 'package:flutter/material.dart';

/// Palette « warm » Claude/Anthropic, reproduite depuis la version web.
/// Tous les widgets lisent leurs couleurs via ces tokens — aucune couleur
/// hardcodée ailleurs (cf. règle du projet).
class ThemeTokens {
  final Color bg; // fond page
  final Color bg2; // cartes, panels
  final Color bg3; // inputs, hover, boutons internes
  final Color border;
  final Color text;
  final Color text2;
  final Color accent;
  final Color accent2;
  final Color danger;
  final Color warn;
  final Color ok;
  final Brightness brightness;

  const ThemeTokens({
    required this.bg,
    required this.bg2,
    required this.bg3,
    required this.border,
    required this.text,
    required this.text2,
    required this.accent,
    required this.accent2,
    required this.danger,
    required this.warn,
    required this.ok,
    required this.brightness,
  });

  bool get isDark => brightness == Brightness.dark;

  static const ThemeTokens dark = ThemeTokens(
    bg: Color(0xFF141413),
    bg2: Color(0xFF1C1B18),
    bg3: Color(0xFF262420),
    border: Color(0xFF3A3733),
    text: Color(0xFFEDE8E1),
    text2: Color(0xFF9A9589),
    accent: Color(0xFFC15F3C),
    accent2: Color(0xFFD4805E),
    danger: Color(0xFFE05252),
    warn: Color(0xFFD4952C),
    ok: Color(0xFF2DB67D),
    brightness: Brightness.dark,
  );

  static const ThemeTokens light = ThemeTokens(
    bg: Color(0xFFF4F3EE),
    bg2: Color(0xFFFFFFFF),
    bg3: Color(0xFFEAE8E1),
    border: Color(0xFFD4D1C7),
    text: Color(0xFF1A1714),
    text2: Color(0xFF6B6659),
    accent: Color(0xFFC15F3C),
    accent2: Color(0xFFD4805E),
    danger: Color(0xFFE05252),
    warn: Color(0xFFD4952C),
    ok: Color(0xFF2DB67D),
    brightness: Brightness.light,
  );

  ThemeData toThemeData() {
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      canvasColor: bg2,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accent2,
        surface: bg2,
        error: danger,
        brightness: brightness,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: accent,
        inactiveTrackColor: bg3,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.15),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.3),
        selectionHandleColor: accent,
      ),
    );
  }
}

/// Couleurs des tags (emballage / emplacement / type) — adaptées au thème.
class TagStyle {
  final Color bg;
  final Color fg;
  final Color border;
  const TagStyle(this.bg, this.fg, this.border);
}

TagStyle tagStyle(String kind, ThemeTokens t) {
  // Versions sombres et claires reproduites depuis le CSS d'origine.
  final dark = t.isDark;
  switch (kind) {
    case 'vacuum':
      return dark
          ? const TagStyle(Color(0xFF1E3A5F), Color(0xFF5AAEFF), Color(0xFF2A4F7A))
          : const TagStyle(Color(0xFFDDEEFF), Color(0xFF1A4A80), Color(0xFFAACCEE));
    case 'open':
      return dark
          ? TagStyle(const Color(0xFF2E1A00), t.warn, const Color(0xFF4A2E00))
          : const TagStyle(Color(0xFFFFF3E0), Color(0xFF7A4500), Color(0xFFF0C070));
    case 'inuse':
      return dark
          ? TagStyle(const Color(0xFF0E2E1A), t.ok, const Color(0xFF1A4A2A))
          : const TagStyle(Color(0xFFE6F9EF), Color(0xFF1A6040), Color(0xFF80D4A8));
    case 'refill':
      return dark
          ? const TagStyle(Color(0xFF2A1A2E), Color(0xFFC084FF), Color(0xFF3D2450))
          : const TagStyle(Color(0xFFF5E6FF), Color(0xFF6A1A8A), Color(0xFFD4A0EE));
    case 'mounted':
      return dark
          ? const TagStyle(Color(0xFF0E2233), Color(0xFF60C8FF), Color(0xFF1A3A50))
          : const TagStyle(Color(0xFFE0F5FF), Color(0xFF0A4A6A), Color(0xFF80CCEE));
    case 'stock':
    default:
      return TagStyle(t.bg3, t.text2, t.border);
  }
}

/// Badge de support selon son type de température.
TagStyle supportBadgeStyle(String type, ThemeTokens t) {
  final dark = t.isDark;
  switch (type) {
    case 'high-temp':
      return dark
          ? TagStyle(const Color(0xFF2E1A00), t.warn, const Color(0xFF4A2E00))
          : const TagStyle(Color(0xFFFFF3E0), Color(0xFF7A4500), Color(0xFFF0C070));
    case 'very-high-temp':
      return dark
          ? const TagStyle(Color(0xFF2E0404), Color(0xFFFF7070), Color(0xFF4A1010))
          : const TagStyle(Color(0xFFFFEAEA), Color(0xFF8A1010), Color(0xFFEE9090));
    case 'normal':
    default:
      return dark
          ? const TagStyle(Color(0xFF1E3A5F), Color(0xFF5AAEFF), Color(0xFF2A4F7A))
          : const TagStyle(Color(0xFFDDEEFF), Color(0xFF1A4A80), Color(0xFFAACCEE));
  }
}
