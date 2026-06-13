// Interactions : modal bobine, panneaux réglages & journal, import/export.
import { state, persist, isTauri } from './store.js';
import { BASE_COLORS, BASE_MATERIALS, TRAITS, SPOOL_WEIGHTS, DEFAULT_WEIGHT, SPOOL_DIFF_FIELDS, ACTION_ICONS, ACTION_LABELS, APP_VERSION } from './constants.js';
import { esc, uid, closestBaseColorName, timeAgo } from './utils.js';
import { generateSpoolCode, generateSupportId, syncCodeCounters, migrateSpools,
         normalizeImportedSpool, normalizeImportedSupport, diffEntity } from './logic.js';
import { addJournalEntry, clearJournalEntries, updateLastModifiedBadge, changesHTML } from './journal.js';
import { render, getHolder, supportTypeIcon, supportTypeCls } from './render.js';
import { askConfirm, askChoice, showAlert } from './dialogs.js';
import { overlayShown, overlayHidden } from './overlays.js';

const $ = id => document.getElementById(id);

// ─── TOAST ───────────────────────────────────────────────────────────
let _toastTimer = null;
export function showToast(msg) {
  const t = $('toast');
  t.textContent = msg; t.classList.add('show');
  clearTimeout(_toastTimer);
  _toastTimer = setTimeout(() => t.classList.remove('show'), 2500);
}

// ─── ALL COLORS / MATERIALS ──────────────────────────────────────────
export function getAllColors()    { return [...BASE_COLORS, ...state.customColors]; }
export function getAllMaterials() { return [...BASE_MATERIALS, ...state.customMaterials]; }

// ─── MODAL BOBINE : FORM HELPERS ─────────────────────────────────────
function currentWeight() { return +$('fWeight').value || DEFAULT_WEIGHT; }

export function updateQtyDisplay(v) {
  const grams = Math.round(currentWeight() * (+v) / 100);
  $('qtyDisplay').textContent = `${grams}g · ${v}%`;
}
function bumpQty(delta) {
  const slider = $('fQty');
  slider.value = Math.max(0, Math.min(100, +slider.value + delta));
  updateQtyDisplay(slider.value);
}
function getToggle(group) { const a = document.querySelector(`.form-toggle.active[data-group="${group}"]`); return a ? a.dataset.val : null; }
function setToggle(group, val) { document.querySelectorAll(`.form-toggle[data-group="${group}"]`).forEach(b => b.classList.toggle('active', b.dataset.val === val)); }

function buildColorRow(activeHex) {
  const row = $('colorRow');
  row.innerHTML = getAllColors().map(c =>
    `<div class="color-swatch${c.hex===activeHex?' selected':''}" style="background:${c.hex}" title="${esc(c.name)}" data-hex="${c.hex}"></div>`
  ).join('') + `<input type="color" id="customColorInput" value="${activeHex}" title="Couleur personnalisée">`;
  row.querySelectorAll('.color-swatch').forEach(el => el.addEventListener('click', () => selectColor(el.dataset.hex, el)));
  $('customColorInput').addEventListener('input', function() { selectColorCustom(this.value); });
}
function selectColor(hex, el) {
  state.ui.selectedColor = hex;
  document.querySelectorAll('.color-swatch').forEach(s=>s.classList.remove('selected'));
  el.classList.add('selected');
}
function selectColorCustom(hex) {
  state.ui.selectedColor = hex;
  document.querySelectorAll('.color-swatch').forEach(s=>s.classList.remove('selected'));
}

function buildTraitsGrid(activeSet) {
  state.ui.selectedTraits = new Set(activeSet || []);
  $('traitsGrid').innerHTML = TRAITS.map(t =>
    `<div class="trait-chip${state.ui.selectedTraits.has(t.id)?' on':''}" data-trait="${t.id}"
      style="${state.ui.selectedTraits.has(t.id)?`border-color:${t.color};color:${t.color};background:${t.color}22`:''}">
      ${t.icon} ${t.label}
    </div>`
  ).join('');
}
function toggleTrait(id, el) {
  const t = TRAITS.find(x => x.id === id);
  if (state.ui.selectedTraits.has(id)) { state.ui.selectedTraits.delete(id); el.classList.remove('on'); el.style.borderColor = el.style.color = el.style.background = ''; }
  else { state.ui.selectedTraits.add(id); el.classList.add('on'); el.style.borderColor = el.style.color = t.color; el.style.background = t.color+'22'; }
}

