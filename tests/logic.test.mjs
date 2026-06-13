// Tests unitaires de la logique métier pure (node --test, zéro dépendance).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  generateSpoolCode, syncCodeCounters, migrateSpools, generateSupportId,
  normalizeImportedSpool, normalizeImportedSupport,
  filterSpools, computeCounts, sortSpools, groupSpools,
  getPrimarySpoolFromGroup, groupTotals, diffEntity,
} from '../src/js/logic.js';
import { esc, getTextColor, closestBaseColorName, spoolGrams } from '../src/js/utils.js';

// ─── codes ───────────────────────────────────────────────────────────
test('generateSpoolCode : format MAT-COULEUR-NNN et incrément', () => {
  const counters = {};
  assert.equal(generateSpoolCode(counters, 'PLA', 'Noir'), 'PLA-NOIR-001');
  assert.equal(generateSpoolCode(counters, 'PLA', 'Noir'), 'PLA-NOIR-002');
  assert.equal(generateSpoolCode(counters, 'PETG', 'Bleu'), 'PETG-BLEU-001');
});

test('generateSpoolCode : accents supprimés, ASCII-safe, tronqué', () => {
  const counters = {};
  assert.equal(generateSpoolCode(counters, 'pla émeraude+', 'Échêvelé'), 'PLAEMERA-ECHEV-001');
});

test('generateSpoolCode : couleur vide → PERSO', () => {
  assert.equal(generateSpoolCode({}, 'PLA', '###'), 'PLA-PERSO-001');
});

test('syncCodeCounters : reprend le max des codes existants (anti-collision import)', () => {
  const counters = {};
  syncCodeCounters(counters, [
    { code: 'PLA-NOIR-007' }, { code: 'PLA-NOIR-002' }, { code: 'ABS-ROUGE-001' }, { code: null },
  ]);
  assert.equal(counters['PLA-NOIR'], 7);
  assert.equal(generateSpoolCode(counters, 'PLA', 'Noir'), 'PLA-NOIR-008');
});

test('migrateSpools : complète code, dates, supportId et poids', () => {
  const counters = {};
  const spools = [{ material: 'PLA', colorName: 'Noir', qty: 50 }];
  const changed = migrateSpools(spools, counters);
  assert.equal(changed, true);
  assert.equal(spools[0].code, 'PLA-NOIR-001');
  assert.equal(spools[0].weight, 1000);
  assert.equal(spools[0].supportId, null);
  assert.ok(spools[0].createdAt && spools[0].lastModified);
  assert.equal(migrateSpools(spools, counters), false, 'idempotent');
});

// ─── supports ────────────────────────────────────────────────────────
test('generateSupportId : préfixe par type et incrément indépendant', () => {
  const supports = [{ id: 'SUP-N-03', type: 'normal' }, { id: 'SUP-HT-01', type: 'high-temp' }];
  assert.equal(generateSupportId(supports, 'normal'), 'SUP-N-04');
  assert.equal(generateSupportId(supports, 'high-temp'), 'SUP-HT-02');
  assert.equal(generateSupportId(supports, 'very-high-temp'), 'SUP-THT-01');
});

// ─── import ──────────────────────────────────────────────────────────
test('normalizeImportedSpool : valeurs invalides remplacées par des défauts sûrs', () => {
  const s = normalizeImportedSpool({ id: "x'><script>", qty: 999, color: 'red', pack: 'nope', traits: ['flexible','inconnu'] });
  assert.match(s.id, /^[\w-]+$/, 'id dangereux régénéré');
  assert.equal(s.qty, 100);
  assert.equal(s.color, '#7a7a82');
  assert.equal(s.pack, 'vacuum');
  assert.deepEqual(s.traits, ['flexible']);
  assert.equal(s.weight, 1000);
});

test('normalizeImportedSpool : valeurs valides conservées', () => {
  const s = normalizeImportedSpool({ id: 'abc-123', brand: 'Prusa', qty: 42, weight: 2000, color: '#aabbcc', pack: 'open', loc: 'inuse', type: 'refill' });
  assert.equal(s.id, 'abc-123');
  assert.equal(s.qty, 42);
  assert.equal(s.weight, 2000);
  assert.equal(s.color, '#aabbcc');
});

test('normalizeImportedSupport : type invalide → normal, id dangereux régénéré', () => {
  const sup = normalizeImportedSupport({ id: '<img>', type: 'plasma' }, []);
  assert.equal(sup.type, 'normal');
  assert.match(sup.id, /^SUP-N-\d+$/);
});

