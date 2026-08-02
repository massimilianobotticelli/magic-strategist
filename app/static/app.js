const HOLD_MS = 450;

function renderCounter() {
  const el = document.getElementById('counter');
  if (!el) return;
  const size = +el.dataset.size, cuts = +el.dataset.cuts, adds = +el.dataset.adds;
  const projected = size - cuts + adds;
  /* The target is the format's, not always 100: Modern and Pauper are a
     60-card MINIMUM, so being over it is legal and must not read as an error. */
  const target = +el.dataset.target || 100, exact = el.dataset.exact === '1';
  const off = exact ? projected !== target : projected < target;
  el.innerHTML =
    '<b>' + size + '</b> cards' +
    (cuts ? ' · <span class="c-cut">−' + cuts + '</span>' : '') +
    (adds ? ' · <span class="c-add">+' + adds + '</span>' : '') +
    ((cuts || adds)
      ? ' → <span class="' + (off ? 'c-bad' : '') + '">' + projected + '</span>' +
        (off ? (exact ? ' (not ' + target + ')' : ' (under ' + target + ')') : '')
      : '');
}

async function toggle(tile) {
  const body = new FormData();
  body.append('deck_id', tile.dataset.deck);
  body.append('oracle_id', tile.dataset.oracle);
  body.append('action', tile.dataset.action);

  const res = await fetch('/api/proposal', { method: 'POST', body });
  if (!res.ok) { console.error('proposal failed', res.status); return; }
  const data = await res.json();

  tile.classList.toggle('tile-' + tile.dataset.action, data.state === 'created');

  const el = document.getElementById('counter');
  if (el && data.totals) {
    el.dataset.size = data.totals.size;
    el.dataset.cuts = data.totals.cuts;
    el.dataset.adds = data.totals.adds;
    renderCounter();
  }
}

let zoomTile = null;

function openZoom(tile) {
  const img = tile.querySelector('img');
  const zoom = document.getElementById('zoom');
  if (!img || !zoom) return;
  const full = document.getElementById('zoom-img');
  full.src = img.dataset.full || img.src;
  full.alt = img.alt || '';
  zoom.hidden = false;
  zoomTile = tile;
}

function closeZoom() {
  const zoom = document.getElementById('zoom');
  if (zoom) zoom.hidden = true;
  zoomTile = null;
}

/* Arrow keys walk the grid behind the zoom. Only tiles actually on screen
   count, so the arrows never wander into the tab you are not looking at or
   into a section you folded away.

   A collapsed <details> is NOT caught by offsetParent: it keeps a layout box
   and only stops rendering its content, so its tiles still measure 204px tall.
   checkVisibility() sees through both that and a display:none panel. A tile
   with no image has nothing to enlarge, so it is skipped rather than leaving
   the previous card on screen under the wrong name. */
function onScreen(el) {
  return el.checkVisibility
    ? el.checkVisibility()
    : el.offsetParent !== null && !el.closest('details:not([open])');
}

function zoomableTiles() {
  return [...document.querySelectorAll('.tile')]
    .filter(t => t.querySelector('img') && onScreen(t));
}

function stepZoom(delta) {
  if (!zoomTile) return;
  const tiles = zoomableTiles();
  const next = tiles[tiles.indexOf(zoomTile) + delta];
  if (!next) return;   // stop at the ends; wrapping around loses your place
  openZoom(next);
  /* Keep the grid in step with the zoom, so closing it leaves you on the card
     you were looking at rather than back where you started. */
  next.focus({ preventScroll: true });
  next.scrollIntoView({ block: 'nearest' });
}

/* Click opens the card. Press and hold marks it, so scrolling past a grid of
   a hundred cards never triggers anything.
   Cancelling is driven by MOVEMENT, not by the pointer leaving an element: a
   hold should survive a shaky hand, but a scroll must never mark a card. */
const MOVE_TOLERANCE = 12;
let holdTimer = null, heldTile = null, didHold = false, startX = 0, startY = 0;

function startHold(tile, x, y) {
  if (!tile || tile.classList.contains('tile-static')) return;
  heldTile = tile;
  didHold = false;
  startX = x;
  startY = y;
  tile.classList.add('tile-holding');
  holdTimer = setTimeout(() => {
    didHold = true;
    tile.classList.remove('tile-holding');
    toggle(tile);
    if (navigator.vibrate) navigator.vibrate(15);
    holdTimer = null;
    heldTile = null;
  }, HOLD_MS);
}

function cancelHold() {
  if (holdTimer) { clearTimeout(holdTimer); holdTimer = null; }
  if (heldTile) { heldTile.classList.remove('tile-holding'); heldTile = null; }
}

function movedTooFar(x, y) {
  return Math.abs(x - startX) > MOVE_TOLERANCE || Math.abs(y - startY) > MOVE_TOLERANCE;
}

