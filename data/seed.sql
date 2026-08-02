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
-- Foot Clan Sneak: a Modern deck, promoted from draft on 2026-08-02.
--
-- Unlike the other three it has no ManaBox binder - it was built from the
-- pools rather than bought as a product - so an import can derive nothing but
-- its card list from decks/foot-clan-sneak/decklist.txt. Everything below has
-- to be stated here or a `make rebuild` would recreate it as an unnamed
-- Commander deck with the default format.
--
-- No target_bracket on purpose: brackets are a Commander concept and this is
-- Modern. validate.py is format-aware and will not ask for one.
-- ---------------------------------------------------------------------------
UPDATE decks
   SET name           = 'Foot Clan Sneak',
       format         = 'modern',
       status         = 'active',
       color_identity = 'BW',
       is_registered  = 1,
       notes          = 'Cheap evasive bodies connect, then get returned to hand during declare blockers to Sneak in a bigger Ninja tapped and attacking. Bouncing your own attacker also turns on Disappear. Late game, Don & Leo blinks Anchovy & Banana Pizza and Foot Mystic every end step: a removal spell and a Ninja token every turn.'
 WHERE slug = 'foot-clan-sneak';

UPDATE locations SET name = 'Foot Clan Sneak' WHERE slug = 'foot-clan-sneak';


-- ---------------------------------------------------------------------------
-- SOS Draft: the 40-card deck built from a Secrets of Strixhaven draft.
--
-- The ManaBox binder is typed `deck`, so the import creates it, but nothing in
-- an export says which format it is and the column defaults to Commander -
-- which is how it first showed up as "0 cards, needs exactly 100".
--
-- No target_bracket, no commander: neither is a Limited concept.
-- ---------------------------------------------------------------------------
UPDATE decks
   SET name          = 'SOS Draft',
       format        = 'limited',
       status        = 'active',
       is_registered = 1,
       notes         = 'Built from the Secrets of Strixhaven boosters opened at a draft night. Kept assembled to play, so its cards are NOT available to other decks.'
 WHERE slug = 'sos-draft';


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
-- The CROSS JOIN must stay pinned to Blight Curse. Without the deck filter it
-- would silently attach Melira and Solemnity to every combo added later, and
-- Melira in particular is irrelevant to any line that does not use -1/-1
-- counters.
INSERT INTO combo_disablers (combo_id, oracle_id, note)
SELECT c.id, k.oracle_id,
       CASE k.name
         WHEN 'Melira, Sylvok Outcast' THEN 'your creatures cannot have -1/-1 counters put on them - kills both lines outright. Explicitly rejected as an addition for this reason.'
         WHEN 'Solemnity' THEN 'counters cannot be put on permanents at all - kills both lines outright'
       END
  FROM combos c CROSS JOIN cards k
 WHERE k.name IN ('Melira, Sylvok Outcast', 'Solemnity')
   AND c.deck_id = (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final');

-- Devoted Druid's untap is an activated ability, so it can be named.
INSERT INTO combo_disablers (combo_id, oracle_id, note)
SELECT (SELECT id FROM combos WHERE name = 'Devoted Druid + Quillspike'),
       oracle_id, 'naming Devoted Druid shuts off the untap ability'
  FROM cards WHERE name = 'Pithing Needle';


-- ---------------------------------------------------------------------------
-- Foot Clan Sneak (Modern draft).
--
-- These are 'value' combos, not infinite ones: recognisable two-card patterns
-- that win games, recorded so they can be played from memory instead of
-- re-read off the cards every game. Modern has no brackets, so nothing here is
-- a legality question.
--
-- Every line was checked against the oracle text in the database.
--
-- NOTE: the deck is a draft and has no decks/<slug>/decklist.txt, so a
-- `make rebuild` will not recreate it. These rows survive a rebuild but their
-- deck_id falls back to NULL until the draft is promoted to a deck folder.
-- ---------------------------------------------------------------------------

-- 3. The exponential clock ---------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Turtle Van + Squirrelanoids',
    'value',
    'A one-mana deathtouch body that doubles in size every attack. 1 -> 2 -> 6 -> 14 -> 30 counters over four swings, and nothing profitably blocks a deathtouch creature that big.',
    'Strongest line in the deck and the least obvious. Online turn 3-4; the Van does the attacking, Squirrelanoids does the growing.',
    'Turtle Van puts one +1/+1 counter on the creature that crewed it, THEN doubles that creature''s total if it is a Mutant, Ninja or Turtle - Squirrelanoids is a Squirrel Mutant, so it qualifies. Crewing taps it, so it grows while sitting back as a blocker; swing with it on a turn you choose not to crew. BEST CREWER IS LITA, not Squirrelanoids: her Alliance banks counters on its own, and the Van doubles whatever total she has already built, so the two engines multiply instead of adding. Any Mutant/Ninja/Turtle crews it: Lita, Prehistoric Pet, Foot Elite, Koya, April O''Neil, Oroku Saki, Mechanized Ninja Cavalry, Ice Cream Kitty, Putrid Pals, Insectoid Exterminator. TRAP: Featherbrained Filcher is 0/2 and cannot meet crew 1 on its own. If they kill the crewer in response to the attack trigger, the trigger simply fizzles.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-sneak')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Turtle Van + Squirrelanoids'),
       oracle_id, 1,
       CASE name WHEN 'Squirrelanoids' THEN 'best crewer: costs 1 and has deathtouch, so the counters matter immediately' END
  FROM cards WHERE name IN ('Turtle Van', 'Squirrelanoids');

