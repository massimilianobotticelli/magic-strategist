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
-- Everything below is free in ninja-booster or came out of the two dismantled
-- decks. Nothing is borrowed from Turtle Power! or Blight-Curse.
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
         WHEN 'Lita, Little Orphan Amphibian' THEN 'free copy in ninja-booster; Turtle Power! keeps its own'
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
