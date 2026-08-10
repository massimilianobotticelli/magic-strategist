"""Read and write queries behind the web app.

Everything goes through the same data/collection.db that the scripts use, so a
session and the app are always looking at the same collection. No caching, no
second source of truth.
"""

from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import db  # noqa: E402

BRACKET_NAMES = {1: "Exhibition", 2: "Core", 3: "Upgraded", 4: "Optimized", 5: "cEDH"}

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import formats as fmt_rules  # noqa: E402

FORMAT_NAMES = {k: v.name for k, v in fmt_rules.FORMATS.items()}
FORMAT_LIST = [
    {"slug": k, "name": v.name, "notes": v.notes} for k, v in fmt_rules.FORMATS.items()
]

# The order deck sections are shown in, and how a type line maps onto them.
TYPE_ORDER = [
    ("commander", "Commander"),
    ("creature", "Creatures"),
    ("planeswalker", "Planeswalkers"),
    ("instant-sorcery", "Instants and sorceries"),
    ("artifact", "Artifacts"),
    ("enchantment", "Enchantments"),
    ("land", "Lands"),
]


def type_group(type_line: str | None, is_commander: bool = False) -> str:
    t = type_line or ""
    if is_commander:
        return "commander"
    if "Land" in t:
        return "land"
    if "Creature" in t:
        return "creature"
    if "Planeswalker" in t:
        return "planeswalker"
    if "Instant" in t or "Sorcery" in t:
        return "instant-sorcery"
    if "Artifact" in t:
        return "artifact"
    if "Enchantment" in t:
        return "enchantment"
    return "instant-sorcery"


def connect() -> sqlite3.Connection:
    return db.connect()


# ---------------------------------------------------------------------------
# Reads
# ---------------------------------------------------------------------------
def list_decks(conn) -> list[dict]:
    rows = conn.execute(
        """
        SELECT d.id, d.slug, d.name, d.status, d.target_bracket, d.color_identity,
               c.name AS commander,
               (SELECT COALESCE(SUM(quantity),0) FROM deck_cards
                 WHERE deck_id = d.id AND section IN ('main','commander')) AS size,
               (SELECT count(*) FROM deck_proposals p
                 WHERE p.deck_id = d.id AND p.status = 'proposed') AS open_proposals
          FROM decks d LEFT JOIN cards c ON c.oracle_id = d.commander_oracle_id
         ORDER BY d.status, d.slug
        """
    ).fetchall()
    out = []
    for r in rows:
        d = dict(r)
        d["bracket_name"] = BRACKET_NAMES.get(d["target_bracket"], "—")
        out.append(d)
    return out


def get_deck(conn, slug: str) -> dict | None:
    row = conn.execute(
        """
        SELECT d.*, c.name AS commander, c.oracle_text AS commander_text,
               c.mana_cost AS commander_cost
          FROM decks d LEFT JOIN cards c ON c.oracle_id = d.commander_oracle_id
         WHERE d.slug = ?
        """,
        (slug,),
    ).fetchone()
    if row is None:
        return None
    deck = dict(row)
    deck["bracket_name"] = BRACKET_NAMES.get(deck["target_bracket"], "—")
    return deck


def _proposal_map(conn, deck_id: int) -> dict[str, dict]:
    return {
        r["oracle_id"]: dict(r)
        for r in conn.execute(
            "SELECT * FROM deck_proposals WHERE deck_id = ? AND status IN ('proposed','accepted')",
            (deck_id,),
        )
    }


def deck_cards(conn, deck_id: int, sections: tuple[str, ...] = ("main", "commander")) -> list[dict]:
    """The deck list, with images, roles, combo membership and any proposal.

    Commander and PDH have no sideboard, so the default sections are what every
    caller wanted until Modern arrived; ask for ('sideboard',) to get the rest.
    """
    proposals = _proposal_map(conn, deck_id)
    rows = conn.execute(
        """
        SELECT dc.quantity, dc.section, c.oracle_id, c.name, c.mana_cost, c.mana_value,
               c.type_line, c.oracle_text, c.color_identity, c.is_game_changer,
               COALESCE(dc.printing_id, (SELECT scryfall_id FROM printings p
                                          WHERE p.oracle_id = c.oracle_id LIMIT 1)) AS printing_id,
               (SELECT group_concat(ro.slug) FROM card_roles cr
                  JOIN roles ro ON ro.id = cr.role_id
                 WHERE cr.oracle_id = c.oracle_id) AS roles,
               (SELECT group_concat(cb.name, ' | ') FROM combo_pieces cp
                  JOIN combos cb ON cb.id = cp.combo_id
                 WHERE cp.oracle_id = c.oracle_id) AS combos
          FROM deck_cards dc JOIN cards c ON c.oracle_id = dc.oracle_id
         WHERE dc.deck_id = ? AND dc.section IN (%s)
         ORDER BY c.mana_value, c.name
        """
        % ",".join("?" * len(sections)),
        (deck_id, *sections),
    ).fetchall()

    out = []
    for r in rows:
        card = dict(r)
        card["group"] = type_group(card["type_line"], card["section"] == "commander")
        card["image"], card["image_small"] = _images(conn, card["printing_id"])
        card["roles"] = (card["roles"] or "").split(",") if card["roles"] else []
        prop = proposals.get(card["oracle_id"])
        card["proposal"] = prop if prop and prop["action"] == "cut" else None
        out.append(card)
    return out


