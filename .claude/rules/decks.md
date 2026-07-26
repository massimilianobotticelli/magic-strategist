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

## After editing a decklist

```bash
make import ARGS='decks/<slug>/decklist.txt'
make validate
```

`import` re-reads the file and replaces that deck's rows; `validate` catches a
list that has drifted off 100 cards, out of colour identity, or past its
bracket's Game Changer limit.

## Before proposing a change

1. `make query ARGS='deck <slug> --roles'` — see what is actually in there.
2. Check the card is not already present.
3. Check colour identity against the commander.
4. Name the specific cut. The deck stays at exactly 100.
5. If the addition comes from another deck, say which deck loses it and what
   that costs — `make query ARGS='card "<name>"'` shows where the copy lives.

## Blight Curse

`decks/blight-curse-b4-final/decklist-pre-upgrade.txt` is the pre-upgrade list,
kept for reference. It is **not** imported and is not the live deck. The 16
cards that came out during the upgrade are in the `moved-blight-curse` pool.
