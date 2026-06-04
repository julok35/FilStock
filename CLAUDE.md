# CLAUDE.md — FilStock (Flutter)

Ce fichier guide Claude Code pour travailler sur la version **application native Flutter** de FilStock (Android + iOS).

> L'ancienne version navigateur (HTML/CSS/JS) reste disponible à titre de référence : `index.html` + `CLAUDE.web.md`. L'ancienne tentative Tauri a été remplacée par ce projet Flutter.

## Stack technique

| Composant | Technologie |
|-----------|-------------|
| Framework | **Flutter** (Dart) — Android + iOS (web pour tests) |
| Gestion d'état | `provider` (`ChangeNotifier`) |
| Stockage | Fichier JSON unique `filstock_data.json` dans le dossier documents de l'app (`path_provider`) |
| Export | `share_plus` (partage du fichier JSON) |
| Import | `file_picker` (sélection d'un `.json`) |

## Prérequis

```bash
# Flutter (canal stable, >= 3.27)
flutter --version

# Android : SDK + Java 17
# iOS : Xcode (macOS uniquement)
```

## Développement

```bash
flutter pub get            # dépendances
flutter run                # lance sur l'appareil/émulateur connecté
flutter analyze            # analyse statique (doit être propre)
flutter test               # tests unitaires
flutter build apk --release        # APK Android
flutter build ios --release --no-codesign   # build iOS (validation)
flutter build web                  # vérification rapide de compilation
```

## Architecture

```
lib/
├── main.dart                 ← bootstrap : Provider + MaterialApp (thème depuis le store)
└── src/
    ├── models.dart           ← Spool, Support, JournalEntry, FilamentColor, UiSettings (toJson/fromJson)
    ├── constants.dart        ← kBaseColors, kBaseMaterials, kTraits, libellés, kAppVersion
    ├── theme.dart            ← ThemeTokens (palette dark/light) + styles de tags
    ├── utils.dart            ← couleurs, codes, formatage (qtyToGrams, timeAgo…)
    ├── storage.dart          ← lecture/écriture du fichier JSON
    ├── store.dart            ← AppStore (ChangeNotifier) : état + persistance + règles métier
    └── ui/
        ├── home_screen.dart  ← écran principal (header, filtres, tri, stats, vues, export/import)
        ├── spool_views.dart  ← SpoolCard, SpoolGroupCard, SpoolListRow, en-têtes de groupe
        ├── spool_form.dart   ← feuille d'ajout/édition de bobine
        ├── settings_panel.dart ← réglages (échelles, supports, matières/couleurs custom)
        ├── journal_panel.dart  ← journal d'activité (filtres + diff)
        └── widgets.dart      ← Pastille, Tag, QtyBar, badges, toast
```

## Modèle de données — `filstock_data.json`

Format **identique** à la version web/Tauri (clés `id`, `brand`, `colorName`, `qty` 0-100, etc.) pour que l'import des anciens fichiers fonctionne :

```json
{
  "spools": [...],
  "supports": [...],
  "customColors": [...],
  "customMaterials": [...],
  "codeCounters": { "PLA-NOIR": 3 },
  "journal": [...],
  "lastModified": "2026-...",
  "theme": "dark",
  "groupMode": "material+color",
  "sortMode": "default",
  "settings": { "fontSize": 100, "pastille": 100, "btnSize": 100 }
}
```

**Bobine :** `{ id, brand, material, colorName, color(hex), qty(0-100), pack, loc, type, traits[], code, supportId, notes, createdAt, lastModified }`

## Règles permanentes

### Persistance
Toute mutation passe par une méthode de `AppStore`, qui appelle `_persist()` (notifyListeners + écriture différée 300 ms via `Storage`). Ne jamais muter l'état hors du store.

### Thème — zéro couleur hardcodée
Toutes les couleurs des widgets viennent de `ThemeTokens` (`tokens.bg`, `tokens.text`, `tokens.accent`, `tokens.border`, etc.) ou des helpers de `theme.dart`. Hiérarchie des fonds : `bg` (page) < `bg2` (cartes) < `bg3` (inputs, boutons internes). Un bouton dans une carte utilise `bg3`, jamais `bg2`.

### Versioning
Avant chaque commit avec changement visible, incrémenter `kAppVersion` dans `lib/src/constants.dart` :
- **Patch** (corrections, ajustements) : `3.0` → `3.1`
- **Feature** (nouvelle fonctionnalité) : `3.1` → `4.0`

Garder `version:` dans `pubspec.yaml` cohérent.

### Responsive
Utiliser `Wrap` / `SingleChildScrollView` pour tout conteneur multi-éléments. Tester en largeur ≤ 360px. La grille de cartes s'adapte via `LayoutBuilder` (2 colonnes minimum).

## CI — GitHub Actions

`.github/workflows/build-android.yml` :
1. `analyze` (Linux) : `flutter analyze` + `flutter test`
2. `build-android` (Linux) : `flutter build apk --release` → artefact `filstock-android-apk`
3. `build-ios` (macOS) : `flutter build ios --release --no-codesign`

## Checklist avant chaque commit

1. `flutter analyze` → aucun problème
2. `flutter test` → vert
3. Ajouter une bobine → relancer → vérifier qu'elle persiste
4. Tester thème clair **et** sombre (boutons visibles dans les cartes)
5. Tester export (partage) et import (fusion/remplacement)
6. Bumper `kAppVersion` si changement visible
