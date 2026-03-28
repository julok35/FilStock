---
tags: [lessons-learned, domain/tauri-v2-webview]
last_updated: 2026-03-28
source_files:
  - FilStock/CLAUDE.md
  - FilStock/src-tauri/tauri.conf.json
  - FilStock/src/index.html
  - FilStock/.github/workflows/build-android.yml
  - FilStock/package.json
---
# Tauri v2 — WebView sans bundler

## Bonnes pratiques

### Accès aux APIs Tauri — withGlobalTauri
Sans bundler (pas de Vite/webpack), la résolution npm des noms de packages échoue dans la WebView.
`import('@tauri-apps/plugin-fs')` lève une erreur silencieuse ou une exception non interceptée.

**Solution :** activer `withGlobalTauri: true` dans `tauri.conf.json` puis accéder via `window.__TAURI__` :
```js
const { readTextFile, writeTextFile, BaseDirectory } = window.__TAURI__.fs;
const { save, open } = window.__TAURI__.dialog;
```

Source : commit `203bc45` — _fix(native): correct Tauri API access and module scope issues_

---

### Fonctions globales avec type="module"
Un script `<script type="module">` isole son scope : les fonctions déclarées à l'intérieur ne sont **pas** accessibles depuis les attributs `onclick="..."` du HTML.

**Solution :** exposer toutes les fonctions appelées depuis le HTML via `Object.assign` à la fin du module :
```js
// Bloc "EXPOSITION GLOBALE" en fin de script
Object.assign(window, {
  openAdd, openEdit, deleteSpool, saveSpool, openSettings, /* ... */
});
```

Source : commit `203bc45`

---

### Persistance duale (Tauri + localStorage)
Pattern obligatoire pour chaque mutation de données :
1. Mettre à jour la variable JS en mémoire
2. Mettre à jour `_appData.X` (mirror in-memory du fichier JSON)
3. Appeler `_flushToDisk()` (écriture différée 300ms, fire-and-forget)
4. Conserver `localStorage.setItem(...)` comme fallback navigateur

```js
function save() {
  localStorage.setItem('filstock_v1', JSON.stringify(spools));
  _appData.spools = spools;
  _flushToDisk();
}
```

---

## Erreurs à éviter

### Android WebView — timing de window.__TAURI__.fs
Sur Android, `window.__TAURI__.fs` peut être `undefined` au moment où le module s'exécute, même si `__TAURI_INTERNALS__` est présent.

**Symptôme :** les boutons ne répondent pas malgré les animations CSS. Aucun addEventListener ni Object.assign(window) ne s'est enregistré.

**Cause :** un destructuring hors try/catch en tête de module lève une TypeError qui tue l'exécution du module entier.

**Correction :** placer la ligne de destructuring dans le bloc try/catch existant :
```js
try {
  const { readTextFile, writeTextFile, BaseDirectory } = window.__TAURI__.fs; // ← ici
  // ...
} catch(e) {
  // silencieux — app continue avec données par défaut
}
```

Source : commit `ce29edd` — _fix(android): protège l'accès window.__TAURI__.fs dans le try/catch_

---

## Patterns et recettes

### Icônes Tauri — génération en CI (jamais commitées manuellement)
`tauri::generate_context!()` est une proc macro Rust qui **ouvre et décode** chaque icône listée dans `bundle.icon` au moment de la compilation.
Un PNG trop petit ou mal formé provoque un panic à la compilation.

**Recette CI (GitHub Actions) :**
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

`tauri.conf.json` doit lister les formats standards (ceux que `tauri icon` génère) :
```json
"icon": ["icons/32x32.png", "icons/128x128.png", "icons/128x128@2x.png", "icons/icon.icns", "icons/icon.ico"]
```

Source : commit `ac9cecb` — _ci: générer les icônes Tauri en CI via npx tauri icon_

---

### Script "tauri" dans package.json — obligatoire pour Android
Gradle (`rustBuildArm64Debug`) appelle `npm run tauri` pendant la compilation Rust Android.
Sans ce script : build échoue avec `npm error Missing script: "tauri"`.

```json
"scripts": {
  "tauri": "tauri",
  "dev": "tauri dev",
  "build": "tauri build",
  "android": "tauri android build"
}
```

Source : commit `fe53a8f`

---

### Cache Rust en CI — Swatinem/rust-cache
`Swatinem/rust-cache` peut restaurer un état partiel issu d'un run raté, faussant les compilations suivantes.
**Ne pas l'activer avant le premier build complet réussi.**

Source : CLAUDE.md, section CI

---

### FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 — toujours une string
Dans les variables d'environnement GitHub Actions, `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` doit être une **string** :
```yaml
env:
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: "true"   # ✅ string
  # FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true   # ❌ booléen YAML
```

Source : commit `fe4a9df`

---

### git pull --rebase dans CI avant push
Lors d'un push depuis CI sur une branche active, un non-fast-forward est possible.
```bash
git pull --rebase origin "$BRANCH" || true
git push origin HEAD:"$BRANCH"
```

Source : commit `645f31f` — _ci: fix git push exit code 1 (non-fast-forward)_

---

## Références

- [Tauri v2 — withGlobalTauri](https://v2.tauri.app/reference/config/#withglobaltauri)
- [tauri icon CLI](https://v2.tauri.app/reference/cli/#icon)
- Commits FilStock clés : `203bc45`, `ce29edd`, `ac9cecb`, `fe53a8f`
