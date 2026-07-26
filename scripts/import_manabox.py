#!/usr/bin/env python3
"""Import ManaBox CSV exports and plain decklists into the collection database.

ManaBox exports carry a `Scryfall ID` column, which is an exact *printing* key,
so there is no name-matching ambiguity with reprints or double-faced cards.
They do not carry an oracle_id, so the abstract card behind each row is only
known after enrich.py runs; rows are staged first and turned into `copies` by
the materialisation step.

Runs inside the container:
    make import ARGS='inbox/ManaBox_Collection.csv inbox/*.txt'
    docker compose run --rm app python scripts/import_manabox.py --help
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import db  # noqa: E402

# `1 Auntie Ool, Cursewretch (ECC) 2 *F*`
DECK_LINE_RE = re.compile(
    r"^(?P<qty>\d+)\s+(?P<name>.+?)\s+\((?P<set>[A-Za-z0-9]{2,6})\)\s+(?P<cn>[^\s*]+)"
    r"(?:\s+\*(?P<finish>[A-Za-z])\*)?\s*$"
)
# `1 Sol Ring` - no printing given
BARE_LINE_RE = re.compile(r"^(?P<qty>\d+)\s+(?P<name>.+?)\s*$")

SECTION_ALIASES = {
    "COMMANDER": "commander",
    "COMMANDERS": "commander",
    "SIDEBOARD": "sideboard",
    "MAINDECK": "main",
    "MAIN": "main",
    "DECK": "main",
}


def _float_or_none(value: str | None) -> float | None:
    try:
        return float(value) if value not in (None, "") else None
    except ValueError:
        return None


def import_csv(conn, path: Path) -> dict[str, int]:
    """Stage every row of a ManaBox export, and register its binders."""
    stats = {"rows": 0, "printings": 0, "wishlist": 0, "locations": 0}
    seen_binders: set[str] = set()

    with path.open(newline="", encoding="utf-8-sig") as handle:
        for index, row in enumerate(csv.DictReader(handle), start=2):
            binder_name = (row.get("Binder Name") or "Unsorted").strip()
            binder_type = (row.get("Binder Type") or "binder").strip().lower()
            scryfall_id = (row.get("Scryfall ID") or "").strip()
            quantity = int(row.get("Quantity") or 1)

            conn.execute(
                """
                INSERT INTO manabox_rows (source_file, row_number, binder_name, binder_type,
                                          name, set_code, collector_number, scryfall_id, foil,
                                          rarity, quantity, condition, language, purchase_price,
                                          purchase_currency, added_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(source_file, row_number) DO NOTHING
                """,
                (
                    path.name, index, binder_name, binder_type,
                    row.get("Name"), row.get("Set code"), row.get("Collector number"),
                    scryfall_id, row.get("Foil"), row.get("Rarity"), quantity,
                    row.get("Condition"), row.get("Language"),
                    _float_or_none(row.get("Purchase price")),
                    row.get("Purchase price currency"), row.get("Added"),
                ),
            )
            stats["rows"] += 1

            # A printing stub. oracle_id stays NULL until enrich.py fills it.
            if scryfall_id:
                cur = conn.execute(
                    """
                    INSERT INTO printings (scryfall_id, name, set_code, set_name,
                                           collector_number, rarity, lang)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(scryfall_id) DO NOTHING
                    """,
                    (
                        scryfall_id, row.get("Name"), (row.get("Set code") or "").upper(),
                        row.get("Set name"), row.get("Collector number"),
                        row.get("Rarity"), (row.get("Language") or "en"),
                    ),
                )
                stats["printings"] += cur.rowcount

            if binder_name not in seen_binders:
                seen_binders.add(binder_name)
                if binder_type == "deck":
                    db.ensure_deck(conn, binder_name)
                    stats["locations"] += 1
                elif binder_type == "binder":
                    db.ensure_location(conn, binder_name, "pool")
                    stats["locations"] += 1

            # ManaBox binders of type `list` are want-lists, not owned cards.
            if binder_type == "list":
                conn.execute(
                    """
                    INSERT INTO wishlist (card_name, notes) VALUES (?, ?)
                    ON CONFLICT(card_name, deck_id) DO NOTHING
                    """,
                    (row.get("Name"), f"from ManaBox list '{binder_name}'"),
                )
                stats["wishlist"] += 1

    conn.commit()
    return stats


def parse_decklist(text: str) -> tuple[list[dict], list[str]]:
    """Parse `1 Card Name (SET) 123 *F*` lines with // SECTION markers."""
    entries: list[dict] = []
    problems: list[str] = []
    section = "main"
    section_entries = 0

    for lineno, raw in enumerate(text.splitlines(), start=1):
        line = raw.strip()
        if not line:
            # These exports mark a block with `// COMMANDER` and close it with a
            # blank line rather than opening a `// DECK` block, so a blank line
            # after at least one entry returns to the main deck.
            if section != "main" and section_entries:
                section, section_entries = "main", 0
            continue
        if line.startswith("//"):
            marker = line.lstrip("/").strip().upper()
            section = SECTION_ALIASES.get(marker, "main")
            section_entries = 0
            continue

        match = DECK_LINE_RE.match(line)
        if match:
            entries.append(
                {
                    "quantity": int(match.group("qty")),
                    "name": match.group("name").strip(),
                    "set_code": match.group("set").upper(),
                    "collector_number": match.group("cn"),
                    "is_foil": 1 if (match.group("finish") or "").upper() == "F" else 0,
                    "section": section,
                }
            )
            section_entries += 1
            continue

        match = BARE_LINE_RE.match(line)
        if match:
            entries.append(
                {
                    "quantity": int(match.group("qty")),
                    "name": match.group("name").strip(),
                    "set_code": None,
                    "collector_number": None,
                    "is_foil": 0,
                    "section": section,
                }
            )
            section_entries += 1
            continue

        problems.append(f"line {lineno}: could not parse {line!r}")

    return entries, problems


def deck_name_for(path: Path) -> str:
    """`decks/turtle-power/decklist.txt` names the deck by its folder, not the file."""
    if path.stem.startswith("decklist") and path.parent.name not in ("", ".", "inbox"):
        return path.parent.name
    return path.stem


def import_decklist(conn, path: Path, slug: str | None = None) -> dict:
    """Load a decklist file into deck_cards for its deck."""
    deck_name = deck_name_for(path)
    deck_id = db.ensure_deck(conn, deck_name, slug)
    entries, problems = parse_decklist(path.read_text(encoding="utf-8"))

    conn.execute("DELETE FROM deck_cards WHERE deck_id = ?", (deck_id,))
    for entry in entries:
        conn.execute(
            """
            INSERT INTO deck_cards (deck_id, card_name, set_code, collector_number,
                                    quantity, section, is_foil)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(deck_id, card_name, section) DO UPDATE SET
                quantity = deck_cards.quantity + excluded.quantity
            """,
            (
                deck_id, entry["name"], entry["set_code"], entry["collector_number"],
                entry["quantity"], entry["section"], entry["is_foil"],
            ),
        )

    conn.commit()
    return {
        "deck": deck_name,
        "slug": db.slugify(slug or deck_name),
        "entries": len(entries),
        "cards": sum(e["quantity"] for e in entries),
        "problems": problems,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Import ManaBox CSV exports and decklists into the collection database.",
        epilog="Runs inside the container. Use `make import ARGS='...'`.",
    )
    parser.add_argument("files", nargs="+", type=Path, help=".csv exports and/or .txt decklists")
    parser.add_argument("--db", type=Path, default=db.DB_PATH, help="database path")
    parser.add_argument("--slug", help="force a deck slug (single decklist only)")
    parser.add_argument(
        "--no-materialize", action="store_true",
        help="stage rows only; skip rebuilding copies (useful before enrich.py)",
    )
    args = parser.parse_args(argv)

    conn = db.connect(args.db)
    db.apply_schema(conn)

    for path in args.files:
        if not path.exists():
            print(f"!! missing file: {path}")
            continue
        if path.suffix.lower() == ".csv":
            stats = import_csv(conn, path)
            print(f"CSV  {path.name}: {stats['rows']} rows staged, "
                  f"{stats['printings']} new printings, {stats['locations']} locations, "
                  f"{stats['wishlist']} wishlist entries")
        elif path.suffix.lower() == ".txt":
            result = import_decklist(conn, path, args.slug if len(args.files) == 1 else None)
            print(f"DECK {path.name}: {result['cards']} cards "
                  f"({result['entries']} entries) -> {result['slug']}")
            for problem in result["problems"]:
                print(f"     !! {problem}")
        else:
            print(f"?? skipping unrecognised file type: {path}")

    if not args.no_materialize:
        copies = db.materialize_copies(conn)
        resolved = db.resolve_deck_cards(conn)
        db.refresh_deck_metadata(conn)
        print(
            f"\nmaterialise: {copies['copies']} copies, {copies['conflicts']} conflicts, "
            f"{copies['unenriched']} rows awaiting enrichment"
        )
        print(
            f"deck cards:  {resolved['by_printing']} matched by printing, "
            f"{resolved['by_name']} by name, {resolved['unresolved']} unresolved"
        )
        if copies["unenriched"] or resolved["unresolved"]:
            print("\nNext: run `make enrich` to fetch card data from Scryfall.")

    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
