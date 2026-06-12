# CLAUDE.md — FilStock Native (Tauri v2)

Ce fichier fournit les instructions à Claude Code pour travailler sur l'application native FilStock.

> La version navigateur historique (`index.html` à la racine + `CLAUDE.web.md`) a été **supprimée** — seule l'app Android est maintenue. La fenêtre desktop (`npm run dev`) ne sert que d'environnement de test.

## Stack technique

| Composant | Technologie |
|-----------|-------------|
| Framework natif | **Tauri v2** (cible : Android ; desktop en dev uniquement) |
| Frontend | HTML / CSS / JS vanilla en modules ES (WebView, sans bundler) |
| Backend | Rust (minimal — délégation de persistance) |
| Stockage | `filstock_data.json` dans `AppData` |
| Plugins | `@tauri-apps/plugin-fs`, `@tauri-apps/plugin-dialog` |
| Tests | `node --test` natif + jsdom (smoke test) |

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
npm install           # installer tauri-cli + plugins JS + jsdom (tests)
npm test              # tests unitaires + smoke test jsdom (rapide, sans Rust)
npm run dev           # lancer en mode développement (fenêtre desktop)
npm run android       # build Android (.apk)
```

## Architecture du projet

```
FilStock/
├── src/
│   ├── index.html          ← shell HTML statique uniquement (aucun JS inline)
│   ├── styles.css          ← tous les styles (tokens de thème en tête)
│   ├── fonts/              ← Baloo 2 embarquée (zéro dépendance réseau)
│   └── js/
│       ├── app.js          ← point d'entrée : chargement état, wiring, 1er rendu
│       ├── constants.js    ← APP_VERSION, couleurs/matières de base, traits, icônes
│       ├── utils.js        ← helpers purs (esc, couleurs, grammes…)
│       ├── store.js        ← état unique `state` + persistance (persist/flushNow)
│       ├── logic.js        ← logique métier PURE (codes, imports, groupes, diffs)
│       ├── render.js       ← rendu cartes/liste/stats
│       ├── ui.js           ← modal bobine, panneaux réglages & journal, import/export
│       ├── journal.js      ← journal des modifications
│       ├── dialogs.js      ← askConfirm/askChoice (confirm() natif INTERDIT)
│       └── overlays.js     ← historique + bouton retour Android
├── tests/
│   ├── logic.test.mjs      ← tests unitaires de logic.js / utils.js
│   └── smoke.test.mjs      ← démarre l'app dans jsdom, parcours principaux
├── src-tauri/              ← coque Rust (main.rs desktop dev, lib.rs Android)
├── package.json
├── AUDIT.md                ← audit de code (perf / modularité / ergonomie)
└── CLAUDE.md               ← ce fichier
```

**Pas de bundler** : les imports ES **relatifs** (`./logic.js`) fonctionnent dans la
WebView ; seuls les noms de packages npm (`import '@tauri-apps/...'`) échouent.
Les APIs Tauri s'utilisent via `window.__TAURI__.fs` / `window.__TAURI__.dialog`
(`withGlobalTauri: true`).

## Modèle de données — fichier JSON

Toutes les données sont stockées dans un seul fichier `filstock_data.json` (AppData) :

- Android : `/data/data/com.filstock.app/files/filstock_data.json`
- Desktop dev : `%APPDATA%\com.filstock.app\filstock_data.json`

```json
{
  "appVersion": "4.0",
  "initialized": true,
  "spools": [{ "...": "...", "weight": 1000 }],
  "supports": [...],
  "customColors": [...],
  "customMaterials": [...],
  "codeCounters": { "PLA-NOIR": 3 },
  "journal": [...],
  "lastModified": "2026-06-12T...",
  "theme": "dark",
  "groupMode": "material+color",
  "sortMode": "default",
  "settings": { "fontSize": 100, "pastille": 100, "btnSize": 100 }
}
```

- `initialized` : posé au premier lancement — **ne jamais re-seeder les données de
  démo** si l'utilisateur a vidé son inventaire.
- `weight` : capacité de la bobine en grammes (défaut 1000). Tout calcul de
  grammes passe par `spoolGrams(s)` / `groupTotals()` — jamais `qty * 10` en dur.
- `localStorage` n'est **plus écrit** (lecture one-shot de migration uniquement,
  dans `store.js`).

## Règle de persistance — OBLIGATOIRE

Toute mutation de données passe par l'objet `state` (store.js) puis :

```js
import { state, persist } from './store.js';
state.spools.push(spool);   // 1. muter state
persist();                  // 2. planifier l'écriture (debounce 300ms, durcie)
render();                   // 3. re-rendre si l'affichage change
```

`persist()` gère : debounce, ré-écriture si mutation pendant un flush, flush
immédiat sur `visibilitychange` (Android tue les apps en arrière-plan), écriture
atomique tmp + rename.

## Dialogues — confirm()/alert() INTERDITS

`confirm()` et `alert()` ne fonctionnent **pas** dans la WebView Tauri (retour
falsy silencieux, surtout Android). Utiliser `dialogs.js` :

```js
import { askConfirm, askChoice, showAlert } from './dialogs.js';
if (await askConfirm('Supprimer ?', { ok: 'Supprimer', danger: true })) { ... }
```

## Événements — délégation, jamais d'onclick inline

Aucun `onclick="..."` dans le HTML ni dans les templates générés. Les éléments
dynamiques portent des `data-*` (`data-spool-id`, `data-del-color`…) et les
listeners sont délégués dans `ui.js` / `app.js`. Ne jamais interpoler de
données utilisateur dans du code JS inline.

## Versioning

Avant chaque commit apportant une modification visible dans l'app, incrémenter
`APP_VERSION` dans `src/js/constants.js` :
- **Patch** (corrections, ajustements visuels) : bump du sous-numéro (ex. `4.0` → `4.1`)
- **Feature** (nouvelle fonctionnalité) : bump du numéro principal (ex. `4.1` → `5.0`)

## Thème sombre/clair — zéro couleur hardcodée

Toutes les couleurs dans les règles CSS doivent utiliser des tokens définis en
tête de `styles.css` (`var(--bg)`, `var(--tag-vacuum-bg)`, `var(--sup-ht-fg)`…).

**Interdit :** hex codes, `rgb()`, `rgba()` avec des valeurs absolues dans les
sélecteurs de composants. (Exception : les couleurs de `TRAITS` dans
`constants.js` sont des données, pas du style.)

## Responsive mobile & tactile

- `flex-wrap: wrap` obligatoire sur tout conteneur multi-éléments ;
  breakpoints `@media (max-width: 600px)` pour modals et grilles.
- **Pas d'interaction accessible uniquement au `:hover`** : tout ce qui est
  révélé au survol doit avoir un équivalent tactile (cf. `@media (hover: none)`).
- Le bouton retour Android doit fermer l'overlay ouvert, pas l'app
  (géré par `overlays.js` — utiliser `overlayShown()`/`overlayHidden()` pour
  tout nouvel overlay).

## Hiérarchie visuelle des tokens — boutons toujours distinguables

Les boutons dans les cartes/lignes doivent utiliser `--bg3` comme fond — jamais `--bg2`.

## Tests — obligatoires avant commit

```bash
npm test    # 5 secondes, sans toolchain Rust
```

- Toute nouvelle logique métier va dans `logic.js`/`utils.js` (purs, testables)
  avec un test dans `tests/logic.test.mjs`.
- Tout nouveau parcours UI important s'ajoute à `tests/smoke.test.mjs`.
- La CI exécute `npm test` AVANT le build APK (~25 min) : un test rouge
  économise un build perdu.

## CI GitHub Actions — règles obligatoires

### Icônes Tauri — ne jamais commiter des PNG générés manuellement

`tauri::generate_context!()` est une proc macro Rust qui **ouvre et décode** chaque fichier listé dans `bundle.icon` de `tauri.conf.json` au moment de la compilation. Un PNG trop petit ou mal formé provoque :

```
error: proc macro panicked — failed to open icon …/icons/icon.png: No such file or directory
```

**Règle :** les icônes doivent être **générées en CI** via `npx tauri icon`, jamais commitées manuellement (le workflow génère une image source par Python puis appelle `tauri icon`).

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

### Signature APK — keystore persistant

Le secret GitHub `ANDROID_KEYSTORE_BASE64` fournit un keystore stable (les mises
à jour s'installent par-dessus l'ancienne version). Sans le secret, le workflow
retombe sur un keystore éphémère et émet un warning. Ne pas supprimer ce
mécanisme.

### Cache Rust dans CI — désactivé jusqu'au premier build réussi

`Swatinem/rust-cache` peut restaurer un état partiel issu d'un run raté, ce qui fausse les compilations suivantes. Ne pas l'activer tant qu'un premier build complet n'a pas réussi.

## Checklist avant chaque commit

1. `npm test` → tout vert
2. `npm run dev` → vérifier que l'app démarre sans erreur
3. Ajouter une bobine → quitter → relancer → vérifier que la bobine est présente
4. Tester thème clair et sombre : boutons visibles dans les cartes
5. Tester export/import via dialog natif (si modifié)
6. Bumper `APP_VERSION` (src/js/constants.js) si changement visible
