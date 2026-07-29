# magic-strategist

Massimiliano's Magic: The Gathering Commander (EDH) collection. Card data lives
in SQLite and is queried per session — never loaded wholesale into context.

## Everything runs in the container

**Never run `pip`, `python`, or `sqlite3` on the host.** The host has Docker and
git, and nothing else. Every command goes through `make` or
`docker compose run --rm app ...`. If a step seems to need a host install, stop
and say so instead of doing it.

```
make app              # web app on http://localhost:8000
make shell            # bash inside the container
make validate         # all deck and collection checks
make query ARGS='...' # query the collection
make import ARGS='...' make enrich   make sync-gc   make seed
make rebuild          # rebuild the database from committed files, offline
```

## Talk to him through the database, not through the chat

The web app (`app/`) reads and writes the same `data/collection.db`. When
proposing deck changes, **write them into `deck_proposals`** instead of only
describing them in prose — he reviews them visually in the app and accepts or
rejects there, and his answer comes back through the same table.

```sql
INSERT INTO deck_proposals (deck_id, oracle_id, action, source, rationale, pairs_with)
VALUES (:deck, :oracle, 'cut'|'add', 'claude', 'why, in one or two sentences', :paired_id);
```

- Always give a `rationale`. It is the only thing he sees next to the card.
- Pair every `add` with the `cut` that pays for it via `pairs_with` — the deck
  stays at 100 and the app shows the projected total.
- `source` is `claude` or `massimiliano`; never write his name on your own idea.
- Rows he created are his marks. Read them before proposing, and respond to
  them rather than duplicating them.
- Nothing touches `decklist.txt` until a proposal is applied deliberately.

## How to work with this repo

- **Query, don't read.** Use `scripts/query.py` for card and deck facts. Do not
  read `data/collection.db`, the decklists, or the Scryfall cache in bulk.
  - `query.py decks` · `query.py deck <slug> --roles` · `query.py card "<name>"`
  - `query.py combos --deck <slug>` · `query.py pool --color-identity BRG`
  - `query.py wishlist` · `query.py conflicts`
- **Run `make validate` after any deck change.** Non-zero exit means something
  is broken. Report the output; do not silently fix it.
- Deck slugs come from ManaBox binder names. ManaBox is the source of truth for
  where a card physically is.
- `data/seed.sql` holds what no import can derive — target brackets, an
  ambiguous commander, combos, wishlist detail. Edit it, then `make seed`.
- Scryfall responses are cached in `data/scryfall/` and committed, so
  `--offline` works for everything except fetching genuinely new cards.

## Session protocol

At the start of a session, ask **which deck we're focusing on** and **which
bracket he's building for today** — it changes, usually 3 or 4, occasionally 1
for fun. Skip the question if he already said.

## The collection's real constraint

He does **not** own exactly one copy of every card — each precon ships its own
Sol Ring, Arcane Signet and Command Tower, so several staples exist in
triplicate. What matters is **supply vs. demand**: if more *active* decks list a
card than there are physical copies, building one deck strips another.
`validate.py` checks this. When proposing a move, always say which deck loses
the card.

## Deck status

Every deck is `active`, `donor` or `retired` (`decks.status`, set in
`data/seed.sql`).

- **active** — kept assembled, held to exactly 100, competes for cards.
- **donor** — cannibalised for parts. Its cards are **available inventory**, its
  list is not held to 100, and it makes no claim on a card an active deck wants.
  `query.py pool` includes donor decks by default, tagged `(donor)`.
- **retired** — kept for the record only.

`dance-of-the-elements` is currently a **donor** deck: the bracket-4 Blight
Curse upgrade took five cards out of it, and rather than rebuy them it was kept
as a parts bin. Its `decklist.txt` still describes the original 100 and is
deliberately stale — treat `copies` as the truth for that deck.

**Freely recommend cards out of a donor deck.** That is what it is for, and no
active deck is weakened by the move.

## Brackets

| # | Name | Game Changers | Combos | Mass land destruction | Extra turns |
|---|------|---------------|--------|------------------------|-------------|
| 1 | Exhibition | 0 | none | no | no |
| 2 | Core | 0 | no early infinites | no | no chaining |
| 3 | Upgraded | max 3 | only ones that can't realistically go off by ~turn 6 | no | no chaining |
| 4 | Optimized | unlimited | unlimited | allowed | allowed |
| 5 | cEDH | unlimited | unlimited | allowed | allowed |

Game Changers determine bracket legality, so **always label them explicitly with
⚡**. The official list is `knowledge/game-changers.json`, refreshed by
`make sync-gc` from Scryfall's `is:game-changer` search. WotC revises it every
few months — never answer from memory.

## Recommendation format

Split every set of suggestions into two buckets:

**Bucket A — cards he already owns.** Name which deck or pool it is currently
in. **Always flag that moving it weakens the donor deck**, and say how.

**Bucket B — cards to buy.** Include a price tier. Respect the ~€10–15 per card
ceiling including worst-case shipping.

## Hard rules

- Stay inside the focus commander's colour identity. No exceptions.
- Never suggest a card already in the deck. Check first with `query.py deck`.
- **For every addition, propose a specific cut, with a reason.** Decks stay at
  exactly 100 including the commander.
- Singleton within a deck; basic lands excepted.
- English, non-foil printings. He rejects cheaper Japanese or other-language
  printings for consistency.

## Verify, don't guess

Two decks are built from **Lorwyn Eclipsed (ECL/ECC)** and **Secrets of
Strixhaven (SOS)**. If unsure whether a card exists or how it works, check the
database or Scryfall and say that you did. Never invent a card, a mana cost, or
an interaction.

## Combo disablers

`combo_disablers` records cards that **shut a combo off**. This is the detail
that keeps getting lost in his notes. When registering or discussing a combo,
always account for its disablers.

## Layout

```
app/                    FastAPI web app — main.py, queries.py, templates, static
data/collection.db      SQLite, the source of truth (committed)
data/collection.sql     text dump of the same, so git history is diffable
data/manabox/<date>/    raw ManaBox exports — committed, never edited
data/scryfall/          cached API responses (committed)
data/seed.sql           hand-maintained facts
decks/<slug>/           decklist.txt, strategy.md, upgrades.md
pool/                   notes on loose cards; the cards live in the database
knowledge/              brackets.md, game-changers.json
scripts/                import_manabox · enrich · sync_gamechangers · validate · query
```
