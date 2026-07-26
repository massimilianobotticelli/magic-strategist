#!/usr/bin/env python3
"""Refresh the official Commander Game Changers list.

WotC maintains the list and revises it every few months; Scryfall exposes it as
the `is:game-changer` search. Game Changers decide bracket legality, so this is
the one piece of knowledge that must never be answered from memory.

Runs inside the container:
    make sync-gc
    docker compose run --rm app python scripts/sync_gamechangers.py --help
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import db  # noqa: E402
import scryfall  # noqa: E402
from enrich import oracle_id_of  # noqa: E402

OUTPUT_PATH = db.REPO_ROOT / "knowledge" / "game-changers.json"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Fetch the Commander Game Changers list and flag those cards.",
        epilog="Runs inside the container. Use `make sync-gc`.",
    )
    parser.add_argument("--db", type=Path, default=db.DB_PATH, help="database path")
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH, help="JSON output path")
    parser.add_argument(
        "--offline", action="store_true", help="re-apply the committed JSON without fetching"
    )
    args = parser.parse_args(argv)

    conn = db.connect(args.db)
    db.apply_schema(conn)

    if args.offline:
        if not args.output.exists():
            print(f"!! {args.output} does not exist; cannot run offline")
            return 1
        payload = json.loads(args.output.read_text())
        entries = payload["cards"]
        print(f"offline: {len(entries)} Game Changers from {args.output.name} "
              f"(fetched {payload.get('fetched_at')})")
    else:
        cards = list(scryfall.search("is:game-changer"))
        entries = sorted(
            ({"name": c["name"], "oracle_id": oracle_id_of(c)} for c in cards),
            key=lambda e: e["name"],
        )
        payload = {
            "source": "https://api.scryfall.com/cards/search?q=is%3Agame-changer",
            "fetched_at": date.today().isoformat(),
            "count": len(entries),
            "cards": entries,
        }
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(payload, indent=2) + "\n")
        print(f"fetched {len(entries)} Game Changers -> {args.output.relative_to(db.REPO_ROOT)}")

    oracle_ids = {e["oracle_id"] for e in entries if e["oracle_id"]}
    names = {e["name"] for e in entries}

    conn.execute("UPDATE cards SET is_game_changer = 0")
    if oracle_ids:
        conn.executemany(
            "UPDATE cards SET is_game_changer = 1 WHERE oracle_id = ?",
            [(oid,) for oid in oracle_ids],
        )
    conn.commit()

    # A card can be flagged without being owned - wishlist entries also get a
    # `cards` row - so report on physical copies, not on the flag alone.
    owned = conn.execute(
        """
        SELECT c.name, group_concat(DISTINCT l.slug) AS locations
          FROM cards c
          JOIN copies cp ON cp.oracle_id = c.oracle_id
          JOIN locations l ON l.id = cp.location_id
         WHERE c.is_game_changer = 1
         GROUP BY c.oracle_id ORDER BY c.name
        """
    ).fetchall()
    wanted = conn.execute(
        """
        SELECT DISTINCT c.name FROM cards c
          JOIN wishlist w ON w.oracle_id = c.oracle_id
         WHERE c.is_game_changer = 1
           AND NOT EXISTS (SELECT 1 FROM copies WHERE oracle_id = c.oracle_id)
         ORDER BY c.name
        """
    ).fetchall()

    print(f"\n{len(owned)} Game Changer(s) owned:")
    for row in owned:
        print(f"  ⚡ {row['name']}  ({row['locations']})")
    if not owned:
        print("  (none)")

    if wanted:
        print(f"\n{len(wanted)} Game Changer(s) on the wishlist but not owned:")
        for row in wanted:
            print(f"  ⚡ {row['name']}")

    print(f"\n({len(names)} Game Changers on the official list)")

    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
