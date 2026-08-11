# Loose card pools

Cards not assigned to a deck. **The cards themselves live in the database, not
in this folder** — this file only explains what each pool is. Query them:

```bash
make query ARGS='pool --location free-cards'
make query ARGS='pool --color-identity BRG --type creature'
```

A pool is a `locations` row with `type = 'pool'`, created from a ManaBox binder
whose Binder Type is `binder` (as opposed to `deck`).

**Donor decks count as pools too.** A deck with `status = 'donor'` has been
cannibalised for parts, so `query.py pool` includes its cards by default, tagged
`(donor)`. Use `--pools-only` to see just the loose binders.

## Current pools

**There is only one, since 2026-08-10.** He consolidated every loose card into a
single ManaBox binder — physically as well as in the app — so the four pools
below became one.

| Slug | ManaBox binder | What it is |
|---|---|---|
| `free-cards` | Free Cards | Every loose card he owns: 310 at the time of writing. |

The pools it replaced were `ninja-booster` (TMNT booster contents, duplicates
and tokens), `moved-blight-curse` (the cards taken out of Blight Curse during
its bracket-4 upgrade), `free-dance-of-the-elements` (the dismantled precon)
and the `dance-of-the-elements` donor deck. **Those names appear in older
`upgrades.md` files and in `data/seed.sql` notes as a record of where a card
came from at the time. They are history, not addresses** — everything loose is
in `free-cards` now, and `make query ARGS='card "<name>"'` is the way to find
anything.

One thing genuinely lost in the merge: the pools used to carry meaning, and
`moved-blight-curse` in particular was "the first place to look when Blight
Curse needs something back". That signal is gone; the git history of
`decks/blight-curse-b4-final/upgrades.md` is where it lives now.

## Notes

- Booster pools legitimately contain multiples of the same card and a lot of
  tokens. `validate.py` lists cards owned in multiples as information, not as
  failures.
- `Blight Curse Future` is a ManaBox binder of type `list`, not a pool — it is
  imported into the `wishlist` table instead. See `make query ARGS='wishlist'`.
