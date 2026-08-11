#!/usr/bin/env python3
"""What to move in ManaBox so its binders match the decklists.

THE PROBLEM THIS SOLVES. `validate` compares a deck's list against the whole
collection's SUPPLY - it asks "do enough copies exist?", never "is the copy in
this deck's binder?". So a decklist can be edited, imported and validated
completely clean while the physical cards are still sitting in a pool. Nothing
fails, nothing warns, and the only symptom is that `query.py pool` keeps
offering cards that are actually sleeved in a deck - which is exactly how a
session ends up proposing a card he cannot take.

This script is the missing check. It reads what each decklist SAYS the deck
contains, compares it against what the last ManaBox export says is physically
in that deck's binder, and prints the moves that would close the gap.

    make moves                 every registered deck
    make moves ARGS='<slug>'   just one

Nothing here writes to the database or to ManaBox. It prints a shopping list
for ten minutes of tapping on a phone, and it is safe to run any time.
"""

from __future__ import annotations

import argparse
import sqlite3
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "data" / "collection.db"


def moves_for(conn: sqlite3.Connection, deck: sqlite3.Row) -> tuple[Counter, Counter]:
    """(to put IN the binder, to take OUT of it), counted by card name."""
    wanted = Counter()
    for r in conn.execute(
        """
        SELECT c.name, dc.quantity FROM deck_cards dc
          JOIN cards c ON c.oracle_id = dc.oracle_id
         WHERE dc.deck_id = ? AND dc.section IN ('main', 'commander')
        """,
        (deck["id"],),
    ):
        wanted[r["name"]] += r["quantity"]

    present = Counter()
    for r in conn.execute(
        """
        SELECT c.name, count(*) AS n FROM copies cp
          JOIN cards c ON c.oracle_id = cp.oracle_id
         WHERE cp.location_id = ? GROUP BY c.name
        """,
        (deck["location_id"],),
    ):
        present[r["name"]] = r["n"]

    return wanted - present, present - wanted


def where_free(conn: sqlite3.Connection, name: str, exclude_loc: int) -> list[str]:
    """Binders holding a takeable copy: a pool, or a deck marked donor."""
    rows = conn.execute(
        """
        SELECT l.slug, count(*) AS n FROM copies cp
          JOIN cards c ON c.oracle_id = cp.oracle_id
          JOIN locations l ON l.id = cp.location_id
         WHERE c.name = ? AND cp.location_id != ?
           AND (l.type = 'pool'
                OR l.id IN (SELECT location_id FROM decks WHERE status = 'donor'))
         GROUP BY l.slug ORDER BY count(*) DESC
        """,
        (name, exclude_loc),
    ).fetchall()
    return [f"{r['slug']}" + (f" (x{r['n']})" if r["n"] > 1 else "") for r in rows]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("slug", nargs="?", help="only this deck")
    args = ap.parse_args()

    if not DB.exists():
        print(f"no {DB}", file=sys.stderr)
        return 1
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row

    sql = "SELECT * FROM decks WHERE status IN ('active', 'draft')"
    params: list = []
    if args.slug:
        sql += " AND slug = ?"
        params.append(args.slug)
    decks = conn.execute(sql + " ORDER BY slug", params).fetchall()
    if not decks:
        print("no matching deck")
        return 1

    clean = True
    for deck in decks:
        put_in, take_out = moves_for(conn, deck)
        binder = conn.execute("SELECT slug FROM locations WHERE id = ?",
                              (deck["location_id"],)).fetchone()["slug"]
        if not put_in and not take_out:
            print(f"\n{deck['slug']}: binder '{binder}' already matches the decklist")
            continue

        clean = False
        print(f"\n{deck['slug']}  ->  ManaBox binder '{binder}'")
        for name, n in sorted(take_out.items()):
            print(f"    OUT  {n}x {name}")
        for name, n in sorted(put_in.items()):
            src = where_free(conn, name, deck["location_id"])
            hint = "  from " + ", ".join(src) if src else "  NO FREE COPY - it is in another active deck"
            print(f"    IN   {n}x {name}{hint}")

    if not clean:
        print("\nMove those in ManaBox, re-export, drop it in data/manabox/<date>/,")
        print("then `make rebuild && make validate`. Re-run this to confirm it is clean.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
