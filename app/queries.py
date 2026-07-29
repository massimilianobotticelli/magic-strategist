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

# The order deck sections are shown in, and how a type line maps onto them.
TYPE_ORDER = [
    ("commander", "Comandante"),
    ("creature", "Creature"),
    ("planeswalker", "Planeswalker"),
    ("instant-sorcery", "Istantanei e stregonerie"),
    ("artifact", "Artefatti"),
    ("enchantment", "Incantesimi"),
    ("land", "Terre"),
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


def deck_cards(conn, deck_id: int) -> list[dict]:
    """The deck list, with images, roles, combo membership and any proposal."""
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
         WHERE dc.deck_id = ? AND dc.section IN ('main','commander')
         ORDER BY c.mana_value, c.name
        """,
        (deck_id,),
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


def candidates(conn, deck: dict, role: str | None = None, query: str | None = None) -> list[dict]:
    """Cards you own that are legal in this deck and not already in it.

    Pools and donor decks both count as available inventory; a card sitting in
    another ACTIVE deck is shown too, but flagged, because taking it costs that
    deck the card.
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
         ORDER BY c.mana_value, c.name
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
        # Taking a card out of an active deck weakens it; out of a pool or a
        # donor deck it costs nothing.
        card["free"] = card["location_type"] == "pool" or card["deck_status"] == "donor"
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


def proposals(conn, deck_id: int) -> list[dict]:
    return [
        dict(r)
        for r in conn.execute(
            """
            SELECT p.*, c.name, c.mana_cost, c.type_line,
                   (SELECT scryfall_id FROM printings pr WHERE pr.oracle_id = c.oracle_id LIMIT 1) AS printing_id
              FROM deck_proposals p JOIN cards c ON c.oracle_id = p.oracle_id
             WHERE p.deck_id = ? AND p.status != 'applied'
             ORDER BY p.action DESC, c.name
            """,
            (deck_id,),
        )
    ]


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
    return {"size": size, "cuts": cuts, "adds": adds, "projected": size - cuts + adds}