INSERT INTO combo_disablers (combo_id, oracle_id, note)
SELECT (SELECT id FROM combos WHERE name = 'Turtle Van + Squirrelanoids'),
       oracle_id,
       CASE name
         WHEN 'Solemnity' THEN 'permanents cannot have counters put on them, so doubling zero stays zero - kills the line outright'
         WHEN 'Pithing Needle' THEN 'crew is an activated ability of the Vehicle; naming Turtle Van means it can never become a creature and never attacks'
       END
  FROM cards WHERE name IN ('Solemnity', 'Pithing Needle');

-- 4. The basic Sneak turn ----------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Featherbrained Filcher + Oroku Saki, Shredder Rising',
    'value',
    'A 3/1 that enters tapped and attacking for {1}{B} and draws a card when it connects - plus a free Food token off the Filcher.',
    'The deck''s default turn from turn 3 onward. This is the pattern to recognise first; every other Sneak card runs on the same enabler.',
    'Filcher is a 0/2 flier, so it is almost never worth blocking - that is the point, not a drawback. Attack, wait for blockers to be declared, then return the unblocked Filcher to hand as part of casting Oroku Saki for his Sneak cost. Filcher leaving the battlefield also triggers its own "create a Food token", so the enabler pays you every time. The same unblocked attacker pays for Leonardo Big Brother ({W}), Shredder''s Technique ({B}) or Karai''s Technique ({W}{B}) instead - pick on the day.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-sneak')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Featherbrained Filcher + Oroku Saki, Shredder Rising'),
       oracle_id, 1,
       CASE name
         WHEN 'Featherbrained Filcher' THEN 'the enabler; makes a Food every time it is returned'
         WHEN 'Prehistoric Pet' THEN 'interchangeable enabler: cannot be blocked by greater power'
         WHEN 'April O''Neil, Kunoichi Trainee' THEN 'interchangeable enabler: cannot be blocked by power 3 or greater'
       END
  FROM cards WHERE name IN ('Featherbrained Filcher', 'Oroku Saki, Shredder Rising',
                            'Prehistoric Pet', 'April O''Neil, Kunoichi Trainee');

