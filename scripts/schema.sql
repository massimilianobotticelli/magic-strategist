-- magic-strategist collection schema
--
-- Three concepts that the old flat files conflated are kept strictly separate:
--
--   cards      the abstract card      (keyed by Scryfall oracle_id)
--   printings  a specific printing    (keyed by Scryfall id)
--   copies     one physical card owned (FK to a printing, plus a location)
--
-- and, separately again:
--
--   deck_cards the *intended* 100-card list for a deck
--
-- copies is physical fact: one row per physical card, in exactly one location.
-- deck_cards is intent and is deliberately unconstrained, so a card listed in
-- more decks than there are physical copies imports cleanly and validate.py
-- can report it.
--
-- NOTE on the "one physical copy of every card" rule: the real collection does
-- not satisfy it and cannot be made to. Each Commander precon ships its own
-- Sol Ring, Arcane Signet and Command Tower, so there are genuinely three
-- distinct printings of each, one per deck. The rule that actually protects
-- against gutting a donor deck is therefore enforced structurally (a copy has
-- exactly one location, so it cannot be in two decks at once) and checked as
-- supply vs. demand in validate.py, rather than as a global UNIQUE index.

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);


-- ---------------------------------------------------------------------------
-- The abstract card
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cards (
    oracle_id        TEXT PRIMARY KEY,
    name             TEXT NOT NULL,
    mana_cost        TEXT,
    mana_value       REAL,
    type_line        TEXT,
    oracle_text      TEXT,
    power            TEXT,
    toughness        TEXT,
    loyalty          TEXT,
    colors           TEXT,                    -- WUBRG subset, '' = colorless
    color_identity   TEXT NOT NULL DEFAULT '',-- WUBRG subset, sorted
    keywords         TEXT,                    -- JSON array
    layout           TEXT,
    card_faces       TEXT,                    -- JSON array; NULL when single-faced
    is_game_changer  INTEGER NOT NULL DEFAULT 0,
    is_basic_land    INTEGER NOT NULL DEFAULT 0,
    is_token         INTEGER NOT NULL DEFAULT 0,
    is_legendary     INTEGER NOT NULL DEFAULT 0,
    can_be_commander INTEGER NOT NULL DEFAULT 0,
    scryfall_uri     TEXT,
    enriched_at      TEXT
);
CREATE INDEX IF NOT EXISTS ix_cards_name ON cards(name);


-- ---------------------------------------------------------------------------
-- A specific physical printing
-- ---------------------------------------------------------------------------
-- NOTE (deviation from the original spec, deliberate): foil lives on `copies`,
-- not here. Scryfall models `finishes` as what a printing is *available* in;
-- whether the card you own is actually foil is a property of that one card.
CREATE TABLE IF NOT EXISTS printings (
    scryfall_id      TEXT PRIMARY KEY,
    oracle_id        TEXT REFERENCES cards(oracle_id),
    name             TEXT NOT NULL,
    set_code         TEXT NOT NULL,
    set_name         TEXT,
    collector_number TEXT NOT NULL,
    rarity           TEXT,
    lang             TEXT NOT NULL DEFAULT 'en',
    finishes         TEXT,                    -- JSON array
    released_at      TEXT,
    image_uri        TEXT,                    -- 'normal' size
    image_small      TEXT                     -- thumbnail, for dense grids
);
CREATE INDEX IF NOT EXISTS ix_printings_setcn  ON printings(set_code, collector_number, lang);
CREATE INDEX IF NOT EXISTS ix_printings_oracle ON printings(oracle_id);


-- ---------------------------------------------------------------------------
-- Where cards live
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS locations (
    id   INTEGER PRIMARY KEY,
    slug TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('deck', 'pool'))
);

CREATE TABLE IF NOT EXISTS decks (
    id                  INTEGER PRIMARY KEY,
    location_id         INTEGER NOT NULL UNIQUE REFERENCES locations(id) ON DELETE CASCADE,
    slug                TEXT NOT NULL UNIQUE,
    name                TEXT NOT NULL,
    commander_oracle_id TEXT REFERENCES cards(oracle_id),
    partner_oracle_id   TEXT REFERENCES cards(oracle_id),
    color_identity      TEXT,
    target_bracket      INTEGER CHECK (target_bracket BETWEEN 1 AND 5),
    is_registered       INTEGER NOT NULL DEFAULT 0,
    -- active: kept assembled and held to exactly 100.
    -- donor:  cannibalised for parts. Its cards count as available inventory,
    --         its list is not held to 100, and it makes no claim on a card
    --         that an active deck also wants.
    -- retired: kept for the record only.
    status              TEXT NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'donor', 'retired')),
    notes               TEXT
);


