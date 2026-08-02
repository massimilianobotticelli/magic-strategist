# Foot Clan Sneak

Modern, W/B. Built entirely from the `ninja-booster` pool, the loose
`free-cards` and `moved-blight-curse` pools, and the `dance-of-the-elements`
donor deck. **Nothing is borrowed from Turtle Power!** — the one contested card,
Lita, exists in two physical copies.

## How it wins

A cheap evasive creature connects. During the declare blockers step it goes back
to your hand to pay a **Sneak** cost, and a bigger Ninja arrives already tapped
and attacking. The tempo swing is the whole deck: you are paying one or two mana
for a threat that is already dealing damage this turn.

Returning your own attacker is also what turns on **Disappear**, so the bounce
you were making anyway pays twice.

If the game goes long, **Don & Leo, Problem Solvers** takes over: at the
beginning of every end step it blinks an artifact *and* a creature. Anchovy &
Banana Pizza destroys a creature every turn, and Foot Mystic — whose own
Disappear condition is satisfied by having just been exiled — makes a 1/1 Ninja
every turn.

## The three phases

1. **Turns 1-2** — land a cheap body. Featherbrained Filcher (0/2 flier),
   Prehistoric Pet, April O'Neil and Leonardo, Leader in Blue all attack past
   blockers rather than through them.
2. **Turns 3-4** — attack, wait for blocks, convert the unblocked attacker into
   Oroku Saki, Leonardo Big Brother, Shredder's Technique or Karai's Technique.
3. **Turn 5+** — Don & Leo, or Leonardo's Technique via Sneak to rebuild two
   creatures for {1}{W} after a wipe.

## What to know at the table

The registered combos carry the sequencing traps. `make query
ARGS='combos --deck foot-clan-sneak'` is the short version; the ones that cost
games if forgotten:

- **Foot Mystic goes down after combat**, never before — its Disappear check is
  on enter.
- **Hamato Guardian Stance goes down in declare attackers**, not declare
  blockers, or the flying comes too late to make the attacker unblocked.
- **Don & Leo does NOT enable Lord Dregg or Insectoid Exterminator.** Both check
  "at the beginning of your end step" with an intervening-if, so the condition is
  tested before Don & Leo's blink resolves. Bounce with Prehistoric Pet or sneak
  earlier in the turn instead.
- **Lita is the best Turtle Van crewer**, not Squirrelanoids: she banks counters
  on her own and the Van doubles the total she has already built.

## Known weaknesses

- **The mana, and it got worse.** Four {2}{B}{B} cards and one {3}{W}{W} on 23
  lands, against 24 black pips and 20 white. Only **2x Foot Headquarters** is a
  true untapped W/B dual. Secluded Courtyard makes either colour but only for
  creature spells, and Illegitimate Business is a black source that enters
  tapped — it is here because Forum of Amity turned out to belong to the SOS
  Draft deck and the collection holds no other free W/B dual. Two or three real
  duals are no longer an upgrade, they are the deck's bottleneck.
- **Near-singleton.** Only Squirrelanoids, Oroku Saki, Shark Shredder, Grounded
  for Life and Foot Headquarters appear twice. Prehistoric Pet, Featherbrained
  Filcher and Shredder's Technique are the enablers that would most want a
  second and third copy.
- **No graveyard protection.** Leonardo's Technique is blanked by an opponent's
  graveyard hate and there is nothing in the 75 that answers it.