-- 5. Manufacturing an unblocked attacker -------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Hamato Guardian Stance + any Sneak card',
    'value',
    'One white mana turns any creature into an unblocked attacker, which is the resource the whole deck actually runs on.',
    'The fix for the deck''s one real failure mode: you attack, they block everything, and no Sneak cost can be paid.',
    'Cast it in the declare attackers step, BEFORE blockers are declared - +1/+3 and flying. Waiting until blockers are on the table is too late. Reading Sneak''s reminder text, it also lets the sorcery-speed Techniques be cast during the declare blockers step, which is otherwise impossible. Because it targets a creature it also turns on Inkling Mascot.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-sneak')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Hamato Guardian Stance + any Sneak card'),
       oracle_id, 1,
       CASE name WHEN 'Hamato Guardian Stance' THEN 'cast in declare attackers, not declare blockers' END
  FROM cards WHERE name IN ('Hamato Guardian Stance', 'Oroku Saki, Shredder Rising');

-- 6. Evasion off the removal you were casting anyway --------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Inkling Mascot + any targeted spell',
    'value',
    'A 2/2 that flies on demand, turning a removal spell you were casting anyway into a second Sneak enabler.',
    'Free value: ten maindeck spells trigger it, so it is live most turns without building around it.',
    'Repartee triggers on any instant or sorcery you cast that targets a creature: Path to Exile, Stab, Crib Swap, Death in the Family, both Grounded for Life, Karai''s Technique, Hamato Guardian Stance, Shredder''s Technique, Make Your Move. Cast it precombat, swing with a flying Mascot, return it for Sneak. CAREFUL: Leonardo''s Technique targets creature CARDS in the graveyard, not creatures, so it does NOT trigger Repartee.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-sneak')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Inkling Mascot + any targeted spell'),
       oracle_id, 1,
       CASE name WHEN 'Path to Exile' THEN 'representative trigger; ten other maindeck spells do the same' END
  FROM cards WHERE name IN ('Inkling Mascot', 'Path to Exile');

-- 7. The finisher ------------------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Leonardo, Leader in Blue - the alpha strike',
    'value',
    'Sneak him in for {3}{W}{W} and every creature you control gets +2/+0, with Leonardo himself arriving tapped and attacking on top of it.',
    'How the deck actually closes. Hold him rather than casting him as a 1-drop 2/1 once the board is wide.',
    'The anthem only fires if the sneak cost was paid - hard-casting him for {W} gets you a 2/1 and nothing else. COUNT BEFORE DECLARING: the unblocked attacker you return to hand leaves combat, so it deals no damage and does not get the +2/+0. Leonardo Big Brother is a different card name, so both Leonardos can be on the battlefield at once.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-sneak')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Leonardo, Leader in Blue - the alpha strike'),
       oracle_id, 1,
       CASE name WHEN 'Leonardo, Big Brother' THEN 'stacks with it: +1/+0 for each other creature, and a separate legend' END
  FROM cards WHERE name IN ('Leonardo, Leader in Blue', 'Leonardo, Big Brother');

-- 8. Repeatable removal on a body --------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Prehistoric Pet + Koya, Death from Above',
    'value',
    'A removal effect every single turn: bounce Koya, recast her, exile the best creature again.',
    'Grindy but genuinely repeatable, and it needs no extra pieces once both are down.',
    'Prehistoric Pet''s {1}{W}, {T} returns another creature you control to hand during your turn; Koya''s enter trigger exiles a creature until the next end step unless you pay {3}{B} to keep it gone. Two things worth remembering: against a TOKEN the exile is permanent for free, because a token that leaves the battlefield ceases to exist and there is no card to return. And the same bounce turns on Disappear, so it doubles as the enabler for Foot Mystic.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-sneak')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Prehistoric Pet + Koya, Death from Above'),
       oracle_id, 1,
       CASE name WHEN 'Prehistoric Pet' THEN 'also re-buys any other enter-the-battlefield trigger in the deck' END
  FROM cards WHERE name IN ('Prehistoric Pet', 'Koya, Death from Above');

