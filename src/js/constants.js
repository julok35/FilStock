// ─── VERSION ─────────────────────────────────────────────────────────
export const APP_VERSION = '4.0';

// ─── CONSTANTES MÉTIER ───────────────────────────────────────────────
export const BASE_COLORS = [
  {name:'Noir',hex:'#1a1a1a'},{name:'Blanc',hex:'#f0eeea'},{name:'Gris',hex:'#7a7a82'},
  {name:'Rouge',hex:'#e83030'},{name:'Orange',hex:'#ff6d1f'},{name:'Jaune',hex:'#ffd600'},
  {name:'Vert',hex:'#1db954'},{name:'Bleu',hex:'#1a78e8'},{name:'Violet',hex:'#8844ee'},
  {name:'Rose',hex:'#ff4dad'},{name:'Marron',hex:'#8b5e3c'},{name:'Transparent',hex:'#c8d8e8'},
];
export const BASE_MATERIALS = ['PLA','PETG','ABS','ASA','TPU','NYLON','PA-CF','PLA-CF','PETG-CF','Autre'];

// Poids de bobine sélectionnables (grammes de filament sur bobine pleine)
export const SPOOL_WEIGHTS = [250, 500, 750, 1000, 2000, 3000, 5000];
export const DEFAULT_WEIGHT = 1000;

export const TRAITS = [
  {id:'flexible',label:'Souple',icon:'🫀',color:'#22c55e'},
  {id:'transparent',label:'Transparent',icon:'💎',color:'#7dd3fc'},
  {id:'glossy',label:'Brillant',icon:'✨',color:'#fbbf24'},
  {id:'matte',label:'Mat',icon:'🪨',color:'#94a3b8'},
  {id:'wood',label:'Bois',icon:'🪵',color:'#a16207'},
  {id:'stone',label:'Pierre',icon:'🪨',color:'#78716c'},
  {id:'carbon',label:'Carbone',icon:'⬛',color:'#1e293b'},
  {id:'fiberglass',label:'Fibre de verre',icon:'🔷',color:'#38bdf8'},
  {id:'antistatic',label:'Antistatique',icon:'⚡',color:'#f59e0b'},
  {id:'fireproof',label:'Anti-feu',icon:'🔥',color:'#ef4444'},
];

export const FIELD_LABELS = {
  brand:'Marque', material:'Matière', qty:'Quantité', pack:'Emballage',
  loc:'Emplacement', type:'Type', colorName:'Couleur', color:'Couleur hex',
  notes:'Notes', supportId:'Support', traits:'Caractéristiques', weight:'Poids bobine'
};
export const SPOOL_DIFF_FIELDS = ['brand','material','qty','weight','pack','loc','type','color','colorName','notes','supportId','traits'];

export const ACTION_ICONS = {
  'created':'✦','edited':'✎','deleted':'🗑',
  'support_created':'✦','support_edited':'✎','support_deleted':'🗑','support_assigned':'🔗'
};
export const ACTION_LABELS = {
  'created':'Créée','edited':'Modifiée','deleted':'Supprimée',
  'support_created':'Créé','support_edited':'Modifié','support_deleted':'Supprimé','support_assigned':'Réassigné'
};

// ─── ICÔNES SVG (style Feather — ligne fine 1.75px, bout arrondi) ────
export const ICONS = {
  moon: `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>`,
  sun:  `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>`,
  list: `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><circle cx="3" cy="6" r="1.2" fill="currentColor" stroke="none"/><circle cx="3" cy="12" r="1.2" fill="currentColor" stroke="none"/><circle cx="3" cy="18" r="1.2" fill="currentColor" stroke="none"/></svg>`,
  grid: `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg>`,
};
