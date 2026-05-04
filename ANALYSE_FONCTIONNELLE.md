# FilStock — Analyse fonctionnelle

App de gestion d'inventaire de bobines de filament 3D.
Entités : **Bobines** + **Supports de bobine**.

## 1. Bobine

### Attributs
- Marque (libre, auto-complétion depuis l'historique)
- Matière : PLA, PETG, ABS, ASA, TPU, NYLON, PA-CF, PLA-CF, PETG-CF, Autre + matières persos
- Couleur : 12 de base (Noir, Blanc, Gris, Rouge, Orange, Jaune, Vert, Bleu, Violet, Rose, Marron, Transparent) + persos + sélecteur HEX libre (nom auto-suggéré depuis la couleur de base la plus proche)
- Quantité : curseur 0–100 %, affichage simultané g (0–1000) + %
- Emballage : Sous vide / Ouvert
- Emplacement : Stock / En machine
- Type : Montée sur support / Recharge
- Support assigné (relation 1-à-1)
- Caractéristiques (multi) : Souple, Transparent, Brillant, Mat, Bois, Pierre, Carbone, Fibre de verre, Antistatique, Anti-feu
- Notes libres
- Code auto `MATIÈRE-COULEUR-NNN` (ex. `PLA-NOIR-001`), compteur incrémental par couple
- Dates de création + dernière modification

### Opérations
- Créer / éditer / supprimer (avec confirmation) / dupliquer (qty=100 %, support libéré)
- Auto-libération : assigner un support déjà pris désassigne l'ancienne bobine

### Défauts
Bambu, PLA, 100 %, Sous vide, Stock, Montée.

## 2. Support de bobine

- Types : 🔩 Normal (~60 °C, PLA), 🌡️ Haute temp (~90 °C, PETG/ABS), 🔥 Très haute temp (>90 °C, PA-CF)
- Notes (max 30 car.)
- ID auto `SUP-N/HT/THT-NN`, aperçu live du prochain ID
- Suppression bloquée si assigné
- Liste avec type, notes, bobine assignée
- Compteur "supports libres" dans les stats

## 3. Affichage

### Vues
- **Cartes** (grille) : pastille couleur + matière, badge code, marque + couleur, barre quantité, tags
- **Liste** : pastille ronde, code, infos, badges, icônes
- Bouton de bascule

### Codes visuels
- Pastille colorée + matière, texte noir/blanc auto selon luminance
- Barre quantité : vert >50 %, orange 21–50 %, rouge ≤20 %
- Cadre rouge + badge "⚠ PRESQUE VIDE" si ≤20 %
- Tags couleur par état (vacuum, open, inuse, stock, mounted, refill)
- Badges support colorés par type
- Badges traits avec icône + couleur dédiée

### Regroupement visuel (bobines redondantes)
- Effet pile (2 ghosts + badge ×N)
- Bobine principale priorisée : 1) en machine + qty mini, 2) ouverte + qty mini, 3) qty mini
- Stats agrégées : N, total g, % composite, X en machine / Y en stock, marques distinctes
- Alerte si ≥1 bobine ≤20 %
- Expansion / réduction du groupe
- Liste : en-tête de groupe + lignes indentées

## 4. Filtres / tri / recherche

- Chips : Tout / Ouvertes / Sous vide / En machine / En stock / ⚠ Presque vides — avec compteurs
- Regroupement : Mat+Couleur (défaut) / Matière / Couleur
- Tri : Défaut / Marque / Qté ↑ / Qté ↓ / Créé / Modifié
- Recherche libre (marque, matière, couleur, notes, code), debounce 150 ms
- Préférences regroupement + tri persistées

## 5. Stats globales

Affichées : bobines affichées, total, en machine, supports libres, presque vides (rouge).

## 6. Réglages

### Apparence
- Police globale 75–130 %
- Texte pastilles 50–200 %
- Boutons & icônes 70–150 %
- Thème clair / sombre

### Données persos
- Matières (majuscule auto, ≤12 car., refus doublons)
- Couleurs (HEX + nom, suggestion auto, refus doublons)
- Supports (ajout, liste, suppression bloquée si assigné)

## 7. Journal

### Événements tracés
Création / édition / suppression bobine et support, réassignation support. Diff champ par champ sur édition.

### Affichage
- Panneau dédié, onglets : Tout / 🧵 Bobines / 🔩 Supports
- Bouton "Effacer" avec confirmation
- Par entrée : icône action (✦ ✎ 🗑 🔗), code, libellé, temps relatif ("à l'instant", "il y a X min/h/j", date au-delà de 30 j), détail ancien → nouveau (libellés humains, formatage g/%, libellés états)

### Indicateur dernière modif
- Badge `🕐 JJ/MM HH:MM` dans le header, cliquable → journal

### Rétention
200 dernières entrées (rotation auto).

## 8. Import / Export

### Export JSON
- Inclut bobines + supports + version + date
- Nom auto `filstock-AAAA-MM-JJ.json`
- Sélecteur natif (app) / téléchargement (web)

### Import JSON
- Validation + sanitisation par enregistrement
- Choix : Fusion (dédup par ID) / Remplacement
- Migration auto (codes, dates, supportId manquants)
- Re-sync compteurs de codes après import
- Erreur explicite si invalide

## 9. Raccourcis clavier

- **N** : nouvelle bobine
- **/** : focus recherche
- **Échap** : fermer panel ouvert (modal > réglages > journal)
- **Ctrl/Cmd+Entrée** : enregistrer

## 10. Retours utilisateur

- Toasts : ajout / maj / suppression / duplication bobine, ajout matière/couleur, support créé/supprimé, export, import, journal effacé, doublon, support déjà assigné
- Tooltips au survol des badges/icônes
- Confirmations avant suppression bobine, effacement journal, remplacement import

## 11. Démarrage / persistance

- Sauvegarde locale auto (inventaire, journal, thème, vue, apparence, données persos)
- 7 bobines de démo au 1er lancement
- Vue vide explicite si inventaire vide
- Badge de version dans le header

## 12. Plateformes

Navigateur, Windows natif, Android natif. Expérience identique. Export/import pour migrer entre plateformes.