-- 9. The rebuild -------------------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Leonardo''s Technique via Sneak',
    'value',
    'Two creatures back from the graveyard for {1}{W}, at instant speed during combat.',
    'The best late-game card in the deck and the answer to a board wipe. Eighteen maindeck creatures cost 3 or less.',
    'Sneak drops it from {3}{W} to {1}{W} and, per the reminder text, lets a sorcery be cast during the declare blockers step. Return one or two creature cards of mana value 3 or less. Best targets are the ones with enter triggers: Koya, April O''Neil, Oroku Saki. NOT protected against graveyard hate - he owns none of the usual pieces, so an opponent''s Rest in Peace or Relic of Progenitus simply blanks this card and there is nothing in the 75 to answer it.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-sneak')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Leonardo''s Technique via Sneak'),
       oracle_id, 1,
       CASE name WHEN 'Koya, Death from Above' THEN 'best target: reanimating her exiles a creature again' END
  FROM cards WHERE name IN ('Leonardo''s Technique', 'Koya, Death from Above');

-- 10. The free rider ---------------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Sneak + Disappear',
    'value',
    'Every Sneak turn hands you a free 1/1 Ninja and a scry, for no extra cards and no extra mana.',
    'Pure upside that is easy to miss. Costs nothing to play around, so the only real risk is forgetting the sequencing.',
    'Returning your unblocked attacker to hand means a permanent left the battlefield under your control this turn, which is exactly the Disappear condition. SEQUENCING: Foot Mystic checks on ENTER, so cast him AFTER combat on a turn you sneaked - cast him precombat and you get nothing. Insectoid Exterminator checks at the beginning of your end step, so it needs no sequencing at all. Prehistoric Pet''s bounce turns both on without any Sneak card involved.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-sneak')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Sneak + Disappear'),
       oracle_id, 1,
       CASE name
         WHEN 'Foot Mystic' THEN 'cast POST-combat: the Disappear check is on enter'
         WHEN 'Insectoid Exterminator' THEN 'checks at your end step, so sequencing does not matter'
       END
  FROM cards WHERE name IN ('Foot Mystic', 'Insectoid Exterminator', 'Oroku Saki, Shredder Rising');

-- ---------------------------------------------------------------------------
-- Second pass over Foot Clan Sneak.
--
-- The first pass missed these because query.py's `available` hides two whole
-- classes of card:
--   * a card LISTED in an active deck is hidden even when a spare physical
--     copy sits free in a pool (this is how Lita was missed), and
--   * --colors filters on colour identity, which is a Commander concept. A
--     {1}{R/W} hybrid is castable off Plains alone but reads as RW, so every
--     hybrid playable in this deck was filtered out.
-- Everything below is free in ninja-booster. Nothing is borrowed from
-- Turtle Power!.
--
-- These combos depend on the six pending deck_proposals being accepted.
-- ---------------------------------------------------------------------------

-- 11. The engine that should have been found first ---------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Don & Leo, Problem Solvers + Anchovy & Banana Pizza',
    'value',
    'Destroy a creature at the beginning of every one of your end steps, for free, forever - and Don & Leo blinks a creature in the same trigger, so Foot Mystic hands you a 1/1 Ninja on the same turn.',
    'The strongest thing this card pool can do, and it costs no extra cards: both halves were already playable. Online turn 5.',
    'Don & Leo exiles up to one target artifact AND up to one target creature you control, then returns both - so you get two enter-the-battlefield triggers every end step, not one. Anchovy & Banana Pizza is a Food ARTIFACT whose enter trigger destroys a creature with no restriction. Best creature half is Foot Mystic: being exiled means a permanent left the battlefield this turn, so its own Disappear check is satisfied when it comes back and it makes a Ninja token every turn. Mechanized Ninja Cavalry (another Robot) and April O''Neil (scry 2) are the other good creature targets. Blinking at end step means everything is back and unsick by your next turn.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-sneak')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Don & Leo, Problem Solvers + Anchovy & Banana Pizza'),
       oracle_id, 1,
       CASE name
         WHEN 'Don & Leo, Problem Solvers' THEN 'castable {3}{W}{W} - the W/U hybrid only makes it read as blue'
         WHEN 'Foot Mystic' THEN 'best creature half: blinking it satisfies its own Disappear condition'
       END
  FROM cards WHERE name IN ('Don & Leo, Problem Solvers', 'Anchovy & Banana Pizza', 'Foot Mystic');