def _images(conn, printing_id: str | None) -> tuple[str | None, str | None]:
    if not printing_id:
        return None, None
    row = conn.execute(
        "SELECT image_uri, image_small FROM printings WHERE scryfall_id = ?", (printing_id,)
    ).fetchone()
    return (row["image_uri"], row["image_small"]) if row else (None, None)


def wishlist(conn, deck_id: int) -> list[dict]:
    """Cards to buy for this deck, worst-priority last.

    A wishlist row is keyed by card NAME, because the whole point is that the
    card is not owned yet - there is no copy and often no printing either. The
    join to `cards` is a left join for the same reason, and it only resolves at
    all because those names are listed in the Makefile's EXTRA_CARDS so a
    rebuild enriches them.
    """
    rows = conn.execute(
        """
        SELECT w.id, w.card_name, w.quantity, w.priority, w.price_ceiling_eur,
               w.status, w.notes, c.mana_cost, c.type_line, c.oracle_text,
               (SELECT p.scryfall_id FROM printings p
                 WHERE p.oracle_id = c.oracle_id ORDER BY p.released_at DESC LIMIT 1) AS printing_id
          FROM wishlist w LEFT JOIN cards c ON c.oracle_id = w.oracle_id
         WHERE w.deck_id = ?
         ORDER BY w.status = 'dropped', w.priority, w.card_name
        """,
        (deck_id,),
    ).fetchall()
    out = []
    for r in rows:
        item = dict(r)
        item["image"], item["image_small"] = _images(conn, item.pop("printing_id"))
        out.append(item)
    return out


def candidates(conn, deck: dict, role: str | None = None, query: str | None = None,
               free_only: bool = False) -> list[dict]:
    """Cards you own that are legal in this deck and not already in it.

    Pools and donor decks both count as available inventory; a card sitting in
    another ACTIVE deck is shown too, but flagged, because taking it costs that
    deck the card. `free_only` drops that second kind entirely, which is the
    view you want when the rule is "nothing may be taken out of a live deck".
    """
    identity = set(deck["color_identity"] or "")
    rows = conn.execute(
        """
        SELECT DISTINCT c.oracle_id, c.name, c.mana_cost, c.mana_value, c.type_line,
               c.oracle_text, c.color_identity, c.is_game_changer,
               l.slug AS location, l.type AS location_type,
               (SELECT status FROM decks WHERE location_id = l.id) AS deck_status,
               cp.printing_id,
               (SELECT group_concat(ro.slug) FROM card_roles cr
                  JOIN roles ro ON ro.id = cr.role_id
                 WHERE cr.oracle_id = c.oracle_id) AS roles
          FROM copies cp
          JOIN cards c ON c.oracle_id = cp.oracle_id
          JOIN locations l ON l.id = cp.location_id
         WHERE c.is_basic_land = 0 AND c.is_token = 0
           AND c.oracle_id NOT IN (SELECT oracle_id FROM deck_cards
                                    WHERE deck_id = ? AND oracle_id IS NOT NULL)
         -- The last key decides which row survives the dedup below, and it has
         -- to prefer a free copy: he owns a few cards twice, and showing the
         -- one locked in an active deck would paint a card amber that is
         -- actually sitting in a pool, free to take.
         ORDER BY c.mana_value, c.name,
                  (l.type = 'pool'
                   OR (SELECT status FROM decks WHERE location_id = l.id) = 'donor') DESC
        """,
        (deck["id"],),
    ).fetchall()

    proposals = _proposal_map(conn, deck["id"])
    seen: set[str] = set()
    out = []
    for r in rows:
        card = dict(r)
        if set(card["color_identity"] or "") - identity:
            continue
        # Taking a card out of an active deck weakens it; out of a pool or a
        # donor deck it costs nothing.
        card["free"] = card["location_type"] == "pool" or card["deck_status"] == "donor"
        # This has to happen BEFORE the dedup below. There is one row per
        # (card, location), and he owns a few cards twice - so a copy locked in
        # an active deck can arrive first and, if it were allowed to claim the
        # `seen` slot, would hide the free copy sitting in a pool behind it.
        # That is the exact blind spot CLAUDE.md warns about.
        if free_only and not card["free"]:
            continue
        if card["oracle_id"] in seen:
            continue
        card["roles"] = (card["roles"] or "").split(",") if card["roles"] else []
        if role and role not in card["roles"]:
            continue
        if query and query.lower() not in card["name"].lower():
            continue
        seen.add(card["oracle_id"])
        card["group"] = type_group(card["type_line"])
        card["image"], card["image_small"] = _images(conn, card["printing_id"])
        prop = proposals.get(card["oracle_id"])
        card["proposal"] = prop if prop and prop["action"] == "add" else None
        out.append(card)
    return out


