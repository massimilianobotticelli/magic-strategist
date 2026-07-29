# Blight Curse — Bracket 4 Upgrade Summary

**Commander:** Auntie Ool, Cursewretch — Jund (B/R/G)
**Format:** Commander, Bracket 4 (Optimized)
**Deck size:** 100 cards (15 in / 15 out from the original precon, plus 1 land swap)

> This is the record of the upgrade that produced the current list. The
> pre-upgrade list is kept at `decklist-pre-upgrade.txt`; the 15 removed cards
> live in the `moved-blight-curse` pool. Both infinite combos below are
> registered in the database with their disablers — see
> `make query ARGS='combos --deck blight-curse-b4-final'`.

---

## Added cards (15)

### Purchases — Bucket B (8 cards, ~€75–80 total)

| Card | Set | Role |
|------|-----|------|
| Nest of Scarabs | AKH | Second half of the primary 2-card combo with Blowfly Infestation |
| Quillspike | EVE | Completes the Devoted Druid infinite mana/power line |
| Obelisk Spider | HOU | Win condition for the Blowfly/Nest loop (opponent drain per counter) |
| Zulaport Cutthroat | BFZ | Redundant drain payoff on creature death |
| Skullclamp | BLC | Converts the loop's disposable Insect tokens into card draw; also rebuilds after board wipes |
| Contagion Engine | SOM | Mass -1/-1 counters on ETB + repeatable double proliferate |
| Diabolic Intent | BRO | Budget tutor — sacrifice cost synergizes with the token loop |
| Yawgmoth, Thran Physician | TSR | Free sac outlet + counter placement + card draw engine |

### Moved from other decks/pool — Bucket A (7 cards)

| Card | From |
|------|------|
| Blasphemous Act | Dance of the Elements |
| Fury | Dance of the Elements |
| Shriekmaw | Dance of the Elements |
| Cultivate | Dance of the Elements |
| Fellwar Stone | Dance of the Elements |
| Exsanguinate | Booster pool |
| Reassembling Skeleton | Booster pool |

⚠️ **Dance of the Elements loses a board wipe, two removal spells, and two
ramp/fixing pieces as a result.** It was left at 95 cards and is now a **donor
deck** — see `decks/dance-of-the-elements/strategy.md`.

### Land swap (independent of the 15/15 plan)

| In | Out | Why |
|----|-----|-----|
| Rogue's Passage (SOC, from booster pool) | 1 Swamp (8 → 7) | On-demand unblockability: guarantees Auntie Ool's combat draw trigger and lets a finisher (Grave Titan, The Scorpion God) close games through blockers. Colorless source absorbed safely — black remains well covered by dual lands. |

**Considered but left out:** Soulstone Sanctuary (FDN, booster pool) — a fine
"better than a basic" manland, but its rebuild-after-wipe role is already
covered by Reassembling Skeleton and Puca's Covenant, and 4 colorless-only
sources (with Ifnir Deadlands + Nesting Grounds) would be the ceiling for this
three-colour manabase. Available in the pool if wanted later.

---

## Removed cards (15)

| Card | Why cut |
|------|---------|
| Cathartic Reunion | Card disadvantage loot, no graveyard payoff |
| Cathartic Pyre | Low-impact modal burn |
| Chain Reaction | Off-theme damage wipe — Blasphemous Act replaces it on-theme |
| Harmonize | Vanilla draw — replaced by tutors |
| Hoarder's Greed | Weakest draw source in the deck |
| Wickersmith's Tools | 3-mana rock → Fellwar Stone (2-mana) is faster |
| Incremental Blight | One-shot 5-mana sorcery, effect replicated better elsewhere |
| Grim Poppet | 7 mana, too slow — Contagion Engine does the job better |
| Liliana, Death Wielder | 7 mana, low impact for the cost — Yawgmoth is the superior engine |
| Wickerbough Elder | Weak body, slow naturalize effect |
| Lasting Tarfire | Incidental burn, too slow |
| Tree of Perdition | Telegraphed, doesn't fit any combo line |
| Archfiend of Ifnir | Too few discard enablers left to support it |
| Binding the Old Gods | Clunky sorcery-speed removal — Shriekmaw is more flexible |
| Commander's Sphere | 3-mana rock → replaced by Cultivate (permanent fixing) |

### Cards kept despite early cut proposals

Chimil, the Inner Sun · Grave Titan · Puca's Covenant · Burning Curiosity ·
Painful Truths — all provide card advantage, resilience, or raw power the deck
can't afford to lose.

### Rejected additions

- **Melira, Sylvok Outcast** ⚠️ — would disable **both** infinite combos.
  Recorded in `combo_disablers` against both, so it cannot be lost again.
- Soul Immolation, Grim Affliction, Drown in Ichor, Banewhip Punisher,
  Plaguecrafter, Blight Rot, Whisper of the Dross — filler below bracket 4
  standard.
- ⚡ Demonic Tutor and ⚡ Vampiric Tutor — too expensive for the budget target,
  replaced by Diabolic Intent. Both are marked `dropped` on the wishlist.

---

## Open items

- (none yet — add candidates here with the specific cut each one implies)