function buildWeightSelect(current) {
  $('fWeight').innerHTML = SPOOL_WEIGHTS.map(w =>
    `<option value="${w}"${w===current?' selected':''}>${w >= 1000 ? (w/1000)+' kg' : w+' g'}</option>`).join('');
}

export function buildMaterialSelect(current) {
  const sel = $('fMaterial'); if (!sel) return;
  sel.innerHTML = getAllMaterials().map(m => `<option${m===current?' selected':''}>${esc(m)}</option>`).join('');
}

function buildSupportSelect(currentSupportId) {
  const sel = $('fSupport');
  if (!sel) return;
  let html = '<option value="">— Aucun support —</option>';
  state.supports.forEach(sup => {
    const holder = getHolder(sup.id);
    const otherHolder = holder && holder.id !== state.ui.editingId ? holder : null;
    const icon = supportTypeIcon(sup.type);
    const noteStr = sup.notes ? ` · ${sup.notes}` : '';
    const isSelected = sup.id === currentSupportId;
    if (otherHolder) {
      const ref = otherHolder.code || otherHolder.brand;
      html += `<option value="${esc(sup.id)}" disabled>${esc(icon+' '+sup.id+noteStr)} → ${esc(ref)}</option>`;
    } else {
      html += `<option value="${esc(sup.id)}"${isSelected?' selected':''}>${esc(icon+' '+sup.id+noteStr)}</option>`;
    }
  });
  sel.innerHTML = html;
}

// Alimente la datalist des marques avec celles déjà utilisées dans l'inventaire
function buildBrandDatalist() {
  const dl = $('brandList');
  if (!dl) return;
  const brands = [...new Set(state.spools.map(s => s.brand))].sort((a,b) => a.localeCompare(b,'fr'));
  dl.innerHTML = brands.map(b => `<option value="${esc(b)}">`).join('');
}

// ─── MODAL BOBINE : OUVERTURE / FERMETURE ────────────────────────────
export function openAdd() {
  state.ui.editingId = null;
  buildBrandDatalist();
  $('modalTitle').textContent = 'Nouvelle bobine';
  $('fBrand').value = 'Bambu';
  buildMaterialSelect('PLA');
  buildWeightSelect(DEFAULT_WEIGHT);
  $('fQty').value = 100;
  $('fNotes').value = '';
  updateQtyDisplay(100);
  setToggle('pack','vacuum'); setToggle('loc','stock'); setToggle('type','mounted');
  state.ui.selectedColor = getAllColors()[0].hex;
  buildColorRow(state.ui.selectedColor); buildTraitsGrid([]); buildSupportSelect(null);
  $('deleteBtn').style.display = 'none';
  $('duplicateBtn').style.display = 'none';
  $('overlay').classList.add('open');
  overlayShown();
}

export function openEdit(id) {
  const s = state.spools.find(x => x.id === id); if (!s) return;
  state.ui.editingId = id;
  buildBrandDatalist();
  $('modalTitle').textContent = `Modifier · ${s.code || 'bobine'}`;
  $('fBrand').value = s.brand;
  buildMaterialSelect(s.material);
  buildWeightSelect(s.weight || DEFAULT_WEIGHT);
  $('fQty').value = s.qty;
  $('fNotes').value = s.notes || '';
  updateQtyDisplay(s.qty);
  setToggle('pack', s.pack); setToggle('loc', s.loc); setToggle('type', s.type);
  state.ui.selectedColor = s.color;
  buildColorRow(s.color); buildTraitsGrid(s.traits||[]); buildSupportSelect(s.supportId||null);
  $('deleteBtn').style.display = 'inline-flex';
  $('duplicateBtn').style.display = 'inline-flex';
  $('overlay').classList.add('open');
  overlayShown();
}

export function closeModal() { $('overlay').classList.remove('open'); overlayHidden(); }

