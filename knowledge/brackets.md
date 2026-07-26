# Commander Brackets

WotC's bracket system describes what a deck is *trying* to be, so that players
can match expectations before shuffling up. A deck declares a target bracket;
the contents should match it.

## 1 — Exhibition

Ultra-casual. Built around a theme or a joke rather than winning.

- Game Changers: **0**
- Infinite combos: **none**
- Mass land destruction: no
- Extra turns: no
- Tutors: sparse; the deck is meant to play out differently every game.

## 2 — Core

The power level of a modern preconstructed deck, straight out of the box.

- Game Changers: **0**
- Infinite combos: none that assemble early
- Mass land destruction: no
- Extra turns: no chaining
- Games are expected to run past turn nine or so.

## 3 — Upgraded

A precon that has been deliberately improved, or a deck built to that level.
This is the most common competitive-but-friendly target.

- Game Changers: **maximum 3**
- Infinite combos: only ones that cannot realistically go off by around turn six
- Mass land destruction: no
- Extra turns: no chaining
- Tutors and fast mana are fine in moderation.

## 4 — Optimized

The strongest version of a chosen strategy, without the cEDH metagame.

- Game Changers: **unlimited**
- Infinite combos: unlimited
- Mass land destruction: allowed
- Extra turns: allowed

## 5 — cEDH

Competitive EDH. Winning is the only goal; the metagame drives every choice.

- Everything is permitted. Decks are built to beat other cEDH decks.

## Game Changers

A curated list of cards strong enough to distort a game — fast mana, powerful
tutors, and effects that end games on their own. WotC maintains it and revises
it every few months.

The current list lives in `knowledge/game-changers.json`, refreshed by:

```bash
make sync-gc
```

which reads Scryfall's `is:game-changer` search. Never answer from memory —
the list changes.
