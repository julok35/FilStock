import 'models.dart';

/// Version applicative affichée dans l'UI (voir règle de versioning du projet).
const String kAppVersion = '3.0';

/// Couleurs de base — identiques à la version web (utilisées aussi pour
/// retrouver un nom canonique via la couleur la plus proche).
const List<FilamentColor> kBaseColors = [
  FilamentColor('Noir', '#1a1a1a'),
  FilamentColor('Blanc', '#f0eeea'),
  FilamentColor('Gris', '#7a7a82'),
  FilamentColor('Rouge', '#e83030'),
  FilamentColor('Orange', '#ff6d1f'),
  FilamentColor('Jaune', '#ffd600'),
  FilamentColor('Vert', '#1db954'),
  FilamentColor('Bleu', '#1a78e8'),
  FilamentColor('Violet', '#8844ee'),
  FilamentColor('Rose', '#ff4dad'),
  FilamentColor('Marron', '#8b5e3c'),
  FilamentColor('Transparent', '#c8d8e8'),
];

const List<String> kBaseMaterials = [
  'PLA',
  'PETG',
  'ABS',
  'ASA',
  'TPU',
  'NYLON',
  'PA-CF',
  'PLA-CF',
  'PETG-CF',
  'Autre',
];

class Trait {
  final String id;
  final String label;
  final String icon;
  final String color; // hex
  const Trait(this.id, this.label, this.icon, this.color);
}

const List<Trait> kTraits = [
  Trait('flexible', 'Souple', '🫀', '#22c55e'),
  Trait('transparent', 'Transparent', '💎', '#7dd3fc'),
  Trait('glossy', 'Brillant', '✨', '#fbbf24'),
  Trait('matte', 'Mat', '🪨', '#94a3b8'),
  Trait('wood', 'Bois', '🪵', '#a16207'),
  Trait('stone', 'Pierre', '🪨', '#78716c'),
  Trait('carbon', 'Carbone', '⬛', '#1e293b'),
  Trait('fiberglass', 'Fibre de verre', '🔷', '#38bdf8'),
  Trait('antistatic', 'Antistatique', '⚡', '#f59e0b'),
  Trait('fireproof', 'Anti-feu', '🔥', '#ef4444'),
];

Trait? traitById(String id) {
  for (final t in kTraits) {
    if (t.id == id) return t;
  }
  return null;
}

const Map<String, String> kFieldLabels = {
  'brand': 'Marque',
  'material': 'Matière',
  'qty': 'Quantité',
  'pack': 'Emballage',
  'loc': 'Emplacement',
  'type': 'Type',
  'colorName': 'Couleur',
  'color': 'Couleur hex',
  'notes': 'Notes',
  'supportId': 'Support',
  'traits': 'Caractéristiques',
};

const List<String> kSpoolDiffFields = [
  'brand',
  'material',
  'qty',
  'pack',
  'loc',
  'type',
  'color',
  'colorName',
  'notes',
  'supportId',
  'traits',
];

const Map<String, String> kActionIcons = {
  'created': '✦',
  'edited': '✎',
  'deleted': '🗑',
  'support_created': '✦',
  'support_edited': '✎',
  'support_deleted': '🗑',
  'support_assigned': '🔗',
};

const Map<String, String> kActionLabels = {
  'created': 'Créée',
  'edited': 'Modifiée',
  'deleted': 'Supprimée',
  'support_created': 'Créé',
  'support_edited': 'Modifié',
  'support_deleted': 'Supprimé',
  'support_assigned': 'Réassigné',
};
