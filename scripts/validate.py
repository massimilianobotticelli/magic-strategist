#!/usr/bin/env python3
"""Check the collection for rule violations. Exits non-zero when any fail.

Run this after ANY deck change. The check that matters most is the
one-physical-copy rule: moving a card into one deck silently guts another, and
that must surface here rather than when the deck is physically built.

Runs inside the container:
    make validate
    docker compose run --rm app python scripts/validate.py --help
"""

from __future__ import annotations

import argparse
import signal
import sys
from pathlib import Path

# Output is meant to be piped into head/less, so a closed pipe is normal.
signal.signal(signal.SIGPIPE, signal.SIG_DFL)

sys.path.insert(0, str(Path(__file__).resolve().parent))

import db  # noqa: E402

# Game Changers allowed per target bracket. 4 and 5 are unlimited.
GAME_CHANGER_LIMIT = {1: 0, 2: 0, 3: 3}
BRACKET_NAMES = {
    1: "Exhibition", 2: "Core", 3: "Upgraded", 4: "Optimized", 5: "cEDH",
}


class Report:
    def __init__(self) -> None:
        self.failures: list[str] = []
        self.warnings: list[str] = []
        self.lines: list[str] = []

    def section(self, title: str) -> None:
        self.lines.append(f"\n{title}\n{'-' * len(title)}")

    def ok(self, message: str) -> None:
        self.lines.append(f"  ✓ {message}")

    def fail(self, message: str, detail: list[str] | None = None) -> None:
        self.failures.append(message)
        self.lines.append(f"  ✗ {message}")
        for item in detail or []:
            self.lines.append(f"      {item}")

    def warn(self, message: str, detail: list[str] | None = None) -> None:
        self.warnings.append(message)
        self.lines.append(f"  ! {message}")
        for item in detail or []:
            self.lines.append(f"      {item}")

    def note(self, message: str) -> None:
        """Neither a failure nor a warning - just worth knowing."""
        self.lines.append(f"  · {message}")


def check_deck_size(conn, report: Report) -> None:
    report.section("Deck size (exactly 100 including the commander)")
    rows = conn.execute(
        """
        SELECT d.slug, d.name, d.status, COALESCE(SUM(dc.quantity), 0) AS total,
               (SELECT count(*) FROM copies cp WHERE cp.location_id = d.location_id) AS physical
          FROM decks d LEFT JOIN deck_cards dc
            ON dc.deck_id = d.id AND dc.section IN ('main', 'commander')
         GROUP BY d.id ORDER BY d.slug
        """
    ).fetchall()
    for row in rows:
        # Donor and retired decks are not kept assembled, so 100 is not a rule
        # for them - reporting it every run would only bury the real failures.
        # Their list is usually stale, so report what is physically there.
        if row["status"] != "active":
            drift = ("" if row["physical"] == row["total"]
                     else f", list still describes {row['total']}")
            report.note(f"{row['slug']}: {row['physical']} cards physically present"
                        f"{drift} ({row['status']} deck — not held to 100)")
        elif row["total"] == 100:
            report.ok(f"{row['slug']}: 100")
        else:
            report.fail(f"{row['slug']}: {row['total']} cards (should be 100)")


def check_singleton(conn, report: Report) -> None:
    report.section("Singleton within each deck (basic lands excepted)")
    rows = conn.execute(
        """
        SELECT d.slug, dc.card_name, dc.quantity
          FROM deck_cards dc
          JOIN decks d ON d.id = dc.deck_id
          LEFT JOIN cards c ON c.oracle_id = dc.oracle_id
         WHERE dc.quantity > 1 AND COALESCE(c.is_basic_land, 0) = 0
         ORDER BY d.slug, dc.card_name
        """
    ).fetchall()
    if not rows:
        report.ok("no deck runs more than one copy of a non-basic")
    for row in rows:
        report.fail(f"{row['slug']}: {row['quantity']}x {row['card_name']}")


