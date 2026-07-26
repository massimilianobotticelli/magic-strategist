-- Facts that no import can derive: target brackets, an ambiguous commander,
-- wishlist detail, and registered combos.
--
-- Edit this file and re-run `make seed`. It is idempotent.
--
-- Deck slugs come from the ManaBox binder names, so renaming a binder in
-- ManaBox renames the deck here on the next import. That keeps ManaBox as the
-- single source of truth for where cards physically are.

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------------
-- Commander for Blight Curse.
-- Its decklist has no `// COMMANDER` marker and contains eight legendary
-- creatures, so it cannot be inferred. The pre-upgrade list names Auntie Ool.
-- ---------------------------------------------------------------------------
UPDATE decks
   SET commander_oracle_id = (SELECT oracle_id FROM cards WHERE name = 'Auntie Ool, Cursewretch')
 WHERE slug = 'blight-curse-b4-final';

UPDATE decks
   SET color_identity = (SELECT color_identity FROM cards WHERE oracle_id = decks.commander_oracle_id)
 WHERE commander_oracle_id IS NOT NULL;


-- ---------------------------------------------------------------------------
-- Target brackets.  1 Exhibition · 2 Core · 3 Upgraded · 4 Optimized · 5 cEDH
--
-- PROVISIONAL - confirm these. `blight-curse-b4-final` is set to 4 because its
-- own name says B4; the other two are unmodified precons, which sit at 2.
-- ---------------------------------------------------------------------------
UPDATE decks SET target_bracket = 4, is_registered = 1 WHERE slug = 'blight-curse-b4-final';
UPDATE decks SET target_bracket = 2, is_registered = 1 WHERE slug = 'turtle-power';
UPDATE decks SET target_bracket = 2, is_registered = 1 WHERE slug = 'dance-of-the-elements';


-- ---------------------------------------------------------------------------
-- Wishlist.  Seeded from the ManaBox `Blight Curse Future` list; the price
-- ceiling follows the standing ~EUR 10-15 per card budget.
-- ---------------------------------------------------------------------------
UPDATE wishlist
   SET deck_id = (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final'),
       price_ceiling_eur = 15.0,
       priority = 2
 WHERE notes LIKE '%Blight Curse Future%';

UPDATE wishlist
   SET oracle_id = (SELECT oracle_id FROM cards WHERE cards.name = wishlist.card_name)
 WHERE oracle_id IS NULL;


-- ---------------------------------------------------------------------------
-- Combos.
--
-- Nothing is seeded here yet: the strategy and upgrade documents these would
-- come from do not exist, and inventing combos would put fiction into the
-- database. Register them as they are worked out, one INSERT per combo.
--
-- The disablers are the part that keeps getting lost, so they are not
-- optional. Template:
--
--   INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
--   VALUES ('Devoted Druid + Quillspike', 'infinite',
--           'infinite +1/+1 counters and unbounded mana',
--           'turn 4-5 with ramp', NULL,
--           (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final'));
--
--   INSERT INTO combo_pieces (combo_id, oracle_id, owned)
--   SELECT (SELECT id FROM combos WHERE name = 'Devoted Druid + Quillspike'),
--          oracle_id, 1 FROM cards WHERE name IN ('Devoted Druid', 'Quillspike');
--
--   INSERT INTO combo_disablers (combo_id, oracle_id, note)
--   SELECT (SELECT id FROM combos WHERE name = 'Devoted Druid + Quillspike'),
--          oracle_id, 'stops the untap' FROM cards WHERE name IN ('Pithing Needle');
-- ---------------------------------------------------------------------------
