---
tags: [lessons-learned, domain/frontend-vanilla]
last_updated: 2026-03-28
source_files:
  - FilStock/CLAUDE.web.md
  - FilStock/CLAUDE.md
  - FilStock/src/index.html
---
# Frontend Vanilla (HTML/CSS/JS sans framework)

## Bonnes pratiques

### CSS tokens — zéro couleur hardcodée
Toutes les couleurs dans les règles CSS doivent utiliser des tokens CSS.

**Interdit :** hex codes, `rgb()`, `rgba()` avec des valeurs absolues dans les sélecteurs de composants.

**Autorisé :** sélecteurs scopés `[data-theme="light"] .composant { }` pour des surcharges spécifiques.

Pour les couleurs semi-transparentes basées sur l'accent :
```css
:root { --accent-rgb: 193, 95, 60; }
/* usage */
background: rgba(var(--accent-rgb), .12);
```

**Pourquoi :** les valeurs absolues survivent aux changements de thème et rendent des éléments invisibles ou illisibles.

---

### Hiérarchie de fonds — boutons toujours distinguables
Hiérarchie obligatoire : `--bg` (page) < `--bg2` (cartes, panels) < `--bg3` (inputs, hover, boutons).

**Règle :** les boutons *à l'intérieur* d'une carte ou d'une ligne (`.btn-small` dans `.list-row`, `.card-actions`) doivent utiliser `--bg3` — jamais `--bg2`.

**Symptôme d'erreur :** le bouton et son conteneur partagent le même token → bouton invisible au changement de thème.

**Checklist avant commit d'UI :**
1. Basculer thème clair → vérifier que tous les boutons d'action sont distincts de leur fond.
2. Basculer thème sombre → même vérification.

Source : commit `a16912f` (_Fix theme violations_), CLAUDE.web.md

---

### Responsive mobile — flex-wrap obligatoire
Tout conteneur `display: flex` multi-éléments **doit** avoir `flex-wrap: wrap`.

**Checklist :**
- Modal footers avec ≥ 2 boutons : `flex-wrap: wrap` + `@media (max-width: 600px)` avec `flex-direction: column-reverse` et `width: 100%` sur chaque bouton
- Grilles 2 colonnes : breakpoint `@media (max-width: 600px)` → `grid-template-columns: 1fr`
- Padding interne des modals : ≤ 16px horizontal sur mobile
- Lignes flex sans `flex-wrap` : vérifier `flex-shrink` ou `min-width: 0` sur les enfants

Source : commit `b318abc` (_fix(mobile): corriger le débordement_), CLAUDE.web.md

---

### Versioning sémantique affiché dans l'UI
Bumper `APP_VERSION` avant chaque commit avec changement visible :
- **Patch** (corrections, ajustements visuels) : sous-numéro (`2.0` → `2.1`)
- **Feature** (nouvelle fonctionnalité) : numéro principal (`2.1` → `3.0`)

La valeur affichée dans l'UI doit toujours refléter le dernier état committé.

---

### Debounce sur les inputs de recherche
150ms de délai sur l'événement `input` pour éviter des re-rendus excessifs :
```js
let _searchDebounce;
document.getElementById('searchInput').addEventListener('input', e => {
  searchQ = e.target.value;
  clearTimeout(_searchDebounce);
  _searchDebounce = setTimeout(render, 150);
});
```

---

## Erreurs à éviter

### Application monofichier — render() complet à chaque changement
Dans une app sans framework, reconstruire l'intégralité du DOM à chaque mutation (`render()` global) est acceptable jusqu'à quelques centaines d'éléments.
Au-delà, envisager une mise à jour partielle ciblée ou un virtual DOM minimal.

### Styles inline injectés en JS — appliquer la même règle
Les styles inline générés dynamiquement en JS doivent aussi utiliser `var(--border)`, `var(--bg2)`, etc. — pas de valeurs rgba absolues.

---

## Patterns et recettes

### Architecture monofichier (single-file app)
Structure d'une app HTML/CSS/JS vanilla complète en un seul fichier :
1. CSS (tokens, thèmes, layout, composants)
2. HTML (shell statique — header, modals, panels)
3. JS inline :
   - Constants → Utilities → Persistence → Business logic → Rendering → Modal Forms → Export/Import → Settings → Event Listeners → Startup

**Avantage :** zéro dépendance de build, déployable par double-clic.
**Limite :** au-delà de ~1500 lignes, la lisibilité souffre.

---

### Normalisation à l'import JSON
Toujours normaliser les données importées avant de les utiliser :
```js
function normalizeImportedSpool(s) {
  return {
    id:       s.id       || generateId(),
    material: s.material || 'PLA',
    // whitelist explicite des valeurs autorisées
    loc:  ['stock','inuse'].includes(s.loc)  ? s.loc  : 'stock',
    type: ['mounted','refill'].includes(s.type) ? s.type : 'mounted',
    // ...
  };
}
```

**Pourquoi :** les imports peuvent contenir des valeurs obsolètes ou inconnues qui cassent le rendu.

---

### Fusion vs remplacement à l'import
Proposer les deux options à l'utilisateur lors d'un import de données :
- Fusion : ne importer que les IDs absents (`existingIds.has(s.id)`)
- Remplacement : écraser tout

```js
const action = spools.length
  ? confirm(`Fusionner avec ${spools.length} éléments ?\nOK = fusionner\nAnnuler = remplacer`)
  : false;
```

---

## Références

- FilStock CLAUDE.web.md
- Commits clés : `b318abc`, `a16912f`, `4e2eb20`
