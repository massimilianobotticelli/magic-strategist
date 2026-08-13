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
-- turtle-power moved 2 -> 3 on 2026-08-10: he chose to build it toward Upgraded.
-- It still runs ZERO Game Changers and no infinite line, so it sits well inside
-- bracket 3 - the change is a statement of intent, not a legality problem.
UPDATE decks SET target_bracket = 3, is_registered = 1 WHERE slug = 'turtle-power';
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
-- Foot Clan Blitz: the Modern deck he actually plays. Promoted 2026-08-09.
--
-- It has NO ManaBox binder yet - it was built out of the pools rather than
-- bought as a product - so an import can derive nothing but its card list from
-- decks/foot-clan-blitz/decklist.txt. Everything below has to be stated here
-- or a `make rebuild` would recreate it as an unnamed Commander deck with the
-- default format.
--
-- Until he creates a `deck` binder named "Foot Clan Blitz" in ManaBox and
-- re-exports, its cards still read as sitting in the old binders. That is the
-- one outstanding physical step.
--
-- No target_bracket on purpose: brackets are a Commander concept and this is
-- Modern. validate.py is format-aware and will not ask for one.
-- ---------------------------------------------------------------------------
UPDATE decks
   SET name           = 'Foot Clan Blitz',
       format         = 'modern',
       status         = 'active',
       color_identity = 'BW',
       is_registered  = 1,
       notes          = 'Cheap bodies from turn 1 backed by eleven removal spells, nine of them at one or two mana. No land enters tapped, and the curve tops at 3 by EFFECTIVE cost: the only two cards printed above it are Grounded for Life, which costs {1}{W} against a tapped creature - cheap on defence, full price on offence. Sneak is a discount now, not the plan. The cost: only ten coloured sources for noncreature spells, which is why every noncreature card is a single pip.'
 WHERE slug = 'foot-clan-blitz';

UPDATE locations SET name = 'Foot Clan Blitz' WHERE slug = 'foot-clan-blitz';


