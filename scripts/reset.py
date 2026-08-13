#!/usr/bin/env python3
"""Empty the repository of one collection so it can be refilled with another.

This is the first thing to run after forking: it removes the previous owner's
cards, decks and recorded decisions, and leaves the machinery — scripts, web
app, container, schema — in place.

Nothing is deleted without being listed first. The default is a dry run:

    make reset              # show exactly what would go
    make reset ARGS=--yes   # actually do it

What it removes:

  * the database and both of its text dumps
  * every ManaBox export under data/manabox/
  * every deck folder under decks/
  * data/seed.sql, replaced by the commented template in data/seed.example.sql

What it keeps, on purpose:

  * data/scryfall/ — a cache of Scryfall responses, not a claim of ownership.
    Keeping it means your first `make enrich` only fetches cards it does not
    already have, and `make rebuild --offline` keeps working for those.
    Pass --drop-cache if you would rather start from an empty cache.
  * knowledge/ — the bracket summary and the Game Changers list are the same
    for everybody. `make sync-gc` refreshes the latter.
  * pool/README.md, README.md, CLAUDE.md — prose about a specific collection.
    A script cannot rewrite these honestly, so it only reminds you to.

Git history is NOT touched. A fork still carries every previous commit; see
FORK.md for how to start from a single empty one instead.
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
DECKS = ROOT / "decks"

# Prose that describes one specific collection. The script cannot rewrite these
# truthfully, so it names them and leaves them alone.
REWRITE_BY_HAND = [
    "README.md",
    "CLAUDE.md",
    "pool/README.md",
    ".claude/rules/decks.md",
]


def targets(drop_cache: bool) -> list[Path]:
    """Everything to delete, in a stable order, skipping what is already gone."""
    found: list[Path] = []

    for name in ("collection.db", "collection.sql", "app-state.sql", "seed.sql"):
        path = DATA / name
        if path.exists():
            found.append(path)

    # A seed.sql that is already the untouched template is not this collection's
    # — leave it, so a second run reports nothing to do instead of churning it.
    template = DATA / "seed.example.sql"
    seed = DATA / "seed.sql"
    if seed in found and template.exists() and seed.read_bytes() == template.read_bytes():
        found.remove(seed)

    if (DATA / "manabox").is_dir():
        found.extend(sorted(p for p in (DATA / "manabox").iterdir() if not p.name.startswith(".")))

    if DECKS.is_dir():
        found.extend(sorted(p for p in DECKS.iterdir() if not p.name.startswith(".")))

    if drop_cache and (DATA / "scryfall").is_dir():
        found.append(DATA / "scryfall")

    return found


def size_of(path: Path) -> str:
    if path.is_file():
        return f"{path.stat().st_size / 1024:.0f} KB"
    files = [p for p in path.rglob("*") if p.is_file()]
    total = sum(p.stat().st_size for p in files)
    return f"{len(files)} file(s), {total / 1024 / 1024:.1f} MB"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Empty this repository of its collection, keeping the tooling.",
    )
    parser.add_argument("--yes", action="store_true",
                        help="actually delete. Without it this is a dry run.")
    parser.add_argument("--drop-cache", action="store_true",
                        help="also delete data/scryfall/, the cached Scryfall responses.")
    args = parser.parse_args(argv)

    template = DATA / "seed.example.sql"
    if not template.exists():
        print(f"error: {template.relative_to(ROOT)} is missing; "
              "the reset would leave no seed file behind.", file=sys.stderr)
        return 1

    doomed = targets(args.drop_cache)
    if not doomed:
        print("Nothing to remove — this repository already looks empty.")
        return 0

    removing, writing = ("Removing", "Writing") if args.yes else ("Would remove", "Would write")
    print(f"{removing} {len(doomed)} path(s):\n")
    for path in doomed:
        print(f"  {path.relative_to(ROOT)}    ({size_of(path)})")

    print(f"\n{writing} data/seed.sql from data/seed.example.sql")

    if not args.drop_cache:
        print("\nKeeping data/scryfall/ (cached Scryfall responses — pass --drop-cache to remove).")

    if not args.yes:
        print("\nDry run. Nothing was deleted. Re-run with --yes to go ahead:\n")
        print("    make reset ARGS=--yes")
        return 0

    for path in doomed:
        if path.is_dir():
            shutil.rmtree(path)
        else:
            path.unlink()

    # Git does not track empty directories, so a fresh clone of the fork would
    # arrive without the two folders everything else expects.
    for folder in (DATA / "manabox", DECKS):
        folder.mkdir(parents=True, exist_ok=True)
        (folder / ".gitkeep").touch()

    shutil.copyfile(template, DATA / "seed.sql")

    print("\nDone. This repository now holds no cards and no decks.\n")
    print("Next:")
    print("  1. Export your collection from ManaBox into data/manabox/<YYYY-MM-DD>/")
    print("  2. make build")
    print("  3. make import ARGS='data/manabox/<YYYY-MM-DD>/*.csv'")
    print("  4. make enrich          (needs a connection the first time)")
    print("  5. make sync-gc && make validate && make dump")
    print("\nBefore the first `make enrich`, identify yourself to Scryfall:")
    print("  cp .env.example .env     # then set SCRYFALL_USER_AGENT")
    print("\nThen rewrite the prose that still describes someone else's collection:")
    for name in REWRITE_BY_HAND:
        print(f"  - {name}")
    print("\nFORK.md has the long version.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
