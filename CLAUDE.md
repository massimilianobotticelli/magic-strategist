# magic-strategist

Massimiliano's Magic: The Gathering collection — Commander, Pauper Commander,
Modern and Pauper. Card data lives in SQLite and is queried per session, never
loaded wholesale into context.

## Everything runs in the container

**Never run `pip`, `python`, or `sqlite3` on the host.** The host has Docker and
git, and nothing else. Every command goes through `make` or
`docker compose run --rm app ...`. If a step seems to need a host install, stop
and say so instead of doing it.

```
make app              # web app on http://localhost:8000
make validate         # all deck and collection checks
make query ARGS='...' # query the collection
make shell   make import ARGS='...'   make enrich   make sync-gc   make seed
make rebuild          # rebuild the database from committed files, offline
```

## Talk to him through the database, not through the chat

The web app (`app/`) reads and writes the same `data/collection.db`. When
proposing deck changes, **write them into `deck_proposals`** instead of only
describing them in prose — he reviews them visually and accepts or rejects
there, and the answer comes back through the same table.

```sql
INSERT INTO deck_proposals (deck_id, oracle_id, action, source, rationale, pairs_with)
VALUES (:deck, :oracle, 'cut'|'add', 'claude', 'why, in one or two sentences', :paired_id);
```

- Always give a `rationale`. It is the only thing he sees next to the card.
- Pair every `add` with the `cut` that pays for it via `pairs_with`, so the deck
  keeps its size and the app can show the projected total.
- `source` is `claude` or `massimiliano`; never put his name on your own idea.
- Rows he created are his marks. Read them before proposing, and respond to
  them rather than duplicating them.
- Nothing touches `decklist.txt` until a proposal is applied deliberately.

## Building a new deck

Run the **`new-deck` skill**. The app's "New deck" button writes a row into
`deck_requests`; the skill reads anything still `pending`, builds from what he
owns, and writes the result back with `status='draft'`. It works straight from a
conversation too, with no request row.

```
make query ARGS='requests'                              # what was asked for
make query ARGS='available --format pdh --colors GU'    # what can be used
```

`available` lists owned cards legal in a format, filtered by colour, role and
type. Without `--borrow` it shows only what costs nothing — pools and donor
decks. With it, cards that would have to leave an assembled deck: never do that
without naming the deck that loses the card.

## Formats

`scripts/formats.py` is the authority — never recall these from memory.

| Format | Size | Copies | Commander | Rarity |
|---|---|---|---|---|
| `commander` | exactly 100 | 1 | yes | any |
| `pdh` | exactly 100 | 1 | uncommon creature | commons |
| `modern` | 60+ (+15 SB) | 4 | no | any |
| `pauper` | 60+ (+15 SB) | 4 | no | commons |

**Deck size is the format's, not always 100.** Colour identity, brackets and
Game Changers are Commander-side concepts; `validate.py` knows this, so don't
re-impose Commander rules on a Modern deck.

## How to work with this repo

- **Query, don't read.** Use `scripts/query.py`. Do not read
  `data/collection.db`, the decklists, or the Scryfall cache in bulk.
  - `decks` · `deck <slug> --roles` · `card "<name>"` · `combos --deck <slug>`
  - `pool --color-identity BRG` · `available --format <fmt>` · `requests`
  - `wishlist` · `conflicts`
- **Run `make validate` after any deck change.** Non-zero exit means something
  is broken. Report the output; do not silently fix it.
- Deck slugs come from ManaBox binder names. ManaBox is the source of truth for
  where a card physically is.
- `data/seed.sql` holds what no import can derive — brackets, deck status, an
  ambiguous commander, combos, wishlist detail. Edit it, then `make seed`.
- Scryfall responses are cached and committed, so `--offline` works for
  everything except genuinely new cards.

## Session protocol

Ask **which deck we're working on**, and for Commander also **which bracket he
is building for today** — it changes, usually 3 or 4, occasionally 1 for fun.
Skip whatever he has already said.

## What the collection can support

He does **not** own one copy of every card: each precon ships its own Sol Ring,
Arcane Signet and Command Tower, so a few staples exist in triplicate. What
matters is **supply vs. demand** — if more *active* decks list a card than there
are physical copies, building one deck strips another. `validate.py` checks it.

He also owns **no playsets and very few duplicates**. Commander and PDH are
singleton, so this costs nothing there. Modern and Pauper decks built from the
collection come out near-singleton: fine for the casual games he plays with
friends, but say which cards would want a second or third copy so they can reach
the wishlist.

## Deck status

`decks.status`, set in `data/seed.sql`:

- **active** — kept assembled, held to its format's size, competes for cards.
- **donor** — cannibalised for parts. Its cards are **available inventory**, its
  list is not held to size, and it makes no claim on a card an active deck
  wants. `query.py pool` includes donor decks by default, tagged `(donor)`.
- **retired** — kept for the record only. **draft** — generated, not yet accepted.

A donor deck's `decklist.txt` is usually stale on purpose; trust `copies`.

## Brackets

| # | Name | Game Changers | Combos | Mass land destruction | Extra turns |
|---|------|---------------|--------|------------------------|-------------|
| 1 | Exhibition | 0 | none | no | no |
| 2 | Core | 0 | no early infinites | no | no chaining |
| 3 | Upgraded | max 3 | only ones that can't realistically go off by ~turn 6 | no | no chaining |
| 4 | Optimized | unlimited | unlimited | allowed | allowed |
| 5 | cEDH | unlimited | unlimited | allowed | allowed |

Game Changers decide bracket legality, so **always label them with ⚡**. The
official list is `knowledge/game-changers.json`, refreshed by `make sync-gc`.
WotC revises it every few months — never answer from memory.

## Recommendation format

**Bucket A — cards he already owns.** Name where the card sits today. If it is
in an **active** deck, say what that deck loses by giving it up. If it is in a
pool or a **donor** deck, it costs nothing — recommend it freely.

**Bucket B — cards to buy.** Include a price tier. Respect the ~€10–15 per card
ceiling including worst-case shipping.

## Hard rules

- Stay inside the commander's colour identity (Commander and PDH). No exceptions.
- Never suggest a card already in the deck. Check first with `query.py deck`.
- **For every addition, propose a specific cut, with a reason.**
- English, non-foil printings. He rejects cheaper other-language printings for
  consistency, even when they are cheaper.

## Verify, don't guess

Two decks come from **Lorwyn Eclipsed (ECL/ECC)** and **Secrets of Strixhaven
(SOS)**. If unsure whether a card exists or how it works, check the database or
Scryfall and say that you did. Never invent a card, a mana cost, or an
interaction.

`combo_disablers` records the cards that **shut a combo off** — the detail his
notes kept losing. Always account for them when discussing a combo.

## Language

He writes in Italian, German or English — **reply in whichever he used**. The
web app and everything committed to the repo stay in English.