// ─── MODAL BOBINE : ACTIONS ──────────────────────────────────────────
export function saveSpool() {
  const editingId = state.ui.editingId;
  const now      = new Date().toISOString();
  const brand    = $('fBrand').value.trim() || 'Bambu';
  const material = $('fMaterial').value;
  const qty      = +$('fQty').value;
  const weight   = currentWeight();
  const pack     = getToggle('pack') || 'vacuum';
  const loc      = getToggle('loc')  || 'stock';
  const type     = getToggle('type') || 'mounted';
  const notes    = $('fNotes').value.trim();
  const traits   = [...state.ui.selectedTraits];
  const newSupportId = $('fSupport').value || null;
  const colorObj = getAllColors().find(c => c.hex === state.ui.selectedColor);
  const colorName = colorObj ? colorObj.name : closestBaseColorName(state.ui.selectedColor);

  if (editingId) {
    const idx = state.spools.findIndex(s => s.id === editingId);
    const oldSnap = {...state.spools[idx]};
    // Effet de bord intentionnel : si ce support était assigné à une autre bobine,
    // on la désassigne silencieusement (règle one-to-one : un support = une bobine)
    if (newSupportId) {
      const prevHolder = state.spools.find(s => s.supportId === newSupportId && s.id !== editingId);
      if (prevHolder) { prevHolder.supportId = null; prevHolder.lastModified = now; }
    }
    state.spools[idx] = { ...state.spools[idx], brand, material, qty, weight, pack, loc, type, notes, traits, color: state.ui.selectedColor, colorName, supportId: newSupportId, lastModified: now };
    const changes = diffEntity(oldSnap, state.spools[idx], SPOOL_DIFF_FIELDS);
    if (changes.length) {
      addJournalEntry({ ts: now, action:'edited', entityType:'spool', entityId: editingId, entityCode: state.spools[idx].code || editingId, entityLabel: `${brand} ${material} ${colorName}`, changes });
    }
  } else {
    // Désassignation de l'ancien propriétaire si besoin
    if (newSupportId) {
      const prevHolder = state.spools.find(s => s.supportId === newSupportId);
      if (prevHolder) { prevHolder.supportId = null; prevHolder.lastModified = now; }
    }
    const code = generateSpoolCode(state.codeCounters, material, colorName);
    const spool = { id: uid(), brand, material, qty, weight, pack, loc, type, notes, traits, color: state.ui.selectedColor, colorName, supportId: newSupportId, code, createdAt: now, lastModified: now };
    state.spools.push(spool);
    addJournalEntry({ ts: now, action:'created', entityType:'spool', entityId: spool.id, entityCode: code, entityLabel: `${brand} ${material} ${colorName}`, changes: [] });
  }
  persist(); closeModal(); render();
  showToast(editingId ? '✓ Bobine mise à jour' : '✓ Bobine ajoutée');
}

export async function deleteSpool() {
  const s = state.spools.find(x => x.id === state.ui.editingId);
  if (!s) return;
  const ok = await askConfirm(`Supprimer la bobine ${s.code || ''} ?`, { ok: '🗑 Supprimer', danger: true });
  if (!ok) return;
  addJournalEntry({ ts: new Date().toISOString(), action:'deleted', entityType:'spool', entityId: s.id, entityCode: s.code||s.id, entityLabel: `${s.brand} ${s.material} ${s.colorName}`, changes:[] });
  state.spools = state.spools.filter(x => x.id !== state.ui.editingId);
  persist(); closeModal(); render();
  showToast('🗑 Bobine supprimée');
}

// Crée une copie de la bobine en cours d'édition (qty remise à 100%, sans support assigné)
export function duplicateSpool() {
  const s = state.spools.find(x => x.id === state.ui.editingId); if (!s) return;
  const now  = new Date().toISOString();
  const code = generateSpoolCode(state.codeCounters, s.material, s.colorName);
  const copy = { ...s, id: uid(), code, qty: 100, supportId: null, createdAt: now, lastModified: now };
  state.spools.push(copy);
  addJournalEntry({ ts: now, action:'created', entityType:'spool', entityId: copy.id, entityCode: code, entityLabel: `${s.brand} ${s.material} ${s.colorName}`, changes: [] });
  persist(); closeModal(); render();
  showToast('⧉ Bobine dupliquée — quantité remise à 100%');
}

