import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import 'widgets.dart';

class JournalPage extends StatelessWidget {
  const JournalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.tokens;
    final entries = store.filteredJournal;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg2,
        foregroundColor: t.text,
        title: const Text('📋 Journal'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Effacer tout le journal ?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Annuler')),
                    TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Effacer')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                store.clearJournal();
                showToast(context, '🗑 Journal effacé');
              }
            },
            child: Text('🗑 Effacer', style: TextStyle(color: t.danger)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              _tab(store, t, 'all', 'Tout'),
              const SizedBox(width: 6),
              _tab(store, t, 'spool', '🧵 Bobines'),
              const SizedBox(width: 6),
              _tab(store, t, 'support', '🔩 Supports'),
            ]),
          ),
          Divider(height: 1, color: t.border),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text('📋 Aucune entrée dans le journal.',
                        style: TextStyle(color: t.text2, fontSize: 13)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 5),
                    itemBuilder: (_, i) => _entryCard(entries[i], t),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tab(AppStore store, ThemeTokens t, String value, String label) {
    final active = store.journalFilter == value;
    return GestureDetector(
      onTap: () => store.setJournalFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? t.accent : t.bg3,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? t.accent : t.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : t.text2,
                fontSize: 11,
                fontFamily: kMono)),
      ),
    );
  }

  Widget _entryCard(JournalEntry e, ThemeTokens t) {
    final icon = kActionIcons[e.action] ?? '·';
    final label = kActionLabels[e.action] ?? e.action;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.bg3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            if (e.entityCode.isNotEmpty)
              Text(e.entityCode,
                  style: TextStyle(
                      color: t.accent,
                      fontSize: 11,
                      fontFamily: kMono,
                      fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Expanded(
              child: Text('${e.entityLabel} — $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: t.text, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Text(timeAgo(e.ts),
                style: TextStyle(color: t.text2, fontSize: 10, fontFamily: kMono)),
          ]),
          if (e.changes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _changeRows(e.changes, t),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _changeRows(List<FieldChange> changes, ThemeTokens t) {
    // Fusionne color + colorName en une seule ligne « Couleur ».
    final others =
        changes.where((c) => c.field != 'color' && c.field != 'colorName').toList();
    final colorName = changes.where((c) => c.field == 'colorName').firstOrNull;
    final hex = changes.where((c) => c.field == 'color').firstOrNull;
    final display = [...others];
    if (colorName != null) {
      display.add(colorName);
    } else if (hex != null) {
      display.add(hex);
    }
    return display.map((c) {
      final lbl = kFieldLabels[c.field] ?? c.field;
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('$lbl : ',
                style: TextStyle(color: t.text2, fontSize: 10, fontFamily: kMono)),
            Text(formatFieldValue(c.field, c.from),
                style: TextStyle(
                    color: t.danger,
                    fontSize: 10,
                    fontFamily: kMono,
                    decoration: TextDecoration.lineThrough)),
            Text(' → ',
                style: TextStyle(color: t.text2, fontSize: 10, fontFamily: kMono)),
            Text(formatFieldValue(c.field, c.to),
                style: TextStyle(color: t.ok, fontSize: 10, fontFamily: kMono)),
          ],
        ),
      );
    }).toList();
  }
}
