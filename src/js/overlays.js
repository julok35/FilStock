// Gestion centralisée des overlays (modal, panneaux, dialogues) et du
// bouton retour Android : à l'ouverture d'un overlay on pousse une entrée
// dans l'historique ; le bouton retour déclenche popstate → on ferme les
// overlays au lieu de quitter l'app.
const OVERLAY_IDS = ['overlay', 'settingsOverlay', 'journalOverlay', 'confirmOverlay'];

let _pushed = false;
const _closeHooks = [];

// Permet à un module (ex. dialogs) d'être prévenu d'une fermeture forcée (bouton retour)
export function registerCloseHook(fn) { _closeHooks.push(fn); }

function anyOpen() {
  return OVERLAY_IDS.some(id => document.getElementById(id)?.classList.contains('open'));
}

// À appeler après avoir ajouté la classe .open
export function overlayShown() {
  if (_pushed) return;
  try { history.pushState({ filstockOverlay: true }, ''); _pushed = true; } catch { /* environnement sans historique */ }
}

// À appeler après avoir retiré la classe .open (consomme l'entrée d'historique)
export function overlayHidden() {
  if (!_pushed || anyOpen()) return;
  _pushed = false;
  try { history.back(); } catch { /* ignore */ }
}

function closeAllDirect() {
  OVERLAY_IDS.forEach(id => document.getElementById(id)?.classList.remove('open'));
  _closeHooks.forEach(fn => fn());
}

export function initBackButton() {
  window.addEventListener('popstate', () => {
    _pushed = false;
    closeAllDirect();
  });
}
