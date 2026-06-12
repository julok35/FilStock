// Point d'entrée — charge l'état, branche les événements globaux, premier rendu.
import { state, loadState, persist } from './store.js';
import { APP_VERSION, ICONS, DEFAULT_WEIGHT } from './constants.js';
import { uid } from './utils.js';
import { syncCodeCounters, migrateSpools } from './logic.js';
import { render } from './render.js';
import { initUI, applyScales, openAdd, closeModal, closeSettings, closeJournal } from './ui.js';
import { updateLastModifiedBadge } from './journal.js';
import { initDialogs, cancelDialog } from './dialogs.js';
import { initBackButton } from './overlays.js';

// ─── CHARGEMENT DE L'ÉTAT (fichier AppData en mode Tauri) ────────────
await loadState();

// ─── MIGRATIONS ──────────────────────────────────────────────────────
syncCodeCounters(state.codeCounters, state.spools);
if (migrateSpools(state.spools, state.codeCounters)) persist();

// ─── DONNÉES D'EXEMPLE (premier lancement uniquement) ────────────────
// Le drapeau `initialized` garantit qu'un inventaire volontairement vidé
// ne sera jamais re-rempli avec les données de démo.
if (!state.initialized) {
  if (!state.spools.length) {
    const W = DEFAULT_WEIGHT;
    state.spools = [
      {id:uid(),brand:'Bambu',material:'PLA',colorName:'Noir',color:'#1a1a1a',qty:85,weight:W,pack:'open',loc:'inuse',type:'mounted',traits:[],supportId:null,notes:''},
      {id:uid(),brand:'Bambu',material:'PETG',colorName:'Blanc',color:'#f0eeea',qty:30,weight:W,pack:'open',loc:'inuse',type:'mounted',traits:[],supportId:null,notes:''},
      {id:uid(),brand:'Bambu',material:'PETG',colorName:'Blanc',color:'#f0eeea',qty:100,weight:W,pack:'vacuum',loc:'stock',type:'refill',traits:[],supportId:null,notes:'Recharge neuve'},
      {id:uid(),brand:'Bambu',material:'ABS',colorName:'Rouge',color:'#e83030',qty:15,weight:W,pack:'open',loc:'stock',type:'refill',traits:[],supportId:null,notes:'Presque vide !'},
      {id:uid(),brand:'Bambu',material:'ASA',colorName:'Gris',color:'#7a7a82',qty:50,weight:W,pack:'open',loc:'stock',type:'mounted',traits:[],supportId:null,notes:''},
      {id:uid(),brand:'Polymaker',material:'PLA',colorName:'Bleu',color:'#1a78e8',qty:72,weight:W,pack:'vacuum',loc:'stock',type:'mounted',traits:[],supportId:null,notes:'Neuve'},
      {id:uid(),brand:'Bambu',material:'TPU',colorName:'Orange',color:'#ff6d1f',qty:10,weight:W,pack:'open',loc:'stock',type:'refill',traits:['flexible'],supportId:null,notes:''},
    ];
    migrateSpools(state.spools, state.codeCounters);
  }
  state.initialized = true;
  persist();
}

// ─── THÈME ───────────────────────────────────────────────────────────
const themeBtn = document.getElementById('themeBtn');
function applyTheme(t) {
  document.body.dataset.theme = t;
  themeBtn.innerHTML = t === 'dark' ? ICONS.moon : ICONS.sun;
  state.theme = t;
  persist();
}
themeBtn.addEventListener('click', () => applyTheme(document.body.dataset.theme==='dark'?'light':'dark'));
// Premier lancement : suit la préférence système ; ensuite, choix de l'utilisateur
const systemTheme = (typeof window.matchMedia === 'function' && window.matchMedia('(prefers-color-scheme: light)').matches) ? 'light' : 'dark';
applyTheme(state.theme ?? systemTheme);