-- ---------------------------------------------------------------------------
-- Raw ManaBox export rows, preserved verbatim. Nothing is ever dropped here;
-- this is the audit trail behind every `copies` row.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS manabox_rows (
    id                INTEGER PRIMARY KEY,
    source_file       TEXT NOT NULL,
    row_number        INTEGER NOT NULL,
    binder_name       TEXT,
    binder_type       TEXT,                   -- deck | binder | list
    name              TEXT,
    set_code          TEXT,
    collector_number  TEXT,
    scryfall_id       TEXT,
    foil              TEXT,
    rarity            TEXT,
    quantity          INTEGER NOT NULL DEFAULT 1,
    condition         TEXT,
    language          TEXT,
    purchase_price    REAL,
    purchase_currency TEXT,
    added_at          TEXT,
    UNIQUE (source_file, row_number)
);


-- ---------------------------------------------------------------------------
-- Physical inventory: one row = one card sleeve-in-hand
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS copies (
    id                INTEGER PRIMARY KEY,
    printing_id       TEXT NOT NULL REFERENCES printings(scryfall_id),
    oracle_id         TEXT NOT NULL REFERENCES cards(oracle_id),
    location_id       INTEGER NOT NULL REFERENCES locations(id),
    is_foil           INTEGER NOT NULL DEFAULT 0,
    is_basic_land     INTEGER NOT NULL DEFAULT 0,
    condition         TEXT,
    language          TEXT NOT NULL DEFAULT 'en',
    purchase_price    REAL,
    purchase_currency TEXT,
    acquired_at       TEXT,
    source_row_id     INTEGER REFERENCES manabox_rows(id)
);
CREATE INDEX IF NOT EXISTS ix_copies_location ON copies(location_id);
CREATE INDEX IF NOT EXISTS ix_copies_oracle   ON copies(oracle_id);

-- A copy has exactly one location_id, so one physical card can never be in two
-- decks at once. That is the structural half of the rule; the other half -
-- "this deck list wants more copies than exist" - is a validate.py check,
-- because it is a question about intent, not about physical storage.

-- Keeps the denormalised oracle_id honest: it must match the printing's card.
CREATE TRIGGER IF NOT EXISTS trg_copies_oracle_matches_printing
BEFORE INSERT ON copies
WHEN NEW.oracle_id IS NOT (SELECT oracle_id FROM printings WHERE scryfall_id = NEW.printing_id)
BEGIN
    SELECT RAISE(ABORT, 'copies.oracle_id does not match printings.oracle_id');
END;

-- Keeps the denormalised basic-land flag in sync if a card is re-enriched.
CREATE TRIGGER IF NOT EXISTS trg_cards_basic_land_resync
AFTER UPDATE OF is_basic_land ON cards
BEGIN
    UPDATE copies SET is_basic_land = NEW.is_basic_land WHERE oracle_id = NEW.oracle_id;
END;


-- ---------------------------------------------------------------------------
-- Rows that could not become a `copies` row at all (unknown printing, card not
-- enriched yet). Nothing is discarded silently: every rejection lands here with
-- its reason, and validate.py reports them.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS copy_conflicts (
    id                 INTEGER PRIMARY KEY,
    card_name          TEXT NOT NULL,
    oracle_id          TEXT,
    printing_id        TEXT,
    location_slug      TEXT,
    kept_location_slug TEXT,
    quantity           INTEGER,
    reason             TEXT NOT NULL,
    source_row_id      INTEGER REFERENCES manabox_rows(id)
);


-- ---------------------------------------------------------------------------
-- Intended decklists. Deliberately NOT constrained across decks: a card listed
-- in two decks must be importable so that validate.py can report it.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS deck_cards (
    id               INTEGER PRIMARY KEY,
    deck_id          INTEGER NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
    oracle_id        TEXT REFERENCES cards(oracle_id),
    card_name        TEXT NOT NULL,
    set_code         TEXT,
    collector_number TEXT,
    printing_id      TEXT REFERENCES printings(scryfall_id),
    quantity         INTEGER NOT NULL DEFAULT 1,
    section          TEXT NOT NULL DEFAULT 'main'
                     CHECK (section IN ('main', 'commander', 'sideboard')),
    is_foil          INTEGER NOT NULL DEFAULT 0,
    UNIQUE (deck_id, card_name, section)
);
CREATE INDEX IF NOT EXISTS ix_deck_cards_oracle ON deck_cards(oracle_id);


