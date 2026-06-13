# Audit de code — FilStock (Tauri v2, cible Android)

Audit réalisé le 12/06/2026 sur `src/index.html` (1 860 lignes — tout le frontend),
`src-tauri/` (coque Rust minimale) et le workflow CI `build-android.yml`.

> **STATUT — appliqué en v4.0 (12/06/2026).** L'intégralité des recommandations
> ci-dessous a été implémentée : correctifs P0 (dialogues, re-seed, flush,
> keystore), ergonomie tactile P1, découpage en modules + store + suppression du
> fallback localStorage (P2), optimisations de rendu, tokens couleur, police
> embarquée et champ `weight` (P3). Tests : `npm test` (32 tests, unitaires +
> smoke jsdom). Seule action restante côté utilisateur : créer le secret GitHub
> `ANDROID_KEYSTORE_BASE64` (procédure commentée dans le workflow) pour une
> signature APK stable.

Verdict global : le code est propre, lisible, bien commenté et le modèle de données
est sain. Les vrais problèmes sont concentrés sur **trois bugs critiques pour
Android** et sur l'architecture mono-fichier qui freinera l'évolution.

---

## 1. Bugs critiques (à corriger en priorité)

### 1.1 `confirm()` / `alert()` ne fonctionnent pas dans la WebView Tauri
La WebView de Tauri (WRY) ne supporte pas les dialogues bloquants natifs :
`confirm()` retourne une valeur falsy sans afficher de dialogue.

Conséquences sur Android :
- **`deleteSpool()` (ligne ~1412) : impossible de supprimer une bobine** — le
  `confirm` échoue, la fonction sort.
- **`importJSON()` (ligne ~1503) : l'import remplace TOUT silencieusement** —
  `confirm` retourne falsy → branche « remplacer » toujours prise, même quand
  l'utilisateur voudrait fusionner. Risque de perte de l'inventaire.
- `clearJournal()` : impossible d'effacer le journal.

**Correctif :** utiliser `window.__TAURI__.dialog.ask()` / `.confirm()` (le plugin
dialog est déjà installé et autorisé dans les capabilities), ou mieux : une petite
modal de confirmation maison, cohérente avec le thème (cf. § 4.6).

### 1.2 Les données de démo réapparaissent si l'inventaire est vidé
`if (!spools.length) { spools = [ …7 bobines de démo… ] }` au démarrage
(ligne ~1822). Un utilisateur qui supprime toutes ses bobines retrouve les
7 bobines d'exemple au redémarrage.

**Correctif :** poser un drapeau `_appData.initialized = true` après le premier
seed et ne plus jamais re-seeder.

### 1.3 Persistance : risque de perte des dernières modifications
- Le flush est différé de 300 ms et **rien n'est écrit quand l'app passe en
  arrière-plan** — or Android tue les apps en arrière-plan sans préavis.
- Bug dans `_flushToDisk()` : si une mutation arrive pendant que l'écriture
  est en cours (`_flushScheduled` encore à `true`), elle est ignorée et ne sera
  écrite qu'à la mutation suivante.

**Correctifs :**
```js
// 1. re-planifier au lieu d'ignorer
let _dirty = false;
async function _doFlush() {
  do { _dirty = false; await writeTextFile(...); } while (_dirty);
  _flushScheduled = false;
}
function _flushToDisk() { _dirty = true; /* … schedule … */ }

// 2. flush immédiat quand l'app perd le focus
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'hidden') _doFlush();
});
```
Bonus robustesse : écrire dans `filstock_data.json.tmp` puis renommer, ou
conserver un `.bak` de la version précédente (protection contre un fichier
tronqué si l'app est tuée pendant l'écriture).

### 1.4 Police Google Fonts chargée depuis le réseau
`<link href="https://fonts.googleapis.com/...Baloo+2...">` : dans une app
native, c'est une dépendance réseau au démarrage. Hors connexion le wordmark
bascule en fallback ; avec une connexion lente, flash de rendu.

