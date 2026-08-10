# Turtle Power! — strategy

> Written from what is actually in the decklist, not from play experience.
> Numbers describe the **current 100**, rebuilt after the commander change of
> 2026-08-10.

**Commanders:** a partner pair — **Leonardo, the Balance** `{3}{W}` +
**Michelangelo, the Heart** `{1}{G}`, both *Partner—Character select*.
**Identity:** BGRUW — which comes from **Leonardo**, whose activated ability
costs `{W}{U}{B}{R}{G}`. That is the only reason the deck can stay five colours
behind a two- and a four-drop.
**Target bracket:** 3 (Upgraded). Runs **zero Game Changers**, so all three of
the allowance are spare.

> **Leonardo:** whenever a token you control enters, you may put a +1/+1 counter
> on each creature you control. Once each turn. — `{W}{U}{B}{R}{G}`: creatures
> you control gain menace, trample and lifelink until end of turn.
>
> **Michelangelo:** trample. Raid — at the beginning of your second main phase,
> if you attacked this turn, put a +1/+1 counter on target creature and create a
> Food token.

**Heroes in a Half Shell is still in the deck**, as an ordinary card. It is a
5/5 with vigilance, menace, trample and haste that draws a card whenever your
Mutants, Ninjas or Turtles connect — a fine top end, but no longer the plan.

## What the deck does

A **+1/+1 counters** deck that used to be a combat-damage tribal deck, and the
difference is the whole point of the 2026-08-10 commander change:

- **Before**, counters were a reward for CONNECTING. Only creatures that got
  through were paid, and the first attack of the game always paid nothing.
- **Now**, counters are a reward for MAKING A TOKEN. Leonardo pays every
  creature you control, once each turn, with no combat required — and
  Michelangelo makes the token himself every turn you attack. Declaring a single
  attacker is enough; it does not need to connect.

**The one piece of timing that governs everything:** Michelangelo's Raid trigger
resolves in your **second main phase**, after combat. The counters are
ammunition for *next* turn's attack, not this one. Every "if it has a counter"
effect in the deck — Gnarlid Colony's trample, Michelangelo Mutant BFF's
unblockability, Raphael's doubling, Ray Fillet's draw — comes online one turn
later than it feels like it should.

The four Turtles (Leonardo,
Donatello, Raphael, Michelangelo) plus Splinter are the core creature suite.

Three jobs:

1. **Creatures that connect** — evasive and aggressive Mutants/Ninjas/Turtles.
2. **Counter payoffs** — Corpsejack Menace doubles the commander's counters;
   Steelbane Hydra, Voracious Hydra and Vigor scale with them.
3. **Fixing** — five colours off a five-colour commander, so City of Brass,
   Grand Coliseum, Chromatic Lantern, Arcane Signet and four tri-lands.

## How it wins

Combat. The commander converts a single connection into a permanent board
upgrade plus cards, so the deck snowballs if it is not blocked. Vanquish the
Horde and Blasphemous Act reset opposing boards to let the attack through.

**Two patterns worth knowing cold**, both registered in `combos`:

- **Michelangelo, Mutant BFF + menace = unblockable.** "Can't be blocked by more
  than one" plus "can't be blocked except by two or more" leaves no legal block.
  The commander supplies the menace itself; it only needs a counter first.
- **Garruk's Uprising, not Gnarlid Colony, is your trample.** A blocked creature
  whose blockers have all died deals **no** damage unless it has trample (CR
  510.1a) — and Garruk's grants it with no condition, so it works on the turn
  before Leonardo's counters arrive. Gnarlid's version is a strict subset and is
  flagged as redundant in `upgrades.md`.
- **Return of the Wildspeaker is held, not cast on curve.** It draws equal to
  your greatest non-Human power, which Leonardo grows for free every turn — and
  it is an instant, so it answers a board wipe by turning the dying board into
  cards.

## Known weak points

- **The commanders now land on curve, which is the whole reason for the change.**
  Measured on this exact 100 — 40,000 simulated games, on the play, London
  mulligan, rocks drawn rather than assumed:

  | | T2 | T3 | T4 | T5 |
  |---|---|---|---|---|
  | Michelangelo `{1}{G}` | **53%** | 90% | 95% | 97% |
  | Leonardo `{3}{W}` | — | 6% | **51%** | 76% |
  | Heroes `{W}{U}{B}{R}{G}` *(now a maindeck card)* | — | — | 10% | 34% |

  Leonardo's `{W}{U}{B}{R}{G}` activation costs exactly what Heroes used to, so
  the team-wide menace alpha strike is still a turn-six play. The reliable
  evasion is Michelangelo, Mutant BFF plus a printed-menace creature.
- **The shortage is mana, not fixing**, and it still is after the upgrade. At
  turn five only 46% of games have five untapped sources of any colour; when
  they do, the five colours line up 75% of the time. Eleven lands individually
  make any colour — what the deck is short of is acceleration, and a lot of its
  lands still enter tapped. This is what the wishlist is aimed at.
- White is the thinnest colour: two Plains among the basics.
- Heavily reliant on combat; a single Fog effect or a wide blocking board
  blanks a turn.
- **The first attack is the weak one.** The commander enters with no counter,
  so Raphael does not double it, Gnarlid Colony gives it no trample, and
  Michelangelo's lock does not switch on. Put a counter on precombat —
  Together Forever, Arcade Cabinet, Level Up, or the Mutagen token Michelangelo
  makes on arrival — and the first swing plays like the second.
- **Dying tokens trigger nothing.** Splinter, Rat King and Tokka & Rahzar all
  say *"another **nontoken** creature you control leaves the battlefield"*.
  Chump-blocking with a Rat or a Ninja token gains only the damage it absorbs.
  Sacrifice them instead: Rat King's `{2}, Sacrifice a token: Draw a card`, or
  Arcade Cabinet, which needs a token anyway.

## To work out in session

- **Applied 2026-08-10:** the twelve-swap upgrade in `upgrades.md`. Big Apple,
  3 a.m. was kept at his call — Savage Lands came in for Vibrant Cityscape
  instead, and the measurement backs it: the three ways of resolving that swap
  differ by 0.2pp, inside the simulation's noise.
- Next lever is the wishlist, not another swap. Birds of Paradise and Nature's
  Lore are aimed straight at the 46% figure above.
- **Springleaf Parade** (free, `free-dance-of-the-elements`) is the one pool card
  still worth arguing about: it makes every creature token tap for any colour —
  including Big Apple's Rats — and its own tokens are changelings, so they are
  Mutants, Ninjas and Turtles at once and do trigger the commander. It needs a
  cut named; that thinking has not been done.
