import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'constants.dart';
import 'models.dart';
import 'storage.dart';
import 'theme.dart';
import 'utils.dart';

/// État global de l'application + persistance + règles métier.
///
/// Porté fidèlement depuis la logique JS de la version web/Tauri :
/// codes uniques, journal avec diff, assignation de support 1-à-1, etc.
class AppStore extends ChangeNotifier {
  final Storage _storage;
  AppStore(this._storage);

  // ── Données persistées ──────────────────────────────────────────────
  List<Spool> spools = [];
  List<Support> supports = [];
  List<FilamentColor> customColors = [];
  List<String> customMaterials = [];
  Map<String, int> codeCounters = {};
  List<JournalEntry> journal = [];
  UiSettings settings = UiSettings();
  String theme = 'dark';
  String groupMode = 'material+color';
  String sortMode = 'default';
  String? lastModified;

  // ── État UI (non persisté) ──────────────────────────────────────────
  String view = 'card'; // 'card' | 'list'
  String filter = 'all';
  String searchQuery = '';
  final Set<String> expandedGroups = {};
  String journalFilter = 'all';

  Timer? _flushTimer;

  ThemeTokens get tokens =>
      theme == 'dark' ? ThemeTokens.dark : ThemeTokens.light;

  // ── Initialisation ──────────────────────────────────────────────────
  Future<void> init() async {
    final data = await _storage.load();
    if (data.isNotEmpty) {
      spools = _list(data['spools']).map((e) => Spool.fromJson(e)).toList();
      supports = _list(data['supports']).map((e) => Support.fromJson(e)).toList();
      customColors =
          _list(data['customColors']).map((e) => FilamentColor.fromJson(e)).toList();
      customMaterials =
          (data['customMaterials'] is List)
              ? (data['customMaterials'] as List).whereType<String>().toList()
              : [];
      codeCounters = (data['codeCounters'] is Map)
          ? (data['codeCounters'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()))
          : {};
      journal = _list(data['journal']).map((e) => JournalEntry.fromJson(e)).toList();
      if (data['settings'] is Map) {
        settings = UiSettings.fromJson((data['settings'] as Map).cast<String, dynamic>());
      }
      theme = (data['theme'] as String?) ?? 'dark';
      groupMode = (data['groupMode'] as String?) ?? 'material+color';
      sortMode = (data['sortMode'] as String?) ?? 'default';
      lastModified = data['lastModified'] as String?;
    }

    if (spools.isEmpty) _loadSampleData();

    _syncCodeCounters();
    _migrateSpools();
    notifyListeners();
  }

  List<Map<String, dynamic>> _list(dynamic v) => (v is List)
      ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
      : <Map<String, dynamic>>[];

  // ── Persistance ─────────────────────────────────────────────────────
  Map<String, dynamic> _toData() => {
        'spools': spools.map((s) => s.toJson()).toList(),
        'supports': supports.map((s) => s.toJson()).toList(),
        'customColors': customColors.map((c) => c.toJson()).toList(),
        'customMaterials': customMaterials,
        'codeCounters': codeCounters,
        'journal': journal.map((j) => j.toJson()).toList(),
        'lastModified': lastModified,
        'theme': theme,
        'groupMode': groupMode,
        'sortMode': sortMode,
        'settings': settings.toJson(),
      };