def check_supply_vs_demand(conn, report: Report) -> None:
    """The rule that actually protects a donor deck.

    A card may legitimately appear in several decks - every precon ships its
    own Sol Ring. What must never happen is more ACTIVE decks wanting a card
    than there are physical copies of it, because then building one deck
    quietly strips another. Donor decks are parts bins and make no claim.
    """
    report.section("Physical copies vs. deck demand (active decks only)")
    rows = conn.execute(
        """
        SELECT c.name,
               count(DISTINCT d.id) AS wanted_by,
               group_concat(DISTINCT d.slug) AS decks,
               (SELECT count(*) FROM copies cp WHERE cp.oracle_id = c.oracle_id) AS owned
          FROM deck_cards dc
          JOIN decks d ON d.id = dc.deck_id
          JOIN cards c ON c.oracle_id = dc.oracle_id
         WHERE dc.section IN ('main', 'commander')
           AND d.status = 'active'
           AND c.is_basic_land = 0 AND c.is_token = 0
         GROUP BY c.oracle_id
        HAVING wanted_by > owned
         ORDER BY (wanted_by - owned) DESC, c.name
        """
    ).fetchall()
    if not rows:
        report.ok("every deck list is backed by enough physical copies")
    for row in rows:
        short = row["wanted_by"] - row["owned"]
        report.fail(
            f"{row['name']}: {row['wanted_by']} deck(s) want it, {row['owned']} owned "
            f"— short {short} ({row['decks']})"
        )


def check_deck_cards_owned(conn, report: Report) -> None:
    report.section("Deck lists backed by cards actually in the collection")
    rows = conn.execute(
        """
        SELECT d.slug, dc.card_name
          FROM deck_cards dc
          JOIN decks d ON d.id = dc.deck_id
          LEFT JOIN cards c ON c.oracle_id = dc.oracle_id
         WHERE dc.section IN ('main', 'commander')
           AND d.status = 'active'
           AND COALESCE(c.is_basic_land, 0) = 0
           AND NOT EXISTS (SELECT 1 FROM copies cp WHERE cp.oracle_id = dc.oracle_id)
         ORDER BY d.slug, dc.card_name
        """
    ).fetchall()
    if not rows:
        report.ok("every card in every deck list is owned")
    for row in rows:
        report.fail(f"{row['slug']}: {row['card_name']} — not in the collection at all")


def check_color_identity(conn, report: Report) -> None:
    report.section("Colour identity inside the commander's")
    decks = conn.execute(
        "SELECT id, slug, name, color_identity, commander_oracle_id FROM decks "
        "WHERE status = 'active' ORDER BY slug"
    ).fetchall()
    for deck in decks:
        if not deck["commander_oracle_id"]:
            report.warn(f"{deck['slug']}: no commander identified — colour check skipped")
            continue
        allowed = set(deck["color_identity"] or "")
        offenders = []
        for row in conn.execute(
            """
            SELECT c.name, c.color_identity FROM deck_cards dc
              JOIN cards c ON c.oracle_id = dc.oracle_id
             WHERE dc.deck_id = ? AND dc.section IN ('main', 'commander')
             ORDER BY c.name
            """,
            (deck["id"],),
        ).fetchall():
            extra = set(row["color_identity"] or "") - allowed
            if extra:
                offenders.append(f"{row['name']} ({row['color_identity']}) adds {''.join(sorted(extra))}")
        if offenders:
            report.fail(f"{deck['slug']}: {len(offenders)} card(s) outside {''.join(sorted(allowed)) or 'C'}",
                        offenders)
        else:
            report.ok(f"{deck['slug']}: all inside {''.join(sorted(allowed)) or 'C'}")


def check_game_changers(conn, report: Report) -> None:
    report.section("Game Changers vs. target bracket")
    for deck in conn.execute(
        "SELECT id, slug, target_bracket FROM decks WHERE status = 'active' ORDER BY slug"
    ).fetchall():
        names = [
            row["name"]
            for row in conn.execute(
                """
                SELECT c.name FROM deck_cards dc
                  JOIN cards c ON c.oracle_id = dc.oracle_id
                 WHERE dc.deck_id = ? AND dc.section IN ('main', 'commander')
                   AND c.is_game_changer = 1
                 ORDER BY c.name
                """,
                (deck["id"],),
            ).fetchall()
        ]
        listed = [f"⚡ {n}" for n in names]

        if deck["target_bracket"] is None:
            report.warn(f"{deck['slug']}: no target bracket set — has {len(names)} Game Changer(s)",
                        listed)
            continue

        bracket = deck["target_bracket"]
        limit = GAME_CHANGER_LIMIT.get(bracket)
        label = f"bracket {bracket} ({BRACKET_NAMES.get(bracket, '?')})"
        if limit is None:
            report.ok(f"{deck['slug']}: {label} — unlimited, has {len(names)}")
        elif len(names) > limit:
            report.fail(f"{deck['slug']}: {label} allows {limit}, has {len(names)}", listed)
        else:
            report.ok(f"{deck['slug']}: {label} allows {limit}, has {len(names)}")


