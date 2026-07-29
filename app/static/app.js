function renderCounter() {
  const el = document.getElementById('counter');
  if (!el) return;
  const size = +el.dataset.size, cuts = +el.dataset.cuts, adds = +el.dataset.adds;
  const projected = size - cuts + adds;
  const off = projected !== 100;
  el.innerHTML =
    '<b>' + size + '</b> carte' +
    (cuts ? ' · <span class="c-cut">−' + cuts + '</span>' : '') +
    (adds ? ' · <span class="c-add">+' + adds + '</span>' : '') +
    ((cuts || adds)
      ? ' → <span class="' + (off ? 'c-bad' : '') + '">' + projected + '</span>' +
        (off ? ' (non 100)' : '')
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

  const cls = 'tile-' + tile.dataset.action;
  tile.classList.toggle(cls, data.state === 'created');

  const el = document.getElementById('counter');
  if (el && data.totals) {
    el.dataset.size = data.totals.size;
    el.dataset.cuts = data.totals.cuts;
    el.dataset.adds = data.totals.adds;
    renderCounter();
  }
}

document.addEventListener('click', (e) => {
  const tile = e.target.closest('.tile:not(.tile-static)');
  if (tile) { toggle(tile); return; }

  const btn = e.target.closest('.proposal-actions button');
  if (btn) {
    const card = btn.closest('.proposal');
    const body = new FormData();
    body.append('status', btn.dataset.status);
    fetch('/api/proposal/' + card.dataset.id + '/status', { method: 'POST', body })
      .then(() => location.reload());
    return;
  }

  const zoom = document.getElementById('zoom');
  if (zoom && !zoom.hidden) zoom.hidden = true;
});

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') { const z = document.getElementById('zoom'); if (z) z.hidden = true; }
  if ((e.key === 'Enter' || e.key === ' ') && document.activeElement.classList.contains('tile')) {
    e.preventDefault();
    toggle(document.activeElement);
  }
});

let hoverTimer = null;
document.addEventListener('mouseover', (e) => {
  const img = e.target.closest('.tile img');
  clearTimeout(hoverTimer);
  if (!img) return;
  hoverTimer = setTimeout(() => {
    const zoom = document.getElementById('zoom');
    if (!zoom) return;
    document.getElementById('zoom-img').src = img.dataset.full || img.src;
    zoom.hidden = false;
  }, 420);
});
document.addEventListener('mouseout', (e) => {
  if (e.target.closest('.tile img')) clearTimeout(hoverTimer);
});

renderCounter();
