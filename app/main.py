"""magic-strategist web app.

Reads and writes the same data/collection.db the scripts use, so what a session
records shows up here and what is changed here is visible to a session.

    make app     ->  http://localhost:8000
"""

from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

import queries as q

BASE = Path(__file__).resolve().parent
app = FastAPI(title="magic-strategist")
app.mount("/static", StaticFiles(directory=BASE / "static"), name="static")
templates = Jinja2Templates(directory=BASE / "templates")
templates.env.globals["TYPE_ORDER"] = q.TYPE_ORDER


def asset(path: str) -> str:
    """Stamp static URLs with the file's mtime.

    Without this the browser keeps serving a cached app.js/app.css after an
    edit, and the page silently runs the old code.
    """
    f = BASE / "static" / path
    stamp = int(f.stat().st_mtime) if f.exists() else 0
    return f"/static/{path}?v={stamp}"


templates.env.globals["asset"] = asset


@app.get("/", response_class=HTMLResponse)
def index(request: Request):
    conn = q.connect()
    try:
        decks = q.list_decks(conn)
    finally:
        conn.close()
    if len(decks) == 1:
        return RedirectResponse(f"/deck/{decks[0]['slug']}")
    return templates.TemplateResponse("index.html", {"request": request, "decks": decks})


@app.get("/deck/{slug}", response_class=HTMLResponse)
def deck_view(request: Request, slug: str, role: str | None = None, q_: str | None = None):
    conn = q.connect()
    try:
        deck = q.get_deck(conn, slug)
        if deck is None:
            raise HTTPException(404, f"no deck '{slug}'")
        context = {
            "request": request,
            "deck": deck,
            "decks": q.list_decks(conn),
            "cards": q.deck_cards(conn, deck["id"]),
            "candidates": q.candidates(conn, deck, role=role, query=q_),
            "combos": q.deck_combos(conn, deck["id"]),
            "proposals": q.proposals(conn, deck["id"]),
            "totals": q.deck_totals(conn, deck["id"]),
            "active_role": role or "",
            "search": q_ or "",
        }
    finally:
        conn.close()
    return templates.TemplateResponse("deck.html", context)


@app.post("/api/proposal")
def api_toggle(deck_id: int = Form(...), oracle_id: str = Form(...), action: str = Form(...)):
    if action not in ("add", "cut"):
        raise HTTPException(400, "action must be 'add' or 'cut'")
    conn = q.connect()
    try:
        result = q.toggle_proposal(conn, deck_id, oracle_id, action)
        result["totals"] = q.deck_totals(conn, deck_id)
    finally:
        conn.close()
    return JSONResponse(result)


@app.post("/api/proposal/{proposal_id}/status")
def api_status(proposal_id: int, status: str = Form(...)):
    if status not in ("proposed", "accepted", "rejected", "applied"):
        raise HTTPException(400, "bad status")
    conn = q.connect()
    try:
        q.set_status(conn, proposal_id, status)
    finally:
        conn.close()
    return JSONResponse({"ok": True})
