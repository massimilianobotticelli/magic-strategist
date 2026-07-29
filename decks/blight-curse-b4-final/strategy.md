# Blight Curse — strategy

**Commander:** Auntie Ool, Cursewretch — {1}{B}{R}{G}, Jund (BGR)
**Target bracket:** 4 (Optimized) · 0 ⚡ Game Changers · registered

> Ward—Blight 2.
> Whenever one or more -1/-1 counters are put on a creature, draw a card if you
> control that creature. If you don't control it, its controller loses 1 life.

The upgrade record is in [upgrades.md](upgrades.md). Combos and their disablers
are in the database: `make query ARGS='combos --deck blight-curse-b4-final'`.

## What the deck does

A **-1/-1 counters** deck. Auntie Ool turns every counter placement into either
a card or a drain, so the deck wants to be placing counters constantly — on
opponents' creatures as removal, and on its own creatures as a draw engine. The
two jobs are the same cards, which is what makes the deck efficient.

1. **Counter sources** — Hapatra, Vizier of Poisons; Blowfly Infestation;
   Soul Snuffers; Midnight Banshee; Carnifex Demon; Contagion Clasp; Contagion
   Engine; Black Sun's Zenith; The Scorpion God; Yawgmoth.
2. **Counter payoffs** — Nest of Scarabs; Flourishing Defenses; Obelisk Spider;
   Kulrath Knight; Necroskitter; Zulaport Cutthroat.
3. **Proliferate** — Contagion Clasp, Contagion Engine, Evolution Sage, Vraska,
   Betrayal's Sting: reuses counters already on board instead of spending cards.

## How it wins

Two infinite lines, both registered with their disablers:

**1. Blowfly Infestation + Nest of Scarabs** — the primary engine. A creature
with a -1/-1 counter dies → Blowfly puts a counter on another of your creatures
→ Nest makes that many Insects → the new token dies → loop. Obelisk Spider and
Zulaport Cutthroat drain each iteration. Needs one or two 1-toughness bodies to
start; Reassembling Skeleton is ideal fuel.

> ⚠️ **Stop condition required.** Auntie Ool's draw is *forced*, so you deck
> yourself if the loop cannot be closed. Keep a toughness-2+ target available.

**2. Devoted Druid + Quillspike** — infinite green mana, sunk into Exsanguinate.
Tap the Druid for {G}, put a counter on it to untap, tap again, then pay
Quillspike's {B/G} to remove that counter. The untap is free, so each iteration
nets a green mana and leaves Quillspike +3/+3. Assembles around turn 4–5 —
legal at bracket 4, and **would not be legal at bracket 3**.

Failing that, it wins by grinding: Auntie Ool draws through the deck while
opponents' boards shrink, then Grave Titan, Massacre Girl or the Yawgmoth
engine closes.

## Value engines

- **Skullclamp** — the loop's disposable 1-toughness tokens become "pay {1}:
  draw 2", and it rebuilds after a board wipe.
- **Yawgmoth, Thran Physician** — free sac outlet that also places counters and
  draws cards, feeding the whole -1/-1 package.
- **Diabolic Intent** — budget tutor whose sacrifice cost is nearly free with
  expendable tokens.
- **Chimil, the Inner Sun** — repeatable advantage and makes your spells
  uncounterable.
- **Rogue's Passage** — {4}, {T} before blocks guarantees Auntie Ool connects,
  or pushes a finisher through a stalled board. Combat only; it does not protect
  the creature or help the combo lines.

## Known weak points

- **Melira, Sylvok Outcast and Solemnity turn both combos off outright.** So
  does Pithing Needle naming Devoted Druid.
- Counter payoffs are individually fragile; losing Necroskitter or Nest of
  Scarabs costs a whole axis.
- Sensitive to enchantment removal — Blowfly Infestation and Nest of Scarabs
  are both enchantments and both are combo pieces.

## Matchup notes (vs. a proliferate / charge-counter Jeskai opponent)

- Expect frequent board wipes — Reassembling Skeleton and Puca's Covenant help
  rebuild the combo pieces afterwards.
- Their plan leans on artifacts: point Assassin's Trophy, Putrefy and Vraska at
  their engine pieces rather than at creatures.
