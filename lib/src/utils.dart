import 'dart:math';
import 'package:flutter/material.dart';
import 'constants.dart';

/// Convertit un hex "#rrggbb" en [Color].
Color colorFromHex(String hex) {
  final h = hex.replaceAll('#', '');
  if (h.length != 6) return const Color(0xFF7A7A82);
  return Color(int.parse('FF$h', radix: 16));
}

String hexFromColor(Color c) {
  int ch(double v) => (v * 255).round() & 0xff;
  final r = ch(c.r).toRadixString(16).padLeft(2, '0');
  final g = ch(c.g).toRadixString(16).padLeft(2, '0');
  final b = ch(c.b).toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}

/// Couleur de texte (noir/blanc) selon la luminance perceptuelle (WCAG).
Color textColorOn(String hex) {
  final h = hex.replaceAll('#', '');
  if (h.length != 6) return Colors.white;
  final r = int.parse(h.substring(0, 2), radix: 16);
  final g = int.parse(h.substring(2, 4), radix: 16);
  final b = int.parse(h.substring(4, 6), radix: 16);
  final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  return lum > 0.55
      ? Colors.black.withValues(alpha: 0.75)
      : Colors.white.withValues(alpha: 0.92);
}

/// Distance euclidienne RGB — approximation rapide pour suggérer un nom.
double colorDistance(String h1, String h2) {
  List<int> p(String h) {
    final x = h.replaceAll('#', '');
    return [
      int.parse(x.substring(0, 2), radix: 16),
      int.parse(x.substring(2, 4), radix: 16),
      int.parse(x.substring(4, 6), radix: 16),
    ];
  }

  final a = p(h1), b = p(h2);
  return sqrt(pow(a[0] - b[0], 2) + pow(a[1] - b[1], 2) + pow(a[2] - b[2], 2)).toDouble();
}

/// Nom de la couleur de BASE la plus proche (jamais une couleur custom),
/// pour garantir des codes et un groupement cohérents.
String closestBaseColorName(String hex) {
  var best = kBaseColors.first;
  for (final c in kBaseColors) {
    if (colorDistance(hex, c.hex) < colorDistance(hex, best.hex)) best = c;
  }
  return best.name;
}

int qtyToGrams(int pct) => (pct * 10).round();

/// Niveau de stock : 'lo' (<=20), 'mid' (<=50), 'hi'.
String qtyLevel(int pct) => pct <= 20 ? 'lo' : pct <= 50 ? 'mid' : 'hi';

/// Identifiant unique (équivalent du uid() web).
String uid() {
  final t = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final r = Random().nextInt(1 << 32).toRadixString(36);
  return '$t$r';
}

/// "ASCII-safe" pour les codes : supprime accents et caractères non alphanum.
String _asciiUpper(String s) {
  const accents = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const plain = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final buf = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final idx = accents.indexOf(ch);
    buf.write(idx >= 0 ? plain[idx] : ch);
  }
  return buf.toString().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

/// Partie "MATÉRIAU-COULEUR" d'un code (sans le numéro).
String codeBase(String material, String colorName) {
  final mat = _asciiUpper(material);
  final matPart = mat.length > 8 ? mat.substring(0, 8) : mat;
  var col = _asciiUpper(colorName);
  if (col.isEmpty) {
    col = 'PERSO';
  } else if (col.length > 5) {
    col = col.substring(0, 5);
  }
  return '$matPart-$col';
}

String timeAgo(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final m = DateTime.now().difference(dt).inMinutes;
  if (m < 1) return "à l'instant";
  if (m < 60) return 'il y a $m min';
  final h = m ~/ 60;
  if (h < 24) return 'il y a ${h}h';
  final d = h ~/ 24;
  if (d < 30) return 'il y a ${d}j';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

String formatFieldValue(String field, dynamic value) {
  if (value == null || value == '') return 'aucun';
  switch (field) {
    case 'qty':
      final v = (value as num).toInt();
      return '${qtyToGrams(v)}g ($v%)';
    case 'pack':
      return value == 'vacuum' ? 'sous vide' : 'ouvert';
    case 'loc':
      return value == 'inuse' ? 'en machine' : 'en stock';
    case 'type':
      return value == 'mounted' ? 'sur support' : 'recharge';
    case 'traits':
      if (value is List) {
        return value.isEmpty ? 'aucun' : value.join(', ');
      }
      return value.toString();
    default:
      return value.toString();
  }
}

String supportTypeIcon(String type) =>
    type == 'normal' ? '🔩' : type == 'high-temp' ? '🌡️' : '🔥';
