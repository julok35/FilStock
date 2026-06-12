import { BASE_COLORS, DEFAULT_WEIGHT } from './constants.js';

// ─── ÉCHAPPEMENT HTML ────────────────────────────────────────────────
export function esc(str) {
  return String(str ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}

// ─── COULEUR DE TEXTE ────────────────────────────────────────────────
// Calcule la luminance perceptuelle (formule WCAG) pour choisir noir ou blanc
// Valeurs de pondération : R=0.299, G=0.587, B=0.114 (sensibilité de l'œil humain)
export function getTextColor(hex) {
  const h = hex.replace('#','');
  const r = parseInt(h.slice(0,2),16), g = parseInt(h.slice(2,4),16), b = parseInt(h.slice(4,6),16);
  return (0.299*r + 0.587*g + 0.114*b) / 255 > 0.55 ? 'rgba(0,0,0,0.75)' : 'rgba(255,255,255,0.92)';
}

// ─── DISTANCE COULEUR ────────────────────────────────────────────────
// Distance euclidienne en espace RGB — approximation rapide (non-perceptuelle).
// Utilisé pour suggérer un nom de couleur canonique depuis une hex arbitraire.
// Note : CIE Lab serait plus précis visuellement, mais RGB suffit ici (12 couleurs de base).
export function colorDistance(h1, h2) {
  const p = h => { const x = h.replace('#',''); return [parseInt(x.slice(0,2),16), parseInt(x.slice(2,4),16), parseInt(x.slice(4,6),16)]; };
  const [r1,g1,b1] = p(h1), [r2,g2,b2] = p(h2);
  return Math.sqrt((r1-r2)**2 + (g1-g2)**2 + (b1-b2)**2);
}
// Retourne le nom de la couleur de BASE la plus proche (jamais les couleurs custom)
// pour garantir un nom canonique cohérent dans les codes et le groupement
export function closestBaseColorName(hex) {
  return BASE_COLORS.reduce((best, c) => colorDistance(hex, c.hex) < colorDistance(hex, best.hex) ? c : best).name;
}

// ─── DIVERS ──────────────────────────────────────────────────────────
export function uid() { return Date.now().toString(36) + Math.random().toString(36).slice(2); }

// Grammes restants d'une bobine (qty en %, weight = capacité de la bobine en g)
export function spoolGrams(s) { return Math.round((s.weight || DEFAULT_WEIGHT) * s.qty / 100); }
export function spoolCapacity(s) { return s.weight || DEFAULT_WEIGHT; }
export function qtyClass(pct) { return pct <= 20 ? 'lo' : pct <= 50 ? 'mid' : 'hi'; }
// Retourne la variable CSS de couleur selon le niveau de stock
export function qtyColor(pct) { return pct <= 20 ? 'var(--danger)' : pct <= 50 ? 'var(--warn)' : 'var(--ok)'; }

export function timeAgo(iso) {
  const m = Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
  if (m < 1) return 'à l\'instant';
  if (m < 60) return `il y a ${m} min`;
  const h = Math.floor(m / 60);
  if (h < 24) return `il y a ${h}h`;
  const d = Math.floor(h / 24);
  if (d < 30) return `il y a ${d}j`;
  return new Date(iso).toLocaleDateString('fr-FR');
}