def check_combos_vs_bracket(conn, report: Report) -> None:
    report.section("Registered combos vs. target bracket")
    rows = conn.execute(
        """
        SELECT cb.name AS combo, cb.kind, d.slug, d.target_bracket,
               count(cp.oracle_id) AS pieces,
               SUM(CASE WHEN EXISTS (SELECT 1 FROM copies WHERE oracle_id = cp.oracle_id)
                        THEN 1 ELSE 0 END) AS present
          FROM combos cb
          JOIN decks d ON d.id = cb.deck_id
          LEFT JOIN combo_pieces cp ON cp.combo_id = cb.id
         GROUP BY cb.id ORDER BY d.slug, cb.name
        """
    ).fetchall()
    if not rows:
        report.ok("no combos registered yet")
        return
    for row in rows:
        assembled = row["pieces"] > 0 and row["pieces"] == row["present"]
        if assembled and row["target_bracket"] in (1, 3):
            reason = ("bracket 1 forbids infinite combos"
                      if row["target_bracket"] == 1
                      else "bracket 3 only permits combos that cannot realistically "
                           "go off by around turn six")
            report.warn(
                f"{row['slug']}: '{row['combo']}' ({row['kind']}) has all "
                f"{row['pieces']} pieces present — {reason}"
            )
        else:
            report.ok(f"{row['slug']}: '{row['combo']}' — {row['present']}/{row['pieces']} pieces")


def check_copy_conflicts(conn, report: Report) -> None:
    report.section("ManaBox rows that could not be imported")
    rows = conn.execute(
        """
        SELECT card_name, location_slug, quantity, reason
          FROM copy_conflicts ORDER BY reason, card_name
        """
    ).fetchall()
    if not rows:
        report.ok("every ManaBox row became a physical copy cleanly")
        return
    for row in rows:
        report.fail(f"{row['card_name']} in '{row['location_slug']}': {row['reason']}")


def check_singleton_across_collection(conn, report: Report) -> None:
    """Informational: cards owned more than once, mostly booster duplicates."""
    report.section("Cards owned in multiples (informational)")
    rows = conn.execute(
        """
        SELECT c.name, count(*) AS n, group_concat(DISTINCT l.slug) AS locations
          FROM copies cp
          JOIN cards c ON c.oracle_id = cp.oracle_id
          JOIN locations l ON l.id = cp.location_id
         WHERE c.is_basic_land = 0 AND c.is_token = 0
         GROUP BY c.oracle_id HAVING n > 1
         ORDER BY n DESC, c.name
        """
    ).fetchall()
    if not rows:
        report.ok("no non-basic card is owned more than once")
        return
    for row in rows:
        report.note(f"{row['n']}x {row['name']} ({row['locations']})")


def check_languages(conn, report: Report) -> None:
    report.section("English, non-foil printing preference")
    rows = conn.execute(
        """
        SELECT c.language, cd.name, l.slug FROM copies c
          JOIN cards cd ON cd.oracle_id = c.oracle_id
          JOIN locations l ON l.id = c.location_id
         WHERE c.language != 'en' ORDER BY cd.name
        """
    ).fetchall()
    if not rows:
        report.ok("every copy is an English printing")
    for row in rows:
        report.warn(f"{row['name']} in '{row['slug']}' is a '{row['language']}' printing")


CHECKS = [
    check_deck_size,
    check_singleton,
    check_supply_vs_demand,
    check_deck_cards_owned,
    check_color_identity,
    check_game_changers,
    check_combos_vs_bracket,
    check_copy_conflicts,
    check_languages,
    check_singleton_across_collection,
]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate every deck and the physical collection. Non-zero exit on failure.",
        epilog="Runs inside the container. Use `make validate`.",
    )
    parser.add_argument("--db", type=Path, default=db.DB_PATH, help="database path")
    parser.add_argument("--quiet", action="store_true", help="print only failures and warnings")
    args = parser.parse_args(argv)

    conn = db.connect(args.db)
    report = Report()
    for check in CHECKS:
        check(conn, report)
    conn.close()

    for line in report.lines:
        if args.quiet and line.strip().startswith("✓"):
            continue
        print(line)

    print(f"\n{'=' * 60}")
    print(f"{len(report.failures)} failure(s), {len(report.warnings)} warning(s)")
    return 1 if report.failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
