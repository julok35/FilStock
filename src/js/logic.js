// Logique métier pure (testable sans DOM) : codes, migrations, imports,
// groupes, compteurs, diffs. Aucune dépendance au DOM ni à Tauri.
import { TRAITS, DEFAULT_WEIGHT } from './constants.js';
import { uid, spoolGrams, spoolCapacity } from './utils.js';

// ─── CODIFICATION UNIQUE ─────────────────────────────────────────────
// Produit des codes lisibles de type "PLA-NOIR-001"
// normalize('NFD') + replace : supprime les accents pour rester ASCII-safe (ex: "Bébé" → "BEBE")
export function generateSpoolCode(codeCounters, material, colorName) {
  const matPart   = material.toUpperCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^A-Z0-9]/g,'').slice(0,8);
  const colorPart = colorName.toUpperCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^A-Z0-9]/g,'').slice(0,5) || 'PERSO';
  const base = `${matPart}-${colorPart}`;
  codeCounters[base] = (codeCounters[base] || 0) + 1;
  return `${base}-${String(codeCounters[base]).padStart(3,'0')}`;
}

// Reconstruction des compteurs à partir des codes existants.
// Nécessaire après un import : évite que de nouvelles bobines dupliquent un code déjà présent.
export function syncCodeCounters(codeCounters, spools) {
  spools.forEach(s => {
    if (!s.code) return;
    const parts = s.code.split('-');
    const num = parseInt(parts[parts.length - 1]);
    if (isNaN(num)) return;
    const base = parts.slice(0, -1).join('-');
    codeCounters[base] = Math.max(codeCounters[base] || 0, num);
  });
  return codeCounters;
}

// Migration des anciennes bobines sans code/dates/poids — appelée au démarrage et à l'import.
// Garantit que tout l'inventaire est conforme au modèle de données actuel.
// Retourne true si quelque chose a changé (l'appelant décide de persister).
export function migrateSpools(spools, codeCounters) {
  let changed = false;
  spools.forEach(s => {
    if (!s.code) { s.code = generateSpoolCode(codeCounters, s.material, s.colorName); changed = true; }
    if (!s.createdAt)    { s.createdAt    = new Date().toISOString(); changed = true; }
    if (!s.lastModified) { s.lastModified = new Date().toISOString(); changed = true; }
    if (s.supportId === undefined) { s.supportId = null; changed = true; }
    if (!s.weight) { s.weight = DEFAULT_WEIGHT; changed = true; }
  });
  return changed;
}

// ─── SUPPORTS ────────────────────────────────────────────────────────
export function generateSupportId(supports, type) {
  const prefix = {normal:'SUP-N','high-temp':'SUP-HT','very-high-temp':'SUP-THT'}[type] || 'SUP-N';
  const max = Math.max(0, ...supports.filter(s => s.type === type).map(s => +(s.id.split('-').pop()) || 0));
  return `${prefix}-${String(max + 1).padStart(2,'0')}`;
}

