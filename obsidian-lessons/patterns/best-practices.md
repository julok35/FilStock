---
tags: [lessons-learned, patterns/best-practices]
last_updated: 2026-03-28
---
# Bonnes pratiques transversales

## CI/CD — GitHub Actions

### Génération d'artefacts binaires en CI, pas en local
Les artefacts qui résultent de transformations déterministes (icônes, assets générés, configs initialisées) doivent être générés **en CI**, pas commitées manuellement.
Raison : un fichier généré manuellement peut être trop petit, mal formé ou obsolète, et planter le build de manière cryptique.

Exemple : icônes Tauri générées via `npx tauri icon` depuis une image source Python → voir `domains/tauri-v2-webview.md`.

### Variables d'environnement — toujours des strings dans YAML
```yaml
env:
  MA_VAR: "true"   # ✅ string
  MA_VAR: true     # ❌ booléen YAML (peut être interprété différemment)
```

### Permissions GitHub Actions — contents:write requis pour git push
Si le workflow pousse des commits sur le repo (config générée, artefacts), déclarer :
```yaml
permissions:
  contents: write
```

### git push depuis CI — gérer le non-fast-forward
```bash
git pull --rebase origin "$BRANCH" || true
git push origin HEAD:"$BRANCH"
```

---

## Gestion des données

### Persistance duale — offline-first avec fallback
Pattern pour une app qui doit fonctionner à la fois en navigateur et en app native :
- Toujours écrire dans le stockage local (localStorage / fichier)
- Mettre à jour le mirror in-memory
- Ne jamais présupposer que le stockage natif est disponible (protéger avec try/catch)

### Normalisation des données importées
Toujours valider et normaliser les données venant de l'extérieur (import JSON, API) :
- Whitelister les valeurs autorisées (ne pas passer une valeur inconnue au DOM/état)
- Fournir des valeurs par défaut pour les champs manquants
- Filtrer les éléments invalides avant de les ajouter à l'état

---

## UX / Interface

### Versioning visible dans l'UI
Afficher la version de l'app dans l'interface. Bumper avant chaque commit visible.
Permet aux utilisateurs de confirmer qu'ils ont bien la dernière version.

### Thème sombre/clair — test obligatoire avant commit
Tout commit touchant des styles doit être validé dans les deux thèmes.
Les bugs de tokens CSS (couleur hardcodée, mauvais niveau de hiérarchie) ne se voient souvent que dans un des deux thèmes.
