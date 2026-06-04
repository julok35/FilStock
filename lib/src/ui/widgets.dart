import 'package:flutter/material.dart';

import '../constants.dart';
import '../theme.dart';
import '../utils.dart';

const String kMono = 'monospace';

/// Pastille ronde colorée portant le nom du matériau.
class Pastille extends StatelessWidget {
  final String hex;
  final String material;
  final double size;
  final double fontSize;
  const Pastille({
    super.key,
    required this.hex,
    required this.material,
    this.size = 96,
    this.fontSize = 26,
  });

  @override
  Widget build(BuildContext context) {
    final bg = colorFromHex(hex);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          material,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColorOn(hex),
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
            height: 1.1,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

/// Barre de progression de quantité.
class QtyBar extends StatelessWidget {
  final int pct;
  final ThemeTokens t;
  const QtyBar({super.key, required this.pct, required this.t});

  @override
  Widget build(BuildContext context) {
    final lvl = qtyLevel(pct);
    final color = lvl == 'lo' ? t.danger : lvl == 'mid' ? t.warn : t.ok;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: pct / 100,
        minHeight: 5,
        backgroundColor: t.bg3,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

/// Petit tag (emballage / emplacement / type).
class Tag extends StatelessWidget {
  final String kind;
  final String label;
  final ThemeTokens t;
  const Tag({super.key, required this.kind, required this.label, required this.t});

  @override
  Widget build(BuildContext context) {
    final style = tagStyle(kind, t);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: style.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: style.fg,
          fontSize: 11,
          fontFamily: kMono,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Badge de support coloré selon le type de température.
class SupportBadge extends StatelessWidget {
  final String supportId;
  final String type;
  final ThemeTokens t;
  const SupportBadge({
    super.key,
    required this.supportId,
    required this.type,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final style = supportBadgeStyle(type, t);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: style.border),
      ),
      child: Text(
        '${supportTypeIcon(type)} $supportId',
        style: TextStyle(
          color: style.fg,
          fontSize: 10,
          fontFamily: kMono,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Badge de caractéristique (trait).
class TraitBadge extends StatelessWidget {
  final String traitId;
  const TraitBadge({super.key, required this.traitId});

  @override
  Widget build(BuildContext context) {
    final t = traitById(traitId);
    if (t == null) return const SizedBox.shrink();
    final c = colorFromHex(t.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.9)),
      ),
      child: Text(
        '${t.icon} ${t.label}',
        style: TextStyle(
          color: c,
          fontSize: 10,
          fontFamily: kMono,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Petite étiquette de code monospace accentuée.
class CodeBadge extends StatelessWidget {
  final String code;
  final ThemeTokens t;
  const CodeBadge({super.key, required this.code, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: t.accent.withValues(alpha: 0.25)),
      ),
      child: Text(
        code,
        style: TextStyle(
          color: t.accent,
          fontSize: 10,
          fontFamily: kMono,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

void showToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2200),
      ),
    );
}