// ─── EXPORT / IMPORT ─────────────────────────────────────────────────
export async function exportJSON() {
  const data = { app:'FilStock Julok', version:1, appVersion:APP_VERSION, exportedAt: new Date().toISOString(), spools: state.spools, supports: state.supports };
  const json = JSON.stringify(data, null, 2);
  if (isTauri) {
    const { save: dialogSave } = window.__TAURI__.dialog;
    const { writeTextFile } = window.__TAURI__.fs;
    const path = await dialogSave({
      filters: [{ name: 'JSON', extensions: ['json'] }],
      defaultPath: `filstock-${new Date().toISOString().slice(0,10)}.json`
    });
    if (path) { await writeTextFile(path, json); showToast('✓ Export enregistré'); }
    return;
  }
  // Fallback navigateur (mode dev)
  const blob = new Blob([json], {type:'application/json'});
  const url  = URL.createObjectURL(blob);
  const a    = document.createElement('a');
  a.href = url; a.download = `filstock-${new Date().toISOString().slice(0,10)}.json`;
  a.click(); URL.revokeObjectURL(url);
  showToast('✓ Export téléchargé');
}

export async function importJSON(text) {
  try {
    const data = JSON.parse(text);
    const importedSpools   = Array.isArray(data) ? data : (Array.isArray(data.spools)   ? data.spools   : null);
    const importedSupports = Array.isArray(data.supports) ? data.supports : [];
    if (!importedSpools) throw new Error('Format invalide');
    const validSpools   = importedSpools.filter(s => s&&s.id&&s.material).map(normalizeImportedSpool);
    const validSupports = importedSupports.map(s => normalizeImportedSupport(s, state.supports));
    if (!validSpools.length) throw new Error('Aucune bobine valide trouvée');

    let mode = 'replace';
    if (state.spools.length) {
      mode = await askChoice(
        `Vous avez déjà ${state.spools.length} bobine(s).\nQue faire avec les ${validSpools.length} bobine(s) du fichier ?`,
        [
          { label: 'Annuler', value: null, kind: 'cancel' },
          { label: 'Tout remplacer', value: 'replace', kind: 'danger' },
          { label: 'Fusionner', value: 'merge', kind: 'save' },
        ]);
      if (!mode) return;
    }
    if (mode === 'merge') {
      const existingIds = new Set(state.spools.map(s => s.id));
      const newOnes = validSpools.filter(s => !existingIds.has(s.id));
      state.spools = [...state.spools, ...newOnes];
      const existingSupIds = new Set(state.supports.map(s => s.id));
      state.supports = [...state.supports, ...validSupports.filter(s => !existingSupIds.has(s.id))];
      showToast(`✓ ${newOnes.length} bobine(s) importée(s) par fusion`);
    } else {
      state.spools = validSpools; state.supports = validSupports;
      showToast(`✓ ${validSpools.length} bobine(s) importée(s)`);
    }
    syncCodeCounters(state.codeCounters, state.spools);
    migrateSpools(state.spools, state.codeCounters);
    persist(); render();
  } catch(err) {
    showAlert('❌ Erreur d\'import : ' + err.message);
  }
}

export async function pickAndImport() {
  if (isTauri) {
    const { open: dialogOpen } = window.__TAURI__.dialog;
    const { readTextFile } = window.__TAURI__.fs;
    const path = await dialogOpen({ filters: [{ name: 'JSON', extensions: ['json'] }] });
    if (path) importJSON(await readTextFile(path));
    return;
  }
  $('importFile').click();
}

// ─── RÉGLAGES : ÉCHELLES ─────────────────────────────────────────────
export function applyScales() {
  const root = document.documentElement;
  const { fontSize, pastille, btnSize } = state.settings;
  const fs = fontSize/100, ps = pastille/100, bs = btnSize/100;
  root.style.setProperty('--app-font',(14*fs)+'px'); root.style.setProperty('--btn-size',(36*bs)+'px');
  root.style.setProperty('--btn-font',(16*bs)+'px'); root.style.setProperty('--btn-add-font',(13*bs)+'px');
  root.style.setProperty('--btn-small-size',(28*bs)+'px'); root.style.setProperty('--btn-small-font',(13*bs)+'px');
  root.style.setProperty('--pastille-card-font',(26*ps)+'px'); root.style.setProperty('--pastille-list-font',(13*ps)+'px');
}