**Correctif :** embarquer le `.woff2` dans `src/fonts/` avec `@font-face`,
ou accepter le fallback système et supprimer les `<link>`.

---

## 2. Rapidité

L'app est rapide à l'échelle actuelle (< 100 bobines). Points à traiter pour
rester fluide en grandissant :

| # | Constat | Effet | Reco |
|---|---------|-------|------|
| 2.1 | `render()` reconstruit tout le DOM en `innerHTML` à chaque clic/frappe | OK < ~200 bobines, jank au-delà sur mobile | Garder l'approche, mais ne re-rendre que `viewContainer` quand stats inchangées ; passer à du rendu incrémental seulement si besoin réel |
| 2.2 | `supportBadgeHTML()` fait un `supports.find()` **par bobine rendue** ; `buildSupportSelect()` fait un `spools.find()` par support | O(n×m) à chaque rendu | Construire une `Map(supportId → support)` et une `Map(supportId → bobine)` une fois par rendu |
| 2.3 | `getFiltered()` + `renderStats()` + `updateFilterCounts()` ≈ 10 itérations complètes de `spools` par rendu | Marginal mais gratuit à corriger | Une seule passe `reduce` qui calcule tous les compteurs |
| 2.4 | Journal : `JSON.parse(localStorage…)` + `JSON.stringify` à **chaque** entrée et à chaque affichage | Parse/stringify répétés d'un tableau de 200 entrées | Garder `journal` en mémoire comme `spools`, persister via le mécanisme commun |
| 2.5 | Double persistance localStorage **+** fichier JSON à chaque mutation | `localStorage.setItem` est synchrone (bloque le main thread) et ne sert plus à rien maintenant que la version web est supprimée | Supprimer le fallback localStorage (garder une migration de lecture one-shot pour les anciennes installs) |

---

## 3. Modularité / évolutivité

### 3.1 Découper le mono-fichier (sans bundler — c'est possible)
Seule la résolution des **noms de packages npm** échoue sans bundler ; les
imports ES **relatifs** fonctionnent parfaitement dans la WebView. Structure cible :

```
src/
├── index.html          ← shell HTML uniquement
├── styles.css
├── fonts/
└── js/
    ├── app.js          ← bootstrap + wiring des événements
    ├── constants.js    ← BASE_COLORS, TRAITS, LABELS…
    ├── store.js        ← état + persistance (fichier + flush)
    ├── codes.js        ← generateSpoolCode, syncCodeCounters, migrations
    ├── journal.js
    ├── import-export.js
    └── render/
        ├── cards.js, list.js, stats.js
        └── panels.js   ← settings, journal, modal
```

### 3.2 Un store centralisé au lieu de la règle manuelle en 4 étapes
La règle « mutation → variable JS → `_appData.X` → `_flushToDisk()` →
`localStorage` » du CLAUDE.md est appliquée à la main à ~12 endroits. C'est
la source d'erreurs n°1 (le journal a déjà deux sources de vérité qui peuvent
diverger). Remplacer par :

```js
// store.js
export function mutate(fn) {
  fn(state);            // une seule source de vérité
  scheduleFlush();      // persistance automatique
  render();             // re-rendu automatique
}
```

### 3.3 Poids de bobine hardcodé à 1 kg
`qtyToGrams(pct) = pct * 10` suppose des bobines de 1 000 g partout (cartes,
groupes, stats). Ajouter un champ `spoolWeight` (défaut 1000) au modèle pour
supporter les bobines 250 g / 2 kg / 3 kg — migration triviale.

### 3.4 Violations de la règle « zéro couleur hardcodée »
`tag-vacuum`, `tag-open`, `support-badge-*`, les couleurs de `TRAITS`, etc.
utilisent des hex en dur dans les sélecteurs (lignes ~227-260) — la propre
règle du CLAUDE.md. Les promouvoir en tokens (`--tag-vacuum-bg`, …) pour que
les thèmes restent cohérents.

