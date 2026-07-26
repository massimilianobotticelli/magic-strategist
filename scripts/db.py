"""Shared database helpers for the magic-strategist collection.

Runs inside the container only. See CLAUDE.md.
"""

from __future__ import annotations

import re
import sqlite3
import unicodedata
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DB_PATH = REPO_ROOT / "data" / "collection.db"
SCHEMA_PATH = Path(__file__).resolve().parent / "schema.sql"
SCRYFALL_CACHE = REPO_ROOT / "data" / "scryfall"

SCHEMA_VERSION = "1"

# Deck binders win over loose binders when the same card is claimed twice, so
# the surviving physical copy is the one that is actually sleeved in a deck.
BINDER_TYPE_PRIORITY = {"deck": 0, "binder": 1, "list": 2}


def connect(path: Path | str = DB_PATH) -> sqlite3.Connection:
    """Open the collection database with foreign keys enforced."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def apply_schema(conn: sqlite3.Connection) -> None:
    """Create every table, index and trigger. Safe to run repeatedly."""
    conn.executescript(SCHEMA_PATH.read_text())
    conn.execute(
        "INSERT INTO meta (key, value) VALUES ('schema_version', ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        (SCHEMA_VERSION,),
    )
    conn.commit()


def slugify(name: str) -> str:
    """'Blight-Curse-B4-Final' -> 'blight-curse-b4-final'."""
    text = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    text = re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()
    return re.sub(r"-{2,}", "-", text) or "unnamed"


def ensure_location(conn: sqlite3.Connection, name: str, loc_type: str, slug: str | None = None) -> int:
    """Get or create a location, returning its id."""
    slug = slug or slugify(name)
    row = conn.execute("SELECT id FROM locations WHERE slug = ?", (slug,)).fetchone()
    if row:
        return row["id"]
    cur = conn.execute(
        "INSERT INTO locations (slug, name, type) VALUES (?, ?, ?)", (slug, name, loc_type)
    )
    return int(cur.lastrowid)


def ensure_deck(conn: sqlite3.Connection, name: str, slug: str | None = None) -> int:
    """Get or create a deck (and its backing location), returning the deck id."""
    slug = slug or slugify(name)
    location_id = ensure_location(conn, name, "deck", slug)
    row = conn.execute("SELECT id FROM decks WHERE slug = ?", (slug,)).fetchone()
    if row:
        return row["id"]
    cur = conn.execute(
        "INSERT INTO decks (location_id, slug, name) VALUES (?, ?, ?)", (location_id, slug, name)
    )
    return int(cur.lastrowid)


# ---------------------------------------------------------------------------
# Materialisation
# ---------------------------------------------------------------------------
# ManaBox exports carry a Scryfall *printing* id but no oracle_id, so the
# abstract card behind a row is unknown until enrich.py has run. Import
# therefore stages rows in `manabox_rows`, and this step turns them into
# `copies` once the oracle_id is known. It is idempotent: it rebuilds copies
# from the staging table every time.


def materialize_copies(conn: sqlite3.Connection) -> dict[str, int]:
    """Rebuild `copies` from staged ManaBox rows.

    One row per physical card: a ManaBox quantity of 3 becomes three copies.
    The collection genuinely contains multiples (every precon ships its own Sol
    Ring), so nothing is deduplicated here. Whether a deck list asks for more
    copies than exist is a question for validate.py.

    Rows that cannot become a copy at all - unknown printing, card not yet
    enriched - are recorded in `copy_conflicts` rather than dropped.
    """
    conn.execute("DELETE FROM copies")
    conn.execute("DELETE FROM copy_conflicts")

    rows = conn.execute(
        """
        SELECT r.*, p.oracle_id AS oracle_id, c.is_basic_land AS is_basic_land
          FROM manabox_rows r
          LEFT JOIN printings p ON p.scryfall_id = r.scryfall_id
          LEFT JOIN cards     c ON c.oracle_id   = p.oracle_id
         WHERE r.binder_type IN ('deck', 'binder')
        """
    ).fetchall()

    # Deck rows are processed first so a deck keeps the card when a loose
    # binder also claims it.
    rows = sorted(
        rows,
        key=lambda r: (BINDER_TYPE_PRIORITY.get(r["binder_type"], 9), r["binder_name"] or "", r["id"]),
    )

    stats = {"copies": 0, "conflicts": 0, "unenriched": 0}

    for row in rows:
        if not row["oracle_id"]:
            stats["unenriched"] += 1
            stats["conflicts"] += 1
            _record_conflict(
                conn, row, None, "card not enriched yet - run enrich.py", None
            )
            continue

        loc_type = "deck" if row["binder_type"] == "deck" else "pool"
        slug = slugify(row["binder_name"] or "unsorted")
        if loc_type == "deck":
            ensure_deck(conn, row["binder_name"], slug)
        location_id = ensure_location(conn, row["binder_name"] or "Unsorted", loc_type, slug)

        is_basic = int(row["is_basic_land"] or 0)
        quantity = max(1, int(row["quantity"] or 1))

        # One row per physical card, exactly as ManaBox reports it.
        for _ in range(quantity):
            try:
                conn.execute(
                    """
                    INSERT INTO copies (printing_id, oracle_id, location_id, is_foil,
                                        is_basic_land, condition, language,
                                        purchase_price, purchase_currency,
                                        acquired_at, source_row_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        row["scryfall_id"],
                        row["oracle_id"],
                        location_id,
                        1 if (row["foil"] or "").lower() == "foil" else 0,
                        is_basic,
                        row["condition"],
                        row["language"] or "en",
                        row["purchase_price"],
                        row["purchase_currency"],
                        row["added_at"],
                        row["id"],
                    ),
                )
                stats["copies"] += 1
            except sqlite3.IntegrityError as exc:
                _record_conflict(conn, row, row["oracle_id"], str(exc), slug)
                stats["conflicts"] += 1

    conn.commit()
    return stats


