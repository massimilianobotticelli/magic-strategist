#!/usr/bin/env python3
"""Populate `cards` and `printings` with real card data from Scryfall.

Two of the decks are built from Lorwyn Eclipsed (ECL/ECC) and Secrets of
Strixhaven (SOS), which are too recent to reason about from memory. Without
real oracle text, deck analysis is guesswork - so this is the script that makes
everything else trustworthy.

Runs inside the container:
    make enrich
    docker compose run --rm app python scripts/enrich.py --help
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import db  # noqa: E402
import roles  # noqa: E402
import scryfall  # noqa: E402


def oracle_id_of(card: dict) -> str | None:
    """Reversible cards carry oracle_id on the faces, not at the top level."""
    if card.get("oracle_id"):
        return card["oracle_id"]
    for face in card.get("card_faces") or []:
        if face.get("oracle_id"):
            return face["oracle_id"]
    return None


def combined_text(card: dict) -> str:
    """Oracle text including the back face - never silently drop it."""
    if card.get("oracle_text") is not None and not card.get("card_faces"):
        return card["oracle_text"]

    faces = card.get("card_faces") or []
    if faces:
        parts = []
        for face in faces:
            header = face.get("name", "")
            body = face.get("oracle_text", "")
            parts.append(f"// {header}\n{body}".strip())
        return "\n\n".join(parts)
    return card.get("oracle_text") or ""


def face_value(card: dict, key: str) -> str | None:
    if card.get(key) is not None:
        return card[key]
    for face in card.get("card_faces") or []:
        if face.get(key) is not None:
            return face[key]
    return None


def upsert_card(conn, card: dict) -> str | None:
    oracle_id = oracle_id_of(card)
    if not oracle_id:
        return None

    type_line = card.get("type_line") or " // ".join(
        f.get("type_line", "") for f in card.get("card_faces") or []
    )
    is_basic = int("Basic" in type_line and "Land" in type_line)
    # Tokens come out of booster packs in multiples and are not deck cards.
    is_token = int(card.get("layout") in ("token", "double_faced_token", "emblem")
                   or "Token" in type_line)
    is_legendary = int("Legendary" in type_line)
    text = combined_text(card)
    can_be_commander = int(
        (is_legendary and "Creature" in type_line)
        or "can be your commander" in text.lower()
    )

    conn.execute(
        """
        INSERT INTO cards (oracle_id, name, mana_cost, mana_value, type_line, oracle_text,
                           power, toughness, loyalty, colors, color_identity, keywords,
                           layout, card_faces, is_basic_land, is_token, is_legendary,
                           can_be_commander, scryfall_uri, enriched_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(oracle_id) DO UPDATE SET
            name = excluded.name, mana_cost = excluded.mana_cost,
            mana_value = excluded.mana_value, type_line = excluded.type_line,
            oracle_text = excluded.oracle_text, power = excluded.power,
            toughness = excluded.toughness, loyalty = excluded.loyalty,
            colors = excluded.colors, color_identity = excluded.color_identity,
            keywords = excluded.keywords, layout = excluded.layout,
            card_faces = excluded.card_faces, is_basic_land = excluded.is_basic_land,
            is_token = excluded.is_token, is_legendary = excluded.is_legendary,
            can_be_commander = excluded.can_be_commander,
            scryfall_uri = excluded.scryfall_uri, enriched_at = excluded.enriched_at
        """,
        (
            oracle_id,
            card.get("name"),
            card.get("mana_cost") or face_value(card, "mana_cost"),
            card.get("cmc"),
            type_line,
            text,
            card.get("power") or face_value(card, "power"),
            card.get("toughness") or face_value(card, "toughness"),
            card.get("loyalty") or face_value(card, "loyalty"),
            "".join(card.get("colors") or []),
            "".join(sorted(card.get("color_identity") or [])),
            json.dumps(card.get("keywords") or []),
            card.get("layout"),
            json.dumps(card["card_faces"]) if card.get("card_faces") else None,
            is_basic,
            is_token,
            is_legendary,
            can_be_commander,
            card.get("scryfall_uri"),
            datetime.now(timezone.utc).isoformat(timespec="seconds"),
        ),
    )

    image = (card.get("image_uris") or {}).get("normal")
    if not image and card.get("card_faces"):
        image = (card["card_faces"][0].get("image_uris") or {}).get("normal")

    conn.execute(
        """
        INSERT INTO printings (scryfall_id, oracle_id, name, set_code, set_name,
                               collector_number, rarity, lang, finishes, released_at, image_uri)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(scryfall_id) DO UPDATE SET
            oracle_id = excluded.oracle_id, name = excluded.name,
            set_code = excluded.set_code, set_name = excluded.set_name,
            collector_number = excluded.collector_number, rarity = excluded.rarity,
            lang = excluded.lang, finishes = excluded.finishes,
            released_at = excluded.released_at, image_uri = excluded.image_uri
        """,
        (
            card["id"], oracle_id, card.get("name"),
            (card.get("set") or "").upper(), card.get("set_name"),
            card.get("collector_number"), card.get("rarity"), card.get("lang", "en"),
            json.dumps(card.get("finishes") or []), card.get("released_at"), image,
        ),
    )
    return oracle_id


def pending_identifiers(conn) -> tuple[list[dict], list[dict]]:
    """What still needs fetching: printings without a card, and unresolved deck lines."""
    by_id = [
        {"id": row["scryfall_id"]}
        for row in conn.execute(
            "SELECT scryfall_id FROM printings WHERE oracle_id IS NULL"
        ).fetchall()
    ]

    by_set_number = []
    seen = set()
    for row in conn.execute(
        """
        SELECT DISTINCT lower(set_code) AS set_code, collector_number
          FROM deck_cards
         WHERE oracle_id IS NULL AND set_code IS NOT NULL AND collector_number IS NOT NULL
        """
    ).fetchall():
        key = (row["set_code"], row["collector_number"])
        if key not in seen:
            seen.add(key)
            by_set_number.append({"set": row["set_code"], "collector_number": row["collector_number"]})

    return by_id, by_set_number


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Fetch card data from the Scryfall API and populate the cards table.",
        epilog="Runs inside the container. Use `make enrich`.",
    )
    parser.add_argument("--db", type=Path, default=db.DB_PATH, help="database path")
    parser.add_argument("--force", action="store_true", help="ignore the cache and refetch")
    parser.add_argument("--offline", action="store_true", help="use only cached responses")
    parser.add_argument(
        "--names", nargs="+", metavar="NAME",
        help="also fetch these cards by exact name. Combo disablers are usually "
             "cards you do not own, but they still need a row to be recorded against.",
    )
    args = parser.parse_args(argv)

    conn = db.connect(args.db)
    db.apply_schema(conn)

    by_id, by_set_number = pending_identifiers(conn)
    aliases = scryfall.load_aliases()

    # Serve whatever the on-disk cache already answers, so re-runs only fetch
    # genuinely new cards.
    to_fetch: list[dict] = []
    from_cache = 0

    for identifier in by_id:
        cached = None if args.force else scryfall.cached_card(identifier["id"])
        if cached:
            upsert_card(conn, cached)
            from_cache += 1
        else:
            to_fetch.append(identifier)

    for identifier in by_set_number:
        key = scryfall.alias_key(identifier["set"], identifier["collector_number"])
        cached_id = None if args.force else aliases.get(key)
        cached = scryfall.cached_card(cached_id) if cached_id else None
        if cached:
            upsert_card(conn, cached)
            from_cache += 1
        else:
            to_fetch.append(identifier)

    conn.commit()
    print(f"cache: {from_cache} card(s) served from data/scryfall/")

    fetched = 0
    missing: list[dict] = []

    if to_fetch and args.offline:
        print(f"offline: skipping {len(to_fetch)} uncached identifier(s)")
    elif to_fetch:
        print(f"fetching {len(to_fetch)} card(s) from Scryfall "
              f"in {(len(to_fetch) - 1) // scryfall.MAX_IDENTIFIERS_PER_REQUEST + 1} batch(es)...")

        for batch in scryfall.chunked(to_fetch):
            found, not_found = scryfall.fetch_collection(batch)
            missing.extend(not_found)

            # Results come back in request order, but every miss shifts the
            # mapping - so match on the card's OWN id and set+number, never on
            # positional index.
            for card in found:
                scryfall.cache_card(card)
                aliases[scryfall.alias_key(card.get("set", ""), card.get("collector_number", ""))] = card["id"]
                upsert_card(conn, card)
                fetched += 1

            conn.commit()

        scryfall.save_aliases(aliases)

    print(f"fetched: {fetched} card(s) from the API")

    if missing:
        print(f"\n!! {len(missing)} identifier(s) not found on Scryfall:")
        for identifier in missing:
            print(f"   {identifier}")

    # Cards referenced by name rather than owned - combo disablers, mostly.
    for name in args.names or []:
        existing = conn.execute("SELECT 1 FROM cards WHERE name = ?", (name,)).fetchone()
        if existing and not args.force:
            continue

        # Serve from cache first, so a rebuild keeps working with no network.
        cached_id = aliases.get(scryfall.name_key(name))
        card = scryfall.cached_card(cached_id) if cached_id else None
        if card is None:
            if args.offline:
                print(f"  offline and uncached, skipping: {name}")
                continue
            card = scryfall.named(name)
            if card is None:
                print(f"  !! not found on Scryfall: {name}")
                continue
            scryfall.cache_card(card)
            aliases[scryfall.name_key(name)] = card["id"]
            scryfall.save_aliases(aliases)
        upsert_card(conn, card)
        print(f"  by name: {card['name']}")
    conn.commit()

    copies = db.materialize_copies(conn)
    resolved = db.resolve_deck_cards(conn)
    db.refresh_deck_metadata(conn)
    tagged = roles.tag_roles(conn)

    print(f"\ncopies:     {copies['copies']} materialised, {copies['conflicts']} conflict(s), "
          f"{copies['unenriched']} still unenriched")
    print(f"deck cards: {resolved['by_printing']} matched by printing, "
          f"{resolved['by_name']} by name, {resolved['unresolved']} unresolved")
    print(f"roles:      {tagged.pop('tagged')} automatic tag(s) — "
          + ", ".join(f"{k} {v}" for k, v in sorted(tagged.items())))

    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
