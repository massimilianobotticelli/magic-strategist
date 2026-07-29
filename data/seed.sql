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
-- Dance of the Elements is a donor deck.
--
-- The bracket-4 Blight Curse upgrade took five cards out of it - Blasphemous
-- Act, Cultivate, Fellwar Stone, Fury and Shriekmaw - leaving it at 95. Rather
-- than rebuy or patch it from the pools, it is kept as a parts bin: its cards
-- are available inventory for the two active decks, its list is not held to
-- 100, and it no longer competes for a card an active deck wants.
--
-- To bring it back: set status = 'active' here, fill the list back to 100, and
-- run `make validate`.
-- ---------------------------------------------------------------------------
UPDATE decks SET status = 'donor', is_registered = 0 WHERE slug = 'dance-of-the-elements';


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
-- Source: the Bracket 4 upgrade summary in
-- decks/blight-curse-b4-final/upgrades.md. Every line below was checked against
-- the oracle text in the database, not against memory.
--
-- Disablers are not optional. Melira, Sylvok Outcast turns BOTH combos off and
-- was only recorded as a one-line aside under "rejected additions" in the
-- original notes -- exactly the kind of detail this table exists to stop losing.
-- ---------------------------------------------------------------------------

DELETE FROM combo_disablers;
DELETE FROM combo_pieces;
DELETE FROM combos;

-- 1. The core two-card engine ------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Blowfly Infestation + Nest of Scarabs',
    'infinite',
    'Obelisk Spider and Zulaport Cutthroat drain every opponent once per iteration. Auntie Ool draws a card each time, since the counters land on your own creatures.',
    'Primary line. Needs one or two 1-toughness bodies on board to start; Reassembling Skeleton is ideal fuel.',
    'A creature with a -1/-1 counter dies, Blowfly Infestation puts a counter on another creature you control, Nest of Scarabs makes that many Insect tokens, the new token dies, loop. STOP CONDITION REQUIRED: Auntie Ool''s draw is forced, so keep a toughness-2+ target available to close the loop before decking yourself out.',
    (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Blowfly Infestation + Nest of Scarabs'),
       oracle_id, 1,
       CASE name WHEN 'Reassembling Skeleton' THEN 'ideal starting fuel, not strictly required' END
  FROM cards WHERE name IN ('Blowfly Infestation', 'Nest of Scarabs', 'Reassembling Skeleton');

-- 2. Infinite mana -----------------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Devoted Druid + Quillspike',
    'infinite',
    'Infinite green mana, plus an arbitrarily large Quillspike. Sink the mana into Exsanguinate for a clean kill.',
    'Two creatures for four mana total, so it assembles around turn 4-5. Legal at bracket 4; it would NOT be legal at bracket 3.',
    'Tap Devoted Druid for {G}, put a -1/-1 counter on it to untap, tap again for {G}, then pay Quillspike''s {B/G} to remove that counter. The untap is free, so each iteration nets one green mana and leaves Quillspike +3/+3. Devoted Druid must be free of summoning sickness.',
    (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Devoted Druid + Quillspike'),
       oracle_id, 1, NULL
  FROM cards WHERE name IN ('Devoted Druid', 'Quillspike');

-- Disablers ------------------------------------------------------------------
-- Melira and Solemnity shut off BOTH lines; they were deliberately rejected as
-- additions to this deck for exactly that reason.
INSERT INTO combo_disablers (combo_id, oracle_id, note)
SELECT c.id, k.oracle_id,
       CASE k.name
         WHEN 'Melira, Sylvok Outcast' THEN 'your creatures cannot have -1/-1 counters put on them - kills both lines outright. Explicitly rejected as an addition for this reason.'
         WHEN 'Solemnity' THEN 'counters cannot be put on permanents at all - kills both lines outright'
       END
  FROM combos c CROSS JOIN cards k
 WHERE k.name IN ('Melira, Sylvok Outcast', 'Solemnity');

-- Devoted Druid's untap is an activated ability, so it can be named.
INSERT INTO combo_disablers (combo_id, oracle_id, note)
SELECT (SELECT id FROM combos WHERE name = 'Devoted Druid + Quillspike'),
       oracle_id, 'naming Devoted Druid shuts off the untap ability'
  FROM cards WHERE name = 'Pithing Needle';


-- ---------------------------------------------------------------------------
-- Wishlist corrections from the upgrade summary.
--
-- Demonic Tutor and Vampiric Tutor are both Game Changers and both legal at
-- bracket 4, but the upgrade summary records them as rejected: too expensive
-- for the budget target, replaced by Diabolic Intent. They stay on the ManaBox
-- list, so they are marked dropped rather than deleted.
--
-- To want them again, change 'dropped' back to 'wanted'.
-- ---------------------------------------------------------------------------
UPDATE wishlist
   SET status = 'dropped',
       notes = notes || ' — rejected in the B4 upgrade: over budget, replaced by Diabolic Intent'
 WHERE card_name IN ('Demonic Tutor', 'Vampiric Tutor');