def deck_combos(conn, deck_id: int) -> list[dict]:
    combos = []
    for cb in conn.execute("SELECT * FROM combos WHERE deck_id = ? ORDER BY name", (deck_id,)):
        combo = dict(cb)
        combo["pieces"] = []
        for p in conn.execute(
            """
            SELECT c.oracle_id, c.name, c.mana_cost, c.type_line, cp.note,
                   (SELECT l.slug FROM copies co JOIN locations l ON l.id = co.location_id
                     WHERE co.oracle_id = cp.oracle_id LIMIT 1) AS at,
                   (SELECT scryfall_id FROM printings p2 WHERE p2.oracle_id = c.oracle_id LIMIT 1) AS printing_id
              FROM combo_pieces cp JOIN cards c ON c.oracle_id = cp.oracle_id
             WHERE cp.combo_id = ? ORDER BY c.mana_value, c.name
            """,
            (combo["id"],),
        ):
            piece = dict(p)
            piece["image"], piece["image_small"] = _images(conn, piece["printing_id"])
            combo["pieces"].append(piece)
        combo["disablers"] = [
            dict(d)
            for d in conn.execute(
                """
                SELECT c.name, cd.note,
                       (SELECT scryfall_id FROM printings p WHERE p.oracle_id = c.oracle_id LIMIT 1) AS printing_id
                  FROM combo_disablers cd JOIN cards c ON c.oracle_id = cd.oracle_id
                 WHERE cd.combo_id = ? ORDER BY c.name
                """,
                (combo["id"],),
            )
        ]
        combos.append(combo)
    return combos


def _where_copies_are(conn, oracle_id: str, this_slug: str | None = None) -> list[dict]:
    """Every physical copy of a card, and whether it can be taken freely.

    Three states, because they mean three different things at the table:

      here  - the copy is in THIS deck. For a `cut` that is simply where it is
              now; it is not a warning and must not be coloured like one.
      free  - a loose binder, or a deck marked donor, which is a parts bin.
              Same definition query.py uses for `pool`. This is the box to open.
      busy  - a copy in ANOTHER active deck. It exists, but taking it strips
              that deck, which is a decision rather than a fetch.
    """
    rows = conn.execute(
        """
        SELECT l.slug, l.type, p.set_code, p.collector_number, cp.is_foil,
               (SELECT status FROM decks d WHERE d.location_id = l.id) AS deck_status
          FROM copies cp
          JOIN locations l ON l.id = cp.location_id
          JOIN printings p ON p.scryfall_id = cp.printing_id
         WHERE cp.oracle_id = ?
         ORDER BY l.slug
        """,
        (oracle_id,),
    ).fetchall()
    # Grouped by binder, not one entry per copy: he owns two Frog Butler in the
    # same pool, and two identical chips say nothing a count does not.
    seen: dict[str, dict] = {}
    for r in rows:
        loc = dict(r)
        if loc["slug"] in seen:
            seen[loc["slug"]]["count"] += 1
            continue
        loc["count"] = 1
        loc["here"] = loc["slug"] == this_slug
        loc["free"] = not loc["here"] and (loc["type"] == "pool"
                                           or loc["deck_status"] == "donor")
        loc["state"] = "here" if loc["here"] else ("free" if loc["free"] else "busy")
        seen[loc["slug"]] = loc

    out = list(seen.values())
    # free copies first: that is the box he should actually open
    out.sort(key=lambda x: {"free": 0, "here": 1, "busy": 2}[x["state"]])
    return out