-- ---------------------------------------------------------------------------
-- Foot Clan Sneak and SOS Draft: DELETED as decks on 2026-08-09. Their
-- binders become plain pools, so their cards are simply free inventory.
--
-- WHY THEY WENT. Foot Clan Sneak lost repeatedly to Steffen's deck and to
-- Florian's Final Fantasy starter for one measurable reason: 22 of its 37
-- spells cost 3 or more, average mana value 2.78, eleven cards at four mana or
-- more. Sneak only discounts a spell when you already have an unblocked
-- attacker, which against a faster deck never happens - so every Sneak cost
-- was paid at full price. SOS Draft was given up because it held the cheap W/B
-- removal the collection was otherwise hiding (Bitter Triumph, Last Gasp,
-- Repel Calamity, Burrog Banemaker, Imperious Inkmage, Elite Interceptor).
-- Both now feed Foot Clan Blitz.
--
-- NOTHING IS NEEDED HERE ANY MORE, and that is the point worth recording.
--
-- Both were real ManaBox binders typed `deck`, so while they existed in the
-- export every import recreated them as decks and this file had to delete them
-- again on every run. The 2026-08-09 export removed both binders and moved
-- their cards into Free Cards, so the export and the repo finally agree and
-- the override could go. Total card count is 576 in both the 2026-08-02 and
-- the 2026-08-09 snapshot: the cards moved, none were duplicated.
--
-- The other half of retiring a deck is the decklist, and it is easy to miss:
-- `make rebuild` imports decks/*/decklist.txt, so a leftover decklist.txt
-- rebuilds the deck from the file even after its binder is gone. Both were
-- renamed to decklist-dismantled-2026-08-09.txt, which keeps the list readable
-- while the importer ignores it - the same convention as
-- decks/dance-of-the-elements/decklist-dismantled.txt.
--
-- The 20 `applied` proposals recorded against Foot Clan Sneak died with it.
-- They documented changes to a deck that no longer exists; the reasoning that
-- mattered was carried into decks/foot-clan-blitz/upgrades.md first.
-- ---------------------------------------------------------------------------


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
DELETE FROM effective_costs;

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
-- Blight Curse, second pass: the lines that were already in the 100 and had
-- never been written down.
--
-- This block sits AFTER the CROSS JOIN above on purpose. Melira does not stop
-- a line that puts its counters on an opponent's creature, so these combos get
-- their disablers named one at a time instead of inheriting the pair.
--
-- Every card below was read out of the database, not recalled. Bracket 4
-- allows unlimited combos, so none of this is a legality question.
-- ---------------------------------------------------------------------------

-- 3. The second infinite: a sacrifice loop that never runs out of bodies -----
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Yawgmoth, Thran Physician + two token makers',
    'infinite',
    'Two creatures die per iteration, so Zulaport Cutthroat and Grave Venerations each drain 2 and Obelisk Spider drains 1 - lethal long before the draw runs out. Without a drain payoff it is still "draw your library for 1 life a card".',
    'The deck''s second real kill, and it shares no card with the Blowfly line except the token makers. Three permanents, so realistically turn 6-7.',
    'Sacrifice a 1/1 token to Yawgmoth and put the -1/-1 counter on ANOTHER 1/1 token: the target dies at 0/0, and both token makers each replace a body, so the count never drops. TRAP: with only ONE token maker this is NOT infinite - each pass is one body down and you are just grinding through an external target. Targets are chosen on activation, so you can never aim at the token you are about to make, and aiming at the creature you sacrifice makes the whole ability fizzle for no counter and no card. TRAP 2: with your own Everlasting Torment on the battlefield you cannot gain the life back, so the loop is capped at your life total. Auntie Ool draws on top of Yawgmoth''s own draw, so count the drain before starting.',
    (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Yawgmoth, Thran Physician + two token makers'),
       oracle_id, 1,
       CASE name
         WHEN 'Yawgmoth, Thran Physician' THEN 'the outlet; 1 life and a card per pass'
         WHEN 'Nest of Scarabs' THEN 'token maker - any TWO of these three'
         WHEN 'Hapatra, Vizier of Poisons' THEN 'token maker - any TWO of these three'
         WHEN 'Flourishing Defenses' THEN 'token maker - any TWO of these three'
         WHEN 'Zulaport Cutthroat' THEN 'payoff: 2 drain per pass, both deaths count'
         WHEN 'Obelisk Spider' THEN 'payoff: 1 drain per pass, and it pays the life back'
       END
  FROM cards WHERE name IN ('Yawgmoth, Thran Physician', 'Nest of Scarabs',
                            'Hapatra, Vizier of Poisons', 'Flourishing Defenses',
                            'Zulaport Cutthroat', 'Obelisk Spider');

-- 4. The mana combo already in the deck, turned into a kill ------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Devoted Druid + Quillspike + Obelisk Spider',
    'infinite',
    'Each opponent loses 1 life per untap and you gain 1. The two cards that already make infinite mana just win on the spot, with no Exsanguinate and no attack needed.',
    'A free upgrade on a line the deck already runs: the third piece is a 3-drop that is in the 100 anyway. Assembles a turn later than the mana version at worst.',
    'Every untap puts a -1/-1 counter on Devoted Druid, and that is a "you put one or more -1/-1 counters on a creature" event, so Obelisk Spider fires on each pass. Nest of Scarabs, Hapatra and Flourishing Defenses each make a token off the same event instead - infinite bodies, but summoning sick, so that version is a next-turn kill. TRAP: Auntie Ool''s draw is not optional and the Druid is yours, so with Ool on the battlefield the loop mills you at exactly the speed it drains them. Count their life totals BEFORE you start, and stop the loop yourself.',
    (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Devoted Druid + Quillspike + Obelisk Spider'),
       oracle_id, 1,
       CASE name
         WHEN 'Obelisk Spider' THEN 'the third piece; drains without needing combat'
         WHEN 'Auntie Ool, Cursewretch' THEN 'forced draw each pass - the reason this loop needs a stop condition'
       END
  FROM cards WHERE name IN ('Devoted Druid', 'Quillspike', 'Obelisk Spider',
                            'Auntie Ool, Cursewretch');

-- 5. The haymaker: wither turns a symmetric wipe one-sided -------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Everlasting Torment + Blasphemous Act',
    'value',
    '13 damage to each creature becomes 13 -1/-1 counters on each creature: Nest of Scarabs answers with thirteen Insects per creature, Auntie Ool draws a card for each creature you controlled, and Necroskitter takes back every creature of theirs that died.',
    'The biggest turn in the deck. Blasphemous Act usually costs {R} on a full board, so this is two cards and about four mana.',
    'Everlasting Torment makes ALL damage wither, so every damage effect stops killing and starts making counters - Fire Covenant is the cheap targeted version, Fury the free one, and Village Pillagers and Massacre Girl, Known Killer bring wither of their own. SEQUENCING: the counters all land at once and the token triggers resolve afterwards, so your Insects arrive after the damage and survive it. Your own board dies too - this is a reset from behind, not a value play. And remember the first line of Everlasting Torment: no player can gain life, so Obelisk Spider, Zulaport Cutthroat and Exsanguinate still drain but stop paying you back.',
    (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Everlasting Torment + Blasphemous Act'),
       oracle_id, 1,
       CASE name
         WHEN 'Fire Covenant' THEN 'cheaper, targeted version of the same trick'
         WHEN 'Necroskitter' THEN 'collects everything of theirs that died with counters'
         WHEN 'Nest of Scarabs' THEN 'turns the wipe into a board'
       END
  FROM cards WHERE name IN ('Everlasting Torment', 'Blasphemous Act', 'Fire Covenant',
                            'Necroskitter', 'Nest of Scarabs');

-- 6. The one-sided wipe ------------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Black Sun''s Zenith + Necroskitter',
    'value',
    'Every creature dies with -1/-1 counters on it, and each of theirs comes back on your side. Their board becomes your board.',
    'X=2 or X=3 is usually enough, so four or five mana empties the table and refills only your half.',
    'Necroskitter is a 1/4: keep X at 3 or less and it lives. It works even if it dies in the same wipe - a trigger that watches other creatures leave the battlefield still sees deaths simultaneous with its own, the same rule that makes Blood Artist work - but keeping it around means it keeps collecting. The Reaper, King No More does the same job capped at once each turn. Auntie Ool draws for each of your creatures and drains 1 per creature of theirs; Nest of Scarabs makes X Insects per creature, so the wipe rebuilds your side twice over. Soul Snuffers, Contagion Engine and Midnight Banshee are the repeatable versions of the same setup. Graveyard hate stops Necroskitter cold: it returns the card from the graveyard.',
    (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Black Sun''s Zenith + Necroskitter'),
       oracle_id, 1,
       CASE name
         WHEN 'The Reaper, King No More' THEN 'same effect, once each turn'
         WHEN 'Soul Snuffers' THEN 'cheaper mass counter, one per creature'
       END
  FROM cards WHERE name IN ('Black Sun''s Zenith', 'Necroskitter',
                            'The Reaper, King No More', 'Soul Snuffers');

-- 7. The lock ----------------------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Kulrath Knight + Midnight Banshee',
    'value',
    'Nothing your opponents control can attack or block. The Banshee puts a counter on each nonblack creature every upkeep, and the Knight turns each of those counters into a lock.',
    'A five- and a six-drop, so it is a late-game lock rather than a plan - but it is a real lock, not a tax, and it holds three opponents at once.',
    'Kulrath Knight reads "counters", not "-1/-1 counters": +1/+1 counters an opponent put there themselves lock the creature just as well. Contagion Engine is the on-demand version (enter puts a counter on each creature one player controls, then proliferate twice per turn), and Everlasting Torment locks anything your damage touches. Midnight Banshee only hits NONBLACK creatures, so it spares your black half - and theirs. The Knight only names creatures your opponents control, so your own counter-covered creatures attack freely.',
    (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Kulrath Knight + Midnight Banshee'),
       oracle_id, 1,
       CASE name
         WHEN 'Contagion Engine' THEN 'on-demand counter source, then proliferate twice a turn'
         WHEN 'Everlasting Torment' THEN 'every damage source becomes a lock enabler'
       END
  FROM cards WHERE name IN ('Kulrath Knight', 'Midnight Banshee',
                            'Contagion Engine', 'Everlasting Torment');

-- 8. The draw engine ---------------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Skullclamp + any token maker',
    'value',
    'Two cards for {1}, again and again: equip a 1/1 token, it becomes 2/0 and dies, you draw two.',
    'The cheapest engine in the deck and the reason the token makers are worth more than their bodies.',
    'Nest of Scarabs, Hapatra and Flourishing Defenses all make 1/1s, and Sinister Gnarlbark blights one of your creatures for free at every end step, so a token appears each turn without spending a card. TRAP: the token dies to +1/-1, NOT to a -1/-1 counter - Blowfly Infestation and Auntie Ool see nothing at all. Zulaport Cutthroat and Grave Venerations do drain, because they only care that a creature died.',
    (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Skullclamp + any token maker'),
       oracle_id, 1,
       CASE name
         WHEN 'Sinister Gnarlbark' THEN 'a free counter every end step, so a free token every turn'
       END
  FROM cards WHERE name IN ('Skullclamp', 'Nest of Scarabs', 'Hapatra, Vizier of Poisons',
                            'Flourishing Defenses', 'Sinister Gnarlbark');

-- 9. Removal that ramps ------------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Yawgmoth, Thran Physician + Necroskitter',
    'value',
    'Every X/1 an opponent controls dies to one activation and comes back under your control, and you draw a card for each one.',
    'As wide as your spare bodies. It turns a sacrifice outlet into repeatable removal that leaves you the creature.',
    'Pay 1 life, sacrifice a creature, put the counter on THEIR creature - note that Auntie Ool then drains that player for 1 instead of drawing you a card, because you do not control it. Massacre Girl, Known Killer gives your creatures wither, so combat damage becomes counters and Necroskitter collects their blockers too. The Reaper, King No More is the same effect capped at once each turn. Both stop dead against graveyard hate: they return the card from the graveyard, not the creature from the battlefield.',
    (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Yawgmoth, Thran Physician + Necroskitter'),
       oracle_id, 1,
       CASE name
         WHEN 'Massacre Girl, Known Killer' THEN 'wither on your whole team, so blockers die with counters'
         WHEN 'The Reaper, King No More' THEN 'same effect, once each turn'
       END
  FROM cards WHERE name IN ('Yawgmoth, Thran Physician', 'Necroskitter',
                            'Massacre Girl, Known Killer', 'The Reaper, King No More');

-- 10. The Goat, aimed at yourself on purpose ---------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Oft-Nabbed Goat + Skinrender / Channeler Initiate',
    'value',
    'Point six -1/-1 counters at your own 0/5 Goat: it dies, you draw six cards and every other player loses six life.',
    'A burn spell and a Painful Truths out of two cards that are in the deck for other reasons. Nothing about it needs an attack.',
    'The death trigger counts the counters that were ON it, so load the Goat in one turn instead of one counter at a time: Skinrender puts three on any creature, Channeler Initiate puts three on a creature YOU control, and Soul Snuffers, Black Sun''s Zenith and Carnifex Demon hit it along with everything else. Each of those events is also an Auntie Ool draw and an Obelisk Spider drain, and Nest of Scarabs turns the same counters into Insects. Read the trigger carefully: "its OWNER draws" means you draw even if an opponent paid {1} to steal it - letting them take it is fine, it comes with a free -1/-1 counter.',
    (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Oft-Nabbed Goat + Skinrender / Channeler Initiate'),
       oracle_id, 1,
       CASE name
         WHEN 'Skinrender' THEN 'three counters, any creature'
         WHEN 'Channeler Initiate' THEN 'three counters, must be a creature you control'
         WHEN 'Soul Snuffers' THEN 'one counter on everything, Goat included'
       END
  FROM cards WHERE name IN ('Oft-Nabbed Goat', 'Skinrender', 'Channeler Initiate',
                            'Soul Snuffers');

-- 11. What the proliferate effects are actually for --------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Carnifex Demon + proliferate',
    'value',
    'A board sweep you can fire once per proliferate: remove a counter from the Demon, put one on every other creature.',
    'Slow, but repeatable, and it is the only thing that makes the deck''s proliferate effects worth their slots.',
    'Carnifex enters with two -1/-1 counters and each activation spends one; proliferate puts them back. Contagion Clasp, Contagion Engine (twice), Evolution Sage on every land drop, Vraska''s 0 and Yawgmoth''s second ability all refill it. Proliferate lets you CHOOSE the permanents, so refill the Demon without adding a counter to Devoted Druid or anything else you need alive. The other direction matters too: it hits each OTHER creature, so it eats your own 1/1 tokens, and the Demon itself dies at six counters.',
    (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Carnifex Demon + proliferate'),
       oracle_id, 1,
       CASE name
         WHEN 'Evolution Sage' THEN 'free proliferate on every land drop'
         WHEN 'Contagion Engine' THEN 'proliferates twice per activation'
       END
  FROM cards WHERE name IN ('Carnifex Demon', 'Contagion Clasp', 'Contagion Engine',
                            'Evolution Sage');

-- 12. The late-game engine ---------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Ferrafor, Young Yew + Nest of Scarabs',
    'value',
    'Tap Ferrafor to double the -1/-1 counters on a creature: the added counters are counters being PUT ON, so Nest of Scarabs pays out again, Obelisk Spider drains and Auntie Ool draws or burns.',
    'Seven mana, so it is a late-game engine - but it is free every turn once it lands, and its enter trigger after a mass-counter turn is a board on its own.',
    'The enter trigger counts counters among creatures ONE target player controls, so cast Ferrafor after Black Sun''s Zenith or a wither wipe and point it at whoever has the most. The tap ability doubles each KIND of counter, so it doubles +1/+1 counters just as happily - only ever aim it at a -1/-1 pile. Doubling three counters adds three: three Insects, one drain, and usually a dead creature.',
    (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Ferrafor, Young Yew + Nest of Scarabs'),
       oracle_id, 1,
       CASE name
         WHEN 'Black Sun''s Zenith' THEN 'sets up the enter trigger: counters on their whole board'
       END
  FROM cards WHERE name IN ('Ferrafor, Young Yew', 'Nest of Scarabs', 'Black Sun''s Zenith');

-- Disablers for the second pass ----------------------------------------------
-- Solemnity is the universal answer: no counters, no deck.
INSERT INTO combo_disablers (combo_id, oracle_id, note)
SELECT c.id, k.oracle_id, 'counters cannot be put on permanents at all - the whole deck stops, this line included'
  FROM combos c CROSS JOIN cards k
 WHERE k.name = 'Solemnity'
   AND c.deck_id = (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final')
   AND c.name IN ('Yawgmoth, Thran Physician + two token makers',
                  'Devoted Druid + Quillspike + Obelisk Spider',
                  'Everlasting Torment + Blasphemous Act',
                  'Black Sun''s Zenith + Necroskitter',
                  'Kulrath Knight + Midnight Banshee',
                  'Skullclamp + any token maker',
                  'Yawgmoth, Thran Physician + Necroskitter',
                  'Oft-Nabbed Goat + Skinrender / Channeler Initiate',
                  'Carnifex Demon + proliferate',
                  'Ferrafor, Young Yew + Nest of Scarabs');

-- Melira only protects YOUR creatures, so she only reaches the lines whose
-- counters have to land on your own side. She does nothing against the ones
-- that point at an opponent's board.
INSERT INTO combo_disablers (combo_id, oracle_id, note)
SELECT c.id, k.oracle_id, 'your creatures cannot have -1/-1 counters put on them, and this line has to put them on your own side'
  FROM combos c CROSS JOIN cards k
 WHERE k.name = 'Melira, Sylvok Outcast'
   AND c.deck_id = (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final')
   AND c.name IN ('Yawgmoth, Thran Physician + two token makers',
                  'Devoted Druid + Quillspike + Obelisk Spider',
                  'Oft-Nabbed Goat + Skinrender / Channeler Initiate');

-- Pithing Needle answers whatever is an activated ability - equip included.
INSERT INTO combo_disablers (combo_id, oracle_id, note)
SELECT c.id, k.oracle_id,
       CASE c.name
         WHEN 'Skullclamp + any token maker' THEN 'naming Skullclamp shuts off equip, which is an activated ability'
         WHEN 'Carnifex Demon + proliferate' THEN 'naming Carnifex Demon shuts off the sweep; naming Contagion Engine shuts off the refill'
         WHEN 'Ferrafor, Young Yew + Nest of Scarabs' THEN 'naming Ferrafor shuts off the doubling'
         WHEN 'Devoted Druid + Quillspike + Obelisk Spider' THEN 'naming Devoted Druid shuts off the untap ability'
       END
  FROM combos c CROSS JOIN cards k
 WHERE k.name = 'Pithing Needle'
   AND c.deck_id = (SELECT id FROM decks WHERE slug = 'blight-curse-b4-final')
   AND c.name IN ('Skullclamp + any token maker',
                  'Carnifex Demon + proliferate',
                  'Ferrafor, Young Yew + Nest of Scarabs',
                  'Devoted Druid + Quillspike + Obelisk Spider');


-- ---------------------------------------------------------------------------
-- Foot Clan Blitz (Modern).
--
-- These are 'value' combos, not infinite ones: recognisable two-card patterns
-- that win games, recorded so they can be played from memory instead of
-- re-read off the cards every game. Modern has no brackets, so nothing here is
-- a legality question.
--
-- Every line was checked against the oracle text in the database.
--
-- REWRITTEN 2026-08-09 for the Foot Clan Sneak -> Foot Clan Blitz rebuild.
-- Four combos were deleted outright because their pieces were cut for costing
-- four or five mana: 'Leonardo''s Technique via Sneak', 'Don & Leo + Anchovy &
-- Banana Pizza', 'Featherbrained Filcher + Ice Cream Kitty' and 'Prehistoric
-- Pet + Putrid Pals / Lord Dregg'. The rest had their notes re-checked card by
-- card against the new 60 - that is the whole reason this table exists.
-- ---------------------------------------------------------------------------

-- 3. The exponential clock ---------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Turtle Van + Squirrelanoids',
    'value',
    'A one-mana deathtouch body that doubles in size every attack. 1 -> 2 -> 6 -> 14 -> 30 counters over four swings, and nothing profitably blocks a deathtouch creature that big.',
    'Strongest line in the deck and the least obvious. Online turn 3-4; the Van does the attacking, Squirrelanoids does the growing.',
    'Turtle Van puts one +1/+1 counter on the creature that crewed it, THEN doubles that creature''s total if it is a Mutant, Ninja or Turtle - Squirrelanoids is a Squirrel Mutant, so it qualifies. Crewing taps it, so it grows while sitting back as a blocker; swing with it on a turn you choose not to crew. BEST CREWER IS LITA, not Squirrelanoids: her Alliance banks counters on its own, and the Van doubles whatever total she has already built, so the two engines multiply instead of adding. Any Mutant/Ninja/Turtle crews it: Lita, Prehistoric Pet, Foot Elite, Koya, April O''Neil, both Oroku Saki, both Leonardos, Mechanized Ninja Cavalry, Insectoid Exterminator, Squirrelanoids. Crew 1 needs total POWER 1, so every creature in the deck now qualifies - the one that did not, Featherbrained Filcher at 0/2, was cut on 2026-08-09 partly for exactly this. If they kill the crewer in response to the attack trigger, the trigger simply fizzles.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-blitz')
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
    'Prehistoric Pet + Oroku Saki, Shredder Rising',
    'value',
    'A 3/1 that enters tapped and attacking for {1}{B} and draws a card every time it connects.',
    'The deck''s default turn from turn 3 onward, whenever an attacker gets through. Worth recognising, but no longer worth building a turn around.',
    'Attack, wait for blockers to be declared, then return the unblocked attacker to hand as part of casting Oroku Saki for his Sneak cost. Both remaining enablers dodge blockers by rule rather than by being unattractive: Prehistoric Pet cannot be blocked by creatures with GREATER POWER, and April O''Neil cannot be blocked by power 3 or greater. FEATHERBRAINED FILCHER WAS THE THIRD AND WAS CUT on 2026-08-09 - a 0/2 blanks the attack step, cannot crew Turtle Van, and only ever existed to feed a Sneak plan that no longer exists. The same unblocked attacker pays for Leonardo Big Brother ({W}) or Shredder''s Technique ({B}) instead - pick on the day. These three are the ONLY Sneak cards left in the maindeck and all three are fine at full price: Sneak is a discount you take when it appears, never a plan.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-blitz')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Prehistoric Pet + Oroku Saki, Shredder Rising'),
       oracle_id, 1,
       CASE name
         WHEN 'Prehistoric Pet' THEN 'primary enabler: cannot be blocked by greater power, and unlike the cut Filcher it has power to attack with'
         WHEN 'April O''Neil, Kunoichi Trainee' THEN 'interchangeable enabler: cannot be blocked by power 3 or greater'
       END
  FROM cards WHERE name IN ('Oroku Saki, Shredder Rising',
                            'Prehistoric Pet', 'April O''Neil, Kunoichi Trainee');

-- 5. Manufacturing an unblocked attacker -------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Hamato Guardian Stance + any Sneak card',
    'value',
    'One white mana turns any creature into an unblocked attacker - and after the rebuild it is just as often used as a plain combat trick to win a fight.',
    'The fix for the deck''s one real failure mode: you attack, they block everything, and no Sneak cost can be paid.',
    'Cast it in the declare attackers step, BEFORE blockers are declared - +1/+3 and flying. Waiting until blockers are on the table is too late. Reading Sneak''s reminder text, it also lets Shredder''s Technique - the one sorcery-speed Sneak card left after the rebuild - be cast during the declare blockers step, which is otherwise impossible. Because it targets a creature it also turns on Inkling Mascot. The +1/+3 half is worth remembering on its own: it wins a fight the opponent thought they had, and it is the deck''s only way to save a creature from damage-based removal.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-blitz')
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
    'Free value: twelve maindeck spells trigger it, so it is live most turns without building around it.',
    'Repartee triggers on any instant or sorcery you cast that targets a creature. Recounted 2026-08-10 after Grounded for Life came back: Path to Exile, Stab, Bitter Triumph, Last Gasp, Death in the Family, Repel Calamity, Hamato Guardian Stance, Shredder''s Technique, Crib Swap and BOTH Grounded for Life - eleven, plus Rejoinder off Elite Interceptor, which is a Sorcery targeting a creature, for twelve. Crib Swap counts because a Kindred Instant is still an instant. Cast one precombat, swing with a flying Mascot. CAREFUL: Banishing Light does NOT trigger it - it is an enchantment, and it exiles on an enter trigger rather than by the spell targeting anything.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-blitz')
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
    'A real finisher when it happens, but do not wait for it. Reassessed 2026-08-10: it needs FIVE mana AND an unblocked attacker AND double white off eleven white sources, so most games he is simply a turn-1 2/1. Cast him early when that is the better play.',
    'The anthem only fires if the sneak cost was paid - hard-casting him for {W} gets you a 2/1 and nothing else. COUNT BEFORE DECLARING: the unblocked attacker you return to hand leaves combat, so it deals no damage and does not get the +2/+0. Leonardo Big Brother is a different card name, so both Leonardos can be on the battlefield at once. His {1}{W} first-strike ability is the part that gets forgotten and it needs no Sneak at all - it also stacks with Quick-Draw Katana on a deathtoucher.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-blitz')
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
    'Prehistoric Pet''s {1}{W}, {T} returns another creature you control to hand during your turn; Koya''s enter trigger exiles a creature until the next end step unless you pay {3}{B} to keep it gone. Two things worth remembering: against a TOKEN the exile is permanent for free, because a token that leaves the battlefield ceases to exist and there is no card to return. And the same bounce turns on Disappear, so it doubles as the enabler for Insectoid Exterminator - the only Disappear card left after the rebuild.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-blitz')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Prehistoric Pet + Koya, Death from Above'),
       oracle_id, 1,
       CASE name WHEN 'Prehistoric Pet' THEN 'also re-buys any other enter-the-battlefield trigger in the deck' END
  FROM cards WHERE name IN ('Prehistoric Pet', 'Koya, Death from Above');

-- 9. The free rider ----------------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Sneak + Disappear',
    'value',
    'Every Sneak turn hands you a free scry, for no extra cards and no extra mana.',
    'Pure upside that is easy to miss, but much smaller than it was: the rebuild cut Foot Mystic, Lord Dregg and Putrid Pals for costing four, so Insectoid Exterminator is the last Disappear card in the deck.',
    'Returning your unblocked attacker to hand means a permanent left the battlefield under your control this turn, which is exactly the Disappear condition. Insectoid Exterminator checks at the beginning of your end step, so it needs no sequencing at all - which is the only reason it survived the cut while the others did not. Prehistoric Pet''s {1}{W}, {T} bounce turns it on with no Sneak card and no combat involved, which after the Filcher cut is the most reliable way to switch it on at all.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-blitz')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Sneak + Disappear'),
       oracle_id, 1,
       CASE name
         WHEN 'Insectoid Exterminator' THEN 'the last Disappear card in the deck; checks at your end step, so sequencing does not matter'
         WHEN 'Prehistoric Pet' THEN 'turns it on with no Sneak and no combat: sorcery-speed bounce on your own turn'
       END
  FROM cards WHERE name IN ('Insectoid Exterminator', 'Oroku Saki, Shredder Rising', 'Prehistoric Pet');

-- ---------------------------------------------------------------------------
-- Alliance and equipment: what carries the deck now that the top end is gone.
--
-- Everything below is free in the loose pool (it was `ninja-booster` when this
-- was written; all loose cards merged into `free-cards` on 2026-08-10) or came
-- out of the two dismantled decks. Nothing is borrowed from Turtle Power! or
-- Blight-Curse.
-- ---------------------------------------------------------------------------

-- 10. Alliance stacking ------------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Lita, Little Orphan Amphibian + Mechanized Ninja Cavalry',
    'value',
    'One card, two creatures entering, two separate Alliance choices - a counter on Lita and a Food, or a counter and a scry.',
    'Cheap and repeatable. Lita is the engine; the Cavalry is simply the most efficient way to feed her twice off a single card.',
    'Lita''s Alliance fires whenever another creature you control enters and lets you choose a mode that has NOT been chosen this turn, so multiple creatures entering in one turn give genuinely different value - up to a counter, a Food and a scry. Casting Mechanized Ninja Cavalry does it twice by itself: the Cavalry enters, then its Robot token enters. TRAP, corrected 2026-08-10: CRIB SWAP DOES NOT FEED HER. Its token is created under the OPPONENT''s control, and Alliance only sees another creature YOU control entering. The same goes for any token you hand an opponent. What does feed her is the deck''s own cheap creatures, plus Mechanized Ninja Cavalry''s Robot. After the rebuild the counters matter more than the other two modes, because Lita is a Turtle Van crewer and the Van DOUBLES whatever total she has already banked - so take the counter first unless the scry is genuinely urgent. The Foods are now just incidental life.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-blitz')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Lita, Little Orphan Amphibian + Mechanized Ninja Cavalry'),
       oracle_id, 1,
       CASE name
         WHEN 'Lita, Little Orphan Amphibian' THEN 'free copy in the loose pool; Turtle Power! keeps its own'
         WHEN 'Mechanized Ninja Cavalry' THEN 'castable {1}{W}; two Alliance triggers off one card'
       END
  FROM cards WHERE name IN ('Lita, Little Orphan Amphibian', 'Mechanized Ninja Cavalry');

-- 11. The clock the cut top end paid for -------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Quick-Draw Katana + any one-drop',
    'value',
    'A 1/1 deathtoucher becomes a 3/1 first striker that kills any blocker and walks away, and it keeps doing it every turn for free once attached.',
    'The replacement for the four- and five-drops that were cut, and the deck''s only mana sink. Slow to start - four mana across two turns - but it never stops mattering, because the Equipment survives the removal the creature does not.',
    'Four mana before it does anything - {2} to cast, {2} to equip - but only the FIRST time. It stays attached, so from then on the bonus is free every turn, and if they kill the creature the Katana survives and re-equips for {2}. That is the difference from an Aura: removal never two-for-ones you. FIRST STRIKE IS THE POINT, not the +2/+0: a 3/1 first striker beats every 2/2 and 3/3 blocker without dying. BEST CARRIERS ARE THE DEATHTOUCHERS - Squirrelanoids and Burrog Banemaker - because first strike plus deathtouch kills any blocker before it deals damage back. TRAP, and it is the opposite of what it looks like: DO NOT EQUIP PREHISTORIC PET. His evasion reads "can''t be blocked by creatures with GREATER power", measured against his OWN power, so a 1/2 Pet dodges everything with power 2 or more, while a 3/2 Pet only dodges power 4 or more. The Katana makes him easier to block, not harder. April O''Neil is safe: her threshold is the BLOCKER''s power (3 or greater), so pumping her changes nothing. The bonus is YOUR TURN ONLY, so it does nothing on defence.',
    (SELECT id FROM decks WHERE slug = 'foot-clan-blitz')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Quick-Draw Katana + any one-drop'),
       oracle_id, 1,
       CASE name
         WHEN 'Quick-Draw Katana' THEN 'your turn only: +2/+0 and first strike, equip {2}, free every turn after the first'
         WHEN 'Squirrelanoids' THEN 'best carrier: deathtouch plus first strike kills any blocker before it deals damage back'
         WHEN 'Burrog Banemaker' THEN 'the other deathtoucher, and {1}{B} pumps it further once the mana is spare'
         WHEN 'Prehistoric Pet' THEN 'ANTI-SYNERGY - do not equip him: his evasion is measured against his own power, so making him bigger makes him easier to block'
       END
  FROM cards WHERE name IN ('Quick-Draw Katana', 'Prehistoric Pet', 'Squirrelanoids', 'Burrog Banemaker');

INSERT INTO combo_disablers (combo_id, oracle_id, note)
SELECT (SELECT id FROM combos WHERE name = 'Quick-Draw Katana + any one-drop'),
       oracle_id, 'equip is an activated ability; naming Quick-Draw Katana means it can never be attached to anything'
  FROM cards WHERE name = 'Pithing Needle';


-- ---------------------------------------------------------------------------
-- Effective mana cost, where it differs from the printed one.
--
-- This table exists because of a real failure. Grounded for Life was cut from
-- Foot Clan Blitz for "costing 5" while the deck casts it for {1}{W}, and the
-- reason was mechanical rather than careless: the build sorted on
-- cards.mana_value, which is printed cost, while the rule about effective cost
-- lived only as prose in CLAUDE.md. When the tool and the rule disagree, the
-- tool wins silently. Anything written here is what the tool now says.
--
-- THE BAR IS "RELIABLY TURNS ON", and it is deliberately high.
--
-- Note which cards are NOT in this table. Every Sneak card in Foot Clan Blitz
-- is cheaper on paper - Leonardo Big Brother {2}{W} -> {W}, Oroku Saki {2}{B}
-- -> {1}{B}, Shredder's Technique {2}{B} -> {B} - and NONE of them is listed,
-- because Sneak needs an unblocked attacker in the declare blockers step and a
-- faster opponent simply never gives you one. That is the finding that killed
-- the deck's predecessor. Listing them would re-import the exact mistake this
-- table is here to prevent: a discount you cannot count on is not a discount.
--
-- Leonardo, Leader in Blue is the mirror case - his Sneak cost is HIGHER than
-- printed ({W} -> {3}{W}{W}) - and he is not listed either, for the same
-- reason. Effective cost means what you actually pay, in both directions.
-- ---------------------------------------------------------------------------
INSERT INTO effective_costs (oracle_id, deck_id, effective_mv, condition)
SELECT c.oracle_id, d.id, 2.0,
       'Costs {3} less if it targets a TAPPED creature, so {1}{W} against anything that has attacked. ONE-DIRECTIONAL: cheap on defence, full price on offence - clearing a fresh blocker on your own turn really does cost five. Counted as 2 because the decks this list is built to beat attack every turn.'
  FROM cards c, decks d
 WHERE c.name = 'Grounded for Life' AND d.slug = 'foot-clan-blitz';


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
-- The NOT LIKE guard is what makes this idempotent. `notes || '...'` appends on
-- every run, so without it a second `make seed` on a live database bolts the
-- same sentence on again, and a third time after that.
UPDATE wishlist
   SET status = 'dropped',
       notes = notes || ' — rejected in the B4 upgrade: over budget, replaced by Diabolic Intent'
 WHERE card_name IN ('Demonic Tutor', 'Vampiric Tutor')
   AND notes NOT LIKE '%rejected in the B4 upgrade%';


-- ---------------------------------------------------------------------------
-- Foot Clan Blitz wishlist. Added 2026-08-09 with buying authorised at the
-- usual ~EUR 10-15 per card ceiling.
--
-- No prices are quoted here because none were checked. The ceiling is the
-- budget, not an estimate.
--
-- Item 1 is not a nice-to-have. The deck meets Steffen's "no lands that enter
-- tapped" rule only by playing 20 basics plus two restricted lands, which
-- leaves TEN coloured sources for noncreature spells. Every noncreature card
-- in the maindeck is a single pip purely to survive that. Two or three real
-- duals are the only fix for that.
--
-- MEASURED 2026-08-09, correcting an earlier overstatement here. Conditioned on
-- having three lands on turn 3, the duals take "both colours available" from
-- 83% to 91% - which is what the eleven single-pip removal spells care about,
-- and it justifies the buy. They do NOT rescue the {W}{W} cards: a dual
-- replaces a Plains AND a Swamp, so four of them move white sources only from
-- 11 to 13, and EPF Point Squad on turn 3 goes 48% -> 57%. Duals fix colour
-- BALANCE, not colour DENSITY. Casting {W}{W} on curve would need more Plains,
-- which the black half cannot pay for.
--
-- Oracle text for all three lands was checked in the database, not recalled:
--   Caves of Koilos      always untapped; 1 damage when it makes W or B
--   Concealed Courtyard  untapped unless you control 3+ other lands
--   Isolated Chapel      untapped if you control a Plains or a Swamp
-- Concealed Courtyard is the best fit precisely because its condition covers
-- turns 1-3, which is the whole game this deck is trying to play.
--
-- Idempotent: ON CONFLICT (card_name, deck_id) rewrites rather than appends.
-- ---------------------------------------------------------------------------
INSERT INTO wishlist (card_name, oracle_id, deck_id, quantity, price_ceiling_eur, priority, notes)
SELECT w.card_name, c.oracle_id, d.id, w.qty, 15.0, w.prio, w.note
  FROM decks d
  JOIN (SELECT 'Caves of Koilos' AS card_name, 2 AS qty, 1 AS prio,
               'Untapped every single turn with no condition at all - the only unconditional W/B dual worth having at this budget. Fixes the ten-source problem that every other weakness in this deck traces back to.' AS note
        UNION ALL SELECT 'Concealed Courtyard', 2, 1,
               'Enters untapped while you control two or fewer other lands, which is exactly turns 1-3 - the only turns this deck cares about. Best fit of any dual in the price range.'
        UNION ALL SELECT 'Isolated Chapel', 1, 2,
               'Enters untapped if you control a Plains or a Swamp. With 20 basics in the deck that is every turn but the first, and it is usually the cheapest of the three.'
        UNION ALL SELECT 'Prehistoric Pet', 2, 2,
               'The best one-drop in the deck and currently a singleton: evasive (cannot be blocked by greater power), crews Turtle Van for doubled counters, and its bounce is the only Disappear enabler that needs no combat.'
        UNION ALL SELECT 'Path to Exile', 2, 2,
               'One-mana unconditional exile, and the single best removal spell in the 75. He owns exactly one.'
        UNION ALL SELECT 'Bitter Triumph', 2, 2,
               'Two-mana unconditional removal, freed up by dismantling the SOS Draft deck. The deck wants to draw this every game and can only draw one.') w
  LEFT JOIN cards c ON c.name = w.card_name
 WHERE d.slug = 'foot-clan-blitz'
    ON CONFLICT (card_name, deck_id) DO UPDATE SET
       quantity          = excluded.quantity,
       priority          = excluded.priority,
       price_ceiling_eur = excluded.price_ceiling_eur,
       notes             = excluded.notes;


-- ---------------------------------------------------------------------------
-- Turtle Power! (Commander, bracket 3).
--
-- REWRITTEN 2026-08-10 for the commander change. The deck ran Heroes in a Half
-- Shell solo; it now runs the partner pair Leonardo, the Balance +
-- Michelangelo, the Heart, and Heroes is an ordinary card in the 98.
--
-- That is not a cosmetic edit. THE ENGINE CHANGED SHAPE:
--
--   before  counters were a reward for CONNECTING. Heroes triggered on combat
--           damage, so only creatures that got through were paid, and the
--           first attack of the game was always the weak one.
--   after   counters are a reward for MAKING A TOKEN. Leonardo pays every
--           creature you control, once each turn, with no combat required -
--           and Michelangelo, the Heart makes the token himself every turn
--           you attack, so the pair needs no third card.
--
-- Every line below was re-checked against oracle text after the change, and
-- every number re-derived. All are 'value' lines: no infinite loop in the deck.
-- ---------------------------------------------------------------------------

-- 1. The commander pair itself -----------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Leonardo, the Balance + Michelangelo, the Heart',
    'value',
    'A +1/+1 counter on EVERY creature you control, every turn, from the command zone alone. Nothing has to connect and nothing has to be drawn.',
    'The deck''s engine and both halves are always available. Michelangelo lands turn 2 in 53% of games, Leonardo turn 4 in 51% - against 34% at turn FIVE for the old Heroes commander.',
    'Michelangelo, the Heart: "Raid — at the beginning of your second main phase, IF YOU ATTACKED THIS TURN, put a +1/+1 counter on target creature and create a Food token." That Food is a token, and Leonardo reads "whenever a token you control enters, you may put a +1/+1 counter on EACH creature you control." So attacking with anything at all - a single 1/1 is enough, it does not need to connect - turns the whole board on. SEQUENCING: it fires in your SECOND main phase, so the counters land AFTER combat. They are ammunition for next turn''s attack, not this one, and every "if it has a counter" effect in the deck comes online one turn later than it feels like it should. LEONARDO IS CAPPED AT ONCE EACH TURN, which is why the deck does not need more token makers - Ninja Pizza already makes a Food every second main phase for free, and Michelangelo, Mutant BFF makes a Mutagen on enter and on every attack. Extra token generation does not stack.',
    (SELECT id FROM decks WHERE slug = 'turtle-power')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Leonardo, the Balance + Michelangelo, the Heart'),
       oracle_id, 1,
       CASE name
         WHEN 'Ninja Pizza' THEN 'backup token every second main phase, free, no attack needed'
       END
  FROM cards WHERE name IN ('Leonardo, the Balance', 'Michelangelo, the Heart', 'Ninja Pizza');

-- 2. The ordering that is worth one counter per creature, every turn ----------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Corpsejack Menace + High Score',
    'value',
    'Every counter Leonardo hands out becomes four - and Leonardo hands one to every creature at once.',
    'Both cheap and both already in the deck. Not a combo you assemble, a rule you have to remember at the table.',
    'Both are replacement effects modifying the same event, so YOU choose which applies first - and the two orders are NOT equal. High Score first: one counter becomes two, then Corpsejack Menace doubles it to FOUR. Corpsejack first: one becomes two, then High Score adds one, THREE. ALWAYS APPLY HIGH SCORE FIRST. (n+1)x2 beats 2n+1 by exactly one counter, every time. THIS GOT BIGGER WITH THE COMMANDER CHANGE: Heroes only paid the creatures that connected, but Leonardo pays EVERY creature you control, so the extra counter is multiplied by your whole board. Five creatures out means 20 counters a turn instead of 15.',
    (SELECT id FROM decks WHERE slug = 'turtle-power')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Corpsejack Menace + High Score'),
       oracle_id, 1,
       CASE name WHEN 'Leonardo, the Balance' THEN 'the event both effects are modifying, every turn' END
  FROM cards WHERE name IN ('Corpsejack Menace', 'High Score', 'Leonardo, the Balance');

-- 3. Damage without combat ---------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Casey Jones, Back Alley Brute + Leonardo, the Balance',
    'value',
    'Leonardo''s counters become direct damage. The deck can kill without a single attack connecting.',
    'Four mana for the payoff and the enabler is in the command zone. Stronger than it was under Heroes, because Leonardo needs no combat damage to fire.',
    'Casey reads "whenever you put one or more +1/+1 counters on A CREATURE you control" - singular. Leonardo''s trigger is ONE event that puts a counter on EACH creature, and that makes one Casey trigger PER CREATURE, not one in total. WORKED CASE, five creatures on board: Leonardo fires, five creatures get one counter each, Casey deals 1+1+1+1+1 = 5 to a chosen opponent. With Corpsejack Menace the counters are 2 each, so 10. With High Score applied first as well, 4 each, so 20. NONE OF THAT NEEDS AN ATTACK TO CONNECT - only a token to enter, which Michelangelo, the Heart supplies for the price of declaring any attacker. Leatherhead, Iron Gator''s attack trigger (two counters on each creature) stacks a second helping on the same turn. WHICH SIDE OF THE COMPARISON: for Raphael, the Muscle to double Casey''s damage the counter has to be on CASEY - he is a creature dealing damage, and Leonardo does put a counter on him, so from the second Leonardo trigger onward Raphael is doubling this.',
    (SELECT id FROM decks WHERE slug = 'turtle-power')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Casey Jones, Back Alley Brute + Leonardo, the Balance'),
       oracle_id, 1,
       CASE name
         WHEN 'Leatherhead, Iron Gator' THEN 'two counters on each creature on attack - a second Casey volley the same turn'
         WHEN 'Raphael, the Muscle' THEN 'doubles Casey''s damage once Casey himself carries a counter'
       END
  FROM cards WHERE name IN ('Casey Jones, Back Alley Brute', 'Leonardo, the Balance',
                            'Leatherhead, Iron Gator', 'Raphael, the Muscle');

-- 4. The card draw that replaced the commander's --------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Ray Fillet, Wave Warrior + Leonardo, the Balance',
    'value',
    'A card for every creature that connects, from the very first attack.',
    'Three mana, and it does not have to attack to pay out. THIS IS THE DECK''S MAIN DRAW ENGINE now that Heroes is not in the command zone - it is what makes losing that commander survivable.',
    'Ray Fillet: "whenever a creature you control WITH A COUNTER ON IT deals combat damage to a player, draw a card" - one draw per creature. THE COMMANDER CHANGE IMPROVED THIS. Under Heroes the counters arrived as a reward for connecting, so the first attack of the game drew nothing from Ray Fillet and only later swings paid. Leonardo puts counters on every creature at the end of the turn you first attack, so from the SECOND attack onward every single attacker is already carrying one: four attackers is four cards, and it scales with the board rather than with what got through. Ray Fillet is a 0/2 with flying and evolve - he does not need to be in combat for any of this, so leave him home as a blocker.',
    (SELECT id FROM decks WHERE slug = 'turtle-power')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Ray Fillet, Wave Warrior + Leonardo, the Balance'),
       oracle_id, 1, NULL
  FROM cards WHERE name IN ('Ray Fillet, Wave Warrior', 'Leonardo, the Balance');

-- 5. Doubling the whole board ------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Raphael, the Muscle + Leonardo, the Balance',
    'value',
    'Every creature you control hits for double - combat damage and noncombat damage alike.',
    'Five mana for the effect. Better under the partner pair than it was under Heroes, because Leonardo puts a counter on EVERY creature rather than only the ones that connected.',
    'Raphael doubles ALL damage that creatures you control WITH COUNTERS ON THEM would deal, which includes Casey Jones'' triggered damage, not just combat. Under Heroes this was partial - a creature that had never connected had no counter and was not doubled. Under Leonardo one trigger arms the entire board at once, so Raphael doubles everything from that point on. THE TRAP IS STILL THE TIMING, AND IT MOVED: Michelangelo''s Raid trigger resolves in your SECOND MAIN PHASE, after combat. So on the turn Leonardo first fires, the attack that caused it was NOT doubled - the doubling starts the following turn. To double the very first swing, put a counter on precombat instead: Together Forever''s support 2, Arcade Cabinet''s enter trigger, Level Up, or a Mutagen token. Raphael himself is in the same position - he makes a token when he enters but nothing puts a counter on HIM, so his own 4/4 body stays undoubled until Leonardo gets there.',
    (SELECT id FROM decks WHERE slug = 'turtle-power')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Raphael, the Muscle + Leonardo, the Balance'),
       oracle_id, 1,
       CASE name
         WHEN 'Together Forever' THEN 'support 2 precombat: the cheapest way to be doubled on the FIRST swing'
         WHEN 'Arcade Cabinet' THEN 'enter trigger puts a counter on up to four creatures at once'
       END
  FROM cards WHERE name IN ('Raphael, the Muscle', 'Leonardo, the Balance',
                            'Together Forever', 'Arcade Cabinet');

-- 6. The wipe that only hits them --------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Wave Goodbye + Leonardo, the Balance',
    'value',
    'A one-sided Evacuation: your board has counters on it, theirs does not.',
    'Four mana, and the enabling condition is now guaranteed rather than combat-gated. The cleanest way this deck breaks a board stall.',
    'Wave Goodbye returns each creature WITHOUT a +1/+1 counter on it to its owner''s hand. THE COMMANDER CHANGE MADE THIS RELIABLE: under Heroes only the creatures that had connected were safe, so a blocked board bounced along with the opponents''. Under Leonardo every creature you control is carrying a counter as a matter of course, whether it attacked, blocked or sat still. SEQUENCING: Leonardo''s counters land in your second main phase, so cast Wave Goodbye AFTER that trigger has resolved, not before. It still does not spare fresh arrivals - anything you cast after the trigger has no counter and bounces with the rest, so hold the extra creature until the Wave has resolved. Tokens returned to hand cease to exist, which is pure upside against a token board.',
    (SELECT id FROM decks WHERE slug = 'turtle-power')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Wave Goodbye + Leonardo, the Balance'),
       oracle_id, 1, NULL
  FROM cards WHERE name IN ('Wave Goodbye', 'Leonardo, the Balance');

-- 7. The one-sided wipe ------------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Vigor + Blasphemous Act',
    'value',
    'A one-sided board wipe that also pumps your team: every creature you control except Vigor gains thirteen +1/+1 counters, and every opposing creature with toughness 13 or less dies.',
    'Both halves already in the deck. Blasphemous Act costs {1} less per creature on the battlefield, so on the wide board that makes this good it usually costs {R} - a five-mana turn, not a nine-mana one.',
    'Vigor prevents damage dealt to each OTHER creature you control and converts it one-for-one into +1/+1 counters. WORKED CASE, board of Vigor plus Casey Jones plus two others: the three non-Vigor creatures take 0 damage and gain 13 counters each; Vigor itself is a 6/6 and is NOT protected by its own ability, so it takes the 13, dies, and shuffles back into your library instead of staying in the graveyard - one use per copy per game. SEQUENCING: Vigor has to already be on the battlefield when the Act resolves. WITH CASEY JONES THIS IS USUALLY LETHAL, NOT JUST A WIPE - each creature gaining counters is its own "you put counters on a creature" event, so Casey triggers three times for 13 damage each, 39 at a single opponent. Corpsejack Menace turns the 13 into 26; with High Score as well, apply High Score first and it is (13+1)x2 = 28 per creature.',
    (SELECT id FROM decks WHERE slug = 'turtle-power')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Vigor + Blasphemous Act'),
       oracle_id, 1,
       CASE name
         WHEN 'Casey Jones, Back Alley Brute' THEN 'turns the wipe into a kill: one trigger per creature that gained counters'
         WHEN 'Corpsejack Menace' THEN 'doubles every one of the counters the prevention hands out'
       END
  FROM cards WHERE name IN ('Vigor', 'Blasphemous Act', 'Casey Jones, Back Alley Brute',
                            'Corpsejack Menace');

-- 8. The repeatable doubler and its fuel supply ------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Arcade Cabinet + Donatello, the Brains',
    'value',
    'A counter doubler you can fire every turn, with a token guaranteed every turn to pay for it.',
    'Three mana and three mana, both already in the deck. Slow but it never runs dry.',
    'Arcade Cabinet costs {2}, {T} and the sacrifice of a token; Donatello turns EVERY token creation under your control into that token plus an extra one, so the sacrifice fuel is free. Doubling is implemented as putting that many MORE counters on, which means Corpsejack Menace doubles the doubling: a creature on 4 counters goes to 8 with Arcade Cabinet alone, and to 12 with Corpsejack out, because the "4 more" becomes "8 more". It doubles EACH KIND of counter, not only +1/+1. WHOSE PERMANENT: Donatello''s replacement only sees tokens created UNDER YOUR CONTROL - a token you hand an opponent gives you nothing. WORTH NOTING SINCE THE COMMANDER CHANGE: Donatello''s extra token is also an extra chance to turn Leonardo on, but Leonardo is capped at once each turn, so treat that as insurance rather than as a second trigger.',
    (SELECT id FROM decks WHERE slug = 'turtle-power')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Arcade Cabinet + Donatello, the Brains'),
       oracle_id, 1,
       CASE name WHEN 'Corpsejack Menace' THEN 'doubles the doubling - 4 counters become 12, not 8' END
  FROM cards WHERE name IN ('Arcade Cabinet', 'Donatello, the Brains', 'Corpsejack Menace');

-- 9. The unblockable lock ----------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Michelangelo, Mutant BFF + any menace source',
    'value',
    'A creature with a counter and menace has NO legal block. It connects every turn.',
    'Four mana, and Leonardo puts the counter on every creature for free. It grants evasion, not a win, so it is comfortably inside bracket 3.',
    'Michelangelo: "each creature you control with a counter on it CAN''T BE BLOCKED BY MORE THAN ONE creature." Menace: "can''t be blocked EXCEPT BY TWO OR MORE creatures." A creature under both restrictions cannot be blocked at all - there is no legal number of blockers. THE COMMANDER CHANGE CUT BOTH WAYS. The counter half got EASIER: Leonardo arms every creature every turn, where Heroes only armed the ones that had already connected. The menace half got HARDER: Heroes had menace printed on it and sat in the command zone, and it is now an ordinary card in the 98 that has to be drawn. The menace left in the deck is Splinter, the Mentor, Casey Jones, Back Alley Brute and Rat King, Pale Piper - three specific creatures - plus Leonardo''s own {W}{U}{B}{R}{G} activation, which grants it to the WHOLE team at once but costs five colours and is realistically a turn-six play. So the reliable version is: point Michelangelo at whichever of those three is on board. Michelangelo also makes a Mutagen token when he enters AND whenever he attacks, which is a Leonardo trigger in its own right.',
    (SELECT id FROM decks WHERE slug = 'turtle-power')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Michelangelo, Mutant BFF + any menace source'),
       oracle_id, 1,
       CASE name
         WHEN 'Splinter, the Mentor' THEN 'cheapest menace body in the deck at {1}{B}'
         WHEN 'Leonardo, the Balance' THEN 'team-wide menace for {W}{U}{B}{R}{G} - the alpha-strike version, but a turn-six cost'
       END
  FROM cards WHERE name IN ('Michelangelo, Mutant BFF', 'Splinter, the Mentor',
                            'Leonardo, the Balance');

-- 10. The card advantage that replaced the commander's -----------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Return of the Wildspeaker + Leonardo, the Balance',
    'value',
    'Refills your hand for five mana at instant speed, and the size of the refill grows on its own every turn Leonardo fires.',
    'Replaced Don & Leo on 2026-08-10 as the direct answer to losing Heroes from the command zone. Five mana, instant, no setup beyond the board you already wanted.',
    'Return of the Wildspeaker: "draw cards equal to the GREATEST POWER among non-Human creatures you control", or the other mode, "+3/+3 to non-Human creatures until end of turn". Leonardo puts a +1/+1 counter on every creature you control once each turn, so the greatest power on your board climbs without you spending anything on it - the card gets better the longer the game runs, which is exactly the shape of card advantage this deck wanted back. NON-HUMAN IS THE CHECK, AND IT MOSTLY PASSES: Mutants, Ninjas, Turtles, Rats and Oozes all count. The Humans in the deck are Casey Jones, Shredder, Shadow Master, April O''Neil and Irma - do not measure off them, and remember the +3/+3 mode misses them too. SEQUENCING: it is an INSTANT, so hold it. Cast it after Leonardo''s second-main-phase trigger has resolved rather than before, and cast it in response to a board wipe to turn a dying board into cards.',
    (SELECT id FROM decks WHERE slug = 'turtle-power')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Return of the Wildspeaker + Leonardo, the Balance'),
       oracle_id, 1,
       CASE name WHEN 'Leonardo, the Balance' THEN 'grows the greatest-power number every turn for free' END
  FROM cards WHERE name IN ('Return of the Wildspeaker', 'Leonardo, the Balance');

-- 11. Trample: which source, and why BOTH is nearly pointless ----------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Garruk''s Uprising + Michelangelo, Mutant BFF',
    'value',
    'Unconditional trample on the whole team, so the unblockable creatures that DO get chump-blocked still dump their damage on the player.',
    'Three mana. Replaced Hard-Won Jitte on 2026-08-10 - the Jitte was in the deck to fire the old commander''s trigger twice, and that reason left with Heroes.',
    'Garruk''s Uprising grants trample to CREATURES YOU CONTROL, full stop - no counter required, so it works on the turn before Leonardo''s counters arrive. GNARLID COLONY IS REDUNDANCY, NOT REDUNDANT, AND THE DIFFERENCE WAS MEASURED. Its text is a strict subset - "each creature you control with a +1/+1 counter on it has trample" - so with both on the battlefield the second one is a 2/2 for {1}{G}. That case is worth 1.9% of games by turn eight. The case where Gnarlid is your ONLY team-wide trample is worth 24.7%. These are the deck''s only two permanent team-wide trample sources in 98 cards: with both you hold one by turn eight in 27% of games, with Garruk''s alone in 14%. Cutting Gnarlid halves an already-thin number for an effect the plan depends on, because Michelangelo, Mutant BFF only makes creatures unblockable alongside one of three menace creatures - everything else gets chump-blocked, and trample is what turns a 9/9 into damage. KEEP BOTH. Kicked for {2}{G} more, Gnarlid also enters with two +1/+1 counters, which arms Michelangelo''s unblockability on itself immediately and is doubled by Corpsejack Menace. The draw half of Garruk''s: a card on the way in, and a card whenever a creature with power 4 or greater enters - 10 such creatures out of 31, so a cantrip that sometimes keeps going, not a draw engine.',
    (SELECT id FROM decks WHERE slug = 'turtle-power')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Garruk''s Uprising + Michelangelo, Mutant BFF'),
       oracle_id, 1,
       CASE name WHEN 'Gnarlid Colony' THEN 'REDUNDANT with Garruk''s Uprising - its trample clause is a strict subset' END
  FROM cards WHERE name IN ('Garruk''s Uprising', 'Michelangelo, Mutant BFF', 'Gnarlid Colony');

-- Disablers for Turtle Power! ------------------------------------------------
-- Solemnity is the universal answer to this deck, and MORE so since the
-- commander change: the whole engine is now "put a counter on each creature".
INSERT INTO combo_disablers (combo_id, oracle_id, note)
SELECT c.id, k.oracle_id,
       CASE c.name
         WHEN 'Leonardo, the Balance + Michelangelo, the Heart' THEN 'the tokens still enter, but no counter is ever put on - the deck''s entire engine is switched off from the command zone down'
         WHEN 'Vigor + Blasphemous Act' THEN 'the damage is still prevented, but no counters are put on - you get a symmetric wipe and no board'
         WHEN 'Wave Goodbye + Leonardo, the Balance' THEN 'nothing on your side can have a counter, so Wave Goodbye returns YOUR creatures as well - it stops being one-sided and becomes a mistake'
         WHEN 'Michelangelo, Mutant BFF + any menace source' THEN 'no counters means nothing qualifies for the "can''t be blocked by more than one" clause, so only the bare menace remains'
         WHEN 'Garruk''s Uprising + Michelangelo, Mutant BFF' THEN 'trample still applies - Garruk''s Uprising does not care about counters - but nothing qualifies for Michelangelo''s unblockability, so they are merely trampling into two blockers'
         ELSE 'counters cannot be put on permanents at all, so the line produces nothing'
       END
  FROM combos c CROSS JOIN cards k
 WHERE k.name = 'Solemnity'
   AND c.deck_id = (SELECT id FROM decks WHERE slug = 'turtle-power');

-- Pithing Needle answers activated abilities only, so it reaches exactly one
-- of these lines. The rest are triggered or static and cannot be named.
INSERT INTO combo_disablers (combo_id, oracle_id, note)
SELECT (SELECT id FROM combos WHERE name = 'Arcade Cabinet + Donatello, the Brains'),
       oracle_id,
       'naming Arcade Cabinet shuts off the doubling, which is an activated ability. Donatello''s half is a replacement effect and cannot be named.'
  FROM cards WHERE name = 'Pithing Needle';
-- ---------------------------------------------------------------------------
-- Turtle Power! wishlist. RE-DERIVED 2026-08-10 after the commander change.
--
-- No prices are quoted: none were checked. The ceiling is the budget.
--
-- THE ORIGINAL LIST IS LARGELY OBSOLETE AND THIS IS THE HONEST REASON WHY.
-- It was built to answer one measurement: Heroes in a Half Shell cost
-- {W}{U}{B}{R}{G} and was castable on turn five in 34% of games, so every item
-- was a cheap accelerant. Swapping to the Leonardo + Michelangelo partner pair
-- fixed that problem by making the commanders cost {3}{W} and {1}{G} instead,
-- and re-measuring says buying mana is no longer the best use of the budget:
--
--                        Michelangelo T2   Michelangelo T3   Leonardo T4
--   as it stands              58.2%             89.1%           44.1%
--   + Birds of Paradise       59.3%             90.0%           47.6%
--   + Nature's Lore too       59.3%             90.6%           50.7%
--
-- Birds moves the two-drop by ONE POINT. A one-mana dork cannot help you cast a
-- two-drop you were already casting. It is still worth having for Leonardo
-- (+3.5pp on turn four), but it is no longer the headline fix, and saying so is
-- the point of re-deriving this instead of leaving the old priorities standing.
--
-- What the deck wants now is not more mana, it is MORE OUT OF LEONARDO. He puts
-- a +1/+1 counter on EVERY creature you control, once each turn - so a counter
-- doubler is no longer multiplying the one creature that connected, it is
-- multiplying the whole board. That is why Branching Evolution moves from the
-- bottom of this list to the top.
--
-- Oracle text checked in the database, not recalled.
-- Idempotent: ON CONFLICT (card_name, deck_id) rewrites rather than appends.
-- ---------------------------------------------------------------------------
INSERT INTO wishlist (card_name, oracle_id, deck_id, quantity, price_ceiling_eur, priority, notes)
SELECT w.card_name, c.oracle_id, d.id, w.qty, 15.0, w.prio, w.note
  FROM decks d
  JOIN (SELECT 'Branching Evolution' AS card_name, 1 AS qty, 1 AS prio,
               'PROMOTED from P3 on the commander change, and it is now the best card money can add to this deck. A second Corpsejack Menace, and under Leonardo the doubling applies to EVERY creature you control every turn rather than only the ones that connected. With both doublers plus High Score applied first, one Leonardo trigger becomes (1+1)x2x2 = 8 counters on each creature - and each of those is a separate Casey Jones trigger.' AS note
        UNION ALL SELECT 'Birds of Paradise', 1, 2,
               'DEMOTED from P1. Measured against the new commanders it is worth +1.1pp on casting Michelangelo at turn two and +3.5pp on Leonardo at turn four - real, but a fraction of what it was worth when the commander cost {W}{U}{B}{R}{G}. A one-mana any-colour dork cannot help you cast a two-drop you were already casting. Buy it for Leonardo and for Leonardo''s {W}{U}{B}{R}{G} activation, not as a fix.'
        UNION ALL SELECT 'Nature''s Lore', 1, 2,
               'Two-mana ramp that arrives UNTAPPED, which is the one mana problem the commander change did not solve: the deck still plays nine lands that enter tapped unconditionally. It searches for a Forest CARD, not a basic, so Cinder Glade, Sodden Verdure and Vernal Fen are all legal targets. Worth +3.1pp on Leonardo at turn four on top of Birds.'
        UNION ALL SELECT 'Swiftfoot Boots', 1, 3,
               'DEMOTED from P2. The old reason was that Heroes cost five colours and could not realistically be recast once it died. Two commanders is its own redundancy - if one dies you still have the other - and Leonardo recasts at {5}{W} rather than {W}{U}{B}{R}{G} plus tax. Still hexproof and not Lightning Greaves, deliberately: shroud would stop you targeting your own creature with Level Up, Saved by the Shell, Together Forever or a Mutagen token.'
        UNION ALL SELECT 'Fellwar Stone', 1, 3,
               'DEMOTED from P2. Both commanders now cost a single coloured pip, so five-colour fixing only matters for Leonardo''s {W}{U}{B}{R}{G} activation and for Everything Pizza. He owns one copy and it is in Blight Curse, so this would be a second copy rather than a steal - but it is no longer urgent.') w
  LEFT JOIN cards c ON c.name = w.card_name
 WHERE d.slug = 'turtle-power'
    ON CONFLICT (card_name, deck_id) DO UPDATE SET
       quantity          = excluded.quantity,
       priority          = excluded.priority,
       price_ceiling_eur = excluded.price_ceiling_eur,
       notes             = excluded.notes;



-- ---------------------------------------------------------------------------
-- Turtle Power! runs a PARTNER PAIR from 2026-08-10: Leonardo, the Balance and
-- Michelangelo, the Heart, both "Partner—Character select". Heroes in a Half
-- Shell dropped into the 98.
--
-- THIS BLOCK IS NOT OPTIONAL. `decks` models ONE commander, and db.py picks it
-- with `LIMIT 1` and no ORDER BY over the commander section - so an import is
-- free to pick Michelangelo, whose colour identity is mono-GREEN. That would
-- collapse the deck's identity from BGRUW to G and fail every card in it.
--
-- Leonardo is the right one to pin, and not by luck: his activated ability
-- costs {W}{U}{B}{R}{G}, so HIS identity is already BGRUW - which is exactly
-- the union of the pair. Pinning him gives the correct answer for the whole
-- partnership rather than an approximation.
--
-- If the pair ever changes to two partners that do NOT include Leonardo, this
-- block is wrong and the identity has to be widened by hand: the schema has no
-- way to express two commanders.
-- ---------------------------------------------------------------------------
UPDATE decks
   SET commander_oracle_id = (SELECT oracle_id FROM cards WHERE name = 'Leonardo, the Balance')
 WHERE slug = 'turtle-power';

UPDATE decks
   SET color_identity = (SELECT color_identity FROM cards WHERE oracle_id = decks.commander_oracle_id)
 WHERE commander_oracle_id IS NOT NULL;


-- ---------------------------------------------------------------------------
-- Roil Elementals: the Temur Commander deck. Promoted 2026-08-13.
--
-- Like Foot Clan Blitz it has NO ManaBox binder - it was assembled out of
-- `free-cards`, not bought as a product - so an import derives only its card
-- list from decks/roil-elementals/decklist.txt. Name, format, status and
-- bracket have to be stated here or a rebuild recreates it as an unnamed
-- Commander deck at the default status.
--
-- Until he creates a `deck` binder named "Roil Elementals" in ManaBox and
-- re-exports, all 100 cards still read as sitting in Free Cards - which means
-- they keep showing up as available inventory for any other deck. That is the
-- one outstanding physical step; `make moves ARGS='roil-elementals'` prints it.
--
-- The commander IS derivable: decklist.txt carries a `// COMMANDER` marker and
-- names exactly one card. It is pinned anyway, because db.py picks the
-- commander with LIMIT 1 and no ORDER BY, and colour identity for the whole
-- deck hangs off that one row.
-- ---------------------------------------------------------------------------
UPDATE decks
   SET name           = 'Roil Elementals',
       format         = 'commander',
       status         = 'active',
       target_bracket = 4,
       is_registered  = 1,
       notes          = 'Temur Elementals on landfall. Every land that enters is a trigger: Omnath grows an Elemental and, past eight lands, draws; Risen Reef turns every Elemental that enters back into a land drop. 21 Elemental cards in the 99 plus the commander. Built entirely from free-cards, 44 of them the Temur half of the dismantled Dance of the Elements precon. Coloured sources G16/U13/R13, rising to G19/U16/R16 for an Elemental spell because Primal Beyond, Unclaimed Territory and Abundant Countryside are conditional any-colour lands. Known gap: one board wipe and it is symmetric.'
 WHERE slug = 'roil-elementals';

UPDATE locations SET name = 'Roil Elementals' WHERE slug = 'roil-elementals';

UPDATE decks
   SET commander_oracle_id = (SELECT oracle_id FROM cards
                               WHERE name = 'Omnath, Locus of the Roil')
 WHERE slug = 'roil-elementals';

UPDATE decks
   SET color_identity = (SELECT color_identity FROM cards
                          WHERE oracle_id = decks.commander_oracle_id)
 WHERE slug = 'roil-elementals';


-- ---------------------------------------------------------------------------
-- Roil Elementals combos.
--
-- None of them is infinite, and `kind` says so. That is the point: this deck
-- wins by accumulating, and writing "infinite" next to the Risen Reef chain
-- would misdescribe it at the table. The chain length is SIMULATED, not
-- estimated - see the note on the first one.
--
-- No combo_disablers rows. What shuts every one of these off is ordinary
-- removal on Risen Reef or on Soulstoke, and there is no specific hate card in
-- the collection worth naming; the notes say so in prose instead of adding a
-- card to the Makefile's EXTRA_CARDS just to point at it.
-- ---------------------------------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Risen Reef + Omnath, Locus of Rage',
    'value',
    'One land drop becomes a chain of 5/5 Elementals.',
    'Strong, and it is NOT infinite.',
    'Both on the battlefield. Play a land: Omnath''s landfall creates a 5/5 red and green Elemental token UNDER YOUR CONTROL, so Risen Reef''s "another Elemental you control enters" sees it and triggers. Reef looks at the top card; if it is a land you put it onto the battlefield tapped, which is a second landfall, which is a second 5/5, which is a third Reef trigger. NOT INFINITE: every iteration spends the top card of your library, so the chain stops at the first non-land, which goes to your hand instead. SIMULATED from a realistic mid-game library (28 lands / 51 spells left, 8 lands on the battlefield): the top card is a land 35% of the time, one land drop yields 1.5 tokens on average, and it reaches three or more tokens only 12% of the time. It is an engine, not a win on the spot. SEQUENCING: play the land in your PRECOMBAT main phase - the tokens have no haste unless Maelstrom Wanderer is out, but the extra lands are what turn on Omnath, Locus of the Roil''s draw. SHUT OFF BY: removal on Risen Reef, of which there is no second copy.',
    (SELECT id FROM decks WHERE slug = 'roil-elementals')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Risen Reef + Omnath, Locus of Rage'),
       oracle_id, 1,
       CASE name
         WHEN 'Risen Reef' THEN 'the only copy; the whole chain routes through it'
         WHEN 'Omnath, Locus of Rage' THEN 'also drains 3 per Elemental that dies, which makes a board wipe a reach spell'
       END
  FROM cards WHERE name IN ('Risen Reef', 'Omnath, Locus of Rage');


INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Risen Reef + Omnath, Locus of the Roil',
    'value',
    'Every Elemental you cast becomes a land drop, a +1/+1 counter and a card.',
    'The deck''s main engine.',
    'The reason the deck exists. With both out and SEVEN lands on the battlefield, cast Mulldrifter: it is an Elemental, so Reef triggers, reveals a land and puts it onto the battlefield tapped. That is your EIGHTH land, and Omnath''s landfall checks the count as it RESOLVES - the land that caused the trigger is already there - so you put a +1/+1 counter on an Elemental AND draw. Mulldrifter''s own ETB then draws two more. OMNATH''S ETB COUNTS ITSELF: "damage equal to the number of Elementals you control" resolves with Omnath already on the battlefield, so it is never zero. With Risen Reef, Smokebraider and two 5/5 tokens out, recasting him from the command zone deals 5, not 4. SHUT OFF BY: removal on Risen Reef. Without Reef, Omnath draws only on natural land drops - one a turn, and only past eight lands.',
    (SELECT id FROM decks WHERE slug = 'roil-elementals')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Risen Reef + Omnath, Locus of the Roil'),
       oracle_id, 1,
       CASE name
         WHEN 'Risen Reef' THEN 'the only copy'
         WHEN 'Omnath, Locus of the Roil' THEN 'the commander, so it always comes back - but each recast costs 2 more'
       END
  FROM cards WHERE name IN ('Risen Reef', 'Omnath, Locus of the Roil');


INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Incandescent Soulstoke cheats an ETB into play',
    'value',
    'A seven-mana Elemental''s ETB for {1}{R}, at instant speed.',
    'The deck''s best mana-efficiency line, and the one with a real sequencing trap.',
    'Soulstoke''s ability has NO timing restriction, so it works at instant speed and during combat. You keep whatever the ETB left behind; only the creature itself is sacrificed at the beginning of the next end step. AVENGER OF ZENDIKAR for {1}{R} instead of {5}{G}{G}: with eight lands its ETB makes eight 0/1 Plants, and the PLANTS STAY after Avenger is sacrificed. It is also an Elemental, so Risen Reef triggers on it too. JUBILATION - SEQUENCING TRAP, this is the one that gets misplayed: its +2/+2 and trample last only until end of turn, so it must enter BEFORE combat damage. The right line is to activate Soulstoke AFTER blockers are declared, when blocks were already committed against the small bodies; every attacker is then +2/+2 with trample. Putting it in after combat does nothing at all. Soulstoke also gives other Elementals +1/+1, so the 5/5 tokens attack as 6/6. SHUT OFF BY: nothing exotic - but Soulstoke taps to activate, so it must have been on the battlefield since your last turn.',
    (SELECT id FROM decks WHERE slug = 'roil-elementals')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Incandescent Soulstoke cheats an ETB into play'),
       oracle_id, 1,
       CASE name
         WHEN 'Incandescent Soulstoke' THEN 'the enabler; instant speed, taps to activate'
         WHEN 'Avenger of Zendikar' THEN 'best target: the Plants outlive the sacrifice'
         WHEN 'Jubilation' THEN 'put it in AFTER blockers, never after damage'
       END
  FROM cards WHERE name IN ('Incandescent Soulstoke', 'Avenger of Zendikar', 'Jubilation');


-- ---------------------------------------------------------------------------
-- Roil Elementals, second pass: the patterns that do NOT start from Risen Reef.
--
-- Added 2026-08-13 after the first three turned out to cover only the Reef
-- engine. Every one below was read off the card in the database, not recalled,
-- and the numbers are worked in the note rather than asserted.
--
-- One of them is an ANTI-synergy (Selvala). It is recorded as a combo on
-- purpose: the trap is that the deck looks like it should draw cards off her
-- and does not, and that is exactly the kind of thing these notes exist to
-- stop being re-derived wrongly at the table.
-- ---------------------------------------------------------------------------
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Risen Reef + Tatyova, Benthic Druid',
    'value',
    'Two cards off a single Elemental, plus life.',
    'The draw half of the engine. Tatyova is the redundancy Omnath does not have.',
    'Same chain as the Omnath pairings, different payoff. Reef puts a land onto the battlefield; Tatyova''s landfall gains 1 life and draws a card. WORKED, with Reef + Tatyova + Omnath, Locus of the Roil out and EIGHT lands: cast one Elemental, Reef reveals a land and puts it in, Tatyova draws 1 and gains 1, Omnath puts a +1/+1 counter on an Elemental and draws 1 - two cards from one creature, before that creature''s own ETB does anything. NOTE WHAT SHE IS NOT: Tatyova is a Merfolk Druid, NOT an Elemental. She does not trigger Risen Reef herself, Incandescent Soulstoke does not pump her, and Primal Beyond''s mana cannot cast her. She is a payoff, never a piece of the Elemental count.',
    (SELECT id FROM decks WHERE slug = 'roil-elementals')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Risen Reef + Tatyova, Benthic Druid'),
       oracle_id, 1,
       CASE name
         WHEN 'Risen Reef' THEN 'the only copy'
         WHEN 'Tatyova, Benthic Druid' THEN 'Merfolk Druid - NOT an Elemental, see the note'
       END
  FROM cards WHERE name IN ('Risen Reef', 'Tatyova, Benthic Druid');


INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Omnath, Locus of Rage + Chain Reaction',
    'value',
    'The symmetric sweeper becomes 15 damage aimed anywhere.',
    'The answer to the deck''s stated weakness: it is the only reach in the list.',
    'Chain Reaction deals X to EACH creature where X is the number of creatures on the battlefield - both sides, which is why it normally hits this deck hardest. With Omnath, Locus of Rage out it stops being a bad card. WORKED: you control Omnath (5/5) and four 5/5 tokens, an opponent has five creatures. Ten creatures on the battlefield, so X = 10 and everything with toughness 10 or less dies, including all five of yours. Omnath''s second ability reads "whenever Omnath OR another Elemental you control dies" - it counts ITSELF, and a leaves-the-battlefield trigger uses last-known information, so you get FIVE triggers, not four: 5 x 3 = 15 damage split however you like. SECOND OUTCOME, equally fine: if X comes out below 5 your tokens survive, the small creatures across the table do not, and you simply keep the board. SEQUENCING: cast it in your PRECOMBAT main phase - the 15 damage can go at a player, and if the board does survive you still have your attack.',
    (SELECT id FROM decks WHERE slug = 'roil-elementals')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Omnath, Locus of Rage + Chain Reaction'),
       oracle_id, 1,
       CASE name
         WHEN 'Omnath, Locus of Rage' THEN 'its death trigger includes its own death'
         WHEN 'Chain Reaction' THEN 'the deck''s only sweeper; bad alone, reach with Omnath'
       END
  FROM cards WHERE name IN ('Omnath, Locus of Rage', 'Chain Reaction');


INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Cream of the Crop + Realmwalker',
    'value',
    'Set the top of your library, then cast it for free off the top.',
    'A two-card engine for four mana. Both halves are cheap and both are Elementals in practice.',
    'Realmwalker: as it enters, CHOOSE ELEMENTAL - the choice is locked in, and naming Shapeshifter instead is the mistake to avoid. It then lets you cast Elemental creature spells from the top of your library. Cream of the Crop: whenever a creature you control enters, look at the top X where X is THAT CREATURE''S POWER, and put one of them on top. WORKED: a 5/5 Locus of Rage token enters, Cream digs 5 deep, you put an Elemental on top, Realmwalker casts it, and that Elemental entering triggers Cream again - and Risen Reef, if it is out. TRAP: X is the ENTERING creature''s power, not the biggest thing you control. A 1/1 Springleaf changeling looks at exactly ONE card. The 5/5 tokens are what make Cream dig; the small bodies barely filter. Realmwalker is a changeling, so it is itself an Elemental: it triggers Risen Reef and Soulstoke pumps it.',
    (SELECT id FROM decks WHERE slug = 'roil-elementals')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Cream of the Crop + Realmwalker'),
       oracle_id, 1,
       CASE name
         WHEN 'Realmwalker' THEN 'name Elemental as it enters, never Shapeshifter'
         WHEN 'Cream of the Crop' THEN 'digs as deep as the entering creature''s power'
         WHEN 'Cavalier of Thorns' THEN 'its death trigger also puts a card on top, which Realmwalker can then cast'
       END
  FROM cards WHERE name IN ('Realmwalker', 'Cream of the Crop', 'Cavalier of Thorns');


INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Springleaf Parade + Omnath, Locus of Rage',
    'value',
    'Every 5/5 token also taps for one mana of any colour.',
    'The real fix for the deck''s colour problem, and it is already in the list.',
    'Springleaf Parade grants "{T}: Add one mana of any color" to CREATURE TOKENS YOU CONTROL - all of them, not only the changelings it made. WORKED: with the Parade out, four 5/5 Locus of Rage tokens are also four mana of any colour, which is what makes Cavalier of Thorns {2}{G}{G}{G} and Titan of Industry {4}{G}{G}{G} castable - the two cards the manabase simulation flagged at 24.5% and 12.8%. TRAP: the tokens have a {T} ability, so they are summoning sick. A token created this turn produces NO mana this turn unless Maelstrom Wanderer is on the battlefield. The X changelings the Parade itself makes are every creature type, so they are Elementals: X tokens entering is X Risen Reef triggers and X Cream of the Crop triggers - though at power 1 Cream only looks at one card each.',
    (SELECT id FROM decks WHERE slug = 'roil-elementals')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Springleaf Parade + Omnath, Locus of Rage'),
       oracle_id, 1,
       CASE name
         WHEN 'Springleaf Parade' THEN 'grants the mana ability to ALL your creature tokens'
         WHEN 'Omnath, Locus of Rage' THEN 'the token engine it turns into a mana engine'
       END
  FROM cards WHERE name IN ('Springleaf Parade', 'Omnath, Locus of Rage');


INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Maelstrom Wanderer + Omnath, Locus of Rage',
    'value',
    'Two free spells, and the 5/5 tokens attack the turn they are made.',
    'The top end. Eight mana, but it does not ask the board for anything first.',
    'Cascade twice off an eight-mana spell exiles until a NONLAND card costing less than 8. COUNTED against this list: of the 61 nonland cards, only Ghalta (mana value 12) and Maelstrom Wanderer itself are out of range, so 59 of 61 are live hits - both cascades connect essentially every time. The haste matters more than it looks: "creatures you control have haste" applies to TOKENS too, so a land played after Wanderer resolves makes a 5/5 that attacks immediately, and Springleaf Parade''s mana tokens produce mana the turn they arrive instead of waiting a full turn.',
    (SELECT id FROM decks WHERE slug = 'roil-elementals')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Maelstrom Wanderer + Omnath, Locus of Rage'),
       oracle_id, 1,
       CASE name
         WHEN 'Maelstrom Wanderer' THEN '59 of 61 nonlands are legal cascade hits'
         WHEN 'Omnath, Locus of Rage' THEN 'its tokens get the haste'
       END
  FROM cards WHERE name IN ('Maelstrom Wanderer', 'Omnath, Locus of Rage');


-- The anti-synergy. Recorded because the deck LOOKS like it should draw here.
INSERT INTO combos (name, kind, payoff, power_level, notes, deck_id)
VALUES (
    'Selvala, Heart of the Wilds + Ghalta — and the draw that does NOT work',
    'value',
    'Ghalta for {G}{G}, and huge mana. But Selvala''s draw trigger is a trap in THIS deck.',
    'The mana half is real. The draw half is an anti-synergy and is written down so it stops being re-derived.',
    'THE MANA HALF WORKS. "{G}, {T}: Add X mana in any combination of colors, where X is the greatest power among creatures YOU control" - one 5/5 token out means {G} becomes five mana. And Ghalta costs {X} less where X is the TOTAL power of creatures you control; the reduction only eats the generic {10}, so at 10 total power - two 5/5 tokens is exactly enough - Ghalta costs {G}{G}. THE DRAW HALF DOES NOT. "Whenever another creature enters, ITS CONTROLLER may draw a card if its power is GREATER THAN EACH OTHER creature''s power." Two separate problems. (1) It says its controller: an opponent''s creature entering draws for THEM, so Selvala is symmetric and helps the table. (2) The entering creature is measured against EVERY OTHER creature on the battlefield, so once you control one 5/5 token the NEXT 5/5 token draws nothing - 5 is not greater than 5. Omnath, Locus of Rage makes identical tokens, so Selvala''s draw switches itself off after the first one. Keep her for the mana. Do not build around the draw.',
    (SELECT id FROM decks WHERE slug = 'roil-elementals')
);

INSERT INTO combo_pieces (combo_id, oracle_id, owned, note)
SELECT (SELECT id FROM combos WHERE name = 'Selvala, Heart of the Wilds + Ghalta — and the draw that does NOT work'),
       oracle_id, 1,
       CASE name
         WHEN 'Selvala, Heart of the Wilds' THEN 'take the mana ability; the draw is symmetric AND self-cancelling'
         WHEN 'Ghalta, Primal Hunger' THEN '{G}{G} once you control 10 total power'
       END
  FROM cards WHERE name IN ('Selvala, Heart of the Wilds', 'Ghalta, Primal Hunger');