def _record_conflict(conn, row, oracle_id, reason, kept_slug) -> None:
    conn.execute(
        """
        INSERT INTO copy_conflicts (card_name, oracle_id, printing_id, location_slug,
                                    kept_location_slug, quantity, reason, source_row_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            row["name"],
            oracle_id,
            row["scryfall_id"],
            slugify(row["binder_name"] or "unsorted"),
            kept_slug,
            row["quantity"],
            reason,
            row["id"],
        ),
    )


def resolve_deck_cards(conn: sqlite3.Connection) -> dict[str, int]:
    """Fill in deck_cards.oracle_id / printing_id once cards are enriched.

    Matches on set code + collector number first (exact, survives reprints and
    double-faced cards), then falls back to an exact name match.
    """
    stats = {"by_printing": 0, "by_name": 0, "unresolved": 0}

    for row in conn.execute("SELECT * FROM deck_cards WHERE oracle_id IS NULL").fetchall():
        printing = None
        if row["set_code"] and row["collector_number"]:
            printing = conn.execute(
                """
                SELECT scryfall_id, oracle_id FROM printings
                 WHERE lower(set_code) = lower(?) AND collector_number = ? AND oracle_id IS NOT NULL
                 LIMIT 1
                """,
                (row["set_code"], row["collector_number"]),
            ).fetchone()

        if printing:
            conn.execute(
                "UPDATE deck_cards SET oracle_id = ?, printing_id = ? WHERE id = ?",
                (printing["oracle_id"], printing["scryfall_id"], row["id"]),
            )
            stats["by_printing"] += 1
            continue

        card = conn.execute(
            "SELECT oracle_id FROM cards WHERE name = ? LIMIT 1", (row["card_name"],)
        ).fetchone()
        if card:
            conn.execute(
                "UPDATE deck_cards SET oracle_id = ? WHERE id = ?", (card["oracle_id"], row["id"])
            )
            stats["by_name"] += 1
        else:
            stats["unresolved"] += 1

    conn.commit()
    return stats


def refresh_deck_metadata(conn: sqlite3.Connection) -> None:
    """Derive each deck's commander and colour identity from its list."""
    for deck in conn.execute("SELECT * FROM decks").fetchall():
        commander = conn.execute(
            """
            SELECT c.oracle_id, c.color_identity
              FROM deck_cards d JOIN cards c ON c.oracle_id = d.oracle_id
             WHERE d.deck_id = ? AND d.section = 'commander'
             LIMIT 1
            """,
            (deck["id"],),
        ).fetchone()

        # No explicit // COMMANDER marker: fall back to the only legendary
        # creature in the list that is legal as a commander.
        if commander is None:
            candidates = conn.execute(
                """
                SELECT c.oracle_id, c.color_identity
                  FROM deck_cards d JOIN cards c ON c.oracle_id = d.oracle_id
                 WHERE d.deck_id = ? AND c.can_be_commander = 1
                """,
                (deck["id"],),
            ).fetchall()
            if len(candidates) == 1:
                commander = candidates[0]

        if commander is not None:
            conn.execute(
                "UPDATE decks SET commander_oracle_id = ?, color_identity = ? WHERE id = ?",
                (commander["oracle_id"], commander["color_identity"], deck["id"]),
            )
    conn.commit()