def proposals(conn, deck_id: int) -> list[dict]:
    """Open proposals, with the card image and where the physical copy lives.

    Both extras exist for the same reason: a proposal is a shopping list for a
    box of cards, so it has to say what the card looks like and which binder it
    is in. An `add` is only actionable if he can find a FREE copy.
    """
    this_slug = conn.execute(
        "SELECT slug FROM decks WHERE id = ?", (deck_id,)
    ).fetchone()["slug"]
    rows = conn.execute(
        """
        SELECT p.*, c.name, c.mana_cost, c.type_line, c.oracle_text, c.oracle_id,
               (SELECT scryfall_id FROM printings pr WHERE pr.oracle_id = c.oracle_id LIMIT 1) AS printing_id
          FROM deck_proposals p JOIN cards c ON c.oracle_id = p.oracle_id
         WHERE p.deck_id = ? AND p.status != 'applied'
         ORDER BY p.action DESC, c.name
        """,
        (deck_id,),
    ).fetchall()

    out = []
    for r in rows:
        prop = dict(r)
        prop["image"], prop["image_small"] = _images(conn, prop["printing_id"])
        prop["locations"] = _where_copies_are(conn, prop["oracle_id"], this_slug)
        prop["free_somewhere"] = any(loc["free"] for loc in prop["locations"])
        out.append(prop)
    return out


# ---------------------------------------------------------------------------
# Writes
# ---------------------------------------------------------------------------
def toggle_proposal(conn, deck_id: int, oracle_id: str, action: str, source: str = "massimiliano",
                    rationale: str | None = None) -> dict:
    """Create a proposal, or remove it if the same one already exists."""
    existing = conn.execute(
        "SELECT * FROM deck_proposals WHERE deck_id = ? AND oracle_id = ? AND action = ?",
        (deck_id, oracle_id, action),
    ).fetchone()

    if existing:
        conn.execute("DELETE FROM deck_proposals WHERE id = ?", (existing["id"],))
        conn.commit()
        return {"state": "removed"}

    conn.execute(
        """
        INSERT INTO deck_proposals (deck_id, oracle_id, action, source, rationale)
        VALUES (?, ?, ?, ?, ?)
        """,
        (deck_id, oracle_id, action, source, rationale),
    )
    conn.commit()
    return {"state": "created", "action": action}


def set_status(conn, proposal_id: int, status: str) -> None:
    conn.execute("UPDATE deck_proposals SET status = ? WHERE id = ?", (status, proposal_id))
    conn.commit()


def create_request(conn, **fields) -> int:
    cur = conn.execute(
        """
        INSERT INTO deck_requests (format, colors, commander_hint, strategy,
                                   allow_borrowing, allow_buying, notes)
        VALUES (:format, :colors, :commander_hint, :strategy,
                :allow_borrowing, :allow_buying, :notes)
        """,
        fields,
    )
    conn.commit()
    return int(cur.lastrowid)


def list_requests(conn, status: str | None = None) -> list[dict]:
    sql = """
        SELECT r.*, d.slug AS deck_slug, d.name AS deck_name
          FROM deck_requests r LEFT JOIN decks d ON d.id = r.deck_id
    """
    params: tuple = ()
    if status:
        sql += " WHERE r.status = ?"
        params = (status,)
    sql += " ORDER BY r.created_at DESC"
    out = []
    for r in conn.execute(sql, params):
        row = dict(r)
        row["format_name"] = FORMAT_NAMES.get(row["format"], row["format"])
        out.append(row)
    return out


def dismiss_request(conn, request_id: int) -> None:
    conn.execute("UPDATE deck_requests SET status = 'dismissed' WHERE id = ?", (request_id,))
    conn.commit()


def deck_totals(conn, deck_id: int) -> dict:
    size = conn.execute(
        "SELECT COALESCE(SUM(quantity),0) n FROM deck_cards "
        "WHERE deck_id = ? AND section IN ('main','commander')", (deck_id,)
    ).fetchone()["n"]
    cuts = conn.execute(
        "SELECT count(*) n FROM deck_proposals WHERE deck_id = ? AND action='cut' "
        "AND status IN ('proposed','accepted')", (deck_id,)
    ).fetchone()["n"]
    adds = conn.execute(
        "SELECT count(*) n FROM deck_proposals WHERE deck_id = ? AND action='add' "
        "AND status IN ('proposed','accepted')", (deck_id,)
    ).fetchone()["n"]
    side = conn.execute(
        "SELECT COALESCE(SUM(quantity),0) n FROM deck_cards "
        "WHERE deck_id = ? AND section = 'sideboard'", (deck_id,)
    ).fetchone()["n"]
    slug = conn.execute("SELECT format FROM decks WHERE id = ?", (deck_id,)).fetchone()["format"]
    rules = fmt_rules.get(slug)
    return {
        "size": size, "cuts": cuts, "adds": adds, "projected": size - cuts + adds,
        "sideboard": side,
        # The counter used to hardcode 100, which is wrong for a 60-card format.
        "target": rules.deck_size, "exact": rules.exact_size,
        "sideboard_max": rules.sideboard,
    }
