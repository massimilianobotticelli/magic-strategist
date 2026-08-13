# Forking this for your own collection

This repository is one person's Magic collection, plus the machinery that makes
it queryable. **The machinery is the reusable part.** Everything under `data/`
and `decks/` describes cards I physically own, and none of it is useful to you
except as a worked example.

There is a command that separates the two:

```bash
make reset              # lists exactly what would go. Deletes nothing.
make reset ARGS=--yes   # actually empties it
```

## What you need

Docker (with the daemon running) and git. Nothing else — no Python on your
host, no virtualenv, no `sqlite3`. Every command in the Makefile runs inside the
container.

You also need **[ManaBox](https://manabox.app)** on your phone, or another
scanner that exports a CSV with a `Scryfall ID` column. That column is the whole
reason the import is unambiguous about reprints and double-faced cards. If your
app of choice exports a different shape, `scripts/import_manabox.py` is ~270
readable lines and the CSV parsing is at the top.

## Step by step

### 1. Fork and clone

```bash
git clone https://github.com/<you>/magic-strategist.git
cd magic-strategist
make build
```

A fork carries my whole commit history, including every version of my
collection. If you would rather start from one empty commit:

```bash
rm -rf .git && git init && git add -A && git commit -m "Start from magic-strategist"
```

Keep [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md) if you do — MIT asks for the
copyright notice to travel with the code, and NOTICE.md is what keeps the card
data on the right side of Wizards' Fan Content Policy.

### 2. Empty it

```bash
make reset              # read the list first
make reset ARGS=--yes
```

That removes the database and its two text dumps, every ManaBox export under
`data/manabox/`, every deck folder under `decks/`, and my `data/seed.sql` —
replaced by the commented template in `data/seed.example.sql`.

It **keeps** `data/scryfall/`, the cached API responses. That is a cache, not a
claim of ownership: keeping it means your first `make enrich` only fetches cards
that are not already there, and it works offline for the ones that are. Pass
`ARGS='--yes --drop-cache'` if you would rather start from nothing.

It also keeps `knowledge/` — the bracket summary and the Game Changers list are
the same for everybody.

### 3. Tell Scryfall who you are

**Required before anything that fetches card data.** `make enrich` and
`make sync-gc` refuse to run until it is set:

```bash
cp .env.example .env
```

Then edit the one line that matters:

```
SCRYFALL_USER_AGENT=my-collection/1.0 (+https://github.com/you/my-collection)
```

Scryfall asks every caller to identify itself and uses that string to get in
touch about its traffic. There is deliberately **no default** — a default would
be *my* repository, and your requests would be attributed to me, silently, with
me unable to do anything about it. Copying `.env.example` without editing it is
caught and rejected too.

`.env` is gitignored and Docker Compose reads it on its own, so there is nothing
else to wire up. Nothing offline needs it: `--offline`, `make rebuild`,
`make validate` and CI all run with no `.env` at all.

### 4. Put your own cards in

Export your collection from ManaBox (Settings → Export → CSV) and drop it into a
dated folder:

```bash
mkdir -p data/manabox/$(date +%F)
# move the CSV in there, then:
make import ARGS="data/manabox/$(date +%F)/*.csv"
make enrich        # fetches card data from Scryfall — needs a connection
make sync-gc       # refreshes the Commander Game Changers list
make validate
make dump          # writes collection.sql + app-state.sql back out
```

`make enrich` is the only step that needs the network, and only for cards the
cache has never seen. It stays under Scryfall's rate limit, and identifies
itself with the `SCRYFALL_USER_AGENT` from step 3 — without it, it stops and
tells you so rather than fetching anonymously.

**How your binders become the model:**

| ManaBox `Binder Type` | becomes |
|---|---|
| `deck` | a deck |
| `binder` | a loose pool of available cards |
| `list` | wishlist entries |

Binder *names* become slugs, so renaming a binder in ManaBox renames the
location here on the next import. That is deliberate: ManaBox stays the single
source of truth for where a card physically is.

**Every export is a full snapshot, not a delta.** Never feed two of them to the
importer — older ones stay committed as history, and `make rebuild` reads only
the newest.

### 5. Add your decks

A deck needs two things the import cannot derive.

**A decklist.** `decks/<slug>/decklist.txt`, one card per line:

```
1 Lightning Bolt (2X2) 117
1 Ragavan, Nimble Pilferer (MH2) 138 *F*
// COMMANDER
1 Kykar, Wind's Fury (M20) 217
```

The `(SET) number` suffix and the `*F*` foil marker are optional but keep the
file true to the physical cards. `// COMMANDER` and `// SIDEBOARD` open a
section; a blank line closes it. `decklist.txt` is the **only** file imported —
any other `decklist-*.txt` in the folder is kept for the record and ignored,
which is how a dismantled list stays readable without becoming a phantom deck.

**A format and a status**, in `data/seed.sql`. Nothing derives these, and a deck
with no row silently defaults to Commander — which is how a 60-card Modern deck
first shows up as "needs exactly 100":

```sql
UPDATE decks SET format = 'modern', status = 'active' WHERE slug = 'my-deck';
```

`data/seed.example.sql` is the template the reset leaves behind, with a
commented example of every block: formats, statuses, brackets, combos, effective
costs, wishlist detail. Edit `data/seed.sql`, then `make seed`.

Then:

```bash
make import ARGS='decks/my-deck/decklist.txt'
make validate
make dump
```

### 6. Rewrite the prose

Four files still describe my collection, and no script can honestly rewrite
them:

| File | What it is |
|---|---|
| `README.md` | what the repo is. The numbers in "Design notes" are mine. |
| `CLAUDE.md` | how an AI session should work in this repo — the useful part, but written to my formats and habits. |
| `pool/README.md` | what the loose pools are. |
| `.claude/rules/decks.md` | conventions inside a deck folder. Mostly general; the worked examples at the bottom are mine. |

`decks/*/strategy.md` and `decks/*/upgrades.md` are gone with the reset — those
are per-deck and you write your own.

### 7. Prove it rebuilds

```bash
make rebuild && make validate
```

`rebuild` throws the database away and reconstructs it from the committed CSVs,
decklists, seed file and Scryfall cache. If that passes, everything you have is
reproducible from files a human can read, and the `.db` is a convenience rather
than the only copy. This is the check worth wiring into CI — see
`.github/workflows/ci.yml`, which does exactly that on every push.

## Working with Claude Code

The repo is built to be driven from a session, but nothing requires it: the
Makefile and the web app work on their own.

If you do use it, `.claude/` holds the parts that matter — `CLAUDE.md` at the
root is the standing brief, `.claude/rules/decks.md` covers deck folders, and
`.claude/skills/new-deck/` builds a deck from what you actually own. The design
principle behind all of it is that **card data is queried per session, never
loaded wholesale into context**: `scripts/query.py` exists so a conversation can
ask focused questions instead of reading a 1 MB dump.

The other half is `deck_proposals`. A session writes proposed changes into that
table with a rationale; you accept or reject them visually in the web app
(`make app`), and neither side edits `decklist.txt` until a change is applied
deliberately. That is what keeps a conversation from quietly rewriting a deck.

## Things that will bite you

- **`validate` checks supply, not location.** It asks "do enough copies of this
  card exist anywhere?", never "is the copy in this deck's own binder?". A
  decklist can be edited, imported and validated completely clean while the
  cards are still sitting in a pool, where they keep reading as free inventory.
  **`make moves` is the check that catches it** — it prints what to move in
  ManaBox for every deck, and where to take each card from.
- **ManaBox import adds, it does not move.** Importing a CSV of a deck you have
  already sleeved will double-count every card. Moving cards between binders is
  done in the app; a CSV is only for cards that are not in it yet.
- **`validate` exempts basic lands** from the copy and supply checks, so it will
  not catch a deck asking for more Forests than you own. Check that yourself.
- **Two exports on the same day** need a letter suffix — `2026-08-10b`, a
  directory of its own. Never a second CSV inside an existing dated directory,
  because `rebuild` globs `<latest>*.csv` and would feed the importer two
  snapshots.
- **`data/app-state.sql` is the only committed home for the app's own tables**
  (proposals, deck requests). `make dump` regenerates it and `make rebuild`
  replays it. Skip the dump and a rebuild silently discards every decision
  recorded in the app.
- **The web app has no authentication.** Anyone who can reach the port can edit
  your decks. `compose.yaml` therefore publishes it on `127.0.0.1` only —
  Docker's usual `"8000:8000"` would put it on every interface, reachable by
  anything on the same wifi. `APP_BIND=0.0.0.0` in `.env` opens it up if you
  want it on your phone; do not leave it that way on a network you do not
  control, and never put it on a public address.

## The card data is not mine to give you

You get the code under MIT. The card names and rules text in `data/` belong to
Wizards of the Coast, and `make reset` removes my copy of them anyway — you
refill from your own collection through Scryfall. [NOTICE.md](NOTICE.md) has the
detail, including the Fan Content Policy terms this project relies on.