// ─── RÉGLAGES : LISTES PERSONNALISÉES ────────────────────────────────
export function renderMaterialList() {
  const el = $('materialList'); if (!el) return;
  el.innerHTML = state.customMaterials.length
    ? state.customMaterials.map((m,i) => `<div class="custom-item"><span class="custom-item-label">${esc(m)}</span><button class="custom-item-del" data-del-material="${i}" title="Supprimer">✕</button></div>`).join('')
    : '<div style="font-size:12px;color:var(--text2)">Aucune matière personnalisée.</div>';
}
export function renderColorList() {
  const el = $('colorList'); if (!el) return;
  el.innerHTML = state.customColors.length
    ? state.customColors.map((c,i) => `<div class="custom-item"><div class="custom-item-dot" style="background:${c.hex}"></div><span class="custom-item-label">${esc(c.name)}</span><button class="custom-item-del" data-del-color="${i}" title="Supprimer">✕</button></div>`).join('')
    : '<div style="font-size:12px;color:var(--text2)">Aucune couleur personnalisée.</div>';
}

export function addMaterial() {
  const input = $('newMaterial');
  const val = input.value.trim().toUpperCase(); if (!val) return;
  if (getAllMaterials().includes(val)) { showToast('⚠ Matière déjà existante'); return; }
  state.customMaterials.push(val); persist(); input.value = ''; renderMaterialList(); showToast('✓ Matière ajoutée');
}
export function removeMaterial(i) { state.customMaterials.splice(i,1); persist(); renderMaterialList(); }

export function addColor() {
  const name = $('newColorName').value.trim();
  const hex  = $('newColorHex').value;
  if (!name) { showToast('⚠ Saisir un nom de couleur'); return; }
  if (getAllColors().find(c => c.name.toLowerCase()===name.toLowerCase())) { showToast('⚠ Couleur déjà existante'); return; }
  state.customColors.push({name, hex}); persist();
  $('newColorName').value = '';
  $('newColorHex').value = '#ff0000';
  renderColorList(); showToast('✓ Couleur ajoutée');
}
export function removeColor(i) { state.customColors.splice(i,1); persist(); renderColorList(); }

// ─── RÉGLAGES : SUPPORTS ─────────────────────────────────────────────
export function renderSupportList() {
  const el = $('supportList'); if (!el) return;
  if (!state.supports.length) { el.innerHTML = '<div style="font-size:12px;color:var(--text2)">Aucun support créé.</div>'; return; }
  // Index local : évite un find() par support
  const holderBySup = new Map();
  for (const s of state.spools) if (s.supportId) holderBySup.set(s.supportId, s);
  el.innerHTML = state.supports.map(sup => {
    const holder = holderBySup.get(sup.id);
    const holderStr = holder ? `<span class="custom-item-sub">→ ${esc(holder.code || holder.brand)}</span>` : '';
    const noteStr = sup.notes ? `<span class="custom-item-sub"> · ${esc(sup.notes)}</span>` : '';
    const canDel = !holder;
    return `<div class="custom-item">
      <span class="support-badge support-badge-${supportTypeCls(sup.type)}" style="flex-shrink:0">${supportTypeIcon(sup.type)}</span>
      <span class="custom-item-label">${esc(sup.id)}${noteStr}${holderStr}</span>
      <button class="custom-item-del" data-del-support="${esc(sup.id)}" title="${canDel?'Supprimer':'Encore assigné'}" ${canDel?'':' disabled'}>✕</button>
    </div>`;
  }).join('');
}

export function addSupport() {
  const type  = $('newSupportType').value;
  const notes = $('newSupportNotes').value.trim();
  const id = generateSupportId(state.supports, type);
  state.supports.push({id, type, notes}); persist();
  addJournalEntry({ ts: new Date().toISOString(), action:'support_created', entityType:'support', entityId:id, entityCode:id, entityLabel:`Support ${id}${notes?' · '+notes:''}`, changes:[] });
  $('newSupportNotes').value = '';
  $('supportIdPreview').textContent = generateSupportId(state.supports, type);
  renderSupportList(); showToast(`✓ Support ${id} créé`);
}

