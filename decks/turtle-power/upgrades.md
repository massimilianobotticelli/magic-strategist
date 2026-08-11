# turtle-power — upgrades

Worked out in session on **2026-08-10**. Target moved from bracket 2 to
**bracket 3 (Upgraded)** at his choice. The deck runs **zero Game Changers**
before and after everything below, so it sits well inside bracket 3 — the
change is a statement of intent, not a legality question.

## Status: APPLIED 2026-08-10

All twelve swaps were accepted and are **in `decklist.txt`**, with one change he
made along the way: **Big Apple, 3 a.m. was kept** and Savage Lands came in for
**Vibrant Cityscape** instead — see the section below, where the measurement
backs his call.

The cards were physically moved in ManaBox and re-exported to
`data/manabox/2026-08-10b/`, so the pools no longer offer them as free
inventory. `make rebuild && make validate` reproduces all of it: 0 failures.

**The `deck_proposals` rows were deleted afterwards, at his request, to clear
the app's Proposals tab.** This file is now the only record of what was decided
and why, which is why the rationale for every swap is written out in full below
rather than summarised.

Result of the upgrade, measured the same way both times:

| | before | after |
|---|---|---|
| curve average | 3.43 | **3.23** |
| two-drops | 17 | **21** |
| five-drops | 8 | **4** |
| mana fixing | 12 | **17** |
| commander castable T5 | 25.9% | **34.4%** |
| commander castable T6 | 43.3% | **52.5%** |

## Rules for anything added to this file

Every entry names a **specific cut** and the reason for it. The deck stays at
exactly 100 cards including the commander.

Split candidates into two buckets:

- **Bucket A — already owned.** Say which deck or pool the copy is in today, and
  what that deck loses by giving it up. Check with:
  ```bash
  make query ARGS='card "<name>"'
  ```
- **Bucket B — to buy.** Price tier, ceiling ~€10–15 per card including
  worst-case shipping. English, non-foil, from Cardmarket.

Label Game Changers with ⚡ — they decide bracket legality.

## The measurement everything else follows from

The commander costs `{W}{U}{B}{R}{G}` — five coloured pips, **no generic**, so
colourless mana buys nothing towards it. Sol Ring does not help cast this
commander. Neither does Ash Barrens once it is on the battlefield, nor Turtle
Lair's first ability. Casting it is a five-way colour matching problem.

Simulated 40,000 games of the current 100: on the play, London mulligan keeping
2–5 lands, rocks treated as single copies that have to be drawn rather than
assumed in hand.

| build | T4 | T5 | T6 | T7 |
|---|---|---|---|---|
| **current 100** | 5.4% | **25.9%** | 43.3% | 55.5% |
| + the four land swaps below | 5.9% | 27.3% | 46.0% | 57.9% |
| + Frog Butler | 8.3% | 30.9% | 49.5% | 61.1% |
| + Fertile Ground | 10.5% | **34.5%** | 52.7% | 64.2% |
| + Birds of Paradise *(to buy)* | 13.4% | 38.1% | 56.0% | 67.1% |

**The diagnosis is the useful part, and it is not what the old strategy.md
assumed.** At turn five only **38%** of games have five untapped mana sources
of *any* colour; of those, the five colours line up **68%** of the time. The
precon's fixing is genuinely good — eleven of its lands individually make any
colour. What it has almost none of is **acceleration**, and it plays a lot of
lands that enter tapped.

So the upgrade direction is cheap ramp and untapped sources, **not** more duals.
Buying tri-lands here would repeat the mistake recorded against Foot Clan Blitz:
fixing colour *balance* when the problem is colour *density* — or in this case,
raw mana count.

The four land swaps below are worth only ~1.4 points at turn five on their own.
They are in anyway because they are free and strictly better; they are not the
fix.

## Bucket A — the twelve swaps, all free

Sources, as the pools were named that day: `ninja-booster`, `free-cards`,
`free-dance-of-the-elements`. They were all merged into `free-cards` on
2026-08-10 — the names below are a record of where each card came from, not an
address to look it up at.
Nothing comes out of an active deck. Savage Lands exists in two copies, so
Blight Curse keeps its own.

### Spells

