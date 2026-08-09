# Foot Clan Blitz — upgrades

## Why the deck was rebuilt rather than tuned

Foot Clan Sneak lost repeatedly to Steffen's deck and to Florian's Final Fantasy
starter, and the diagnosis was the same both times: too many cards that cost
too much. The measurement, before the rebuild:

- **22 of 37 spells (59%) cost 3 or more.** Average mana value 2.78.
- **Eleven cards at four mana or more**, most of them without immediate board
  impact: Foot Mystic, Lord Dregg, Putrid Pals, Anchovy & Banana Pizza,
  Leonardo's Technique, Don & Leo at five.
- **Three of 23 lands entered tapped**, and Secluded Courtyard made coloured
  mana only for one creature type.

The deeper problem was structural, and tuning could not reach it: **Sneak is not
a fast mechanic.** It discounts a spell only when you already have an unblocked
attacker in the declare blockers step. Against a deck that develops faster than
yours, that attacker never connects, so every Sneak cost was paid at full price
— a 4-mana Shark Shredder and a 4-mana Leonardo's Technique in a deck that was
dead on turn five.

Tuning within W/B could reach average MV 2.29 at best, and half the additions
would have been artifacts that do not attack. Dismantling **sos-draft** unlocked
the cheap removal the collection was otherwise hiding — Bitter Triumph, Last
Gasp, Repel Calamity, Burrog Banemaker, Imperious Inkmage, Elite Interceptor —
and that is what made a genuinely fast list possible.

## What was cut and why

| Out | Reason |
|---|---|
| Don & Leo, Problem Solvers `{3}{W/U}{W/U}` | Five mana. A late-game engine in a deck that must win early. |
| Leonardo's Technique `{3}{W}` | Rebuilds after a wipe — a card for the game this deck is trying not to play. |
| Anchovy & Banana Pizza `{2}{B}{B}` | Four-mana removal on a strained mana base, and the only `{B}{B}` left. → `free-cards` |
| Foot Mystic, Lord Dregg, Putrid Pals | Four-mana bodies whose Disappear triggers needed a bounce the deck no longer makes. |
| Shark Shredder x2 `{2}{B}{B}` | The best top end, but still top end. → `free-cards` |
| ~~Grounded for Life x2~~ | **Reversed on 2026-08-09 — see below.** |
| Ice Cream Kitty, Make Your Move | Sorcery-speed value and conditional removal; both too slow for the plan. |
| Illegitimate Business, Foot Headquarters x2, Forum of Amity | Every one enters tapped. Rule 2 is now met with zero exceptions. |

## Correction, 2026-08-09: Grounded for Life back in, at full count

**Caught by him while sleeving the deck, and he was right.** The rebuild cut
both copies for a printed mana value of 5, which is the wrong measure — the
rule in CLAUDE.md is *effective* cost, and Grounded for Life costs `{1}{W}`
whenever it targets a tapped creature. It was even identified correctly in the
first pass over the old deck and then cut anyway in the rebuild. Printed cost
was applied where effective cost was called for.

| In | Out | Why |
|---|---|---|
| Grounded for Life `{4}{W}` → `{1}{W}` | Tunnel Rats `{1}{B}` | His call. Tunnel Rats is a vanilla 2/2 for two; its recursion costs `{4}{B}`, far outside the curve, and it is a Rat so Turtle Van does not double it. Two-mana unconditional *destroy target creature* is simply a better card. |
| Grounded for Life (2nd copy) | Goldvein Pick `{2}` | The weaker of the two Equipment by a distance — `+1/+1` for a two-mana card plus `{1}` to equip, against Quick-Draw Katana's `+2/+0` and first strike. Losing its Treasures costs a little colour fixing; see the mana section. |

**The condition is one-directional and worth internalising: cheap on defence,
full price on offence.** Against Steffen and Florian — the decks that were
attacking him while he durdled — their creatures are tapped every combat, so it
is a two-mana removal spell exactly when it is needed. Trying to clear a fresh
blocker on his own turn really does cost five. It is not a proactive card.

Net effect: 22 creatures instead of 23, removal from 9 to 11, effective average
mana value unchanged at 2.00 (printed 2.16).

**The lesson worth keeping:** a printed mana value is a filter, not a verdict.
Before cutting anything for cost, read the card for a reduction or an
alternative cost the deck reliably turns on — and if it has one, say which
direction it works in.

## The trade that was made deliberately