export function deleteSupport(id) {
  const holder = state.spools.find(s => s.supportId === id);
  if (holder) { showToast(`⚠ Support assigné à ${holder.code || holder.brand}`); return; }
  state.supports = state.supports.filter(s => s.id !== id);
  addJournalEntry({ ts: new Date().toISOString(), action:'support_deleted', entityType:'support', entityId:id, entityCode:id, entityLabel:`Support ${id}`, changes:[] });
  persist(); renderSupportList(); showToast(`🗑 Support ${id} supprimé`);
}

// ─── RÉGLAGES : PANNEAU ──────────────────────────────────────────────
export function openSettings() {
  $('slFontSize').value = state.settings.fontSize;
  $('slPastille').value = state.settings.pastille;
  $('slBtnSize').value  = state.settings.btnSize;
  $('valFontSize').textContent = state.settings.fontSize+'%';
  $('valPastille').textContent = state.settings.pastille+'%';
  $('valBtnSize').textContent  = state.settings.btnSize+'%';
  renderMaterialList(); renderColorList(); renderSupportList();
  $('supportIdPreview').textContent = generateSupportId(state.supports, $('newSupportType').value);
  $('settingsOverlay').classList.add('open');
  overlayShown();
}
export function closeSettings() { $('settingsOverlay').classList.remove('open'); overlayHidden(); }

// ─── JOURNAL : PANNEAU ───────────────────────────────────────────────
export function openJournal() { renderJournal(); $('journalOverlay').classList.add('open'); overlayShown(); }
export function closeJournal() { $('journalOverlay').classList.remove('open'); overlayHidden(); }

export function setJournalFilter(f) {
  state.ui.journalFilter = f;
  document.querySelectorAll('.journal-tab').forEach(t => t.classList.toggle('active', t.dataset.jfilter === f));
  renderJournal();
}

export async function clearJournal() {
  const ok = await askConfirm('Effacer tout le journal ?', { ok: '🗑 Effacer', danger: true });
  if (!ok) return;
  clearJournalEntries();
  renderJournal();
  showToast('🗑 Journal effacé');
}

export function renderJournal() {
  const container = $('journalEntries');
  let j = state.journal;
  if (state.ui.journalFilter === 'spool')   j = j.filter(e => e.entityType === 'spool');
  if (state.ui.journalFilter === 'support') j = j.filter(e => e.entityType === 'support');
  if (!j.length) { container.innerHTML = `<div class="journal-empty">📋 Aucune entrée dans le journal.</div>`; return; }
  container.innerHTML = j.map(entry => {
    const icon  = ACTION_ICONS[entry.action]  || '·';
    const label = ACTION_LABELS[entry.action] || entry.action;
    const changes = changesHTML(entry.changes || []);
    return `<div class="journal-entry">
      <div class="journal-entry-header">
        <span class="journal-action-icon">${icon}</span>
        <span class="journal-code">${esc(entry.entityCode||'')}</span>
        <span class="journal-label">${esc(entry.entityLabel||'')} — ${esc(label)}</span>
        <span class="journal-time">${timeAgo(entry.ts)}</span>
      </div>
      ${changes ? `<div class="journal-changes">${changes}</div>` : ''}
    </div>`;
  }).join('');
}

