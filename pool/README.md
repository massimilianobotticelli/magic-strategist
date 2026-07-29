# Loose card pools

Cards not assigned to a deck. **The cards themselves live in the database, not
in this folder** — this file only explains what each pool is. Query them:

```bash
make query ARGS='pool --location ninja-booster'
make query ARGS='pool --color-identity BRG --type creature'
```

A pool is a `locations` row with `type = 'pool'`, created from a ManaBox binder
whose Binder Type is `binder` (as opposed to `deck`).

**Donor decks count as pools too.** A deck with `status = 'donor'` has been
cannibalised for parts, so `query.py pool` includes its cards by default, tagged
`(donor)`. Use `--pools-only` to see just the loose binders.

## Current pools

| Slug | ManaBox binder | What it is |
|---|---|---|
| `ninja-booster` | Ninja Booster | Booster pack contents from the TMNT sets. Contains genuine duplicates and tokens. Not a deck. |
| `free-cards` | Free Cards | Assorted loose singles from various sets. |
| `moved-blight-curse` | Moved Blight Curse | The 16 cards taken **out** of Blight Curse during the bracket-4 upgrade. The first place to look when that deck needs something back. |
| `dance-of-the-elements` | *(donor deck)* | Not a binder — a deck with `status = 'donor'`. Blight Curse took Blasphemous Act, Cultivate, Fellwar Stone, Fury and Shriekmaw out of it, and it is now kept as a parts bin at 95 cards. |

## Notes

- Booster pools legitimately contain multiples of the same card and a lot of
  tokens. `validate.py` lists cards owned in multiples as information, not as
  failures.
- `Blight Curse Future` is a ManaBox binder of type `list`, not a pool — it is
  imported into the `wishlist` table instead. See `make query ARGS='wishlist'`.