  /// Écriture différée (300 ms) pour éviter d'écrire à chaque frappe.
  void _flush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 300), () {
      _storage.save(_toData());
    });
  }

  /// Force une écriture immédiate (utile avant fermeture).
  Future<void> flushNow() async {
    _flushTimer?.cancel();
    await _storage.save(_toData());
  }

  void _persist({bool notify = true}) {
    _flush();
    if (notify) notifyListeners();
  }

  // ── Couleurs / matières ─────────────────────────────────────────────
  List<FilamentColor> get allColors => [...kBaseColors, ...customColors];
  List<String> get allMaterials => [...kBaseMaterials, ...customMaterials];

  // ── Codes uniques ───────────────────────────────────────────────────
  String generateSpoolCode(String material, String colorName) {
    final base = codeBase(material, colorName);
    codeCounters[base] = (codeCounters[base] ?? 0) + 1;
    return '$base-${codeCounters[base].toString().padLeft(3, '0')}';
  }

  void _syncCodeCounters() {
    for (final s in spools) {
      final code = s.code;
      if (code == null) continue;
      final parts = code.split('-');
      final num = int.tryParse(parts.last);
      if (num == null) continue;
      final base = parts.sublist(0, parts.length - 1).join('-');
      codeCounters[base] = (codeCounters[base] ?? 0) > num ? codeCounters[base]! : num;
    }
  }

  void _migrateSpools() {
    var changed = false;
    for (var i = 0; i < spools.length; i++) {
      final s = spools[i];
      if (s.code == null || s.code!.isEmpty) {
        s.code = generateSpoolCode(s.material, s.colorName);
        changed = true;
      }
    }
    if (changed) _flush();
  }

  // ── Journal ─────────────────────────────────────────────────────────
  void _addJournalEntry(JournalEntry entry) {
    journal.insert(0, entry);
    if (journal.length > 200) journal = journal.sublist(0, 200);
    lastModified = entry.ts;
  }

  List<FieldChange> _diffSpool(Spool oldS, Spool newS) {
    final changes = <FieldChange>[];
    final o = oldS.toJson(), n = newS.toJson();
    for (final f in kSpoolDiffFields) {
      if (jsonEncode(o[f]) != jsonEncode(n[f])) {
        changes.add(FieldChange(f, o[f], n[f]));
      }
    }
    return changes;
  }

  void clearJournal() {
    journal = [];
    lastModified = null;
    _persist();
  }

  void setJournalFilter(String f) {
    journalFilter = f;
    notifyListeners();
  }

  List<JournalEntry> get filteredJournal {
    if (journalFilter == 'spool') {
      return journal.where((e) => e.entityType == 'spool').toList();
    }
    if (journalFilter == 'support') {
      return journal.where((e) => e.entityType == 'support').toList();
    }
    return journal;
  }

  // ── CRUD bobines ────────────────────────────────────────────────────
  void saveSpool({
    String? editingId,
    required String brand,
    required String material,
    required int qty,
    required String pack,
    required String loc,
    required String type,
    required String notes,
    required List<String> traits,
    required String color,
    required String colorName,
    String? supportId,
  }) {
    final now = DateTime.now().toIso8601String();

    if (editingId != null) {
      final idx = spools.indexWhere((s) => s.id == editingId);
      if (idx < 0) return;
      final oldSnap = spools[idx].copyWith();
      // Règle 1-à-1 : un support assigné est retiré de son ancien porteur.
      if (supportId != null) {
        for (final s in spools) {
          if (s.supportId == supportId && s.id != editingId) {
            s.supportId = null;
            s.lastModified = now;
          }
        }
      }
      final updated = spools[idx].copyWith(
        brand: brand,
        material: material,
        qty: qty,
        pack: pack,
        loc: loc,
        type: type,
        notes: notes,
        traits: traits,
        color: color,
        colorName: colorName,
        supportId: supportId,
        lastModified: now,
      );
      spools[idx] = updated;
      final changes = _diffSpool(oldSnap, updated);
      if (changes.isNotEmpty) {
        _addJournalEntry(JournalEntry(
          ts: now,
          action: 'edited',
          entityType: 'spool',
          entityId: editingId,
          entityCode: updated.code ?? editingId,
          entityLabel: '$brand $material $colorName',
          changes: changes,
        ));
      }
    } else {
      if (supportId != null) {
        for (final s in spools) {
          if (s.supportId == supportId) {
            s.supportId = null;
            s.lastModified = now;
          }
        }
      }
      final code = generateSpoolCode(material, colorName);
      final spool = Spool(
        id: uid(),
        brand: brand,
        material: material,
        colorName: colorName,
        color: color,
        qty: qty,
        pack: pack,
        loc: loc,
        type: type,
        notes: notes,
        traits: traits,
        code: code,
        supportId: supportId,
        createdAt: now,
        lastModified: now,
      );
      spools.add(spool);
      _addJournalEntry(JournalEntry(
        ts: now,
        action: 'created',
        entityType: 'spool',
        entityId: spool.id,
        entityCode: code,
        entityLabel: '$brand $material $colorName',
        changes: const [],
      ));
    }
    _persist();
  }

  void deleteSpool(String id) {
    final s = spools.where((x) => x.id == id).firstOrNull;
    if (s != null) {
      _addJournalEntry(JournalEntry(
        ts: DateTime.now().toIso8601String(),
        action: 'deleted',
        entityType: 'spool',
        entityId: s.id,
        entityCode: s.code ?? s.id,
        entityLabel: '${s.brand} ${s.material} ${s.colorName}',
        changes: const [],
      ));
    }
    spools.removeWhere((x) => x.id == id);
    _persist();
  }

  /// Copie d'une bobine (quantité remise à 100 %, sans support).
  void duplicateSpool(String id) {
    final s = spools.where((x) => x.id == id).firstOrNull;
    if (s == null) return;
    final now = DateTime.now().toIso8601String();
    final code = generateSpoolCode(s.material, s.colorName);
    final copy = s.copyWith(
      id: uid(),
      code: code,
      qty: 100,
      supportId: null,
      createdAt: now,
      lastModified: now,
    );
    spools.add(copy);
    _addJournalEntry(JournalEntry(
      ts: now,
      action: 'created',
      entityType: 'spool',
      entityId: copy.id,
      entityCode: code,
      entityLabel: '${s.brand} ${s.material} ${s.colorName}',
      changes: const [],
    ));
    _persist();
  }

  // ── Supports ────────────────────────────────────────────────────────
  String generateSupportId(String type) {
    final prefix = {
          'normal': 'SUP-N',
          'high-temp': 'SUP-HT',
          'very-high-temp': 'SUP-THT',
        }[type] ??
        'SUP-N';
    var max = 0;
    for (final s in supports.where((s) => s.type == type)) {
      final n = int.tryParse(s.id.split('-').last) ?? 0;
      if (n > max) max = n;
    }
    return '$prefix-${(max + 1).toString().padLeft(2, '0')}';
  }

  String addSupport(String type, String notes) {
    final id = generateSupportId(type);
    supports.add(Support(id: id, type: type, notes: notes));
    _addJournalEntry(JournalEntry(
      ts: DateTime.now().toIso8601String(),
      action: 'support_created',
      entityType: 'support',
      entityId: id,
      entityCode: id,
      entityLabel: 'Support $id${notes.isNotEmpty ? ' · $notes' : ''}',
      changes: const [],
    ));
    _persist();
    return id;
  }

  /// Retourne false si le support est encore assigné (suppression refusée).
  bool deleteSupport(String id) {
    final holder = spools.where((s) => s.supportId == id).firstOrNull;
    if (holder != null) return false;
    supports.removeWhere((s) => s.id == id);
    _addJournalEntry(JournalEntry(
      ts: DateTime.now().toIso8601String(),
      action: 'support_deleted',
      entityType: 'support',
      entityId: id,
      entityCode: id,
      entityLabel: 'Support $id',
      changes: const [],
    ));
    _persist();
    return true;
  }

  Spool? supportHolder(String supportId) =>
      spools.where((s) => s.supportId == supportId).firstOrNull;

  // ── Couleurs / matières personnalisées ──────────────────────────────
  bool addMaterial(String value) {
    final v = value.trim().toUpperCase();
    if (v.isEmpty) return false;
    if (allMaterials.contains(v)) return false;
    customMaterials.add(v);
    _persist();
    return true;
  }

  void removeMaterial(int index) {
    customMaterials.removeAt(index);
    _persist();
  }

  bool addColor(String name, String hex) {
    final n = name.trim();
    if (n.isEmpty) return false;
    if (allColors.any((c) => c.name.toLowerCase() == n.toLowerCase())) return false;
    customColors.add(FilamentColor(n, hex));
    _persist();
    return true;
  }

  void removeColor(int index) {
    customColors.removeAt(index);
    _persist();
  }

  // ── Réglages / thème / vue ──────────────────────────────────────────
  void setSettings({int? fontSize, int? pastille, int? btnSize}) {
    if (fontSize != null) settings.fontSize = fontSize;
    if (pastille != null) settings.pastille = pastille;
    if (btnSize != null) settings.btnSize = btnSize;
    _persist();
  }

  void toggleTheme() {
    theme = theme == 'dark' ? 'light' : 'dark';
    _persist();
  }

  void toggleView() {
    view = view == 'card' ? 'list' : 'card';
    notifyListeners();
  }

  void setGroupMode(String mode) {
    groupMode = mode;
    expandedGroups.clear();
    _persist();
  }

  void setSortMode(String mode) {
    sortMode = mode;
    _persist();
  }

  void setFilter(String f) {
    filter = f;
    notifyListeners();
  }

  void setSearch(String q) {
    searchQuery = q;
    notifyListeners();
  }

  void toggleGroup(String key) {
    if (!expandedGroups.remove(key)) expandedGroups.add(key);
    notifyListeners();
  }

  // ── Filtrage / tri / groupement ─────────────────────────────────────
  List<Spool> get filtered {
    return spools.where((s) {
      switch (filter) {
        case 'open':
          if (s.pack != 'open') return false;
          break;
        case 'vacuum':
          if (s.pack != 'vacuum') return false;
          break;
        case 'inuse':
          if (s.loc != 'inuse') return false;
          break;
        case 'stock':
          if (s.loc != 'stock') return false;
          break;
        case 'alert':
          if (s.qty > 20) return false;
          break;
      }
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      final hay =
          '${s.brand}${s.material}${s.colorName}${s.notes}${s.code ?? ''}'
              .toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  List<Spool> _sorted(List<Spool> items) {
    if (sortMode == 'default') return items;
    final list = [...items];
    list.sort((a, b) {
      switch (sortMode) {
        case 'brand':
          return a.brand.toLowerCase().compareTo(b.brand.toLowerCase());
        case 'qty-asc':
          return a.qty - b.qty;
        case 'qty-desc':
          return b.qty - a.qty;
        case 'date':
          return b.createdAt.compareTo(a.createdAt);
        case 'modified':
          return (b.lastModified).compareTo(a.lastModified);
        default:
          return 0;
      }
    });
    return list;
  }

  /// Groupes ordonnés selon le mode courant.
  List<MapEntry<String, List<Spool>>> groups(List<Spool> items) {
    final sorted = _sorted(items);
    final map = <String, List<Spool>>{};
    for (final s in sorted) {
      final key = groupMode == 'material'
          ? s.material
          : groupMode == 'color'
              ? s.colorName
              : '${s.material}::${s.colorName}';
      map.putIfAbsent(key, () => []).add(s);
    }
    return map.entries.toList();
  }

  /// Règle de priorité d'affichage : en machine la plus basse, sinon ouverte
  /// la plus basse, sinon la plus basse tout court.
  Spool primaryOf(List<Spool> group) {
    final inuse = group.where((s) => s.loc == 'inuse').toList();
    if (inuse.isNotEmpty) return inuse.reduce((a, b) => a.qty <= b.qty ? a : b);
    final open = group.where((s) => s.pack == 'open').toList();
    if (open.isNotEmpty) return open.reduce((a, b) => a.qty <= b.qty ? a : b);
    return group.reduce((a, b) => a.qty <= b.qty ? a : b);
  }

  // ── Statistiques ────────────────────────────────────────────────────
  int get totalCount => spools.length;
  int get alertCount => spools.where((s) => s.qty <= 20).length;
  int get inuseCount => spools.where((s) => s.loc == 'inuse').length;
  int get freeSupportCount =>
      supports.length - spools.where((s) => s.supportId != null).length;

  Map<String, int> get filterCounts => {
        'all': spools.length,
        'open': spools.where((s) => s.pack == 'open').length,
        'vacuum': spools.where((s) => s.pack == 'vacuum').length,
        'inuse': spools.where((s) => s.loc == 'inuse').length,
        'stock': spools.where((s) => s.loc == 'stock').length,
        'alert': spools.where((s) => s.qty <= 20).length,
      };

  // ── Export / Import ─────────────────────────────────────────────────
  String exportJson() {
    final data = {
      'app': 'FilStock Julok',
      'version': 1,
      'appVersion': kAppVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'spools': spools.map((s) => s.toJson()).toList(),
      'supports': supports.map((s) => s.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Importe un JSON (export, fichier de données complet, ou tableau brut).
  /// [merge] true = fusion (doublons ignorés), false = remplacement.
  /// Retourne le nombre de bobines effectivement importées.
  ImportResult importJson(String raw, {required bool merge}) {
    final decoded = jsonDecode(raw);
    List importedSpools;
    List importedSupports = const [];
    if (decoded is List) {
      importedSpools = decoded;
    } else if (decoded is Map && decoded['spools'] is List) {
      importedSpools = decoded['spools'];
      if (decoded['supports'] is List) importedSupports = decoded['supports'];
    } else {
      throw const FormatException('Format invalide');
    }

    final validSpools = importedSpools
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .where((e) => e['id'] != null && e['material'] != null)
        .map((e) => Spool.fromJson(e))
        .toList();
    final validSupports = importedSupports
        .whereType<Map>()
        .map((e) => Support.fromJson(e.cast<String, dynamic>()))
        .toList();

    if (validSpools.isEmpty) {
      throw const FormatException('Aucune bobine valide trouvée');
    }

    int added;
    if (merge) {
      final existingIds = spools.map((s) => s.id).toSet();
      final newOnes = validSpools.where((s) => !existingIds.contains(s.id)).toList();
      spools = [...spools, ...newOnes];
      final existingSup = supports.map((s) => s.id).toSet();
      supports = [...supports, ...validSupports.where((s) => !existingSup.contains(s.id))];
      added = newOnes.length;
    } else {
      spools = validSpools;
      supports = validSupports;
      added = validSpools.length;
    }
    _syncCodeCounters();
    _migrateSpools();
    _persist();
    return ImportResult(added: added, merged: merge);
  }

  // ── Données d'exemple ───────────────────────────────────────────────
  void _loadSampleData() {
    final now = DateTime.now().toIso8601String();
    Spool s(String brand, String mat, String cn, String col, int qty, String pack,
        String loc, String type, List<String> traits, String notes) {
      return Spool(
        id: uid(),
        brand: brand,
        material: mat,
        colorName: cn,
        color: col,
        qty: qty,
        pack: pack,
        loc: loc,
        type: type,
        notes: notes,
        traits: traits,
        code: null,
        supportId: null,
        createdAt: now,
        lastModified: now,
      );
    }

    spools = [
      s('Bambu', 'PLA', 'Noir', '#1a1a1a', 85, 'open', 'inuse', 'mounted', [], ''),
      s('Bambu', 'PETG', 'Blanc', '#f0eeea', 30, 'open', 'inuse', 'mounted', [], ''),
      s('Bambu', 'PETG', 'Blanc', '#f0eeea', 100, 'vacuum', 'stock', 'refill', [],
          'Recharge neuve'),
      s('Bambu', 'ABS', 'Rouge', '#e83030', 15, 'open', 'stock', 'refill', [],
          'Presque vide !'),
      s('Bambu', 'ASA', 'Gris', '#7a7a82', 50, 'open', 'stock', 'mounted', [], ''),
      s('Polymaker', 'PLA', 'Bleu', '#1a78e8', 72, 'vacuum', 'stock', 'mounted', [],
          'Neuve'),
      s('Bambu', 'TPU', 'Orange', '#ff6d1f', 10, 'open', 'stock', 'refill',
          ['flexible'], ''),
    ];
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    super.dispose();
  }
}

class ImportResult {
  final int added;
  final bool merged;
  const ImportResult({required this.added, required this.merged});
}
