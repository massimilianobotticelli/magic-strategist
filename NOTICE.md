# Third-party data and fan content

The MIT licence in [LICENSE](LICENSE) covers the code and my own writing. Two
kinds of data in this repository are not mine to license, and are included here
under the terms below.

## Magic: The Gathering card data

`data/collection.db`, `data/collection.sql` and `data/scryfall/` contain card
names, rules text, mana costs, type lines, rarities and set names.

> Magic: The Gathering, its card names and rules text, and all associated
> imagery are © Wizards of the Coast LLC.

This project is **unofficial Fan Content** permitted under the
[Wizards of the Coast Fan Content Policy](https://company.wizardsofthecoast.com/fancontentpolicy).
It is not approved or endorsed by Wizards. Portions of the material used are
property of Wizards of the Coast. It is non-commercial: nothing here is sold,
and there is no advertising or donation link.

Card **images** are not stored in this repository, with one narrow exception:
the app screenshots under `docs/screenshots/` show card art as part of the
interface, included as Fan Content under the same policy. The web app itself
loads every image directly from Scryfall's image servers at display time, so
they are hotlinked rather than redistributed.

## Scryfall

Card data comes from the [Scryfall API](https://scryfall.com/docs/api).
Scryfall's own contributions to that data are dedicated to the public domain
(CC0), but the underlying card text remains Wizards'. Scryfall is not
affiliated with this project.

`scripts/scryfall.py` follows Scryfall's API guidelines: it sends an
identifying `User-Agent`, stays under 10 requests per second, and caches every
response under `data/scryfall/` so a re-run fetches only genuinely new cards.

**`SCRYFALL_USER_AGENT` is required, with no default** — copy `.env.example` to
`.env` and edit one line. That string is how Scryfall reaches whoever is making
the requests. A default would name this repository, so a fork that never
configured it would have its traffic attributed to someone else; instead, a live
request without it stops and says what to set. Nothing offline is affected.

## Commander brackets and Game Changers

`knowledge/game-changers.json` mirrors the official Commander Game Changers
list, refreshed from Scryfall's `is:game-changer` search by
`scripts/sync_gamechangers.py`. Wizards revises that list every few months; the
committed copy is a snapshot, and `make sync-gc` is how it is brought up to
date. `knowledge/brackets.md` is my own summary of Wizards' published bracket
system.

## What this means if you fork it

The code is yours to use under MIT. The card data is not — but you do not need
mine, because the repository is designed to be reset and refilled from your own
collection. See **[FORK.md](FORK.md)**.
