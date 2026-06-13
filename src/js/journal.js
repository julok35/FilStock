// Journal des modifications — le tableau vit dans state.journal (une seule
// source de vérité, persistée avec le reste via persist()).
import { state, persist } from './store.js';
import { FIELD_LABELS } from './constants.js';
import { esc } from './utils.js';

const MAX_ENTRIES = 200;

export function addJournalEntry(entry) {
  state.journal.unshift(entry);
  if (state.journal.length > MAX_ENTRIES) state.journal.length = MAX_ENTRIES;
  state.lastModified = entry.ts;
  persist();
  updateLastModifiedBadge();
}

export function clearJournalEntries() {
  state.journal = [];
  state.lastModified = null;
  persist();
  updateLastModifiedBadge();
}

export function updateLastModifiedBadge() {
  const badge = document.getElementById('lastModifiedBadge');
  if (!state.lastModified) { badge.style.display = 'none'; return; }
  const d = new Date(state.lastModified);
  const dd = String(d.getDate()).padStart(2,'0'), mm = String(d.getMonth()+1).padStart(2,'0');
  const hh = String(d.getHours()).padStart(2,'0'), mn = String(d.getMinutes()).padStart(2,'0');
  badge.textContent = `🕐 ${dd}/${mm} ${hh}:${mn}`;
  badge.style.display = '';
}

export function formatFieldValue(field, value) {
  if (value === null || value === undefined || value === '') return 'aucun';
  if (field === 'qty')    return `${value}%`;
  if (field === 'weight') return `${value}g`;
  if (field === 'pack')   return value === 'vacuum' ? 'sous vide' : 'ouvert';
  if (field === 'loc')    return value === 'inuse'  ? 'en machine' : 'en stock';
  if (field === 'type')   return value === 'mounted'? 'sur support' : 'recharge';
  if (field === 'traits') return Array.isArray(value) ? (value.length ? value.join(', ') : 'aucun') : String(value);
  return String(value);
}

export function changesHTML(changes) {
  if (!changes || !changes.length) return '';
  // Merge color + colorName into single "Couleur" entry
  const hasColorName = changes.find(c => c.field === 'colorName');
  const hasHex = changes.find(c => c.field === 'color');
  const others = changes.filter(c => c.field !== 'color' && c.field !== 'colorName');
  const display = [...others];
  if (hasColorName) display.push({field:'colorName', from: hasColorName.from, to: hasColorName.to});
  else if (hasHex) display.push({field:'color', from: hasHex.from, to: hasHex.to});
  return display.map(c => {
    const lbl = FIELD_LABELS[c.field] || c.field;
    return `<div><span style="color:var(--text2)">${esc(lbl)} :</span> <span class="j-from">${esc(formatFieldValue(c.field,c.from))}</span> → <span class="j-to">${esc(formatFieldValue(c.field,c.to))}</span></div>`;
  }).join('');
}
