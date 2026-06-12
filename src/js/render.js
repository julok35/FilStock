// Rendu des vues (cartes, liste, stats). Tous les éléments interactifs
// utilisent des data-attributes + délégation d'événements (voir app.js) —
// jamais d'onclick inline avec des données interpolées.
import { state } from './store.js';
import { TRAITS } from './constants.js';
import { esc, getTextColor, spoolGrams, qtyClass, qtyColor } from './utils.js';
import { filterSpools, computeCounts, groupSpools, getPrimarySpoolFromGroup, groupTotals } from './logic.js';

// ─── INDEX SUPPORTS (reconstruits à chaque rendu — O(n+m) au lieu de O(n×m)) ──
let supportById = new Map();
let holderBySupportId = new Map();

export function rebuildSupportIndexes() {
  supportById = new Map(state.supports.map(s => [s.id, s]));
  holderBySupportId = new Map();
  for (const s of state.spools) if (s.supportId) holderBySupportId.set(s.supportId, s);
}
export function getSupport(id) { return supportById.get(id); }
export function getHolder(supportId) { return holderBySupportId.get(supportId); }

// ─── SUPPORTS : BADGES ───────────────────────────────────────────────
export function supportTypeIcon(type) {
  return type === 'normal' ? '🔩' : type === 'high-temp' ? '🌡️' : '🔥';
}
export function supportTypeCls(type) {
  return type === 'normal' ? 'n' : type === 'high-temp' ? 'ht' : 'vht';
}
export function supportBadgeHTML(supportId) {
  if (!supportId) return '';
  const sup = supportById.get(supportId);
  if (!sup) return `<span class="support-badge support-badge-n">${esc(supportId)}</span>`;
  return `<span class="support-badge support-badge-${supportTypeCls(sup.type)}">${supportTypeIcon(sup.type)} ${esc(supportId)}</span>`;
}

// ─── PASTILLE ────────────────────────────────────────────────────────
export function pastilleHTML(color, material) {
  return `<div class="pastille" style="background:${color}">
    <span class="pastille-label" style="color:${getTextColor(color)}">${esc(material)}</span>
  </div>`;
}

// ─── TRAITS ──────────────────────────────────────────────────────────
export function traitsHTML(traits) {
  if (!traits||!traits.length) return '';
  return traits.map(id => { const t = TRAITS.find(x=>x.id===id); return t ? `<span class="trait-badge" style="color:${t.color}">${t.icon} ${t.label}</span>` : ''; }).join('');
}

// ─── STATS ───────────────────────────────────────────────────────────
function renderStats(counts, filteredCount) {
  const el = document.getElementById('statsBar');
  const freeSup = state.supports.length - counts.mountedSupports;
  el.innerHTML = `
    <div class="stat"><strong>${filteredCount}</strong><br>affichées</div>
    <div class="stat"><strong>${counts.all}</strong><br>total</div>
    <div class="stat"><strong>${counts.inuse}</strong><br>en machine</div>
    ${state.supports.length ? `<div class="stat"><strong>${freeSup}</strong><br>supports libres</div>` : ''}
    ${counts.alert ? `<div class="stat" style="color:var(--danger)"><strong>${counts.alert}</strong><br>⚠ presque vides</div>` : ''}
  `;
}

// Met à jour les attributs data-count sur chaque chip pour afficher les totaux
function updateFilterCounts(counts) {
  document.querySelectorAll('.filters .filter-chip[data-filter]').forEach(btn => {
    const n = counts[btn.dataset.filter];
    if (n !== undefined) btn.dataset.count = n > 0 ? `(${n})` : '';
  });
}

// ─── CARTE ───────────────────────────────────────────────────────────
function renderCard(s) {
  const alert  = s.qty <= 20;
  const grams  = spoolGrams(s);
  const qCls   = qtyClass(s.qty);
  const qColor = qtyColor(s.qty);
  const packLabel = s.pack==='vacuum' ? '🔒 Sous vide' : '📦 Ouvert';
  const locLabel  = s.loc==='inuse'   ? '🖨 Machine'   : '📦 Stock';
  const typeLabel = s.type==='refill' ? '♻ Recharge'   : '🔩 Support';
  const codeBadge = s.code ? `<div class="card-code-badge">${esc(s.code)}</div>` : '';
  const supBadge  = supportBadgeHTML(s.supportId);
  return `<div class="card${alert?' alert':''}" data-spool-id="${esc(s.id)}">
    <div class="card-actions">
      <button class="btn-small" data-edit-id="${esc(s.id)}">✎</button>
    </div>
    <div class="spool-visual">${pastilleHTML(s.color, s.material)}</div>
    <div class="card-body">
      <div class="card-title">${esc(s.brand)} · ${esc(s.colorName)}</div>
      ${codeBadge}
      <div class="card-sub">${esc(s.material)}</div>
      <div class="qty-bar"><div class="qty-fill ${qCls}" style="width:${s.qty}%"></div></div>
      <div class="card-footer">
        <div class="card-footer-top">
          <span class="card-qty" style="color:${qColor}">${grams}g · ${s.qty}%</span>
        </div>
        <div class="card-tags-row">
          <span class="tag tag-${s.pack}">${packLabel}</span>
          <span class="tag tag-${s.loc}">${locLabel}</span>
          <span class="tag tag-${s.type}">${typeLabel}</span>
          ${supBadge}
        </div>
        ${s.traits&&s.traits.length?`<div class="card-tags-row" style="margin-top:2px">${traitsHTML(s.traits)}</div>`:''}
      </div>
    </div>
  </div>`;
}