// ─── filtres / compteurs ─────────────────────────────────────────────
const INV = [
  { brand:'Bambu', material:'PLA',  colorName:'Noir',  qty: 85, weight:1000, pack:'open',   loc:'inuse', code:'PLA-NOIR-001', notes:'' },
  { brand:'Bambu', material:'PETG', colorName:'Blanc', qty: 15, weight:1000, pack:'open',   loc:'stock', code:'PETG-BLANC-001', notes:'presque vide' },
  { brand:'Prusa', material:'PLA',  colorName:'Noir',  qty:100, weight:2000, pack:'vacuum', loc:'stock', code:'PLA-NOIR-002', notes:'' },
];

test('computeCounts : une passe, tous les compteurs', () => {
  const c = computeCounts(INV);
  assert.deepEqual({ all:c.all, open:c.open, vacuum:c.vacuum, inuse:c.inuse, stock:c.stock, alert:c.alert },
                   { all:3, open:2, vacuum:1, inuse:1, stock:2, alert:1 });
});

test('filterSpools : filtre + recherche (marque, code, notes)', () => {
  assert.equal(filterSpools(INV, 'alert', '').length, 1);
  assert.equal(filterSpools(INV, 'all', 'prusa').length, 1);
  assert.equal(filterSpools(INV, 'all', 'petg-blanc').length, 1);
  assert.equal(filterSpools(INV, 'open', 'vide').length, 1);
  assert.equal(filterSpools(INV, 'vacuum', 'vide').length, 0);
});

// ─── tri / groupes ───────────────────────────────────────────────────
test('sortSpools : qty-asc trie, default préserve l\'ordre', () => {
  assert.deepEqual(sortSpools(INV, 'qty-asc').map(s => s.qty), [15, 85, 100]);
  assert.equal(sortSpools(INV, 'default'), INV, 'pas de copie inutile en mode défaut');
});

test('groupSpools : clés selon le mode de groupement', () => {
  assert.deepEqual([...groupSpools(INV, 'material+color', 'default').keys()],
                   ['PLA::Noir', 'PETG::Blanc']);
  assert.deepEqual([...groupSpools(INV, 'material', 'default').keys()], ['PLA', 'PETG']);
  assert.deepEqual([...groupSpools(INV, 'color', 'default').keys()], ['Noir', 'Blanc']);
});

test('getPrimarySpoolFromGroup : en machine prioritaire, puis ouverte, qty la plus basse', () => {
  const group = groupSpools(INV, 'material+color', 'default').get('PLA::Noir');
  assert.equal(getPrimarySpoolFromGroup(group).loc, 'inuse');
  const noInuse = group.map(s => ({ ...s, loc: 'stock' }));
  assert.equal(getPrimarySpoolFromGroup(noInuse).pack, 'open');
});

test('groupTotals : grammes et % composite pondérés par la capacité réelle', () => {
  const group = [
    { qty: 50, weight: 1000 },  // 500 g
    { qty: 100, weight: 2000 }, // 2000 g
  ];
  const { totalGrams, compositePct } = groupTotals(group);
  assert.equal(totalGrams, 2500);
  assert.equal(compositePct, 83); // 2500 / 3000
});

// ─── diff ────────────────────────────────────────────────────────────
test('diffEntity : détecte les changements y compris les arrays', () => {
  const oldS = { qty: 80, traits: ['matte'], brand: 'Bambu' };
  const newS = { qty: 60, traits: ['matte','wood'], brand: 'Bambu' };
  const d = diffEntity(oldS, newS, ['qty','traits','brand']);
  assert.deepEqual(d.map(c => c.field), ['qty','traits']);
});

// ─── utils ───────────────────────────────────────────────────────────
test('esc : échappe le HTML', () => {
  assert.equal(esc(`<b a="1" b='2'>&`), '&lt;b a=&quot;1&quot; b=&#39;2&#39;&gt;&amp;');
});

test('getTextColor : noir sur fond clair, blanc sur fond sombre', () => {
  assert.match(getTextColor('#ffffff'), /0,0,0/);
  assert.match(getTextColor('#1a1a1a'), /255,255,255/);
});

test('closestBaseColorName : hex arbitraire → couleur canonique', () => {
  assert.equal(closestBaseColorName('#ff0000'), 'Rouge');
  assert.equal(closestBaseColorName('#0a0a0a'), 'Noir');
});

test('spoolGrams : utilise le poids réel de la bobine', () => {
  assert.equal(spoolGrams({ qty: 50, weight: 2000 }), 1000);
  assert.equal(spoolGrams({ qty: 50 }), 500, 'défaut 1 kg');
});
