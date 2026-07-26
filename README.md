# magic-strategist

My Magic: The Gathering Commander (EDH) collection, as a queryable repository.

Card data lives in a SQLite database on disk. A Claude session queries what it
needs for the deck at hand instead of loading the whole collection into context.

**Everything runs in a container.** The only things installed on the host are
Docker and git — no Python packages, no virtualenvs, no `sqlite3`.

## Getting running from a clean machine

You need Docker (with the daemon running) and git. Nothing else.

```bash
git clone https://github.com/massimilianobotticelli/magic-strategist.git
cd magic-strategist
make build
make validate
```

`make validate` works immediately on a fresh clone: the database and the cached
Scryfall responses are committed, so the repo is functional offline.

`make help` lists every command.

## What each script does

| Script | What it does |
|---|---|
| `import_manabox.py` | Reads a ManaBox CSV export, keyed on its `Scryfall ID` column — an exact printing key, so reprints and double-faced cards are unambiguous. Also parses plain decklists (`1 Card Name (SET) 123`, optional `*F*`, `// COMMANDER` markers). |
| `enrich.py` | Fetches real card data from the Scryfall API and fills the `cards` table. Batches of ≤75 identifiers, throttled under 10 req/s, every response cached to `data/scryfall/`. |
| `sync_gamechangers.py` | Refreshes the official Commander Game Changers list from Scryfall's `is:game-changer` search into `knowledge/game-changers.json`. |
| `validate.py` | Every deck and collection check. Exits non-zero on failure. |
| `query.py` | Focused questions about decks, cards, combos, the loose pools and the wishlist. |

All of them take `--help`.

## Weekly workflow

**1. Export from ManaBox** and drop the CSV into a dated folder:

```bash
mkdir -p data/manabox/$(date +%F)
```

**2. Import it, fetch any new cards, refresh the Game Changers list:**

```bash
make import ARGS='data/manabox/2026-07-26/ManaBox_Collection.csv'
make enrich
make sync-gc
```

**3. After changing a decklist**, re-import that deck and validate:

```bash
make import ARGS='decks/blight-curse-b4-final/decklist.txt'
make validate
```

**4. Ask the collection things:**

```bash
make query ARGS='decks'
make query ARGS='deck blight-curse-b4-final --roles'
make query ARGS='card "Obelisk Spider"'
make query ARGS='combos --deck blight-curse-b4-final'
make query ARGS='pool --color-identity BRG --type creature'
make query ARGS='wishlist'
```

**5. Commit**, refreshing the text dump so the history is diffable:

```bash
make dump
git add -A && git commit -m "collection: <what changed>"
```

## Rebuilding from scratch

The database is derived from the committed raw exports, decklists and Scryfall
cache, so it can always be rebuilt without network access:

```bash
make rebuild
```

## Layout

```
.devcontainer/       Dockerfile + devcontainer.json (Python 3.12, non-root)
compose.yaml         same image, editor-independent
Makefile             every command, containerised
data/
  collection.db      SQLite — the source of truth (committed)
  collection.sql     text dump of the same, so git diffs are readable
  seed.sql           facts no import can derive: brackets, combos, commanders
  manabox/<date>/    raw ManaBox exports — committed, never edited
  scryfall/          cached API responses (committed)
decks/<slug>/        decklist.txt, strategy.md, upgrades.md
pool/                notes on the loose card pools
knowledge/           brackets.md, game-changers.json
scripts/             the five scripts above, plus db.py and scryfall.py
```

## Design notes

**Cards, printings and copies are three different things.** `cards` is the
abstract card keyed by Scryfall `oracle_id`; `printings` is a specific physical
printing keyed by Scryfall `id`; `copies` is one physical card I own, in exactly
one location. Deck *lists* live separately again in `deck_cards`, because what a
deck is supposed to contain and what is physically sleeved in it are different
claims that can disagree — and when they disagree, that is exactly what I want
to be told.

**On owning one copy of everything.** I thought I owned exactly one physical
copy of every card. I don't: every Commander precon ships its own Sol Ring,
Arcane Signet and Command Tower, so several staples exist in triplicate. The
rule that actually matters is **supply vs. demand** — if more decks list a card
than there are physical copies, building one deck strips another. `validate.py`
checks that, and a copy having exactly one location makes "in two decks at once"
structurally impossible.

**Why the database is committed.** I want the full history of how the collection
changed over time, and I want the repo to work offline. `data/collection.sql` is
a text dump of the same data so `git log -p` shows something readable.