// ─── GROUPES (vue carte) ─────────────────────────────────────────────
function groupLabels(key, groupSpools) {
  // Clé peut être "MAT::COULEUR", "MAT" (mode material) ou "COULEUR" (mode color)
  const primary = groupSpools[0];
  const parts = key.split('::');
  const material  = state.groupMode === 'color'    ? primary.material  : parts[0];
  const colorName = state.groupMode === 'material' ? primary.colorName : (parts[1] ?? parts[0]);
  return { material, colorName };
}

function renderCardGroup(key, groupSpools) {
  const primary    = getPrimarySpoolFromGroup(groupSpools);
  const hasAlert   = groupSpools.some(s => s.qty <= 20);
  const n          = groupSpools.length;
  const { totalGrams, compositePct } = groupTotals(groupSpools);
  const qCls   = qtyClass(compositePct);
  const qColor = qtyColor(compositePct);
  const inuseCount = groupSpools.filter(s => s.loc === 'inuse').length;
  const stockCount = groupSpools.filter(s => s.loc === 'stock').length;
  const statusParts = [];
  if (inuseCount) statusParts.push(`${inuseCount} en machine`);
  if (stockCount) statusParts.push(`${stockCount} en stock`);
  const brands    = [...new Set(groupSpools.map(s => s.brand))];
  const brandStr  = brands.length === 1 ? brands[0] : `${brands.length} marques`;
  const { material, colorName } = groupLabels(key, [primary]);
  return `<div class="card-group">
    <div class="card-ghost card-ghost-2"></div>
    <div class="card-ghost card-ghost-1"></div>
    <span class="card-group-badge${hasAlert?' alert':''}">&times;${n}</span>
    <div class="card${hasAlert?' alert':''}">
      <div class="spool-visual">${pastilleHTML(primary.color, material)}</div>
      <div class="card-body">
        <div class="card-title">${esc(brandStr)} · ${esc(colorName)}</div>
        <div class="card-sub">${esc(material)}</div>
        <div class="qty-bar"><div class="qty-fill ${qCls}" style="width:${compositePct}%"></div></div>
        <div class="card-footer">
          <div class="card-footer-top">
            <span class="card-qty" style="color:${qColor}">${totalGrams}g total · ${compositePct}%</span>
          </div>
          <div class="mono" style="font-size:11px;color:var(--text2)">${statusParts.join(' · ')}</div>
        </div>
      </div>
      <div class="card-group-toggle-wrap">
        <button class="btn-group-toggle" data-group-key="${esc(key)}">▼ Voir les ${n} bobines</button>
      </div>
    </div>
  </div>`;
}

function renderCardGroupExpanded(key, groupSpools) {
  const { material, colorName } = groupLabels(key, groupSpools);
  const hasAlert   = groupSpools.some(s => s.qty <= 20);
  const { totalGrams } = groupTotals(groupSpools);
  const n = groupSpools.length;
  return `<div class="card-group-expanded-wrapper">
    <div class="card-group-expanded-header">
      <span style="font-size:14px;font-weight:700">
        ${esc(material)} · ${esc(colorName)}
        <span class="mono" style="font-size:12px;color:var(--text2);margin-left:8px">${n} bobines · ${totalGrams}g total</span>
        ${hasAlert?'<span style="font-size:11px;color:var(--danger);margin-left:6px">⚠ alerte stock</span>':''}
      </span>
      <button class="btn-group-toggle" style="width:auto" data-group-key="${esc(key)}">▲ Réduire</button>
    </div>
    <div class="card-group-sub-grid">${groupSpools.map(s => renderCard(s)).join('')}</div>
  </div>`;
}