-- ---------------------------------------------------------------------------
-- Combos
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS combos (
    id          INTEGER PRIMARY KEY,
    name        TEXT NOT NULL,
    kind        TEXT NOT NULL CHECK (kind IN ('infinite', 'value')),
    payoff      TEXT,
    power_level TEXT,
    notes       TEXT,
    deck_id     INTEGER REFERENCES decks(id) ON DELETE SET NULL,
    UNIQUE (name, deck_id)
);

CREATE TABLE IF NOT EXISTS combo_pieces (
    combo_id  INTEGER NOT NULL REFERENCES combos(id) ON DELETE CASCADE,
    oracle_id TEXT    NOT NULL REFERENCES cards(oracle_id),
    owned     INTEGER NOT NULL DEFAULT 0,   -- 0 = still needs buying
    note      TEXT,
    PRIMARY KEY (combo_id, oracle_id)
);

-- Cards that SHUT THE COMBO OFF. The part the old notes kept losing.
CREATE TABLE IF NOT EXISTS combo_disablers (
    combo_id  INTEGER NOT NULL REFERENCES combos(id) ON DELETE CASCADE,
    oracle_id TEXT    NOT NULL REFERENCES cards(oracle_id),
    note      TEXT,
    PRIMARY KEY (combo_id, oracle_id)
);


-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS roles (
    id   INTEGER PRIMARY KEY,
    slug TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS card_roles (
    oracle_id TEXT    NOT NULL REFERENCES cards(oracle_id),
    role_id   INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    source    TEXT    NOT NULL DEFAULT 'auto' CHECK (source IN ('auto', 'manual')),
    PRIMARY KEY (oracle_id, role_id)
);

INSERT OR IGNORE INTO roles (slug, name) VALUES
    ('ramp',         'Ramp'),
    ('card-draw',    'Card Draw'),
    ('spot-removal', 'Spot Removal'),
    ('board-wipe',   'Board Wipe'),
    ('tutor',        'Tutor'),
    ('wincon',       'Win Condition'),
    ('protection',   'Protection'),
    ('recursion',    'Recursion'),
    ('fixing',       'Mana Fixing');


-- ---------------------------------------------------------------------------
-- Proposed deck changes.
--
-- This is the shared workspace between a session and the web app: a session
-- writes proposals here while discussing a deck, the app renders them as red
-- (cut) and green (add) and lets them be accepted or rejected, and the answer
-- comes back through the same table. Neither side edits decklist.txt until a
-- proposal is applied.
--
-- `pairs_with` links an add to the cut that pays for it, because the standing
-- rule is that every addition names a specific cut and the deck stays at 100.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS deck_proposals (
    id          INTEGER PRIMARY KEY,
    deck_id     INTEGER NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
    oracle_id   TEXT    NOT NULL REFERENCES cards(oracle_id),
    action      TEXT    NOT NULL CHECK (action IN ('add', 'cut')),
    status      TEXT    NOT NULL DEFAULT 'proposed'
                CHECK (status IN ('proposed', 'accepted', 'rejected', 'applied')),
    rationale   TEXT,
    source      TEXT    NOT NULL DEFAULT 'claude'
                CHECK (source IN ('claude', 'massimiliano')),
    pairs_with  INTEGER REFERENCES deck_proposals(id) ON DELETE SET NULL,
    created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at  TEXT    NOT NULL DEFAULT (datetime('now')),
    UNIQUE (deck_id, oracle_id, action)
);
CREATE INDEX IF NOT EXISTS ix_proposals_deck ON deck_proposals(deck_id, status);

CREATE TRIGGER IF NOT EXISTS trg_proposals_touch
AFTER UPDATE ON deck_proposals
BEGIN
    UPDATE deck_proposals SET updated_at = datetime('now') WHERE id = NEW.id;
END;


-- ---------------------------------------------------------------------------
-- Wishlist
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS wishlist (
    id                INTEGER PRIMARY KEY,
    card_name         TEXT NOT NULL,
    oracle_id         TEXT REFERENCES cards(oracle_id),
    price_ceiling_eur REAL,
    priority          INTEGER NOT NULL DEFAULT 3,
    deck_id           INTEGER REFERENCES decks(id) ON DELETE SET NULL,
    status            TEXT NOT NULL DEFAULT 'wanted'
                      CHECK (status IN ('wanted', 'ordered', 'acquired', 'dropped')),
    notes             TEXT,
    UNIQUE (card_name, deck_id)
);
