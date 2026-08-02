# magic-strategist

Massimiliano's Magic: The Gathering collection — Commander, Pauper Commander,
Modern, Pauper and Limited. Card data lives in SQLite and is queried per
session, never loaded wholesale into context.

**This file describes how we work together. It is not a card reference — the
database is.** Do not add card lists, deck contents or set trivia here.

## Everything runs in the container

**Never run `pip`, `python`, or `sqlite3` on the host.** The host has Docker and
git, and nothing else. Every command goes through `make` or
`docker compose run --rm app ...`. If a step seems to need a host install, stop
and say so instead of doing it.

```
make app              # web app on http://localhost:8000
make validate         # all deck and collection checks
make query ARGS='...' # query the collection
make dump             # collection.sql + app-state.sql — run after any change
make rebuild          # rebuild the database from committed files, offline
make shell   make import ARGS='...'   make enrich   make sync-gc   make seed
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

When he says "go ahead, you choose", still write the proposals — then apply
them. The record of *why* is worth as much as the change.

## Keeping ManaBox in sync

ManaBox on his phone is the source of truth for **where a card physically is**.
The repo learns about it only through committed exports in `data/manabox/`.

- **Every export is a full snapshot, not a delta.** `make rebuild` imports only
  the newest dated directory. Older ones stay committed as history — never feed
  two snapshots to the importer.
- **ManaBox import ADDS, it does not move.** Handing him a CSV of a deck he has
  already sleeved will double-count every card. Moving cards between binders is
  done in the ManaBox app; a CSV is only for cards that are not in it yet.
- Binder types map straight through: **`deck`** becomes a deck, **`binder`**
  becomes a pool, **`list`** becomes the wishlist. Binder names become slugs, so
  renaming a binder in ManaBox renames the location here — and dismantling a
  deck into a binder turns it into a pool.
- **A deck's card list comes from its `decklist.txt`, never from the binder.**
  The binder supplies the physical copies. `validate` checks the two agree.
- **Everything he keeps assembled must exist as a binder**, or its cards sit in
  a pool and read as available inventory. When a deck turns out to be missing,
  registering it in ManaBox and re-exporting fixes the whole class of problem at
  once — do that instead of patching one card at a time.

After he changes anything physically: he re-exports, drops it in
`data/manabox/<date>/`, then `make rebuild && make validate`. Read the output
before saying it worked.

## Building a deck from what he owns

Run the **`new-deck` skill**. The app's "New deck" button writes a row into
`deck_requests`; the skill reads anything still `pending` and writes the result
back. It works straight from a conversation too, with no request row.

```
make query ARGS='requests'
make query ARGS='available --format modern'
```

`available` lists owned cards legal in a format. Without `--borrow` it shows
only what costs nothing; with it, cards sitting in assembled decks — never take
one without naming the deck that loses it.

**Two blind spots in `available` that will cost you a whole rebuild of the deck
if you trust it alone:**

1. **`--colors` filters on colour identity, which is a Commander concept.** In
   Modern and Pauper only *castability* matters, so a hybrid card is excluded
   even when your lands can pay for it. For a non-Commander deck, check the mana
   cost yourself instead of filtering by colour.
2. **A card listed in an active deck is hidden even when a spare copy sits free
   in a pool.** He owns a few duplicates. Query `copies` directly when a card
   seems missing.

**The set code is not the test for whether a card is available.** One deck mixes
printings from many sets, so "it is from set X" tells you nothing. What matters
is the pool it sits in and whether an assembled deck already claims it.

**A card in a free pool is free — trust that.** The pools are accurate as long
as ManaBox is complete, and treating them as suspect just adds friction. The one
failure mode is a deck that exists on the table but was never registered as a
binder: its cards then read as free because nothing says otherwise. If he says a
card is not available when the database says it is, that is the cause, and the
fix is to register the missing deck in ManaBox — not to start doubting pools.

## Formats

`scripts/formats.py` is the authority — never recall these from memory.

| Format | Size | Copies | Commander | Rarity |
|---|---|---|---|---|
| `commander` | exactly 100 | 1 | yes | any |
| `pdh` | exactly 100 | 1 | uncommon creature | commons |
| `modern` | 60+ (+15 SB) | 4 | no | any |
| `pauper` | 60+ (+15 SB) | 4 | no | commons |
| `limited` | 40+ | unlimited | no | any |

**Deck size is the format's, not always 100.** Colour identity, brackets and
Game Changers are Commander-side concepts; `validate.py` knows this, so don't
re-impose Commander rules on a 60-card deck. `limited` has an empty
`legality_key` on purpose: if he opened it, he may play it.

## Building for Modern and the other 60-card formats

Steffen — the friend he plays with, and the more experienced player — gave him
three rules. Treat them as the target, and say plainly when the collection
cannot reach them:

1. **Two colours.** Splashing a third is not worth it at this level.
2. **No lands that enter tapped**, unless there is a real strategic reason. A
   tapped land is a lost turn in a format that punishes slow starts.
3. **Keep the curve at 3 or below.** Count effective cost, not printed cost: a
   cost reduction or an alternative cost that the deck reliably turns on makes a
   card cheaper than its mana value suggests. Say which ones do.

His collection often cannot satisfy 2 and 3 at once — the fixing he owns enters
tapped, and the cheap interaction runs out fast. **Report the gap honestly with
numbers rather than pretending the deck meets the target**, and turn it into a
wishlist entry (below) instead of a compromise nobody wrote down.

## How to work with this repo

- **Query, don't read.** Use `scripts/query.py`. Do not read
  `data/collection.db`, the decklists, or the Scryfall cache in bulk.
  - `decks` · `deck <slug> --roles` · `card "<name>"` · `combos --deck <slug>`
  - `pool` · `available --format <fmt>` · `requests` · `wishlist` · `conflicts`
- **Run `make validate` after any deck change.** Non-zero exit means something
  is broken. Report the output; do not silently fix it.
- **`validate` exempts basic lands** from the copy and supply checks, so it will
  *not* catch a deck asking for more basics than he owns. Check that yourself.
- `data/seed.sql` holds what no import can derive — brackets, deck status and
  format, an ambiguous commander, combos, wishlist detail. Edit it, then
  `make seed`. **It must stay idempotent**: guard anything that appends, or a
  second run corrupts the text it wrote the first time.
- `data/app-state.sql` carries the app's own tables (proposals, requests). It is
  regenerated by `make dump` and replayed by `make rebuild`. Without it a
  rebuild silently discards every decision recorded in the app.
- Scryfall responses are cached and committed, so `--offline` works for
  everything except genuinely new cards.
- **When a deck changes, re-check its combo notes.** They quote card names and
  counts, and those go stale silently — that is exactly what the table exists to
  prevent.

## Session protocol

Ask **which deck we're working on**, and for Commander also **which bracket he
is building for today** — it changes, usually 3 or 4, occasionally 1 for fun.
Skip whatever he has already said.

## What the collection can support

He does **not** own one copy of every card: each precon ships its own staples,
so a few exist in triplicate. What matters is **supply vs. demand** — if more
*active* decks list a card than there are physical copies, building one deck
strips another. `validate.py` checks it.

He owns **no playsets and very few duplicates**. Commander and PDH are
singleton, so this costs nothing there. Modern and Pauper decks built from the
collection come out near-singleton: fine for the casual games he plays with
friends, but say which cards would want a second or third copy.

Basic lands are the quiet exception — he can run out of them like anything else,
and nothing checks it for you.

## Deck status

`decks.status`, set in `data/seed.sql`:

- **active** — kept assembled, held to its format's size, competes for cards.
- **donor** — cannibalised for parts. Its cards are **available inventory**, its
  list is not held to size, and it makes no claim on a card an active deck
  wants. A donor deck's `decklist.txt` is usually stale on purpose; trust
  `copies`.
- **retired** — kept for the record only. **draft** — generated, not yet accepted.

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
in an **active** deck, say what that deck loses by giving it up. If it costs
nothing, recommend it freely.

**Bucket B — cards to buy.** Do not shop, and do not quote prices you have not
checked. **Write the card into `wishlist` with the deck it is for and why**, at
the ~€10–15 per card ceiling including worst-case shipping. A skill that looks
cards up online may be added later; the wishlist is the handover point, so a row
with a clear `notes` is worth more than a paragraph in chat.

Never add a wishlist row against an explicit "no buying" — say what is missing
and offer.

## Hard rules

- Stay inside the commander's colour identity (Commander and PDH). No exceptions.
- Never suggest a card already in the deck. Check first with `query.py deck`.
- **For every addition, propose a specific cut, with a reason.**
- English, non-foil printings. He rejects cheaper other-language printings for
  consistency, even when they are cheaper.

## Verify, don't guess

The collection includes sets released after your training cutoff. If unsure
whether a card exists or how it works, check the database or Scryfall and say
that you did. Never invent a card, a mana cost, or an interaction.

`combo_disablers` records the cards that **shut a combo off** — the detail his
notes kept losing. Always account for them when discussing a combo.

Combos here are not only infinite loops: **any pair of cards that reliably wins
or gains an advantage counts**, and `combos.kind` has a `value` slot for them.
He wants to recognise patterns at the table instead of re-reading cards, so the
sequencing traps in `notes` are the point — which card must be played after
combat, which trigger checks its condition too early to help.

## Language

He writes in Italian, German or English — **reply in whichever he used**. The
web app and everything committed to the repo stay in English.