// ─── LISTE ───────────────────────────────────────────────────────────
function renderListRow(s) {
  const alert  = s.qty <= 20;
  const grams  = spoolGrams(s);
  const qColor = qtyColor(s.qty);
  const packTip  = s.pack==='vacuum' ? 'Emballage : sous vide' : 'Emballage : ouvert';
  const locTip   = s.loc==='inuse'   ? 'Emplacement : en machine' : 'Emplacement : en stock';
  const typeTip  = s.type==='refill' ? 'Type : recharge' : 'Type : montée sur support';
  const alertTip = alert ? 'Niveau bas : commander bientôt !' : `Stock : ${grams}g restants`;
  const packIcon = s.pack==='vacuum' ? '🔒' : '📦';
  const locIcon  = s.loc==='inuse'   ? '🖨️' : '🗄️';
  const typeIcon = s.type==='refill' ? '♻️' : '🔩';
  const traitIcons = (s.traits||[]).map(id => {
    const t = TRAITS.find(x => x.id === id); if (!t) return '';
    return `<span class="tag tag-trait tip" data-tip="${esc(t.label)}" style="background:${t.color}18;color:${t.color};border:1px solid ${t.color}44">${t.icon}</span>`;
  }).join('');
  const codePart = s.code ? `<span class="list-code">${esc(s.code)}</span>` : '';
  const supBadge = supportBadgeHTML(s.supportId);
  return `<div class="list-row${alert?' alert':''}" data-spool-id="${esc(s.id)}">
    <div class="list-dot" style="background:${s.color}">
      <span class="list-dot-label" style="color:${getTextColor(s.color)}">${esc(s.material)}</span>
    </div>
    <div class="list-info">
      <div class="list-name">${esc(s.brand)} ${esc(s.material)} · ${esc(s.colorName)}</div>
      <div class="list-sub">${codePart}${s.notes ? esc(s.notes) : '&nbsp;'}</div>
    </div>
    <div class="list-qty tip" data-tip="${alertTip}" style="color:${qColor}">${grams}g · ${s.qty}%</div>
    <div class="list-tags">
      ${traitIcons}${supBadge}
      <span class="tag tag-${s.pack} tag-icon tip" data-tip="${packTip}">${packIcon}</span>
      <span class="tag tag-${s.loc} tag-icon tip" data-tip="${locTip}">${locIcon}</span>
      <span class="tag tag-${s.type} tag-icon tip" data-tip="${typeTip}">${typeIcon}</span>
    </div>
    <div class="list-actions"><button class="btn-small" data-edit-id="${esc(s.id)}">✎</button></div>
  </div>`;
}

function renderListGroup(key, groupSpools) {
  const primary = getPrimarySpoolFromGroup(groupSpools);
  const { material, colorName } = groupLabels(key, [primary]);
  const hasAlert = groupSpools.some(s => s.qty <= 20);
  const { totalGrams } = groupTotals(groupSpools);
  const header = `<div class="list-group-header${hasAlert?' alert':''}">
    <div class="list-dot" style="background:${primary.color}">
      <span class="list-dot-label" style="color:${getTextColor(primary.color)}">${esc(material.slice(0,4))}</span>
    </div>
    <div><div style="font-size:13px;font-weight:700">${esc(material)} · ${esc(colorName)}</div>
    <div class="mono" style="font-size:11px;color:var(--text2);margin-top:2px">${groupSpools.length} bobines · ${totalGrams}g total</div></div>
  </div>`;
  const rows = groupSpools.map(s => `<div class="list-group-indent">${renderListRow(s)}</div>`).join('');
  return header + rows;
}

// ─── RENDU PRINCIPAL ─────────────────────────────────────────────────
export function render() {
  rebuildSupportIndexes();
  const counts = computeCounts(state.spools);
  const items = filterSpools(state.spools, state.ui.filter, state.ui.searchQ);
  renderStats(counts, items.length);
  updateFilterCounts(counts);
  const container = document.getElementById('viewContainer');
  if (!items.length) {
    container.innerHTML = `<div class="empty"><div class="empty-icon">🧵</div><h3>Aucune bobine</h3><p>Ajoutez votre première bobine<br>en cliquant sur "+ Bobine".</p></div>`;
    return;
  }
  const groups = groupSpools(items, state.groupMode, state.sortMode);
  if (state.ui.view === 'card') {
    let html = '<div class="grid">';
    for (const [key, gs] of groups) {
      if (gs.length < 2)                        html += renderCard(gs[0]);
      else if (state.ui.expandedGroups.has(key)) html += renderCardGroupExpanded(key, gs);
      else                                       html += renderCardGroup(key, gs);
    }
    html += '</div>';
    container.innerHTML = html;
  } else {
    let html = '<div class="list">';
    for (const [key, gs] of groups) {
      html += gs.length < 2 ? renderListRow(gs[0]) : renderListGroup(key, gs);
    }
    html += '</div>';
    container.innerHTML = html;
  }
}
