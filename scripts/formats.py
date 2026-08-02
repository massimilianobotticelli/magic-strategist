"""What each supported format actually requires.

Kept in one place because the rules differ in ways that used to be hardcoded
as "100 cards, singleton" everywhere: Modern and Pauper are 60-card, 4-of
formats with a sideboard, and the two Commander variants are not.

`legality_key` is the field name in Scryfall's `legalities` object.
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class Format:
    slug: str
    name: str
    legality_key: str
    deck_size: int
    exact_size: bool           # Commander is exactly 100; Modern is a minimum
    max_copies: int            # per card, basics excepted
    needs_commander: bool
    sideboard: int
    # Rarities a maindeck card may have been printed at. Empty means no limit.
    allowed_rarities: frozenset[str] = field(default_factory=frozenset)
    commander_rarity: str | None = None
    notes: str = ""

    @property
    def singleton(self) -> bool:
        return self.max_copies == 1


FORMATS: dict[str, Format] = {
    "commander": Format(
        slug="commander",
        name="Commander",
        legality_key="commander",
        deck_size=100,
        exact_size=True,
        max_copies=1,
        needs_commander=True,
        sideboard=0,
        notes="Singleton, exactly 100 including the commander, colour identity enforced.",
    ),
    "pdh": Format(
        slug="pdh",
        name="Pauper Commander",
        legality_key="paupercommander",
        deck_size=100,
        exact_size=True,
        max_copies=1,
        needs_commander=True,
        sideboard=0,
        allowed_rarities=frozenset({"common"}),
        commander_rarity="uncommon",
        notes="Singleton commons, exactly 100. The commander is an uncommon creature.",
    ),
    "modern": Format(
        slug="modern",
        name="Modern",
        legality_key="modern",
        deck_size=60,
        exact_size=False,
        max_copies=4,
        needs_commander=False,
        sideboard=15,
        notes="At least 60 cards, up to 4 copies of any card, 15-card sideboard.",
    ),
    "pauper": Format(
        slug="pauper",
        name="Pauper",
        legality_key="pauper",
        deck_size=60,
        exact_size=False,
        max_copies=4,
        needs_commander=False,
        sideboard=15,
        allowed_rarities=frozenset({"common"}),
        notes="At least 60 cards, commons only, up to 4 copies, 15-card sideboard.",
    ),
}

DEFAULT = "commander"


def get(slug: str | None) -> Format:
    return FORMATS.get((slug or DEFAULT).lower(), FORMATS[DEFAULT])


def choices() -> list[str]:
    return list(FORMATS)