-- 12. Alliance stacking ------------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Lita, Little Orphan Amphibian + Mechanized Ninja Cavalry',
    'value',
    'One card, two creatures entering, two separate Alliance choices - a counter on Lita and a Food, or a counter and a scry.',
    'Cheap and repeatable. Lita is the engine; the Cavalry is simply the most efficient way to feed her twice off a single card.',
    'Lita''s Alliance fires whenever another creature you control enters and lets you choose a mode that has NOT been chosen this turn, so multiple creatures entering in one turn give genuinely different value - up to a counter, a Food and a scry. Casting Mechanized Ninja Cavalry does it twice by itself: the Cavalry enters, then its Robot token enters. Foot Mystic''s Ninja token, Lord Dregg''s Insect token and Leonardo''s Technique returning two creatures all feed her the same way. The Food she banks is fuel for Ice Cream Kitty.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-sneak')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Lita, Little Orphan Amphibian + Mechanized Ninja Cavalry'),
       oracle_id, 1,
       CASE name
         WHEN 'Lita, Little Orphan Amphibian' THEN 'free copy in ninja-booster; Turtle Power! keeps its own'
         WHEN 'Mechanized Ninja Cavalry' THEN 'castable {1}{W}; two Alliance triggers off one card'
       END
  FROM cards WHERE name IN ('Lita, Little Orphan Amphibian', 'Mechanized Ninja Cavalry');

-- 13. Turning the enabler into cards -----------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Featherbrained Filcher + Ice Cream Kitty',
    'value',
    'Every Sneak turn draws you an extra card: the Filcher leaves, makes a Food, and the Kitty eats the Food.',
    'Not flashy, but it fires on the turn you were already going to have, and it means the deck stops running out of cards.',
    'Returning the Filcher to hand to pay a Sneak cost triggers its own "when this creature leaves the battlefield, create a Food token". Ice Cream Kitty then sacrifices that token for {2} to draw. LIMIT: the Kitty''s ability is sorcery-speed only, so it is once per turn in practice - sequence it in your second main phase, after combat. It also eats Lita''s Food, Foot Mystic''s Ninja token, Mechanized Ninja Cavalry''s Robot and Lord Dregg''s Insect. The Kitty is a Food Cat MUTANT, so it also crews Turtle Van for doubled counters.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-sneak')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Featherbrained Filcher + Ice Cream Kitty'),
       oracle_id, 1,
       CASE name WHEN 'Ice Cream Kitty' THEN 'castable {1}{B}; sorcery-speed only, so play it postcombat' END
  FROM cards WHERE name IN ('Featherbrained Filcher', 'Ice Cream Kitty');

-- 14. Disappear, now worth building around -----------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Prehistoric Pet + Putrid Pals / Lord Dregg',
    'value',
    'One bounce in your main phase switches on every Disappear card at once: Putrid Pals lands as a 5/5 deathtouch and Lord Dregg makes a flying token.',
    'Turns Disappear from a bonus into something you can actually plan a turn around, without needing to attack at all.',
    'Prehistoric Pet''s {1}{W}, {T} bounce is sorcery-speed on your own turn, which is EARLIER than every end-step check - that is what makes it reliable where Sneak is not. Cast Putrid Pals after the bounce and it enters with two +1/+1 counters. TRAP, and it is a real one: Don & Leo does NOT enable Lord Dregg or Insectoid Exterminator. Both trigger "at the beginning of your end step" with an intervening-if, so the condition is checked when the trigger would go on the stack, and Don & Leo''s blink resolves in that same step - too late. Bounce or sneak earlier in the turn, or those two do nothing.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-sneak')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Prehistoric Pet + Putrid Pals / Lord Dregg'),
       oracle_id, 1,
       CASE name
         WHEN 'Prehistoric Pet' THEN 'the reliable enabler: sorcery speed, your turn, no combat needed'
         WHEN 'Lord Dregg, Insect Invader' THEN 'castable {3}{B}; only the dead {3}{G} ability makes it read as green'
       END
  FROM cards WHERE name IN ('Prehistoric Pet', 'Putrid Pals', 'Lord Dregg, Insect Invader');


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
