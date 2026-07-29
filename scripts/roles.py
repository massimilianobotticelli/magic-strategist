"""Tag cards with deck-building roles, derived from oracle text.

These are heuristics over real Scryfall oracle text, not judgements about how a
card plays. Everything written here is marked source='auto', so hand-made
tags (source='manual') are never overwritten and always win.

A card can hold several roles - Shriekmaw is spot removal and a creature you
recur; Cultivate is both ramp and fixing - so this is deliberately many-to-many.
"""

from __future__ import annotations

import re
import sqlite3

# Each role maps to patterns matched case-insensitively against oracle text.
# `exclude` patterns veto a match, which is how "each opponent draws a card"
# avoids being tagged as card draw for you.
RULES: dict[str, dict[str, list[str]]] = {
    # Lands are NOT ramp. A land is your normal land drop; tagging every dual
    # land as ramp inflated Blight Curse's count from 6 to 27 and made the role
    # breakdown useless. Only non-lands that produce extra mana, and land
    # fetching from non-lands, count here. `land_excluded` is enforced against
    # the type line in roles_for().
    "ramp": {
        "include": [
            r"search your library for .{0,40}\bland\b.{0,80}onto the battlefield",
            r"\{t\}: add \{",
            r"\{t\}: add one mana",
            r"\{t\}: add two mana",
            r"you may play an additional land",
        ],
        "exclude": [],
        "land_excluded": True,
    },
    "card-draw": {
        "include": [
            r"\bdraw (a|two|three|x|that many) cards?\b",
            r"\bdraws? (a|two|three|x) cards?\b",
            r"\bdraw cards equal\b",
        ],
        "exclude": [
            r"each opponent draws",
            r"target opponent draws",
        ],
    },
    "spot-removal": {
        "include": [
            r"destroy target (creature|permanent|artifact|enchantment|planeswalker|land|nonland)",
            r"exile target (creature|permanent|artifact|enchantment|planeswalker)",
            r"target creature gets [-−]",
            r"target creature an opponent controls",
            r"deals? \d+ damage to target (creature|planeswalker)",
            r"put .{0,30}-1/-1 counters? on target creature",
        ],
        "exclude": [],
    },
    "board-wipe": {
        "include": [
            r"destroy all (creatures|permanents|artifacts|enchantments|lands)",
            r"exile all (creatures|permanents)",
            r"all creatures get [-−]",
            r"each creature gets [-−]",
            r"each player sacrifices",
            r"put .{0,30}-1/-1 counters? on each creature",
            r"deals? \d+ damage to each creature",
        ],
        "exclude": [],
    },
    "tutor": {
        "include": [
            r"search your library for a card",
            r"search your library for an? (creature|artifact|enchantment|instant|sorcery|planeswalker)",
        ],
        "exclude": [r"search your library for .{0,40}\bland\b"],
    },
    "protection": {
        "include": [
            r"\bhexproof\b",
            r"\bindestructible\b",
            r"protection from",
            r"\bward\b",
            r"counter target spell",
            r"\bshroud\b",
            r"regenerate",
        ],
        "exclude": [],
    },
    "recursion": {
        "include": [
            r"return .{0,60}from your graveyard to (your hand|the battlefield)",
            r"return .{0,40}card from your graveyard",
            r"put .{0,40}from your graveyard onto the battlefield",
            r"\bescape\b",
            r"\bflashback\b",
            r"\bunearth\b",
        ],
        "exclude": [],
    },
    "fixing": {
        "include": [
            r"add one mana of any color",
            r"add \{[wubrg]\}, \{[wubrg]\}",
            r"mana of any (color|type)",
            r"lands? you control .{0,40}any color",
        ],
        "exclude": [],
    },
    "wincon": {
        "include": [
            r"you win the game",
            r"loses? the game",
            r"can't lose the game",
        ],
        "exclude": [],
    },
}

COMPILED = {
    role: {
        key: [re.compile(p, re.IGNORECASE | re.DOTALL) for p in patterns]
        for key, patterns in spec.items()
        if key in ("include", "exclude")
    }
    for role, spec in RULES.items()
}
LAND_EXCLUDED = {role for role, spec in RULES.items() if spec.get("land_excluded")}


def roles_for(oracle_text: str | None, type_line: str | None) -> set[str]:
    """Which roles a card's text supports."""
    text = oracle_text or ""
    types = type_line or ""
    if not text:
        return set()

    is_land = "Land" in types

    found: set[str] = set()
    for role, spec in COMPILED.items():
        if is_land and role in LAND_EXCLUDED:
            continue
        if any(pattern.search(text) for pattern in spec["include"]) and not any(
            pattern.search(types) or pattern.search(text) for pattern in spec["exclude"]
        ):
            found.add(role)

    # A land that taps for several colours is fixing, whatever its wording.
    if "Land" in types and "Basic" not in types:
        if len(set(re.findall(r"add \{([wubrg])\}", text, re.IGNORECASE))) > 1:
            found.add("fixing")

    return found


def tag_roles(conn: sqlite3.Connection) -> dict[str, int]:
    """Re-derive every automatic role tag. Manual tags are left alone."""
    role_ids = {row["slug"]: row["id"] for row in conn.execute("SELECT id, slug FROM roles")}

    conn.execute("DELETE FROM card_roles WHERE source = 'auto'")
    manual = {
        (row["oracle_id"], row["role_id"])
        for row in conn.execute("SELECT oracle_id, role_id FROM card_roles WHERE source = 'manual'")
    }

    tagged = 0
    per_role: dict[str, int] = {}

    for card in conn.execute(
        "SELECT oracle_id, oracle_text, type_line FROM cards WHERE is_token = 0"
    ).fetchall():
        for role in roles_for(card["oracle_text"], card["type_line"]):
            role_id = role_ids.get(role)
            if role_id is None or (card["oracle_id"], role_id) in manual:
                continue
            conn.execute(
                "INSERT OR IGNORE INTO card_roles (oracle_id, role_id, source) VALUES (?, ?, 'auto')",
                (card["oracle_id"], role_id),
            )
            tagged += 1
            per_role[role] = per_role.get(role, 0) + 1

    conn.commit()
    return {"tagged": tagged, **per_role}
