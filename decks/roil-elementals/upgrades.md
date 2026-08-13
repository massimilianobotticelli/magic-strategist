# Roil Elementals — upgrades

Candidate changes, each with the cut it implies. Nothing here is applied.

## Why the deck looks like this

Built 2026-08-13 entirely from `free-cards`, with no borrowing. That constraint
decided most of the list: 44 cards are the Temur half of the dismantled
**Dance of the Elements** precon, and the rest is what the loose pool happened
to hold in green, blue and red.

Two colours were dropped on purpose. Ashling's five-colour build had white and
black bodies (Belonging, Lamentation, Shimmercreep, Vernal Sovereign), but the
free pool's fixing is 13 tapped duals and no untapped ones, so a fourth or
fifth colour would have been paid for entirely in tempo. Temur keeps the whole
landfall package — both Omnaths, Risen Reef, Tatyova, Avenger — and gives up
only removal that green and red already cover.

## The first cuts

These are the weakest cards in the deck and the right place to put anything
better. They are filler, not mistakes — the pool ran out of quality before it
ran out of slots.

| Cut | Why |
|---|---|
| Visionary's Dance | {5}{U}{R} for two 3/3 fliers is a bad rate; it survives only because the tokens are Elementals and it can be discarded to filter. |
| Wild Hypothesis | The Fractal it makes is **not** an Elemental, so it triggers neither Risen Reef nor anything else. Pure filler. |
| Fractal Mascot | Six mana to tap one creature and stun it. Same problem: the body is a Fractal Elk, not an Elemental. |
| Uncharted Voyage | Tempo only, and the deck is not a tempo deck. |

## What to buy — none of it is required to play

The deck is complete at 100 without spending anything. These are quality gaps,
not supply gaps, and they are listed in the order they would actually change
games. **Nothing has been written to `wishlist` yet** and no prices have been
checked.

1. **Redundancy for Risen Reef.** One copy carries both engines. Cheap
   Elementals that replace themselves would also raise the Elemental count,
   which is the number the whole deck runs on. Verify any candidate against
   Scryfall before adding it — do not take a name from memory.
2. **A sweeper that is not symmetric.** Chain Reaction kills this side hardest;
   see weakness 1 in `strategy.md`. Green and red have real answers here that
   the free pool simply did not contain.
3. **Protection for the commander and for Risen Reef.** One card in the whole
   deck does this.
4. **Untapped fixing.** 13 of 16 nonbasics enter tapped, which is what makes
   turn-4 Omnath a coin flip at 46.2%. Note the lesson already recorded in
   `CLAUDE.md`: duals fix colour **balance**, not colour **density** — buying
   one does not repair a `{G}{G}{G}` cost. Cavalier of Thorns and Titan of
   Industry are the cards paying that tax, and cutting them is the cheaper fix.

## Deliberately not done

- **No Sneak discount was recorded in `effective_costs`.** New Generation's
  Technique has Sneak {2}{G}, and it is *not* in that table, for the same
  reason the Foot Clan Sneak deck failed: Sneak needs an unblocked attacker,
  and the deck that is beating you never gives you one. Recording it would
  re-import a mistake this repo already paid for.
- **Chain Reaction was kept anyway.** It is the only sweeper the colours had,
  and a deck with zero answers to a wide board is worse than one with a bad
  answer. It is flagged in `strategy.md` rather than pretended away.
- **No fourth colour.** See above — the tempo cost is not payable with this
  land pool.