| out | in | why |
|---|---|---|
| Electric Seaweed `{2}{R}{R}` | **Michelangelo, Mutant BFF** `{2}{G}{G}` | a 0/4 Defender cannot attack, and every payoff starts with combat damage |
| Mole Module `{5}` | **Shark Shredder, Killer Clone** `{2}{B}{B}` | a Vehicle is not a Mutant/Ninja/Turtle; crewing also taps two attackers |
| Game Over `{3}{B}{B}` | **Don & Leo, Problem Solvers** `{3}{W/U}{W/U}` | fourth wipe, and the only purely symmetric one |
| Coin of Mastery `{4}` | **Frog Butler** `{1}{G}` | needs artifact mana the deck does not have |
| Krang, the All-Powerful `{4}{U}` | **Fertile Ground** `{1}{G}` | doubles exactly one trigger in the deck (Baxter) |
| Roadkill Rodney `{2}` | **Gnarlid Colony** `{1}{G}` | Robot, no tribal type, never triggers the commander |
| Acidic Slime `{3}{G}{G}` | **Hard-Won Jitte** `{1}{R}` | five mana for one removal the deck already covers three ways |
| Biogenic Ooze `{3}{G}{G}` | **Saved by the Shell** `{1}{G}` | its counters only grow Oozes, a tribe this deck does not have |

Curve effect: the eight cuts average MV 4.4, the eight adds average MV 2.9.
That is deliberate — the simulation says the bottleneck is reaching five mana,
so the fix is partly to stop asking for it.

### Lands — four tapped lands for four better tapped lands

| out | in | why |
|---|---|---|
| Thriving Grove | **Jungle Shrine** (GRW) | three flexible colours instead of two, one locked at enter |
| Thriving Isle | **Seaside Citadel** (GUW) | same |
| Thriving Moor | **Sandsteppe Citadel** (BGW) | same |
| Big Apple, 3 a.m. | **Savage Lands** (BGR) | Big Apple is tapped *and* makes one colour only |

Three of the four incoming lands make **white**, which is the deck's scarcest
colour: only two Plains among the basics.

### The one that is worth more than the other eleven

**Michelangelo, Mutant BFF** — *"Each creature you control with a counter on it
can't be blocked by more than one creature."*

Menace reads *"can't be blocked except by two or more creatures."* A creature
under both restrictions **has no legal block at all.**

- Heroes in a Half Shell has menace printed on it. It enters with no counter, so
  the *first* attack is menace-only. It gets a counter from its own damage
  trigger, and from then on it is unblockable — every turn, drawing a card and
  growing each time.
- You do not have to wait for that first hit: Michelangelo creates a token when
  he enters **and** when he attacks, and that token puts the enabling counter on
  at sorcery speed. He turns himself on.
- Leonardo, the Balance's `{W}{U}{B}{R}{G}` activation grants menace to the
  **whole team** — with Michelangelo out and counters on the board, that is an
  unblockable alpha strike.

This line is **not** registered in the `combos` table yet, on purpose:
`validate` treats a combo piece the deck does not run as a failure, and the card
is still in the pool. It gets a block in `data/seed.sql` the day the proposal is
applied.

### Big Apple, 3 a.m. — kept, and what the Rats actually do

Cut proposed 2026-08-10 and **rejected by him the same day**. He is right and the
measurement says so: resolving the twelfth swap three different ways —
Savage Lands in and Big Apple out, Savage Lands in and Vibrant Cityscape out, or
Savage Lands rejected — gives turn-five castability of 34.5%, 34.4% and 34.6%.
All three sit inside the simulation's noise (±0.24pp standard error at 40,000
trials). Big Apple is the weakest land in isolation, but with eleven other
any-colour lands already doing that job, removing it buys nothing. Savage Lands
now comes in for **Vibrant Cityscape**, which has no mana ability at all.

It stays as a **late-game mana sink**, which the deck otherwise lacks:
`{5}, {T}` for a 1/1 Rat per opponent.

Three things about the Rats, all checked against oracle text:

- **A Rat is not a Mutant, Ninja or Turtle**, so Rats never trigger the
  commander. No counter, no card. That is the ceiling on the plan.
