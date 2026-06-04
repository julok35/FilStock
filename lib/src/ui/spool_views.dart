import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import 'widgets.dart';

String _packLabel(String p) => p == 'vacuum' ? '🔒 Sous vide' : '📦 Ouvert';
String _locLabel(String l) => l == 'inuse' ? '🖨 Machine' : '📦 Stock';
String _typeLabel(String ty) => ty == 'refill' ? '♻ Recharge' : '🔩 Support';

Color _qtyColor(int pct, ThemeTokens t) =>
    pct <= 20 ? t.danger : pct <= 50 ? t.warn : t.ok;

/// Carte d'une bobine unique.
class SpoolCard extends StatelessWidget {
  final Spool s;
  final AppStore store;
  final VoidCallback onTap;
  const SpoolCard({super.key, required this.s, required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = store.tokens;
    final alert = s.qty <= 20;
    final grams = qtyToGrams(s.qty);
    final pastilleFont = 26 * store.settings.pastille / 100;
    final sup = s.supportId != null
        ? store.supports.where((x) => x.id == s.supportId).firstOrNull
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: t.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: alert ? t.danger : t.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Zone visuelle (pastille)
            Stack(
              children: [
                Container(
                  height: 130,
                  color: t.bg3,
                  alignment: Alignment.center,
                  child: Pastille(hex: s.color, material: s.material, fontSize: pastilleFont),
                ),
                if (alert)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: t.danger,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('⚠ PRESQUE VIDE',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontFamily: kMono,
                              letterSpacing: 0.5)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s.brand} · ${s.colorName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: t.text, fontSize: 14, fontWeight: FontWeight.w700)),
                  if (s.code != null) ...[
                    const SizedBox(height: 6),
                    CodeBadge(code: s.code!, t: t),
                  ],
                  const SizedBox(height: 6),
                  Text(s.material,
                      style: TextStyle(color: t.text2, fontSize: 11, fontFamily: kMono)),
                  const SizedBox(height: 10),
                  QtyBar(pct: s.qty, t: t),
                  const SizedBox(height: 6),
                  Text('${grams}g · ${s.qty}%',
                      style: TextStyle(
                          color: _qtyColor(s.qty, t),
                          fontSize: 13,
                          fontFamily: kMono,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 5, runSpacing: 5, children: [
                    Tag(kind: s.pack, label: _packLabel(s.pack), t: t),
                    Tag(kind: s.loc, label: _locLabel(s.loc), t: t),
                    Tag(kind: s.type, label: _typeLabel(s.type), t: t),
                    if (sup != null)
                      SupportBadge(supportId: sup.id, type: sup.type, t: t),
                  ]),
                  if (s.traits.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: s.traits.map((id) => TraitBadge(traitId: id)).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte « groupe » repliée (bobines redondantes empilées).
class SpoolGroupCard extends StatelessWidget {
  final String groupKey;
  final List<Spool> group;
  final AppStore store;
  final VoidCallback onExpand;
  const SpoolGroupCard({
    super.key,
    required this.groupKey,
    required this.group,
    required this.store,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final t = store.tokens;
    final primary = store.primaryOf(group);
    final hasAlert = group.any((s) => s.qty <= 20);
    final n = group.length;
    final totalGrams = group.fold<int>(0, (a, s) => a + qtyToGrams(s.qty));
    final compositePct = (totalGrams / (n * 1000) * 100).round().clamp(0, 100);
    final inuse = group.where((s) => s.loc == 'inuse').length;
    final stock = group.where((s) => s.loc == 'stock').length;
    final statusParts = <String>[];
    if (inuse > 0) statusParts.add('$inuse en machine');
    if (stock > 0) statusParts.add('$stock en stock');
    final brands = group.map((s) => s.brand).toSet().toList();
    final brandStr = brands.length == 1 ? brands.first : '${brands.length} marques';
    final parts = groupKey.split('::');
    final material = store.groupMode == 'color' ? primary.material : parts[0];
    final colorName = store.groupMode == 'material'
        ? primary.colorName
        : (parts.length > 1 ? parts[1] : parts[0]);
    final pastilleFont = 26 * store.settings.pastille / 100;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Ombres « fantômes » des cartes empilées dessous
        Positioned.fill(
          child: Transform.rotate(
            angle: 0.026,
            child: Transform.translate(
              offset: const Offset(3, 9),
              child: Container(
                decoration: BoxDecoration(
                  color: t.bg2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.border),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Transform.rotate(
            angle: -0.026,
            child: Transform.translate(
              offset: const Offset(0, 5),
              child: Container(
                decoration: BoxDecoration(
                  color: t.bg2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.border),
                ),
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: t.bg2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hasAlert ? t.danger : t.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 130,
                color: t.bg3,
                alignment: Alignment.center,
                child: Pastille(hex: primary.color, material: material, fontSize: pastilleFont),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$brandStr · $colorName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: t.text, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(material,
                        style:
                            TextStyle(color: t.text2, fontSize: 11, fontFamily: kMono)),
                    const SizedBox(height: 10),
                    QtyBar(pct: compositePct, t: t),
                    const SizedBox(height: 6),
                    Text('${totalGrams}g total · $compositePct%',
                        style: TextStyle(
                            color: _qtyColor(compositePct, t),
                            fontSize: 13,
                            fontFamily: kMono,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(statusParts.join(' · '),
                        style:
                            TextStyle(color: t.text2, fontSize: 11, fontFamily: kMono)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onExpand,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: t.bg3,
                          foregroundColor: t.text2,
                          side: BorderSide(color: t.border),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('▼ Voir les $n bobines',
                            style: const TextStyle(fontSize: 11, fontFamily: kMono)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -5,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: hasAlert ? t.danger : t.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('×$n',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontFamily: kMono,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

/// Ligne de la vue liste.
class SpoolListRow extends StatelessWidget {
  final Spool s;
  final AppStore store;
  final VoidCallback onTap;
  final bool indent;
  const SpoolListRow({
    super.key,
    required this.s,
    required this.store,
    required this.onTap,
    this.indent = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = store.tokens;
    final alert = s.qty <= 20;
    final grams = qtyToGrams(s.qty);
    final sup = s.supportId != null
        ? store.supports.where((x) => x.id == s.supportId).firstOrNull
        : null;
    final listFont = 13 * store.settings.pastille / 100;

    return Padding(
      padding: EdgeInsets.only(left: indent ? 22 : 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: t.bg2,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: alert ? t.danger : t.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorFromHex(s.color),
                  shape: BoxShape.circle,
                  border: Border.all(color: t.border, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(s.material,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: textColorOn(s.color),
                          fontSize: listFont,
                          height: 1.1,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${s.brand} ${s.material} · ${s.colorName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: t.text, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Row(children: [
                      if (s.code != null) ...[
                        CodeBadge(code: s.code!, t: t),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(s.notes.isNotEmpty ? s.notes : ' ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: t.text2, fontSize: 11, fontFamily: kMono)),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text('${grams}g · ${s.qty}%',
                  style: TextStyle(
                      color: _qtyColor(s.qty, t),
                      fontSize: 13,
                      fontFamily: kMono)),
              if (sup != null) ...[
                const SizedBox(width: 8),
                SupportBadge(supportId: sup.id, type: sup.type, t: t),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// En-tête d'un groupe en vue liste.
class SpoolListGroupHeader extends StatelessWidget {
  final String groupKey;
  final List<Spool> group;
  final AppStore store;
  const SpoolListGroupHeader({
    super.key,
    required this.groupKey,
    required this.group,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final t = store.tokens;
    final primary = store.primaryOf(group);
    final hasAlert = group.any((s) => s.qty <= 20);
    final totalGrams = group.fold<int>(0, (a, s) => a + qtyToGrams(s.qty));
    final parts = groupKey.split('::');
    final material = store.groupMode == 'color' ? primary.material : parts[0];
    final colorName = store.groupMode == 'material'
        ? primary.colorName
        : (parts.length > 1 ? parts[1] : parts[0]);
    final shortMat = material.length > 4 ? material.substring(0, 4) : material;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: t.bg3,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: hasAlert ? t.danger : t.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorFromHex(primary.color),
              shape: BoxShape.circle,
              border: Border.all(color: t.border, width: 2),
            ),
            child: Text(shortMat,
                style: TextStyle(
                    color: textColorOn(primary.color),
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$material · $colorName',
                    style: TextStyle(
                        color: t.text, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${group.length} bobines · ${totalGrams}g total',
                    style: TextStyle(color: t.text2, fontSize: 11, fontFamily: kMono)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
