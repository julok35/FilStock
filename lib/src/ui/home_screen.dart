import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import 'journal_panel.dart';
import 'settings_panel.dart';
import 'spool_form.dart';
import 'spool_views.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.tokens;
    final bs = store.settings.btnSize / 100;
    final items = store.filtered;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg2,
        elevation: 0,
        titleSpacing: 16,
        title: Row(children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              children: [
                TextSpan(text: 'Fil', style: TextStyle(color: t.text)),
                TextSpan(text: 'Stock', style: TextStyle(color: t.accent)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: t.bg3,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.border),
            ),
            child: Text('v$kAppVersion',
                style: TextStyle(color: t.text2, fontSize: 10, fontFamily: kMono)),
          ),
        ]),
        actions: [
          _iconBtn(t, bs, store.theme == 'dark' ? Icons.dark_mode : Icons.light_mode,
              'Thème', store.toggleTheme),
          _iconBtn(t, bs, store.view == 'card' ? Icons.view_list : Icons.grid_view,
              'Vue', store.toggleView),
          _iconBtn(t, bs, Icons.upload_file, 'Exporter', () => _export(context, store)),
          _iconBtn(t, bs, Icons.download, 'Importer', () => _import(context, store)),
          _iconBtn(t, bs, Icons.history, 'Journal',
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const JournalPage()))),
          _iconBtn(t, bs, Icons.settings, 'Réglages',
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()))),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: t.accent,
        foregroundColor: Colors.white,
        onPressed: () => showSpoolForm(context, store),
        icon: const Icon(Icons.add),
        label: const Text('Bobine'),
      ),
      body: Column(
        children: [
          _filterBar(store, t),
          _sortBar(store, t),
          _statsBar(store, t, items.length),
          Expanded(
            child: items.isEmpty
                ? _empty(t)
                : (store.view == 'card'
                    ? _cardView(context, store, items)
                    : _listView(context, store, items)),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(ThemeTokens t, double scale, IconData icon, String tip,
          VoidCallback onTap) =>
      IconButton(
        tooltip: tip,
        iconSize: 20 * scale,
        color: t.text2,
        onPressed: onTap,
        icon: Icon(icon),
      );

  // ── Filtres ───────────────────────────────────────────────────────
  Widget _filterBar(AppStore store, ThemeTokens t) {
    final counts = store.filterCounts;
    final filters = {
      'all': 'Tout',
      'open': 'Ouvertes',
      'vacuum': 'Sous vide',
      'inuse': 'En machine',
      'stock': 'En stock',
      'alert': '⚠ Presque vides',
    };
    return Container(
      color: t.bg2,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.entries.map((e) {
                final n = counts[e.key] ?? 0;
                final label = n > 0 ? '${filters[e.key]} ($n)' : filters[e.key]!;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _chip(t, label, store.filter == e.key,
                      () => store.setFilter(e.key)),
                );
              }).toList(),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _sortBar(AppStore store, ThemeTokens t) {
    final groups = {'material+color': 'Mat.+Couleur', 'material': 'Matière', 'color': 'Couleur'};
    final sorts = {
      'default': 'Défaut',
      'brand': 'Marque',
      'qty-asc': 'Qté ↑',
      'qty-desc': 'Qté ↓',
      'date': 'Créé',
      'modified': 'Modifié',
    };
    return Container(
      color: t.bg2,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _sortLabel('Grouper', t),
          for (final e in groups.entries) ...[
            _chip(t, e.value, store.groupMode == e.key,
                () => store.setGroupMode(e.key)),
            const SizedBox(width: 6),
          ],
          Container(width: 1, height: 20, color: t.border),
          const SizedBox(width: 8),
          _sortLabel('Trier', t),
          for (final e in sorts.entries) ...[
            _chip(t, e.value, store.sortMode == e.key,
                () => store.setSortMode(e.key)),
            const SizedBox(width: 6),
          ],
        ]),
      ),
    );
  }

  Widget _sortLabel(String s, ThemeTokens t) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(s.toUpperCase(),
            style: TextStyle(
                color: t.text2,
                fontSize: 10,
                fontFamily: kMono,
                letterSpacing: 0.5)),
      );

  Widget _chip(ThemeTokens t, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
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

  // ── Recherche + stats ─────────────────────────────────────────────
  Widget _statsBar(AppStore store, ThemeTokens t, int shown) {
    Widget stat(String value, String label, {Color? color}) => Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color ?? t.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Text(label,
                  style: TextStyle(
                      color: color ?? t.text2, fontSize: 11, fontFamily: kMono)),
            ],
          ),
        );

    return Container(
      width: double.infinity,
      color: t.bg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: store.setSearch,
            style: TextStyle(color: t.text, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, color: t.text2, size: 18),
              hintText: 'Rechercher…',
              hintStyle: TextStyle(color: t.text2),
              filled: true,
              fillColor: t.bg3,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: t.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: t.accent),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              stat('$shown', 'affichées'),
              stat('${store.totalCount}', 'total'),
              stat('${store.inuseCount}', 'en machine'),
              if (store.supports.isNotEmpty)
                stat('${store.freeSupportCount}', 'supports libres'),
              if (store.alertCount > 0)
                stat('${store.alertCount}', '⚠ presque vides', color: t.danger),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _empty(ThemeTokens t) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🧵', style: TextStyle(fontSize: 52, color: t.text2)),
            const SizedBox(height: 16),
            Text('Aucune bobine',
                style: TextStyle(
                    color: t.text, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Ajoutez votre première bobine\navec le bouton "+ Bobine".',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.text2, fontSize: 13)),
          ],
        ),
      );

  // ── Vue cartes ────────────────────────────────────────────────────
  Widget _cardView(BuildContext context, AppStore store, List<Spool> items) {
    final groups = store.groups(items);
    return LayoutBuilder(builder: (ctx, constraints) {
      const spacing = 14.0;
      final cols = (constraints.maxWidth / 240).floor().clamp(2, 8);
      final tileWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;

      final blocks = <Widget>[];
      var run = <Widget>[];

      void flushRun() {
        if (run.isEmpty) return;
        blocks.add(Wrap(spacing: spacing, runSpacing: spacing, children: run));
        run = [];
      }

      for (final entry in groups) {
        final key = entry.key;
        final gs = entry.value;
        if (gs.length < 2) {
          run.add(SizedBox(
            width: tileWidth,
            child: SpoolCard(
              s: gs.first,
              store: store,
              onTap: () => showSpoolForm(context, store, existing: gs.first),
            ),
          ));
        } else if (store.expandedGroups.contains(key)) {
          flushRun();
          blocks.add(_expandedGroup(context, store, key, gs, tileWidth, spacing, cols));
        } else {
          run.add(SizedBox(
            width: tileWidth,
            child: SpoolGroupCard(
              groupKey: key,
              group: gs,
              store: store,
              onExpand: () => store.toggleGroup(key),
            ),
          ));
        }
      }
      flushRun();

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            blocks[i],
            if (i < blocks.length - 1) const SizedBox(height: spacing),
          ],
        ],
      );
    });
  }

  Widget _expandedGroup(BuildContext context, AppStore store, String key,
      List<Spool> gs, double tileWidth, double spacing, int cols) {
    final t = store.tokens;
    final primary = store.primaryOf(gs);
    final parts = key.split('::');
    final material = store.groupMode == 'color' ? primary.material : parts[0];
    final colorName = store.groupMode == 'material'
        ? primary.colorName
        : (parts.length > 1 ? parts[1] : parts[0]);
    final hasAlert = gs.any((s) => s.qty <= 20);
    final totalGrams = gs.fold<int>(0, (a, s) => a + qtyToGrams(s.qty));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasAlert ? t.danger : t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text('$material · $colorName',
                      style: TextStyle(
                          color: t.text, fontSize: 14, fontWeight: FontWeight.w700)),
                  Text('${gs.length} bobines · ${totalGrams}g total',
                      style:
                          TextStyle(color: t.text2, fontSize: 12, fontFamily: kMono)),
                  if (hasAlert)
                    Text('⚠ alerte stock',
                        style: TextStyle(color: t.danger, fontSize: 11)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => store.toggleGroup(key),
              child: Text('▲ Réduire',
                  style: TextStyle(color: t.text2, fontSize: 11, fontFamily: kMono)),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: gs
                .map((s) => SizedBox(
                      width: tileWidth,
                      child: SpoolCard(
                        s: s,
                        store: store,
                        onTap: () => showSpoolForm(context, store, existing: s),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Vue liste ─────────────────────────────────────────────────────
  Widget _listView(BuildContext context, AppStore store, List<Spool> items) {
    final groups = store.groups(items);
    final children = <Widget>[];
    for (final entry in groups) {
      final gs = entry.value;
      if (gs.length < 2) {
        children.add(SpoolListRow(
          s: gs.first,
          store: store,
          onTap: () => showSpoolForm(context, store, existing: gs.first),
        ));
      } else {
        children.add(SpoolListGroupHeader(
            groupKey: entry.key, group: gs, store: store));
        for (final s in gs) {
          children.add(SpoolListRow(
            s: s,
            store: store,
            indent: true,
            onTap: () => showSpoolForm(context, store, existing: s),
          ));
        }
      }
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: children.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => children[i],
    );
  }

  // ── Export / Import ───────────────────────────────────────────────
  Future<void> _export(BuildContext context, AppStore store) async {
    try {
      final json = store.exportJson();
      final dir = await getTemporaryDirectory();
      final name = 'filstock-${DateTime.now().toIso8601String().substring(0, 10)}.json';
      final file = File('${dir.path}/$name');
      await file.writeAsString(json);
      await Share.shareXFiles([XFile(file.path)], subject: 'Export FilStock');
      if (context.mounted) showToast(context, '✓ Export prêt à partager');
    } catch (e) {
      if (context.mounted) showToast(context, '❌ Erreur export : $e');
    }
  }

  Future<void> _import(BuildContext context, AppStore store) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      String content;
      if (f.bytes != null) {
        content = String.fromCharCodes(f.bytes!);
      } else if (f.path != null) {
        content = await File(f.path!).readAsString();
      } else {
        return;
      }

      bool merge = false;
      if (store.spools.isNotEmpty && context.mounted) {
        final choice = await showDialog<String>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Importer'),
            content: Text(
                'Fusionner avec vos ${store.spools.length} bobine(s) existante(s) ?\n\n'
                'Fusionner = ajoute les nouvelles (doublons ignorés)\n'
                'Remplacer = écrase tout l\'inventaire'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, 'cancel'),
                  child: const Text('Annuler')),
              TextButton(
                  onPressed: () => Navigator.pop(c, 'replace'),
                  child: const Text('Remplacer')),
              TextButton(
                  onPressed: () => Navigator.pop(c, 'merge'),
                  child: const Text('Fusionner')),
            ],
          ),
        );
        if (choice == null || choice == 'cancel') return;
        merge = choice == 'merge';
      }

      final res = store.importJson(content, merge: merge);
      if (context.mounted) {
        showToast(
            context,
            res.merged
                ? '✓ ${res.added} bobine(s) importée(s) par fusion'
                : '✓ ${res.added} bobine(s) importée(s)');
      }
    } catch (e) {
      if (context.mounted) showToast(context, '❌ Erreur d\'import : $e');
    }
  }
}
