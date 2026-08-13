# Roil Elementals — strategy

> **Draft.** Written from the list and from simulation, not from play
> experience. Nothing here has been tested at the table yet.

**Commander:** Omnath, Locus of the Roil — {1}{G}{U}{R}, Temur (GRU)
**Format:** Commander · **Target bracket:** 4 (Optimized) · **Game Changers: 0**

> When Omnath enters, it deals damage to any target equal to the number of
> Elementals you control.
> Landfall — Whenever a land you control enters, put a +1/+1 counter on target
> Elemental you control. If you control eight or more lands, draw a card.

## What the deck does

Every land that enters is a trigger. Omnath grows an Elemental on each one and,
past **eight lands**, draws a card. Risen Reef runs the loop the other way:
every Elemental that enters looks at the top card and may put a land straight
onto the battlefield — which is another landfall.

The deck therefore does not need to draw well to keep going. It needs to keep
**Elementals entering**, and it has **21 Elemental cards in the 99** (20 by type
line, plus Realmwalker, which is a changeling and so is every creature type),
plus the commander. Springleaf Parade's tokens are changelings too, so X tokens
entering is X Risen Reef triggers.

The kill is not a combo. It is a wide board of 5/5s from Omnath, Locus of Rage,
pumped by Jubilation or Soulstoke, with Drakuseth or Ghalta as the card that
ends a stalled table.

## Where the cards came from

44 of these 100 cards are the Temur half of **Dance of the Elements**, the
five-colour Ashling precon that was dismantled into `free-cards`. This deck is
not that deck rebuilt: Ashling's plan was an evoke-and-copy loop across five
colours, and this one drops white and black entirely to make the mana work, then
routes the same Elemental bodies through landfall instead.

**Nothing here was taken from an assembled deck.** All 100 cards came out of
`free-cards`; `make moves` shows 81 moves and every one of them starts there.

## The manabase, simulated

38 lands: 16 nonbasic and 22 basics (10 Forest, 6 Island, 6 Mountain). Basic
supply was checked by hand, because `validate` exempts basics from the supply
check — 17 Forest, 9 Island and 10 Mountain are free, so the list fits with room
to spare.

**Coloured sources: G 16 · U 13 · R 13** for an ordinary spell. That rises to
**G 19 · U 16 · R 16 for an Elemental spell**, because Primal Beyond, Unclaimed
Territory (naming Elemental) and Abundant Countryside are conditional
any-colour lands. The commander is an Elemental *creature*, so it is one of the
few cards that turns on all three at once.

Simulated on the play, no mulligan, **lands only — the ramp is not counted, so
these are floors**:

| | |
|---|---|
| Omnath on turn 4 | 46.2% |
| Omnath by turn 5 | 54.6% |
| Risen Reef on turn 3 | 59.6% |
| Selvala / Endurance `{1}{G}{G}` on turn 3 | 43.6% |
| *baseline: any `{4}{G}` Elemental on turn 5* | *38.5%* |
| Cavalier of Thorns `{2}{G}{G}{G}` on turn 5 | 24.5% |
| Titan of Industry `{4}{G}{G}{G}` by turn 7 | 12.8% |

The baseline row is the one that matters: **the triple green costs 14
percentage points** against a single-pip card of the same mana value. Titan's
12.8% is a different problem — that is seven lands in thirteen cards, not
colour.

Those two rows are lands only, and the deck has one real answer to them:
**Springleaf Parade gives every creature token you control "{T}: Add one mana
of any color"**, so four Locus of Rage tokens are four mana of any colour. That
is what actually makes Cavalier and Titan castable. The tokens are summoning
sick, though — a token made this turn produces nothing this turn unless
Maelstrom Wanderer is out.

## Sequencing, the part that gets misplayed

- **Play the land in the precombat main phase.** The Locus of Rage tokens have
  no haste unless Maelstrom Wanderer is out, but the extra lands are what turn
  on the commander's draw.
- **Jubilation must enter before combat damage.** Its +2/+2 and trample last
  only until end of turn. The correct line is Soulstoke *after blockers are
  declared* — blocks were committed against the small bodies. Putting it in
  after combat does nothing at all.
- **Omnath's ETB counts itself.** It resolves with Omnath already on the
  battlefield, so it is never zero. With Risen Reef, Smokebraider and two tokens
  out, recasting him from the command zone deals 5.
- **Soulstoke is instant speed** — no timing restriction on the ability. What
  the cheated creature *left behind* stays; only the creature is sacrificed.
  Avenger of Zendikar for {1}{R} with eight lands leaves eight Plants.
- **The eighth land turns on the draw immediately.** Omnath counts lands as the
  trigger resolves, and the land that caused it is already there.

## Known weaknesses

Stated with numbers so they do not quietly stop being true.

1. **One board wipe, and it is symmetric.** Chain Reaction deals X to *each*
   creature where X is the number of creatures on the battlefield. In a deck
   that makes 5/5 tokens and Plant tokens, it hits this side hardest. The free
   pool had no one-sided sweeper in Temur.
   **The exception is worth knowing**: with Omnath, Locus of Rage out it is not
   a bad card at all — every Elemental of yours that dies, Omnath included,
   deals 3. Five bodies dying is 15 damage aimed anywhere. Registered as a
   combo. Without Locus of Rage it is still only a catch-up card.
2. **13 of the 16 nonbasic lands enter tapped.** Every dual in `free-cards`
   reads "This land enters tapped" — checked one by one. In Commander this is
   survivable, but it is the direct cause of turn-4 Omnath being a coin flip.
3. **Risen Reef is a single copy** and both value engines route through it.
   There is no redundancy in the collection; removal on Reef turns the deck
   into an ordinary pile of Elementals.
4. **The last eight or so slots are filler** — Visionary's Dance, Wild
   Hypothesis, Fractal Mascot, Uncharted Voyage. The free Temur pool holds 149
   Commander-legal cards but roughly 75 that belong in a deck. These are the
   first cards to cut for anything better.
5. **Only one card protects a creature.** With the whole plan sitting on Risen
   Reef and the commander, that is the gap most likely to lose a game.

## Combos

**Nine** are registered in the database with their worked cases — read them with
`make query ARGS='combos --deck roil-elementals'`. **None of them is infinite**,
and that is recorded deliberately: the Reef + Locus of Rage chain averages
**1.5 tokens per land drop** and reaches three or more only **12%** of the time.

Four run the engine — Risen Reef paired with each Omnath and with Tatyova, and
Incandescent Soulstoke cheating an ETB into play. Three are the payoffs:
Chain Reaction as reach, Springleaf Parade as the colour fix, Maelstrom
Wanderer as the top end. One is Cream of the Crop + Realmwalker, casting off
the top.

**The ninth is an anti-synergy**, and it is filed as a combo on purpose.
Selvala, Heart of the Wilds looks like a draw engine here and is not: her
trigger draws for *the controller of the entering creature*, so it helps
opponents, and it needs the entering creature's power to be **greater than each
other** creature's power — so the second identical 5/5 token draws nothing.
Keep her for the mana ability, which genuinely does turn {G} into five.
