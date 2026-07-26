---
description: Start a deck-tuning session — pick the deck and bracket, load its state
---

Start a Commander deck-tuning session.

1. Run `make validate` and note anything already broken.
2. Ask which **deck** we are focusing on and which **bracket** he is building
   for today (usually 3 or 4, occasionally 1). Skip whichever he already said.
   List the decks with `make query ARGS='decks'` so he can pick.
3. Load only that deck: `make query ARGS='deck <slug> --roles'` and
   `make query ARGS='combos --deck <slug>'`.
4. Report the deck's current state in a few lines — size, colour identity,
   Game Changer count (⚡) against the chosen bracket's limit, and any
   validator failures that touch this deck.

Then work on whatever he asks, following the recommendation format and hard
rules in CLAUDE.md: Bucket A (owned, name the donor deck and what it loses) vs.
Bucket B (to buy, with a price tier), a specific cut for every addition, and
exactly 100 cards.

$ARGUMENTS