// ─── WIRING DES ÉVÉNEMENTS UI ────────────────────────────────────────
export function initUI() {
  // Modal bobine : boutons statiques
  $('addBtn').addEventListener('click', openAdd);
  $('saveSpoolBtn').addEventListener('click', saveSpool);
  $('cancelModalBtn').addEventListener('click', closeModal);
  $('deleteBtn').addEventListener('click', deleteSpool);
  $('duplicateBtn').addEventListener('click', duplicateSpool);
  $('overlay').addEventListener('click', e => { if (e.target === $('overlay')) closeModal(); });

  // Quantité : slider + boutons rapides ; le poids recalcule l'affichage en grammes
  $('fQty').addEventListener('input', e => updateQtyDisplay(e.target.value));
  $('qtyMinusBtn').addEventListener('click', () => bumpQty(-10));
  $('qtyPlusBtn').addEventListener('click', () => bumpQty(10));
  $('fWeight').addEventListener('change', () => updateQtyDisplay($('fQty').value));

  // Traits : délégation
  $('traitsGrid').addEventListener('click', e => {
    const chip = e.target.closest('.trait-chip');
    if (chip) toggleTrait(chip.dataset.trait, chip);
  });

  // Toggles emballage / emplacement / type : délégation
  document.addEventListener('click', e => {
    const btn = e.target.closest('.form-toggle');
    if (!btn || !btn.dataset.group) return;
    document.querySelectorAll(`.form-toggle[data-group="${btn.dataset.group}"]`).forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
  });

  // Vue principale : délégation cartes / lignes / groupes
  $('viewContainer').addEventListener('click', e => {
    const groupBtn = e.target.closest('.btn-group-toggle');
    if (groupBtn && groupBtn.dataset.groupKey) {
      const key = groupBtn.dataset.groupKey;
      if (state.ui.expandedGroups.has(key)) state.ui.expandedGroups.delete(key);
      else state.ui.expandedGroups.add(key);
      render();
      return;
    }
    const editBtn = e.target.closest('[data-edit-id]');
    if (editBtn) { openEdit(editBtn.dataset.editId); return; }
    const row = e.target.closest('[data-spool-id]');
    if (row) openEdit(row.dataset.spoolId);
  });

  // Export / import
  $('exportBtn').addEventListener('click', exportJSON);
  $('importBtn').addEventListener('click', pickAndImport);
  $('importFile').addEventListener('change', async e => {
    const f = e.target.files[0];
    if (f) importJSON(await f.text());
    e.target.value = '';
  });

  // Panneau réglages
  $('settingsBtn').addEventListener('click', openSettings);
  $('settingsCloseBtn').addEventListener('click', closeSettings);
  $('settingsOverlay').addEventListener('click', e => { if (e.target === $('settingsOverlay')) closeSettings(); });
  $('addMaterialBtn').addEventListener('click', addMaterial);
  $('addColorBtn').addEventListener('click', addColor);
  $('addSupportBtn').addEventListener('click', addSupport);
  $('newMaterial').addEventListener('keydown', e => { if (e.key==='Enter') addMaterial(); });
  $('newColorName').addEventListener('keydown', e => { if (e.key==='Enter') addColor(); });
  $('newColorHex').addEventListener('input', function() {
    const nameInput = $('newColorName');
    if (!nameInput.value.trim()) nameInput.value = closestBaseColorName(this.value);
  });
  $('newSupportType').addEventListener('change', function() {
    $('supportIdPreview').textContent = generateSupportId(state.supports, this.value);
  });
  // Suppression matière / couleur / support : délégation
  $('materialList').addEventListener('click', e => {
    const b = e.target.closest('[data-del-material]'); if (b) removeMaterial(+b.dataset.delMaterial);
  });
  $('colorList').addEventListener('click', e => {
    const b = e.target.closest('[data-del-color]'); if (b) removeColor(+b.dataset.delColor);
  });
  $('supportList').addEventListener('click', e => {
    const b = e.target.closest('[data-del-support]'); if (b && !b.disabled) deleteSupport(b.dataset.delSupport);
  });
  // Sliders d'échelle
  const sliderMap = { slFontSize: ['fontSize','valFontSize'], slPastille: ['pastille','valPastille'], slBtnSize: ['btnSize','valBtnSize'] };
  Object.entries(sliderMap).forEach(([id, [key, valId]]) => {
    $(id).addEventListener('input', function() {
      state.settings[key] = +this.value;
      $(valId).textContent = this.value+'%';
      persist(); applyScales();
    });
  });

  // Panneau journal
  $('journalBtn').addEventListener('click', openJournal);
  $('lastModifiedBadge').addEventListener('click', openJournal);
  $('journalCloseBtn').addEventListener('click', closeJournal);
  $('journalOverlay').addEventListener('click', e => { if (e.target === $('journalOverlay')) closeJournal(); });
  $('clearJournalBtn').addEventListener('click', clearJournal);
  $('journalTabs').addEventListener('click', e => {
    const tab = e.target.closest('.journal-tab');
    if (tab) setJournalFilter(tab.dataset.jfilter);
  });
}