**Rule 2 (no taplands) was bought at the cost of colour consistency.** The
collection owns no untapped W/B dual, so the only way to keep every land
untapped was to fill the deck with basics plus two restricted lands, leaving
**ten coloured sources for noncreature spells**. Every noncreature card in the
maindeck is a single pip precisely because of this; adding one `{B}{B}` card
would break it.

This is the honest gap. It is not solved from the collection — it is item 1 on
the wishlist.

## The sideboard: deliberately deferred

The deck was promoted with a 15-card sideboard and he removed it on 2026-08-09.
**This was a choice, not an oversight** — he is not used to sideboarding yet and
would rather play a clean 60 than carry 15 cards he would not know when to
bring in. The ManaBox binder holds exactly the 60 maindeck cards. He wants to
do it properly later, so this section is the handover, not a complaint.

A bare 60 with no sideboard is completely legal in Modern. What it costs is the
answer to a stabilised board, which is this deck's one structural weakness.

The cards that were in it, all still owned and free in `free-cards`, in the
order they would come back:

1. **Shark Shredder x2** `{2}{B}{B}` — the top end, against decks that go longer
   than you do. The two that matter most.
2. **Grounded for Life x2** `{4}{W}` — effectively `{1}{W}` on a tapped
   attacker, so it is cheap exactly against the fast decks.
3. **Make Your Move** — the only artifact and enchantment answer he owns in W/B.
4. Then: Bake into a Pie, Anchovy & Banana Pizza, Shatter the Sky, Henchbots,
   Soul-Shackled Zombie, Uneasy Alliance, Pain 101, Graduation Day,
   Interjection, Cost of Brilliance.

Worth knowing before he starts: **moving a card between main and sideboard is a
decklist edit, not a proposal** — the app tracks maindeck size, so a sideboard
card is not markable there.
## EPF Point Squad: rejected on the numbers, not on taste

He asked whether EPF Point Squad should replace Helpful Hunter — a fair
question, since a `{1}{W}` 1/1 is a poor body. **The answer is no, and it is
not close.** Two things make it worse than it looks:

1. **Secluded Courtyard names Ninja. EPF Point Squad is a Human Soldier**, so
   the Courtyard does not cast it — it only makes `{C}`. That leaves **11 white
   sources**, not 12.
2. Simulated over 200k hands, on the play: **EPF Point Squad is castable on
   turn 3 only 48% of the time.** Helpful Hunter on turn 2 is 77%.

And the fix people reach for does not work. Buying duals moves it to **57%**,
because a dual replaces a Plains *and* a Swamp — four of them take white
sources from 11 to only 13. **Duals fix colour balance, not colour density.**
The same reasoning rules out Triceraton Commander `{W}{W}` (a Dinosaur Soldier,
so the Courtyard misses it too).

**Helpful Hunter stays**, and the case for it is not the body: two mana buys
**a card plus a free 1/1**, so it is card-neutral. The deck's only other draw is
Omni-Cheese Pizza x2, Oroku Saki connecting, and Rejoinder — thin for a
near-singleton list. There is also simply no better two-drop in the collection:
the whole W/B pool at two mana is Pain 101, Uneasy Alliance, Hoofprints of the
Stag, Everything Pizza and Page, Loose Leaf.

If the 1/1 body still grates, the honest alternative is **Abigale, Poet
Laureate** `{1}{W}{B}` — a 2/3 flier that re-arms a `+1/+1` counter every time
you cast a creature, and 63% castable on turn 3 because one Plains plus one
Swamp is a much easier ask than two Plains. It is a three-drop though, and the
deck already runs twelve.

## Other candidates

- **Soaring Stoneglider** — **taken, 2026-08-09**, replacing Featherbrained
  Filcher. See the correction section above.
- **East Wind Avatar** x3 `{3}{W}` 2/4 flier with Alliance. Three copies is the
  closest thing to a playset the collection owns in white, but four mana and
  defensive stats put it outside the curve target. Only if the deck proves too
  flat — and take the Shark Shredders out of `free-cards` first.

## To buy

Written into the `wishlist` table against this deck. Priority order:

1. **Two or three untapped W/B duals** (Caves of Koilos, Concealed Courtyard,
   Shattered Sanctum and similar are all inside the ceiling). The single biggest
   improvement available, and the only fix for the ten-source problem above.
2. **Prehistoric Pet** x2-3 — evasive one-drop and the best Turtle Van crewer at
   its cost.
3. **Path to Exile** x2-3 — the best removal spell in the deck, currently a
   singleton.
4. **Bitter Triumph** x2-3 — unconditional removal at two mana.