document.addEventListener('mousedown', (e) => {
  if (e.button !== 0) return;
  startHold(e.target.closest('.tile'), e.clientX, e.clientY);
});
document.addEventListener('mouseup', cancelHold);
document.addEventListener('mousemove', (e) => {
  if (heldTile && movedTooFar(e.clientX, e.clientY)) cancelHold();
});

document.addEventListener('touchstart', (e) => {
  const t = e.touches[0];
  startHold(e.target.closest('.tile'), t.clientX, t.clientY);
}, { passive: true });
document.addEventListener('touchend', cancelHold);
document.addEventListener('touchcancel', cancelHold);
document.addEventListener('touchmove', (e) => {
  const t = e.touches[0];
  if (heldTile && t && movedTooFar(t.clientX, t.clientY)) cancelHold();
}, { passive: true });

document.addEventListener('contextmenu', (e) => {
  if (e.target.closest('.tile')) e.preventDefault();
});

document.addEventListener('click', (e) => {
  const btn = e.target.closest('.proposal-actions button');
  if (btn) {
    const card = btn.closest('.proposal');
    const body = new FormData();
    body.append('status', btn.dataset.status);
    fetch('/api/proposal/' + card.dataset.id + '/status', { method: 'POST', body })
      .then(() => location.reload());
    return;
  }

  const tile = e.target.closest('.tile');
  if (tile) {
    if (didHold) { didHold = false; return; }
    openZoom(tile);
    return;
  }

  closeZoom();
});

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') { closeZoom(); return; }
  if (zoomTile && (e.key === 'ArrowRight' || e.key === 'ArrowLeft')) {
    e.preventDefault();
    stepZoom(e.key === 'ArrowRight' ? 1 : -1);
    return;
  }
  const tile = document.activeElement;
  if (!tile || !tile.classList.contains('tile')) return;
  if (e.key === 'Enter') { e.preventDefault(); openZoom(tile); }
  /* Press-and-hold already skips static tiles; the keyboard has to as well. */
  if (e.key === ' ' && !tile.classList.contains('tile-static')) {
    e.preventDefault();
    toggle(tile);
  }
});

/* Tabs. Combos and candidates are one click away instead of a long scroll.
   The active tab lives in the URL hash so a reload or the back button keeps it,
   with sessionStorage as the fallback for the filter form, which submits a
   plain GET and drops the hash. */
const TAB_KEY = 'ms-tab:' + location.pathname;

function showTab(name, remember) {
  const panels = document.querySelectorAll('.panel');
  if (!panels.length) return;
  const known = [...document.querySelectorAll('.tab')].map(t => t.dataset.tab);
  if (known.indexOf(name) < 0) name = known[0];

  panels.forEach(p => { p.hidden = p.dataset.panel !== name; });
  document.querySelectorAll('.tab').forEach(t => t.classList.toggle('tab-on', t.dataset.tab === name));
  syncToggleAll();

  if (remember) {
    sessionStorage.setItem(TAB_KEY, name);
    history.replaceState(null, '', '#' + name);
  }
}

/* Fold state per group, remembered across reloads. */
const GROUP_KEY = 'ms-groups:' + location.pathname;

function loadGroups() {
  try { return JSON.parse(localStorage.getItem(GROUP_KEY)) || {}; } catch (_) { return {}; }
}
function saveGroups(state) {
  try { localStorage.setItem(GROUP_KEY, JSON.stringify(state)); } catch (_) {}
}

function syncToggleAll() {
  const btn = document.getElementById('toggle-all');
  if (!btn) return;
  const visible = [...document.querySelectorAll('.panel:not([hidden]) .group')];
  btn.hidden = !visible.length;
  btn.textContent = visible.some(g => g.open) ? 'collapse all' : 'expand all';
}

function initGroups() {
  const state = loadGroups();
  document.querySelectorAll('.group').forEach(g => {
    const key = g.dataset.group;
    if (key in state) g.open = state[key];
    g.addEventListener('toggle', () => {
      const s = loadGroups();
      s[key] = g.open;
      saveGroups(s);
      syncToggleAll();
    });
  });
}

document.addEventListener('click', (e) => {
  const tab = e.target.closest('.tab');
  if (tab) { showTab(tab.dataset.tab, true); window.scrollTo(0, 0); return; }

  if (e.target.closest('#toggle-all')) {
    const visible = [...document.querySelectorAll('.panel:not([hidden]) .group')];
    const collapsing = visible.some(g => g.open);
    visible.forEach(g => { g.open = !collapsing; });
  }
});

initGroups();
showTab(location.hash.slice(1) || sessionStorage.getItem(TAB_KEY) || 'deck', false);
renderCounter();
