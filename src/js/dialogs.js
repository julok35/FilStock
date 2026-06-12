// Dialogues maison (Promise-based) — remplacent confirm()/alert() natifs,
// qui ne sont PAS supportés par la WebView Tauri (ils retournent une valeur
// falsy sans rien afficher, en particulier sur Android).
import { esc } from './utils.js';
import { overlayShown, overlayHidden, registerCloseHook } from './overlays.js';

let _resolve = null;

function el(id) { return document.getElementById(id); }

function close(value) {
  el('confirmOverlay').classList.remove('open');
  if (_resolve) { _resolve(value); _resolve = null; }
  overlayHidden();
}

// Affiche un dialogue avec une liste de boutons [{label, value, kind}]
// kind : 'save' (accent) | 'danger' | 'cancel' (neutre). Résout avec `value`
// du bouton cliqué, ou null (backdrop / Escape).
export function askChoice(message, buttons) {
  el('confirmMsg').textContent = message;
  el('confirmButtons').innerHTML = buttons.map((b, i) => {
    const cls = b.kind === 'danger' ? 'btn-save danger' : b.kind === 'cancel' ? 'btn-cancel' : 'btn-save';
    return `<button class="${cls}" data-choice="${i}">${esc(b.label)}</button>`;
  }).join('');
  el('confirmButtons').querySelectorAll('[data-choice]').forEach(btn =>
    btn.addEventListener('click', () => close(buttons[+btn.dataset.choice].value)));
  el('confirmOverlay').classList.add('open');
  overlayShown();
  return new Promise(resolve => { _resolve = resolve; });
}

// Confirmation simple oui/non. Résout true si confirmé.
export function askConfirm(message, { ok = 'Confirmer', cancel = 'Annuler', danger = false } = {}) {
  return askChoice(message, [
    { label: cancel, value: false, kind: 'cancel' },
    { label: ok, value: true, kind: danger ? 'danger' : 'save' },
  ]).then(v => v === true);
}

// Message d'information (remplace alert()).
export function showAlert(message) {
  return askChoice(message, [{ label: 'OK', value: true, kind: 'save' }]);
}

// Ferme le dialogue en cours (utilisé par Escape / bouton retour Android)
export function cancelDialog() {
  if (el('confirmOverlay').classList.contains('open')) { close(null); return true; }
  return false;
}

export function initDialogs() {
  el('confirmOverlay').addEventListener('click', e => {
    if (e.target === el('confirmOverlay')) close(null);
  });
  // Fermeture forcée par le bouton retour Android : résoudre la promesse en cours
  registerCloseHook(() => {
    if (_resolve) { _resolve(null); _resolve = null; }
  });
}
