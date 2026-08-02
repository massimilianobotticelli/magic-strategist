---
name: new-deck
description: Build a new deck from the cards Massimiliano already owns, in Commander, Pauper Commander, Modern or Pauper. Use when he asks for a new deck, or when there is a pending request from the web app.
---

# Build a new deck from the collection

The point is **using what he already has**. Buying is the fallback for gaps,
never the starting point. Everything runs in the container.

## 1. Find out what is being asked

```bash
make query ARGS='requests'
```

Pending requests come from the web app's "New deck" button. If there are none,
take the preferences from the conversation instead — the skill works either way.

Every preference is optional. Ask only what actually blocks you; a request with
nothing filled in means "surprise me with whatever the collection supports".
Never block on questions you can answer from the database.

## 2. Know the format's rules

`scripts/formats.py` is the authority — do not recall these from memory.

| Format | Size | Copies | Commander | Rarity |
|---|---|---|---|---|
| `commander` | exactly 100 | 1 | yes | any |
| `pdh` | exactly 100 | 1 | yes, uncommon creature | commons |
| `modern` | 60+ (+15 SB) | 4 | no | any |
| `pauper` | 60+ (+15 SB) | 4 | no | commons |
| `limited` | 40+ | unlimited | no | any |

For Modern and Pauper, aim for **two colours, no lands that enter tapped, and a
curve topping out at 3** — see CLAUDE.md. Say so when the collection cannot get
there, rather than quietly missing the target.

## 3. See what is actually available

```bash
make query ARGS='available --format pdh --colors GU'
make query ARGS='available --format modern --role spot-removal'
make query ARGS='available --format commander --colors BG --borrow'
```

Without `--borrow` you see only cards that cost nothing: the loose pools and
donor decks. With it you also see cards sitting in assembled decks — use it
only if the request allows borrowing, and **name every deck that loses a card**.

Add `--text` when you need oracle text to judge a card. Two decks come from
sets past the training cutoff, so never assume what a card does.

## 4. Build it

- **Respect the colour identity.** For Commander and PDH it is the commander's.
- **Count the lands.** Roughly 36–38 for Commander and PDH, 22–24 for a 60-card
  deck. Basics are unlimited and always available.
- **Cover the roles.** Check the balance with
  `make query ARGS='available --format X --role ramp'` and the same for
  `card-draw`, `spot-removal`, `board-wipe`. A deck with no removal is not a
  deck. Note that lands are deliberately not tagged as ramp.
- **Say what the deck is trying to do** in a sentence before listing cards. If
  you cannot, the pile has no plan yet.
- **Do not invent cards.** Every card must come from a query result.

If the collection cannot fill the list, that is a real finding — say how short
it is and in which role, rather than padding with cards that do nothing.

## 5. Write it to the database

Create the deck as a **draft**, so nothing touches an assembled deck:

```sql
INSERT INTO locations (slug, name, type) VALUES ('<slug>', '<name>', 'deck');
INSERT INTO decks (location_id, slug, name, format, status, color_identity,
                   commander_oracle_id, notes)
VALUES ((SELECT id FROM locations WHERE slug='<slug>'), '<slug>', '<name>',
        '<format>', 'draft', '<WUBRG>',
        (SELECT oracle_id FROM cards WHERE name='<commander>'), '<one-line plan>');

INSERT INTO deck_cards (deck_id, oracle_id, card_name, quantity, section)
SELECT (SELECT id FROM decks WHERE slug='<slug>'), oracle_id, name, 1, 'main'
  FROM cards WHERE name IN (...);
```

Basic lands need an explicit quantity. Then close the request:

```sql
UPDATE deck_requests
   SET status='ready', deck_id=(SELECT id FROM decks WHERE slug='<slug>'),
       response='<what you built, and what is missing>'
 WHERE id=<id>;
```

Cards you could not supply go on the wishlist, never silently dropped:

```sql
INSERT INTO wishlist (card_name, deck_id, quantity, price_ceiling_eur, priority, notes)
VALUES ('<name>', (SELECT id FROM decks WHERE slug='<slug>'), <n>, 15.0, 2, '<why>');
```

## 6. Check it

```bash
make validate
```

The validator is format-aware: size, copy limit, legality and rarity are all
checked against the deck's own format. A draft that fails is not finished.

Then `make dump` and tell him the deck is in the app, with:

- the plan, in a sentence
- how many cards came from pools, how many were borrowed, and **from which deck**
- what is missing and what it would cost
- for Commander, the ⚡ Game Changer count against the target bracket

## Watch out for

- **He owns almost no playsets** — the large majority of cards are single
  copies, so Modern and Pauper decks come out closer to singleton piles than to
  tournament lists. Say so plainly; he plays casually with friends and has
  accepted this, but he should still know which cards would want a second or
  third copy. Count it from `copies` rather than quoting a number from here.
- **Borrowing weakens a real deck.** Never take a card from an assembled deck
  without naming the deck and what it loses.
- **`available` has two blind spots** — it filters by colour identity, which is
  meaningless outside Commander and hides castable hybrids, and it hides a card
  listed in an active deck even when a spare copy is free in a pool. See
  CLAUDE.md before concluding that the collection cannot supply something.
- **The set a card comes from says nothing about whether it is free.** A loose
  pool can hold leftovers from a draft whose deck he still plays. Ask him.
- **Basic lands run out too**, and `validate` will not tell you: it exempts them
  from the supply check.
- **Do not modify `decklist.txt`.** Drafts live in the database until he
  promotes them.