- **DYING RATS TRIGGER NOTHING.** Splinter, Rat King and Tokka & Rahzar all
  read *"another **nontoken** creature you control leaves the battlefield"* —
  three separate cards, same word. So chump-blocking with a Rat gains only the
  damage it absorbs. **Sacrifice them instead**: Rat King's `{2}, Sacrifice a
  token: Draw a card` turns three Rats into three cards, and Arcade Cabinet
  needs a token to sacrifice anyway.
- **Leonardo's token trigger is capped at once each turn**, and the deck already
  fires it every turn for free — Ninja Pizza makes a Food at the beginning of
  every second main phase for zero mana, and Michelangelo, Mutant BFF makes a
  Mutagen on enter *and* on every attack. Six mana of Rats does not buy a
  Leonardo trigger you did not already have.

**Springleaf Parade** (`{X}{G}{G}`, free in `free-cards`) is the
card that would make the Rats earn their mana: *"Creature tokens you control
have '{T}: Add one mana of any color'"* turns them into any-colour sources, and
its own X tokens are changelings — every creature type at once, so they DO
trigger the commander. Not proposed yet: it needs a cut named, and that thinking
has not been done.

### Double strike does not push a creature past a blocker — trample does

Worth writing down because the tactic is right and the mechanism is not.
Blockers are declared **once**, in their own step, before any damage. There is
no "first attack" that uses up blocks and a second one that gets through — going
wide with Rats forces the opponent to *spread* blocks, which is real, but it has
nothing to do with the damage steps.

What double strike does is combine with **trample**, which Gnarlid Colony now
gives to every creature carrying a counter. A blocked creature whose blockers
have all died assigns **no** combat damage at all (CR 510.1a) — unless it has
trample, in which case it assigns everything to the player.

Worked case. Heroes in a Half Shell, 6/6 with a counter, carrying Hard-Won
Jitte, blocked by two 2/2s (menace forces two):

- **First-strike step** — assigns 6. Lethal to the blockers first: 2 and 2, and
  trample carries the remaining **2 to the player**. Commander's trigger: +1
  counter (7/7) and a card. Both blockers die.
- **Regular step** — still a blocked creature, but there is nothing left
  blocking it. Trample assigns all **7 to the player**. Trigger again: +1
  counter (8/8) and a second card.
- **Total: 9 damage, 2 cards, 2 counters — out of an attack that was blocked.**

Without trample the regular step deals **0** to the player. That is the whole
reason Gnarlid Colony and Hard-Won Jitte belong in the deck together.

### Two traps in the adds, written down so they are not re-learned

- **Don & Leo blink loses counters.** Its end-step trigger exiles and returns a
  creature, which comes back as a new object with **no +1/+1 counters**. Never
  point it at the creature you have loaded up. It is there for enter triggers
  and for dodging removal in response. Both targets are *"up to one"*, so
  declining costs nothing.
- **Hard-Won Jitte's first hit is not doubled by Raphael.** Double strike makes
  the commander's trigger fire twice: first-strike damage 5, trigger puts a
  counter on it and draws, regular damage now 6, trigger again — 11 damage, two
  cards, two counters in one swing. But Raphael, the Muscle only doubles damage
  from creatures **that already have a counter**, and on the first-strike step
  the commander does not yet. Put a counter on precombat and both hits double.

## Bucket B — to buy

Written into `wishlist` against this deck, ceiling €15, priorities as recorded.
No prices quoted; none were checked.

1. **Birds of Paradise** (P1) — one-mana any-colour source. The measured fix.
2. **Nature's Lore** (P1) — two-mana ramp that arrives **untapped**, and fetches
   a Forest *card*, so Cinder Glade, Sodden Verdure and Vernal Fen are all legal
   targets (each still applies its own two-basics clause).
3. **Swiftfoot Boots** (P2) — protects the engine. **Boots and not Lightning
   Greaves**: shroud would stop you targeting your own creature with Level Up,
   Saved by the Shell, Together Forever or a Mutagen token.
4. **Fellwar Stone** (P2) — second copy; the first is in Blight Curse.
5. **Branching Evolution** (P3) — a second Corpsejack. With both plus High Score
   applied first, one commander counter becomes `(1+1)×2×2 = 8`.

## Registered combos

Seven `value` lines now live in the `combos` table for this deck — see
`make query ARGS='combos --deck turtle-power'`. The one worth reading before
every game is **Corpsejack Menace + High Score**: both are replacement effects
on the same event, you choose the order, and **High Score must apply first**.
`(n+1)×2` beats `2n+1` by one counter on every creature on every trigger, all
game long.

## Considered and rejected

- **Timeless Lotus** (free, dance-of-the-elements) — five mana and it enters
  tapped. It cannot help cast a five-mana commander; it only helps the turn
  after you already could.
- **More tri-lands / Unclaimed Territory** — the simulation says colour is not
  the binding constraint. Of the 74% of games where the commander is *not*
  castable on turn five, **83% are short of mana outright** (fewer than five
  untapped sources) and only 17% have the mana and the wrong colours. Adding
  more tapped lands answers the smaller half.
- **Commander's Sphere / Weather Maker** (free) — three-mana rocks. Too slow to
  accelerate into a five-drop; they arrive the turn you wanted the commander.
- **Faeburrow Elder** (free) — genuinely strong once it lands, but `{1}{G}{W}`
  is one of the harder costs in the deck to produce on turn three, which is
  exactly when it would need to arrive.
- **Vanquish the Horde** — kept. Cutting Game Over leaves two wipes plus
  Wave Goodbye, and Blasphemous Act is one-sided with Vigor, so the deck can
  still catch up from behind.

## Second pass — 2026-08-10, after the commander change

Switching to the **Leonardo, the Balance + Michelangelo, the Heart** partner
pair invalidated the *reasons* behind two of the twelve swaps, though not the
swaps themselves. Both were re-examined and replaced:

| out | in | why the original reason died |
|---|---|---|
| Hard-Won Jitte | **Garruk's Uprising** `{2}{G}` | the Jitte was in for "fires the commander's trigger twice per attack" — gone with Heroes out of the command zone |
| Don & Leo, Problem Solvers | **Return of the Wildspeaker** `{4}{G}` | added as a Mutant Ninja Turtle feeding the tribal trigger; under Leonardo the creature type is worth nothing, and its blink LOSES +1/+1 counters |

Everything else held. The three that could have flipped under the new engine
because they make tokens — **Coin of Mastery** (`{T}`: a Treasure every turn),
**Biogenic Ooze** and **Roadkill Rodney** — were re-checked and stay cut, for
one reason: **Leonardo is capped at once each turn**, and Ninja Pizza already
fires it for free every second main phase. Extra token generation does not stack.

Two swaps got *better* under the new commanders rather than worse:
**Gnarlid Colony** (Leonardo arms every creature, so trample is no longer
gated on having connected) and **Saved by the Shell** (Michelangelo, the Heart
is a Turtle sitting in the command zone, so its `{1}` discount is permanent).

### Resolved: Gnarlid Colony stays

Flagged on 2026-08-10 as redundant with Garruk's Uprising, then **measured, and
the flag was wrong.** Garruk's grants trample to *creatures you control*
unconditionally; Gnarlid's *"each creature you control with a +1/+1 counter on
it has trample"* is a strict subset — so the two overlap completely **when both
are on the battlefield**, and that is the only case where one is wasted.

These are the deck's **only two permanent team-wide trample sources in 98
cards.** Everything else in the deck that mentions trample — Michelangelo the
Heart, Heroes, Vigor, Leatherhead, Rocksteady, Voracious Hydra, Saved by the
Shell — grants it only to itself. Leonardo's activation grants it to the team
but costs `{W}{U}{B}{R}{G}`.

Hypergeometric, on the play, 98 cards:

| by turn | no trample source | exactly one | **both** (the wasteful case) |
|---|---|---|---|
| 6 | 76.9% | 21.7% | **1.4%** |
| 8 | 73.3% | 24.7% | **1.9%** |
| 10 | 69.9% | 27.6% | **2.5%** |

And holding at least one: **27% by turn eight with both, 14% with Garruk's
alone.** Cutting Gnarlid halves an already-thin number, and the overlap it would
save costs 1.9% of games — a ratio of about 13 to 1 in favour of keeping it.

That matters because trample is load-bearing here. Michelangelo, Mutant BFF only
makes a creature unblockable alongside one of **three** printed-menace creatures;
everything else gets chump-blocked, and trample is what turns a Leonardo-inflated
9/9 into actual damage.

Kicked for `{2}{G}` more, Gnarlid also enters with two +1/+1 counters — which
arms Michelangelo's unblockability on itself immediately and is doubled by
Corpsejack Menace. Even in the 1.9% case it is not a blank.

**Two copies of a core effect is thin coverage in a singleton deck, not waste.**
The original note had the wrong frame, and this is what re-measuring it was for.

## Open items

- **Move the two swapped cards in ManaBox**: Hard-Won Jitte and Don & Leo out of
  the Turtle Power! binder, Garruk's Uprising and Return of the Wildspeaker in
  from `Free Dance of the Elements`. Until that export lands, the pools still
  offer them as free inventory.
- The wishlist still targets the OLD mana problem. With a `{1}{G}` and a
  `{3}{W}` commander instead of `{W}{U}{B}{R}{G}`, tapped lands hurt more and
  five-colour fixing matters less — Birds of Paradise and Nature's Lore still
  apply, but the reasoning in `data/seed.sql` should be re-derived.