// ─── VUE CARTE / LISTE ───────────────────────────────────────────────
const viewBtn = document.getElementById('viewBtn');
function applyView(v) { state.ui.view = v; viewBtn.innerHTML = v === 'card' ? ICONS.list : ICONS.grid; }
viewBtn.addEventListener('click', () => { applyView(state.ui.view==='card'?'list':'card'); render(); });
applyView('card'); // initialisation icône

// ─── FILTRES & RECHERCHE ─────────────────────────────────────────────
document.querySelectorAll('.filters .filter-chip').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.filters .filter-chip').forEach(b => b.classList.remove('active'));
    btn.classList.add('active'); state.ui.filter = btn.dataset.filter; render();
  });
});
const searchInput = document.getElementById('searchInput');
const searchWrap = searchInput.closest('.search-wrap');
let _searchDebounce;
searchInput.addEventListener('input', e => {
  state.ui.searchQ = e.target.value;
  searchWrap.classList.toggle('has-value', !!e.target.value);
  clearTimeout(_searchDebounce);
  _searchDebounce = setTimeout(render, 150);
});
document.getElementById('searchClearBtn').addEventListener('click', () => {
  searchInput.value = ''; state.ui.searchQ = '';
  searchWrap.classList.remove('has-value');
  render(); searchInput.focus();
});

// ─── TRI & GROUPEMENT ────────────────────────────────────────────────
document.getElementById('sortBar').addEventListener('click', e => {
  const chip = e.target.closest('.filter-chip');
  if (!chip) return;
  if (chip.dataset.group !== undefined) {
    state.groupMode = chip.dataset.group;
    persist();
    document.querySelectorAll('#sortBar [data-group]').forEach(b => b.classList.toggle('active', b.dataset.group === state.groupMode));
    state.ui.expandedGroups.clear();
    render();
  } else if (chip.dataset.sort !== undefined) {
    state.sortMode = chip.dataset.sort;
    persist();
    document.querySelectorAll('#sortBar [data-sort]').forEach(b => b.classList.toggle('active', b.dataset.sort === state.sortMode));
    render();
  }
});

// ─── RACCOURCIS CLAVIER ──────────────────────────────────────────────
// N = nouvelle bobine | / = focus recherche | Escape = fermer panels
document.addEventListener('keydown', e => {
  // Ne pas intercepter si un champ est actif
  if (e.target.matches('input, textarea, select, button')) return;
  if (e.key === 'n' || e.key === 'N') { openAdd(); e.preventDefault(); }
  if (e.key === '/')                  { searchInput.focus(); e.preventDefault(); }
});
// Escape : fermer le panel ouvert (dialogue > modal > settings > journal)
document.addEventListener('keydown', e => {
  if (e.key !== 'Escape') return;
  if (cancelDialog()) return;
  if (document.getElementById('overlay').classList.contains('open'))         { closeModal();    return; }
  if (document.getElementById('settingsOverlay').classList.contains('open')) { closeSettings(); return; }
  if (document.getElementById('journalOverlay').classList.contains('open'))  { closeJournal();  return; }
});
// Ctrl+Enter (ou Cmd+Enter) dans la modal pour sauvegarder sans quitter le clavier
document.getElementById('overlay').addEventListener('keydown', e => {
  if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') { e.preventDefault(); document.getElementById('saveSpoolBtn').click(); }
});

// ─── DÉMARRAGE ───────────────────────────────────────────────────────
initDialogs();
initBackButton();
initUI();
document.getElementById('versionBadge').textContent = 'v' + APP_VERSION;
applyScales();
updateLastModifiedBadge();
// Synchroniser les chips sort/group avec les préférences chargées
document.querySelectorAll('#sortBar [data-group]').forEach(b => b.classList.toggle('active', b.dataset.group === state.groupMode));
document.querySelectorAll('#sortBar [data-sort]').forEach(b => b.classList.toggle('active', b.dataset.sort === state.sortMode));
render();
