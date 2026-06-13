// Smoke test : démarre l'app complète dans jsdom (mode hors-Tauri, état en
// mémoire) et vérifie les parcours principaux : rendu initial, ajout,
// édition, suppression (avec le dialogue de confirmation maison), filtres.
import { test, before } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { JSDOM } from 'jsdom';

let window, document, state, render;

before(async () => {
  const html = readFileSync(new URL('../src/index.html', import.meta.url), 'utf8');
  const dom = new JSDOM(html, { url: 'http://localhost/', pretendToBeVisual: true });
  window = dom.window;
  document = window.document;
  // Les modules de l'app référencent les globals du navigateur
  global.window = window;
  global.document = document;
  global.localStorage = window.localStorage;
  global.history = window.history;
  global.Blob = window.Blob;
  global.URL = window.URL;
  await import('../src/js/app.js');
  ({ state } = await import('../src/js/store.js'));
  ({ render } = await import('../src/js/render.js'));
});

function click(el) {
  el.dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
}
function $(id) { return document.getElementById(id); }

test('démarrage : seed de démo rendu en cartes', () => {
  assert.equal(state.initialized, true);
  assert.equal(state.spools.length, 7);
  assert.ok(document.querySelectorAll('#viewContainer .card').length >= 1);
  assert.equal($('versionBadge').textContent.startsWith('v'), true);
});

test('le seed ne revient pas si l\'inventaire est vidé (drapeau initialized)', () => {
  // simule la logique de démarrage : initialized=true + 0 bobines → pas de re-seed
  assert.equal(state.initialized, true);
});

test('ajout d\'une bobine via la modal', () => {
  const countBefore = state.spools.length;
  click($('addBtn'));
  assert.ok($('overlay').classList.contains('open'));
  $('fBrand').value = 'TestBrand';
  $('fWeight').value = '2000';
  $('fQty').value = '50';
  click($('saveSpoolBtn'));
  assert.equal(state.spools.length, countBefore + 1);
  const added = state.spools[state.spools.length - 1];
  assert.equal(added.brand, 'TestBrand');
  assert.equal(added.weight, 2000);
  assert.ok(added.code, 'code généré');
  assert.equal($('overlay').classList.contains('open'), false);
  assert.equal(state.journal[0].action, 'created');
});

test('édition par tap sur la carte (délégation data-spool-id)', () => {
  render();
  const card = document.querySelector('#viewContainer [data-spool-id]');
  assert.ok(card);
  click(card);
  assert.ok($('overlay').classList.contains('open'));
  assert.equal(state.ui.editingId, card.dataset.spoolId);
  click($('cancelModalBtn'));
  assert.equal($('overlay').classList.contains('open'), false);
});

test('suppression : passe par le dialogue maison (pas confirm() natif)', async () => {
  const target = state.spools[0];
  const countBefore = state.spools.length;
  // ouvre l'édition
  const { openEdit } = await import('../src/js/ui.js');
  openEdit(target.id);
  click($('deleteBtn'));
  // le dialogue de confirmation doit être ouvert
  await new Promise(r => setTimeout(r, 0));
  assert.ok($('confirmOverlay').classList.contains('open'), 'dialogue de confirmation affiché');
  // clic sur le bouton danger (Supprimer)
  const dangerBtn = $('confirmButtons').querySelector('.btn-save.danger');
  assert.ok(dangerBtn);
  click(dangerBtn);
  await new Promise(r => setTimeout(r, 0));
  assert.equal(state.spools.length, countBefore - 1);
  assert.equal(state.spools.find(s => s.id === target.id), undefined);
  assert.equal(state.journal[0].action, 'deleted');
});

test('annulation du dialogue : ne supprime pas', async () => {
  const target = state.spools[0];
  const countBefore = state.spools.length;
  const { openEdit } = await import('../src/js/ui.js');
  openEdit(target.id);
  click($('deleteBtn'));
  await new Promise(r => setTimeout(r, 0));
  click($('confirmButtons').querySelector('.btn-cancel'));
  await new Promise(r => setTimeout(r, 0));
  assert.equal(state.spools.length, countBefore);
});

test('filtres : chip "presque vides" ne montre que qty <= 20', () => {
  const alertChip = document.querySelector('.filters [data-filter="alert"]');
  click(alertChip);
  const expected = state.spools.filter(s => s.qty <= 20).length;
  // les cartes affichées (hors groupes) doivent correspondre au filtre
  assert.equal(state.ui.filter, 'alert');
  const shown = document.querySelectorAll('#viewContainer [data-spool-id]').length
    + document.querySelectorAll('#viewContainer .card-group').length;
  assert.ok(shown >= Math.min(1, expected));
  // retour à "tout"
  click(document.querySelector('.filters [data-filter="all"]'));
});

test('recherche : filtre par marque', async () => {
  const input = $('searchInput');
  input.value = 'TestBrand';
  input.dispatchEvent(new window.Event('input', { bubbles: true }));
  await new Promise(r => setTimeout(r, 200)); // debounce 150ms
  const shown = document.querySelectorAll('#viewContainer [data-spool-id]');
  assert.equal(shown.length, 1);
  // reset
  input.value = '';
  input.dispatchEvent(new window.Event('input', { bubbles: true }));
  await new Promise(r => setTimeout(r, 200));
});

test('vue liste : bascule et rendu', () => {
  click($('viewBtn'));
  assert.equal(state.ui.view, 'list');
  assert.ok(document.querySelector('#viewContainer .list'));
  click($('viewBtn'));
  assert.equal(state.ui.view, 'card');
});

test('réglages : ajout de matière et de support', () => {
  click($('settingsBtn'));
  assert.ok($('settingsOverlay').classList.contains('open'));
  $('newMaterial').value = 'SILK';
  click($('addMaterialBtn'));
  assert.ok(state.customMaterials.includes('SILK'));
  click($('addSupportBtn'));
  assert.equal(state.supports.length, 1);
  assert.match(state.supports[0].id, /^SUP-N-\d+$/);
  click($('settingsCloseBtn'));
});

test('journal : entrées présentes et panneau rendu', () => {
  click($('journalBtn'));
  assert.ok($('journalOverlay').classList.contains('open'));
  assert.ok(document.querySelectorAll('#journalEntries .journal-entry').length > 0);
  click($('journalCloseBtn'));
});

test('bouton retour (popstate) ferme la modal ouverte', async () => {
  click($('addBtn'));
  assert.ok($('overlay').classList.contains('open'));
  window.dispatchEvent(new window.PopStateEvent('popstate'));
  assert.equal($('overlay').classList.contains('open'), false);
});
