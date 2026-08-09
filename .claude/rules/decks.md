---
description: Deck-specific working rules
globs: ["decks/**"]
---

# Working inside a deck folder

Each `decks/<slug>/` holds:

- `decklist.txt` — the authoritative list, format `1 Card Name (SET) 123`, with
  an optional trailing `*F*` for foils and `// COMMANDER` / `// SIDEBOARD`
  markers. A blank line closes a `//` section.
- `strategy.md` — how the deck wins and what it is trying to do.
- `upgrades.md` — candidate changes, with the cut each one implies.

**Only `decklist.txt` is imported.** Any other `decklist-*.txt` in the folder is
kept for the record and ignored, which is how a superseded or dismantled list
stays readable without becoming a phantom deck. Use that rather than deleting
history.

Write the list from the physical copies he owns, not from card names alone: put
a card whose copies have different printings or finishes on separate lines, so
the file stays true to what is in the box.

## After editing a decklist

```bash
make import ARGS='decks/<slug>/decklist.txt'
make validate
make dump
```

`import` re-reads the file and replaces that deck's rows. `validate` is
format-aware: it catches a list that has drifted off its own size, out of colour
identity, or past its bracket's Game Changer limit. `dump` writes the change
back to the committed files, including the app's own tables.

## Before proposing a change

1. `make query ARGS='deck <slug> --roles'` — see what is actually in there.
2. Check the card is not already present.
3. For Commander and PDH, check colour identity. For the 60-card formats check
   *castability* instead — a hybrid card may be perfectly playable.
4. Name the specific cut. The deck stays at **its format's size**, not always 100.
5. If the addition comes from another deck, say which deck loses it and what
   that costs — `make query ARGS='card "<name>"'` shows where the copy lives.

## Promoting a draft into a real deck

A deck the `new-deck` skill produced lives only in the database until it is
promoted. Doing it properly means all of:

1. `decks/<slug>/decklist.txt`, generated from his physical copies.
2. `strategy.md` and `upgrades.md`.
3. A block in `data/seed.sql` setting **name, format and status** — an import
   derives none of these, and the format silently defaults to Commander, which
   is how a 40-card deck first appears as "0 cards, needs exactly 100".
4. `make rebuild && make validate` to prove the committed files reproduce it.

Step 4 is not optional. It is the only thing that proves the deck survives a
rebuild rather than living on in a database nobody can regenerate.

## Retiring a deck for good

Deleting a deck is **two** changes, and doing only one leaves the repo lying:

1. **Rename its `decklist.txt`** to `decklist-<why>-<date>.txt`. The importer
   only reads `decklist.txt`, so the list stays readable without building a
   phantom deck. Keep `strategy.md` and `upgrades.md` — they are the record of
   why it existed.
2. **If it was a ManaBox binder typed `deck`, an import will recreate it every
   time**, and no committed file can stop that — only a fresh export can. Until
   he retypes the binder to `binder` and re-exports, `data/seed.sql` has to
   delete the deck row and flip `locations.type` to `'pool'`. That block runs
   after the import, so it wins; once the export agrees it becomes a no-op.

**Never rename the binder to "fix" it.** The binder name *is* the slug, so
renaming creates a second location and orphans the first, taking the copies
with it. Change the type, keep the name.

`make seed` pipes into `sqlite3`, which leaves foreign keys **off**, so
`ON DELETE CASCADE` does not fire. Delete `deck_cards` and `deck_proposals`
yourself before deleting the deck, and null out `wishlist.deck_id` and
`deck_requests.deck_id`.

Deleting a deck **destroys its proposals**, which is the app's record of what
was decided and why. Carry anything worth keeping into the successor's
`upgrades.md` first, and say plainly that the rows are gone.

Examples of the kept-for-reference convention:
`decks/blight-curse-b4-final/decklist-pre-upgrade.txt` and
`decks/foot-clan-sneak/decklist-dismantled-2026-08-09.txt`.

## Sideboards

Only the 60-card formats have one. The app shows it in its own tab, read-only:
proposals track maindeck size, so a sideboard card is not markable. Moving a
card between main and sideboard is a decklist edit, not a proposal.

## Keeping strategy.md honest

`strategy.md` is what he reads before a game, so a stale claim there is worse
than no claim. After any swap, re-check the parts that quote numbers — land
counts, colour sources, how many cheap creatures — and the "known weaknesses"
section, which is exactly where an out-of-date sentence hides longest.

Record the *why* of a forced swap in `upgrades.md`, not just the what. A card
leaving because it belongs to another deck is a different fact from a card
leaving because something better arrived, and only the first one will repeat.

## Blight Curse

`decks/blight-curse-b4-final/decklist-pre-upgrade.txt` is the pre-upgrade list,
kept for reference and not imported. The cards that came out during the upgrade
are in the `moved-blight-curse` pool.
