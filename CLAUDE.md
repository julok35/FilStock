# CLAUDE.md — FilStock Native (Tauri v2)

Ce fichier fournit les instructions à Claude Code pour travailler sur la version **application native** de FilStock (branche `native-app`).

> La version navigateur originale (branche `main`) est documentée dans `CLAUDE.web.md`.

## Stack technique

| Composant | Technologie |
|-----------|-------------|
| Framework natif | **Tauri v2** (Windows + Android) |
| Frontend | HTML / CSS / JS vanilla (WebView) |
| Backend | Rust (minimal — délégation de persistance) |
| Stockage | `filstock_data.json` dans `AppData` |
| Plugins | `@tauri-apps/plugin-fs`, `@tauri-apps/plugin-dialog` |

## Prérequis système

```bash
# Rust (obligatoire)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup update

# Node.js 18+ (pour tauri-cli)
node --version

# Android (pour la cible Android uniquement)
# → Android SDK avec NDK, Java 17, ANDROID_HOME défini
# → android target Rust : rustup target add aarch64-linux-android
```

## Développement

```bash
npm install           # installer tauri-cli + plugins JS
npm run dev           # lancer en mode développement (fenêtre desktop)
npm run build         # build Windows (.exe / .msi)
npm run android       # build Android (.apk)
```

## Architecture du projet

```
FilStock/
├── index.html              ← version navigateur (inchangée, branche main)
├── src/
│   └── index.html          ← version Tauri (frontend adapté)
├── src-tauri/
│   ├── src/
│   │   ├── main.rs         ← entry point Windows
│   │   └── lib.rs          ← entry point Android + plugins init
│   ├── build.rs
│   ├── capabilities/
│   │   └── default.json    ← permissions FS + dialog
│   ├── Cargo.toml
│   └── tauri.conf.json
├── package.json
├── CLAUDE.md               ← ce fichier (native)
└── CLAUDE.web.md           ← instructions version navigateur
```

## Modèle de données — fichier JSON

Toutes les données sont stockées dans un seul fichier `filstock_data.json` dans le répertoire AppData de l'OS :

- Windows : `%APPDATA%\com.filstock.app\filstock_data.json`
- Android : `/data/data/com.filstock.app/files/filstock_data.json`

**Structure du fichier :**
```json
{
  "spools": [...],
  "supports": [...],
  "customColors": [...],
  "customMaterials": [...],
  "codeCounters": { "PLA-NOIR": 3 },
  "journal": [...],
  "lastModified": "2026-03-12T...",
  "theme": "dark",
  "groupMode": "material+color",
  "sortMode": "default",
  "settings": { "fontSize": 100, "pastille": 100, "btnSize": 100 }
}
```

## APIs Tauri — accès sans bundler

`withGlobalTauri: true` dans `tauri.conf.json` expose les plugins sur `window.__TAURI__` :

```js
// FS
const { readTextFile, writeTextFile, BaseDirectory } = window.__TAURI__.fs;

// Dialog
const { save, open } = window.__TAURI__.dialog;
```

**Ne jamais utiliser** `import('@tauri-apps/plugin-fs')` — sans bundler, la résolution npm des package names échoue dans la WebView.

## Fonctions globales (type="module")

Le script principal est `type="module"`. Toutes les fonctions appelées depuis les `onclick="..."` du HTML doivent être exposées via `Object.assign(window, { ... })` à la fin du script (voir bloc "EXPOSITION GLOBALE" dans `src/index.html`).

## Règle de persistance — OBLIGATOIRE

Chaque mutation de données doit :
1. Mettre à jour la variable JS en mémoire
2. Mettre à jour `_appData.X` (mirror in-memory du fichier)
3. Appeler `_flushToDisk()` (écriture différée 300ms, fire-and-forget)
4. Conserver le `localStorage.setItem(...)` existant (fallback navigateur)

**Exemple :**
```js
// Correct
function save() {
  localStorage.setItem('filstock_v1', JSON.stringify(spools));
  _appData.spools = spools;
  _flushToDisk();
}
```

## Versioning

Avant chaque commit apportant une modification visible dans l'app, incrémenter `APP_VERSION` dans `src/index.html` :
- **Patch** (corrections, ajustements visuels) : bump du sous-numéro (ex. `2.0` → `2.1`)
- **Feature** (nouvelle fonctionnalité) : bump du numéro principal (ex. `2.1` → `3.0`)

## Thème sombre/clair — zéro couleur hardcodée

Toutes les couleurs dans les règles CSS doivent utiliser des tokens CSS (`var(--bg)`, `var(--text)`, `var(--accent)`, `var(--border)`, etc.).

**Interdit :** hex codes, `rgb()`, `rgba()` avec des valeurs absolues dans les sélecteurs de composants.

## Responsive mobile — zéro débordement dans les conteneurs flex/grid

`flex-wrap: wrap` obligatoire sur tout conteneur multi-éléments. Breakpoints `@media (max-width: 600px)` pour les modals et grilles.

## Hiérarchie visuelle des tokens — boutons toujours distinguables

Les boutons dans les cartes/lignes doivent utiliser `--bg3` comme fond — jamais `--bg2`.

## Checklist avant chaque commit

1. `npm run dev` → vérifier que l'app démarre sans erreur
2. Ajouter une bobine → quitter → relancer → vérifier que la bobine est présente
3. Tester thème clair et sombre : boutons visibles dans les cartes
4. Tester export/import via dialog natif (si modifié)
5. Bumper `APP_VERSION` si changement visible