// ─── IMPORT : SANITISATION ───────────────────────────────────────────
// Sanitise et normalise un objet bobine importé (JSON externe ou ancienne version).
// Chaque champ est validé ; les valeurs invalides sont remplacées par des défauts sûrs.
export function normalizeImportedSpool(s) {
  return {
    id:          (typeof s.id === 'string' && /^[\w-]+$/.test(s.id)) ? s.id : uid(),
    brand:       s.brand       || 'Inconnu',
    material:    s.material    || 'PLA',
    colorName:   s.colorName   || 'Personnalisée',
    color:       (s.color && /^#[0-9a-fA-F]{6}$/.test(s.color)) ? s.color : '#7a7a82',
    qty:         (typeof s.qty==='number' && s.qty>=0 && s.qty<=100) ? Math.round(s.qty) : 100,
    weight:      (typeof s.weight==='number' && s.weight>0 && s.weight<=20000) ? Math.round(s.weight) : DEFAULT_WEIGHT,
    pack:        ['vacuum','open'].includes(s.pack)    ? s.pack  : 'vacuum',
    loc:         ['stock','inuse'].includes(s.loc)     ? s.loc   : 'stock',
    type:        ['mounted','refill'].includes(s.type) ? s.type  : 'mounted',
    notes:       s.notes       || '',
    traits:      Array.isArray(s.traits) ? s.traits.filter(t => TRAITS.some(x=>x.id===t)) : [],
    code:        s.code        || null,
    supportId:   s.supportId   || null,
    createdAt:   s.createdAt   || new Date().toISOString(),
    lastModified:s.lastModified|| new Date().toISOString(),
  };
}
export function normalizeImportedSupport(s, supports) {
  return {
    id:    (typeof s.id === 'string' && /^[\w-]+$/.test(s.id)) ? s.id : generateSupportId(supports, s.type||'normal'),
    type:  ['normal','high-temp','very-high-temp'].includes(s.type) ? s.type : 'normal',
    notes: s.notes || ''
  };
}

// ─── FILTRES / COMPTEURS (une seule passe) ───────────────────────────
export function matchesFilter(s, filter) {
  if (filter === 'open')   return s.pack === 'open';
  if (filter === 'vacuum') return s.pack === 'vacuum';
  if (filter === 'inuse')  return s.loc  === 'inuse';
  if (filter === 'stock')  return s.loc  === 'stock';
  if (filter === 'alert')  return s.qty  <= 20;
  return true;
}

export function filterSpools(spools, filter, searchQ) {
  const q = (searchQ || '').toLowerCase();
  return spools.filter(s => matchesFilter(s, filter) &&
    (!q || (s.brand + s.material + s.colorName + (s.notes || '') + (s.code || '')).toLowerCase().includes(q)));
}

// Tous les compteurs en une seule itération de l'inventaire
export function computeCounts(spools) {
  const c = { all: spools.length, open: 0, vacuum: 0, inuse: 0, stock: 0, alert: 0, mountedSupports: 0 };
  for (const s of spools) {
    if (s.pack === 'open') c.open++; else if (s.pack === 'vacuum') c.vacuum++;
    if (s.loc === 'inuse') c.inuse++; else if (s.loc === 'stock') c.stock++;
    if (s.qty <= 20) c.alert++;
    if (s.supportId) c.mountedSupports++;
  }
  return c;
}

// ─── TRI / GROUPES ───────────────────────────────────────────────────
export function sortSpools(items, sortMode) {
  if (sortMode === 'default') return items;
  return [...items].sort((a, b) => {
    if (sortMode === 'brand')    return a.brand.localeCompare(b.brand);
    if (sortMode === 'material') return a.material.localeCompare(b.material);
    if (sortMode === 'color')    return a.colorName.localeCompare(b.colorName);
    if (sortMode === 'qty-asc')  return a.qty - b.qty;
    if (sortMode === 'qty-desc') return b.qty - a.qty;
    if (sortMode === 'date')     return new Date(b.createdAt) - new Date(a.createdAt);
    if (sortMode === 'modified') return new Date(b.lastModified||b.createdAt) - new Date(a.lastModified||a.createdAt);
    return 0;
  });
}

export function groupSpools(items, groupMode, sortMode) {
  const sorted = sortSpools(items, sortMode);
  const map = new Map();
  for (const s of sorted) {
    const key = groupMode === 'material' ? s.material
              : groupMode === 'color'    ? s.colorName
              : `${s.material}::${s.colorName}`;
    if (!map.has(key)) map.set(key, []);
    map.get(key).push(s);
  }
  return map;
}

// Règle métier de priorité d'affichage dans les groupes :
//   1. Bobine "en machine" avec la quantité la plus basse (celle en cours de consommation)
//   2. Sinon, bobine "ouverte" avec la quantité la plus basse (prochaine à utiliser)
//   3. Fallback : n'importe quelle bobine, qty la plus basse
export function getPrimarySpoolFromGroup(spools) {
  const inuse = spools.filter(s => s.loc === 'inuse');
  if (inuse.length) return inuse.reduce((a,b) => a.qty <= b.qty ? a : b);
  const open = spools.filter(s => s.pack === 'open');
  if (open.length) return open.reduce((a,b) => a.qty <= b.qty ? a : b);
  return spools.reduce((a,b) => a.qty <= b.qty ? a : b);
}

// Total de grammes restants et % composite d'un groupe (pondéré par la capacité réelle)
export function groupTotals(groupSpools) {
  const totalGrams = groupSpools.reduce((acc,s) => acc + spoolGrams(s), 0);
  const capacity   = groupSpools.reduce((acc,s) => acc + spoolCapacity(s), 0);
  const compositePct = Math.min(100, Math.round(totalGrams / capacity * 100));
  return { totalGrams, compositePct };
}

// ─── DIFF (journal) ──────────────────────────────────────────────────
// Compare deux snapshots d'objet sur les champs listés.
// JSON.stringify permet de comparer les arrays (traits[]) en profondeur.
export function diffEntity(oldObj, newObj, fields) {
  return fields.filter(f => JSON.stringify(oldObj[f]) !== JSON.stringify(newObj[f]))
               .map(f => ({ field: f, from: oldObj[f], to: newObj[f] }));
}
