---
tags: [lessons-learned, patterns/errors-to-avoid]
last_updated: 2026-03-28
---
# Erreurs à éviter

## Tauri v2

| Erreur | Symptôme | Correction |
|--------|----------|------------|
| `import('@tauri-apps/plugin-fs')` sans bundler | Exception silencieuse, API inaccessible | Utiliser `window.__TAURI__.fs` avec `withGlobalTauri: true` |
| Destructuring `window.__TAURI__.fs` hors try/catch | Sur Android : tous les boutons silencieux, aucun event listener enregistré | Placer le destructuring dans un try/catch |
| Icônes PNG trop petites commitées manuellement | `proc macro panicked — failed to open icon` à la compilation Rust | Générer en CI avec `npx tauri icon` |
| Pas de script `"tauri"` dans `package.json` | `npm error Missing script: "tauri"` lors du build Android Gradle | Ajouter `"tauri": "tauri"` dans scripts |
| `Swatinem/rust-cache` activé dès le départ | Restauration d'un état partiel → builds faussés | Désactiver jusqu'au premier build réussi |
| `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true` (booléen) | Comportement inattendu de l'action | Mettre en string : `"true"` |

## Frontend CSS

| Erreur | Symptôme | Correction |
|--------|----------|------------|
| Boutons dans carte avec `background: var(--bg2)` | Boutons invisibles en thème clair ou sombre | Utiliser `--bg3` pour les boutons dans des conteneurs `--bg2` |
| `display: flex` sans `flex-wrap: wrap` | Débordement horizontal sur mobile | Ajouter `flex-wrap: wrap` + breakpoint 600px |
| Couleurs hardcodées (`#abc`, `rgba(...)`) dans CSS composants | Thème cassé après changement | Utiliser `var(--token)` uniquement |
| Styles inline JS avec `rgba` absolues | Même problème que ci-dessus | Utiliser `var(--border)`, `var(--bg2)`, etc. |

## CI / Git

| Erreur | Symptôme | Correction |
|--------|----------|------------|
| `git push` direct depuis CI sur branche active | Exit code 1 (non-fast-forward) | `git pull --rebase origin "$BRANCH" || true` avant push |
| Push sans `permissions: contents: write` | 403 Forbidden depuis Actions | Déclarer la permission dans le job |
