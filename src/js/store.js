import { APP_VERSION, DEFAULT_WEIGHT } from './constants.js';

// ─── DÉTECTION TAURI ─────────────────────────────────────────────────
// En mode Tauri (app native) : persistance dans filstock_data.json (AppData).
// Hors Tauri (ouverture directe dans un navigateur, tests) : état en mémoire
// uniquement — la version web n'est plus maintenue.
export const isTauri = typeof window !== 'undefined' && typeof window.__TAURI_INTERNALS__ !== 'undefined';

const DATA_FILE = 'filstock_data.json';

// ─── ÉTAT UNIQUE ─────────────────────────────────────────────────────
// Source de vérité unique de l'app. Les clés listées dans PERSISTED_KEYS
// sont écrites sur disque ; `ui` est l'état d'interface volatile.
export const state = {
  // données persistées
  spools: [],
  supports: [],
  customColors: [],
  customMaterials: [],
  codeCounters: {},
  journal: [],
  lastModified: null,
  theme: null,
  groupMode: 'material+color',
  sortMode: 'default',
  settings: { fontSize: 100, pastille: 100, btnSize: 100 },
  initialized: false,   // true dès le premier lancement — empêche le re-seed des données de démo
  // état UI volatile
  ui: {
    filter: 'all',
    view: 'card',
    searchQ: '',
    selectedColor: '',
    selectedTraits: new Set(),
    editingId: null,
    expandedGroups: new Set(),
    journalFilter: 'all',
  },
};

const PERSISTED_KEYS = ['spools','supports','customColors','customMaterials','codeCounters',
  'journal','lastModified','theme','groupMode','sortMode','settings','initialized'];

function snapshot() {
  const out = { appVersion: APP_VERSION };
  for (const k of PERSISTED_KEYS) out[k] = state[k];
  return out;
}

// ─── CHARGEMENT ──────────────────────────────────────────────────────
export async function loadState() {
  if (!isTauri) return;
  const { readTextFile, BaseDirectory } = window.__TAURI__.fs;
  try {
    const raw = await readTextFile(DATA_FILE, { baseDir: BaseDirectory.AppData });
    applyLoaded(JSON.parse(raw));
    return;
  } catch { /* fichier absent ou illisible : première launch ou migration */ }
  migrateFromLocalStorage();
}

function applyLoaded(data) {
  for (const k of PERSISTED_KEYS) {
    if (data[k] !== undefined && data[k] !== null) state[k] = data[k];
  }
  // anciens fichiers (< v4.0) : pas de drapeau initialized — un inventaire
  // existant vaut initialisation
  if (data.initialized === undefined && Array.isArray(data.spools)) state.initialized = true;
}

// Migration one-shot depuis les anciennes clés localStorage (versions < 4.0
// qui écrivaient en double localStorage + fichier). Lecture seule : on
// n'écrit plus jamais dans localStorage.
function migrateFromLocalStorage() {
  const J = (k, d) => { try { return JSON.parse(localStorage.getItem(k)) ?? d; } catch { return d; } };
  const spools = J('filstock_v1', null);
  if (!Array.isArray(spools)) return; // rien à migrer
  state.spools          = spools;
  state.supports        = J('filstock_supports', []);
  state.customColors    = J('filstock_custom_colors', []);
  state.customMaterials = J('filstock_custom_materials', []);
  state.codeCounters    = J('filstock_code_counters', {});
  state.journal         = J('filstock_journal', []);
  state.lastModified    = localStorage.getItem('filstock_last_modified') || null;
  state.theme           = localStorage.getItem('filstock_theme') || null;
  state.groupMode       = localStorage.getItem('filstock_groupMode') || state.groupMode;
  state.sortMode        = localStorage.getItem('filstock_sortMode')  || state.sortMode;
  state.settings = {
    fontSize: +localStorage.getItem('filstock_fontSize') || 100,
    pastille: +localStorage.getItem('filstock_pastille') || 100,
    btnSize:  +localStorage.getItem('filstock_btnSize')  || 100,
  };
  state.initialized = true;
  persist();
}

// ─── PERSISTANCE (écriture différée durcie) ──────────────────────────
// - debounce 300ms pour grouper les mutations
// - si une mutation arrive pendant une écriture, la boucle ré-écrit (pas de perte)
// - flush immédiat quand l'app passe en arrière-plan (Android peut tuer le process)
// - écriture via fichier temporaire + rename pour ne jamais laisser un JSON tronqué
let _dirty = false;
let _timer = null;
let _writing = false;

export function persist() {
  _dirty = true;
  if (!isTauri || _timer || _writing) return;
  _timer = setTimeout(() => { _timer = null; flushNow(); }, 300);
}

export async function flushNow() {
  if (!isTauri || _writing) return;
  if (_timer) { clearTimeout(_timer); _timer = null; }
  _writing = true;
  const { writeTextFile, rename, BaseDirectory } = window.__TAURI__.fs;
  try {
    while (_dirty) {
      _dirty = false;
      const json = JSON.stringify(snapshot());
      try {
        // écriture atomique : tmp puis rename par-dessus le fichier principal
        await writeTextFile(DATA_FILE + '.tmp', json, { baseDir: BaseDirectory.AppData });
        await rename(DATA_FILE + '.tmp', DATA_FILE, {
          oldPathBaseDir: BaseDirectory.AppData, newPathBaseDir: BaseDirectory.AppData,
        });
      } catch {
        // fallback : écriture directe (ex. permission rename absente)
        await writeTextFile(DATA_FILE, json, { baseDir: BaseDirectory.AppData });
      }
    }
  } catch (err) {
    console.error('FilStock: échec écriture', err);
    _dirty = true; // réessaiera à la prochaine mutation
  } finally {
    _writing = false;
  }
}

if (typeof document !== 'undefined') {
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') flushNow();
  });
}
