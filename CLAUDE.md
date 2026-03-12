# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**FilStock** is a single-file web application for managing 3D printer filament inventory. It has no build system, no dependencies, and no test suite — open `index.html` directly in any modern browser. All data persists in browser localStorage.

## Development

No build, install, or lint steps. To run the app, open `index.html` in a browser (double-click or `file://` URL). All logic, styles, and markup live in this one file (~1,500+ lines).

## Architecture

The entire application is `index.html`, structured as:

1. **CSS** (~380 lines): CSS custom properties for dark/light themes, responsive grid layout
2. **HTML** (~200 lines): Static shell — header, filter bar, stats bar, modal overlay, settings panel, journal panel
3. **JavaScript** (~900 lines): All application logic, inline in a `<script>` tag

### Data Model

State is stored in `localStorage` and loaded at startup. Key storage keys:

| Key | Contents |
|-----|----------|
| `filstock_v1` | Main spools array |
| `filstock_supports` | Support holders array |
| `filstock_custom_colors` / `filstock_custom_materials` | User-defined types |
| `filstock_code_counters` | Auto-increment counters per material-color key |
| `filstock_journal` | Activity log (max 200 entries) |
| `filstock_theme` / `filstock_fontSize` / etc. | UI settings |

**Spool object shape:**
```js
{ id, brand, material, colorName, color (hex), qty (0-100%), pack, loc, type, traits[], code, supportId, notes, createdAt, lastModified }
```

### JavaScript Module Layout (within the single `<script>` tag)

1. **Constants** — `BASE_COLORS`, `BASE_MATERIALS`, `TRAITS`
2. **Utilities** — `esc()` (HTML escape), `getTextColor()` (contrast)
3. **Persistence** — `save()`, `saveSettings()`, `saveSupports()` (write to localStorage)
4. **Code Generation** — `generateSpoolCode()` produces `MATERIAL-COLOR-###` codes; `syncCodeCounters()` keeps counters in sync
5. **Supports** — CRUD for physical holder objects (three temperature types: normal/high/very-high)
6. **Journal** — `addJournalEntry()` diffs before/after state; `renderJournal()` renders the log panel
7. **Rendering** — `render()` is the main re-render function; calls `renderCard()` / `renderListRow()` per spool; `getSpoolGroups()` groups by `material::colorName`
8. **Modal Forms** — `openAdd()`, `openEdit()`, `saveSpool()`, `deleteSpool()`
9. **Export/Import** — JSON download/upload via `exportJSON()` / `importJSON()`
10. **Settings** — `openSettings()`, `applyScales()`, custom color/material management
11. **Event Listeners** — wired at bottom of script
12. **Startup** — load from localStorage, call `render()`

### Key Behaviors to Know

- **Quantity** is stored as a 0–100 percentage; displayed in grams as `qty * 10` (rounded).
- **Alerts** trigger when `qty ≤ 20`.
- **Support assignment** is one-to-one: assigning a support removes it from its previous spool automatically.
- **Journal** diffs are field-by-field comparisons captured in `addJournalEntry()` before any mutation.
- `render()` rebuilds the entire view from state on every change — no partial DOM updates.

---

## Règles permanentes

### Versioning
Avant chaque commit apportant une modification visible dans l'appli, incrémenter `APP_VERSION` dans `index.html` :
- **Patch** (corrections, ajustements visuels) : bump du sous-numéro (ex. `1.3` → `1.4`)
- **Feature** (nouvelle fonctionnalité) : bump du numéro principal (ex. `1.3` → `2.0`)

La valeur affichée dans l'UI doit toujours refléter le dernier état committé.

### Thème sombre/clair — zéro couleur hardcodée
Toutes les couleurs dans les règles CSS doivent utiliser des tokens CSS (`var(--bg)`, `var(--text)`, `var(--accent)`, `var(--border)`, etc.).

**Interdit :** hex codes, `rgb()`, `rgba()` avec des valeurs absolues dans les sélecteurs de composants.

**Exception autorisée :** sélecteurs scopés `[data-theme="light"] .composant { … }` pour des surcharges light spécifiques, ou `[data-theme="dark"] .composant { … }` pour des surcharges dark spécifiques.

Cette règle s'applique aussi aux **styles inline injectés en JS** — utiliser `var(--border)`, `var(--bg2)`, etc. plutôt que des valeurs rgba absolues.

Pour les couleurs semi-transparentes basées sur l'accent, définir `--accent-rgb` dans `:root` et utiliser `rgba(var(--accent-rgb), .12)` plutôt que les valeurs rgb codées en dur.

### Responsive mobile — zéro débordement dans les conteneurs flex/grid

Tout conteneur `display: flex` contenant plusieurs boutons ou éléments d'action **doit** avoir `flex-wrap: wrap` ou être explicitement testé à ≤ 375px.

**Checklist obligatoire pour toute nouvelle UI :**
- Les footers de modal avec ≥ 2 boutons : `flex-wrap: wrap` + règle `@media (max-width: 600px)` avec `flex-direction: column-reverse` et `width: 100%` sur chaque bouton
- Les grilles 2 colonnes (`grid-template-columns: 1fr 1fr`) : prévoir un breakpoint `@media (max-width: 600px)` pour passer à `1fr`
- Le padding interne des modals/panels : réduire à `≤ 16px` horizontal sur mobile
- Les lignes `display: flex` sans `flex-wrap` : vérifier que les enfants ont `flex-shrink` ou `min-width: 0` pour éviter tout overflow caché

**Interdit :** ajouter un `display: flex` multi-éléments sur une ligne sans vérifier que cela reste lisible à 320px de large.

---

## Licensing Note

MIT license for personal/educational use. Commercial use requires contacting the author (see README.md).
