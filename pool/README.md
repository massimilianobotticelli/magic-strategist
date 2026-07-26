# Loose card pools

Cards not assigned to a deck. **The cards themselves live in the database, not
in this folder** — this file only explains what each pool is. Query them:

```bash
make query ARGS='pool --location ninja-booster'
make query ARGS='pool --color-identity BRG --type creature'
```

A pool is a `locations` row with `type = 'pool'`, created from a ManaBox binder
whose Binder Type is `binder` (as opposed to `deck`).

## Current pools

| Slug | ManaBox binder | What it is |
|---|---|---|
| `ninja-booster` | Ninja Booster | Booster pack contents from the TMNT sets. Contains genuine duplicates and tokens. Not a deck. |
| `free-cards` | Free Cards | Assorted loose singles from various sets. |
| `moved-blight-curse` | Moved Blight Curse | The 16 cards taken **out** of Blight Curse during the bracket-4 upgrade. The first place to look when that deck needs something back. |

## Notes

- Booster pools legitimately contain multiples of the same card and a lot of
  tokens. `validate.py` lists cards owned in multiples as information, not as
  failures.
- `Blight Curse Future` is a ManaBox binder of type `list`, not a pool — it is
  imported into the `wishlist` table instead. See `make query ARGS='wishlist'`.
