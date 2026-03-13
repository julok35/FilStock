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

## CI GitHub Actions — règles obligatoires

### Icônes Tauri — ne jamais commiter des PNG générés manuellement

`tauri::generate_context!()` est une proc macro Rust qui **ouvre et décode** chaque fichier listé dans `bundle.icon` de `tauri.conf.json` au moment de la compilation. Un PNG trop petit ou mal formé provoque :

```
error: proc macro panicked — failed to open icon …/icons/icon.png: No such file or directory
```

**Règle :** les icônes doivent être **générées en CI** via `npx tauri icon`, jamais commitées manuellement. Le workflow génère une image source valide par Python, puis appelle `tauri icon` pour produire tous les formats.

```yaml
- name: Generate Tauri icons
  run: |
    python3 - <<'PYEOF'
    import struct, zlib, os
    def make_png(w, h, r=33, g=150, b=243):
        def chunk(tag, data):
            crc = zlib.crc32(tag + data) & 0xFFFFFFFF
            return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', crc)
        raw = b''.join(b'\x00' + bytes([r, g, b] * w) for _ in range(h))
        return (b'\x89PNG\r\n\x1a\n'
                + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
                + chunk(b'IDAT', zlib.compress(raw, 9))
                + chunk(b'IEND', b''))
    os.makedirs('src-tauri/icons', exist_ok=True)
    open('app-icon.png', 'wb').write(make_png(512, 512))
    PYEOF
    npx tauri icon app-icon.png
```

**`tauri.conf.json` doit lister les formats standards** (ceux que `tauri icon` génère) :

```json
"icon": [
  "icons/32x32.png",
  "icons/128x128.png",
  "icons/128x128@2x.png",
  "icons/icon.icns",
  "icons/icon.ico"
]
```

### Script `tauri` dans `package.json` — obligatoire

Gradle (`rustBuildArm64Debug`) appelle `npm run tauri` pendant la compilation Rust Android. Sans ce script, le build échoue avec `npm error Missing script: "tauri"`.

**`package.json` doit toujours contenir :**

```json
"scripts": {
  "tauri": "tauri",
  "dev": "tauri dev",
  "build": "tauri build",
  "android": "tauri android build"
}
```

### Cache Rust dans CI — désactivé jusqu'au premier build réussi

`Swatinem/rust-cache` peut restaurer un état partiel issu d'un run raté, ce qui fausse les compilations suivantes. Ne pas l'activer tant qu'un premier build complet n'a pas réussi.

## Checklist avant chaque commit

1. `npm run dev` → vérifier que l'app démarre sans erreur
2. Ajouter une bobine → quitter → relancer → vérifier que la bobine est présente
3. Tester thème clair et sombre : boutons visibles dans les cartes
4. Tester export/import via dialog natif (si modifié)
5. Bumper `APP_VERSION` si changement visible