### 3.5 Robustesse des templates
- `onclick="openEdit('${s.id}')"` interpole des ids non échappés : un JSON
  importé avec un id contenant `'` casse le DOM (et ouvre un vecteur
  d'injection). → délégation d'événements + `data-id` partout (déjà fait pour
  `.btn-group-toggle`, généraliser).
- `font-family: ui-monospace, 'SF Mono'…` répétée ~15× en style inline dans
  les templates → une classe utilitaire `.mono`.

### 3.6 Zéro test
La logique pure (codes, `diffEntity`, groupes, `normalizeImportedSpool`) est
facilement extractible et testable avec vitest en ~30 min de setup. Un job
`npm test` en CI **avant** le build APK (25 min) éviterait de découvrir les
régressions après coup.

---

## 4. Ergonomie (usage Android / tactile)

| # | Constat | Reco |
|---|---------|------|
| 4.1 | `.card-actions` en `opacity:0` révélé au `:hover` → bouton ✎ invisible au tactile (le tap carte ouvre l'édition, le bouton est mort) | Supprimer le bouton sur mobile, ou l'afficher en permanence |
| 4.2 | Tooltips `.tip` basés sur `:hover` → inaccessibles au doigt (infos quantité/type perdues) | Mettre l'info dans le contenu sur mobile, ou retirer les tooltips |
| 4.3 | Bouton **retour Android** ferme l'app même quand une modal/panneau est ouvert | Pousser un état `history.pushState` à l'ouverture des overlays et fermer sur `popstate` |
| 4.4 | Thème par défaut « dark » fixe | Initialiser avec `matchMedia('(prefers-color-scheme: dark)')` au premier lancement |
| 4.5 | Slider quantité peu précis au doigt | Ajouter des boutons rapides −10 % / +10 % et/ou une saisie directe en grammes — c'est l'action la plus fréquente de l'app |
| 4.6 | Dialogues `confirm/alert` natifs (cf. § 1.1) | Modal de confirmation maison aux couleurs du thème |
| 4.7 | Recherche : champ 130 px sur mobile, pas de bouton effacer | `type="search"` (croix native) + élargir quand focus |

---

## 5. CI / distribution

| # | Constat | Reco |
|---|---------|------|
| 5.1 | Workflow déclenché uniquement sur des branches obsolètes (`native-app`, anciennes branches `claude/…`) | ✅ Corrigé dans cet audit : déclenchement sur `main` |
| 5.2 | **Keystore de debug régénéré à chaque run** → chaque APK a une signature différente : Android **refuse la mise à jour** par-dessus l'installation précédente (il faut désinstaller, donc perdre les données… heureusement dans AppData) | Stocker un keystore persistant en secret GitHub (`base64`) et signer toujours avec |
| 5.3 | `tauri android init` + commit de `gen/android` à chaque run, `git pull --rebase \|\| true` fragile | `gen/android` est déjà commité : supprimer l'étape init/commit, ou la conditionner à l'absence du dossier |
| 5.4 | Pas de cache Rust → ~25 min par build | Une fois un build vert en place, activer `Swatinem/rust-cache` (la règle CLAUDE.md le permet après le premier build réussi) |

---

## 6. Plan d'action recommandé

1. **P0 — fiabilité Android** : § 1.1 (confirm), 1.2 (re-seed démo), 1.3 (flush),
   5.2 (keystore persistant). Petits patchs, gros impact.
2. **P1 — ergonomie tactile** : § 4.1, 4.3, 4.5, 4.6.
3. **P2 — dette** : découpage en modules + store (§ 3.1, 3.2), suppression du
   fallback localStorage (§ 2.5), tests (§ 3.6).
4. **P3 — confort** : optimisations de rendu (§ 2.x), tokens couleur (§ 3.4),
   police embarquée (§ 1.4), `spoolWeight` (§ 3.3).
