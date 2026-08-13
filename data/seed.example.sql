-- Facts that no import can derive: target brackets, commanders that cannot be
-- inferred, deck status and format, registered combos, effective costs and
-- wishlist detail.
--
-- Edit this file and re-run `make seed`. It runs AFTER the import, so it wins.
--
-- IT MUST STAY IDEMPOTENT. `make seed` and `make rebuild` both replay the whole
-- file, so guard anything that appends — an INSERT without a guard will append
-- a second copy on the second run, and a text column that appends to itself
-- corrupts the sentence it wrote the first time.
--
-- Deck slugs come from the ManaBox binder names, so renaming a binder in
-- ManaBox renames the deck here on the next import. That keeps ManaBox as the
-- single source of truth for where cards physically are.

PRAGMA foreign_keys = ON;


-- ---------------------------------------------------------------------------
-- Deck format and status.
--
-- An import derives NEITHER. A deck with no row here silently defaults to
-- Commander, which is how a 60-card Modern deck first shows up as
-- "needs exactly 100".
--
--   format: commander · pdh · modern · pauper · limited   (see scripts/formats.py)
--   status: active · donor · retired · draft
-- ---------------------------------------------------------------------------
-- UPDATE decks SET format = 'commander', status = 'active' WHERE slug = 'my-first-deck';
-- UPDATE decks SET format = 'modern',    status = 'active' WHERE slug = 'my-modern-deck';


-- ---------------------------------------------------------------------------
-- Commanders that cannot be inferred.
--
-- The importer reads a `// COMMANDER` marker in decklist.txt. Only name a
-- commander here when the list has no marker and holds several legendary
-- creatures, so the guess would be wrong.
-- ---------------------------------------------------------------------------
-- UPDATE decks
--    SET commander_oracle_id = (SELECT oracle_id FROM cards WHERE name = 'Commander Name')
--  WHERE slug = 'my-first-deck';

UPDATE decks
   SET color_identity = (SELECT color_identity FROM cards WHERE oracle_id = decks.commander_oracle_id)
 WHERE commander_oracle_id IS NOT NULL;


-- ---------------------------------------------------------------------------
-- Target brackets (Commander only).
-- 1 Exhibition · 2 Core · 3 Upgraded · 4 Optimized · 5 cEDH
--
-- The bracket decides how many Game Changers the deck may run, and validate.py
-- enforces it. See knowledge/brackets.md.
-- ---------------------------------------------------------------------------
-- UPDATE decks SET target_bracket = 3, is_registered = 1 WHERE slug = 'my-first-deck';


-- ---------------------------------------------------------------------------
-- Registered combos.
--
-- Not only infinite loops: any pair of cards that reliably wins or gains a
-- decisive advantage belongs here, with kind = 'value'. The point is to
-- recognise the pattern at the table without re-reading the cards, so put the
-- sequencing traps in `notes` — which card must be played after combat, which
-- trigger checks its condition too early to help.
--
-- `combos` is UNIQUE (name, deck_id) and the two child tables are keyed on
-- (combo_id, oracle_id), so INSERT OR IGNORE is all the guard these need.
-- ---------------------------------------------------------------------------
-- INSERT OR IGNORE INTO combos (name, kind, payoff, power_level, notes, deck_id)
-- SELECT 'Combo name', 'infinite', 'What it produces', 'bracket 4',
--        'Sequencing traps and the stop condition.',
--        (SELECT id FROM decks WHERE slug = 'my-first-deck');
--
-- INSERT OR IGNORE INTO combo_pieces (combo_id, oracle_id, owned, note)
-- SELECT (SELECT id FROM combos WHERE name = 'Combo name'),
--        (SELECT oracle_id FROM cards WHERE name = 'First Piece'), 1, NULL;
--
-- The cards that shut the combo OFF. This is the detail notes lose first, and
-- it is why the table exists.
-- INSERT OR IGNORE INTO combo_disablers (combo_id, oracle_id, note)
-- SELECT (SELECT id FROM combos WHERE name = 'Combo name'),
--        (SELECT oracle_id FROM cards WHERE name = 'Hate Card'),
--        'Why it turns the combo off.';
--
-- A disabler usually is NOT a card you own, so nothing imports it and the
-- subselect resolves to NULL. Add its name to EXTRA_CARDS in the Makefile so
-- `make rebuild` fetches it and keeps resolving it offline.


-- ---------------------------------------------------------------------------
-- Effective costs (60-card formats).
--
-- cards.mana_value is the PRINTED cost and every query sorts on it. When a deck
-- reliably turns on a cost reduction or an alternative cost, record the real
-- cost here — scoped to the deck, because "reliably" is a property of the deck.
--
-- Two rules, both learned the hard way:
--   * Say which DIRECTION the discount works in. A card that costs two on
--     defence and five on offence needs that written down, or the note is worse
--     than none.
--   * Do NOT record a discount the deck cannot count on. A cost reduction that
--     needs a condition a faster opponent never gives you is not a discount.
-- ---------------------------------------------------------------------------
-- INSERT OR REPLACE INTO effective_costs (oracle_id, deck_id, effective_mv, condition)
-- SELECT (SELECT oracle_id FROM cards WHERE name = 'Card Name'),
--        (SELECT id FROM decks WHERE slug = 'my-modern-deck'),
--        2.0,
--        'Costs {1}{W} while you control a creature with toughness 4+. Defence only.';


-- ---------------------------------------------------------------------------
-- Wishlist detail.
--
-- ManaBox `list` binders import as wishlist rows with a card name. What they
-- cannot carry is which deck the card is for and why it is wanted.
-- ---------------------------------------------------------------------------
-- UPDATE wishlist
--    SET deck_id = (SELECT id FROM decks WHERE slug = 'my-first-deck'),
--        notes   = 'What it answers, and what it would replace.'
--  WHERE card_name = 'Card Name';
