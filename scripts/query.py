#!/usr/bin/env python3
"""Ask focused questions about the collection.

This exists so a session never has to load the whole collection into context.
Query what you need, when you need it.

Runs inside the container:
    make query ARGS='deck blight-curse-b4-final --roles'
    make query ARGS='card "Obelisk Spider"'
    make query ARGS='combos --deck blight-curse-b4-final'
    make query ARGS='pool --color-identity BRG'
"""

from __future__ import annotations

import argparse
import json
import signal
import sys
import textwrap
from pathlib import Path

# Output is meant to be piped into head/less, so a closed pipe is normal.
signal.signal(signal.SIGPIPE, signal.SIG_DFL)

sys.path.insert(0, str(Path(__file__).resolve().parent))

import db  # noqa: E402
import formats  # noqa: E402

BRACKET_NAMES = {1: "Exhibition", 2: "Core", 3: "Upgraded", 4: "Optimized", 5: "cEDH"}


def gc(flag: int) -> str:
    """Game Changers are always labelled explicitly — they decide bracket legality."""
    return "⚡ " if flag else "   "


def fmt_identity(identity: str | None) -> str:
    return identity or "C"


def cmd_decks(conn, args) -> int:
    rows = conn.execute(
        """
        SELECT d.slug, d.name, d.color_identity, d.target_bracket, d.is_registered, d.status,
               c.name AS commander,
               (SELECT COALESCE(SUM(quantity), 0) FROM deck_cards
                 WHERE deck_id = d.id AND section IN ('main','commander')) AS size,
               (SELECT count(*) FROM copies cp WHERE cp.location_id = d.location_id) AS physical
          FROM decks d LEFT JOIN cards c ON c.oracle_id = d.commander_oracle_id
         ORDER BY d.slug
        """
    ).fetchall()
    print(f"{len(rows)} deck(s)\n")
    for row in rows:
        bracket = (f"bracket {row['target_bracket']} "
                   f"({BRACKET_NAMES.get(row['target_bracket'], '?')})"
                   if row["target_bracket"] else "bracket not set")
        flag = "" if row["status"] == "active" else f"  [{row['status'].upper()}]"
        # A donor deck's list is usually stale, so report what is really there.
        size = (f"{row['size']} cards" if row["status"] == "active"
                else f"{row['physical']} cards present, list says {row['size']}")
        print(f"  {row['slug']}{flag}")
        print(f"    {row['name']}  —  {size}, {fmt_identity(row['color_identity'])}, {bracket}")
        print(f"    commander: {row['commander'] or '(not identified)'}")
    return 0


def cmd_deck(conn, args) -> int:
    deck = conn.execute(
        "SELECT * FROM decks WHERE slug = ? OR name = ?", (args.slug, args.slug)
    ).fetchone()
    if not deck:
        print(f"no deck '{args.slug}'. Try: query.py decks")
        return 1

    commander = conn.execute(
        "SELECT name, type_line FROM cards WHERE oracle_id = ?", (deck["commander_oracle_id"],)
    ).fetchone()
    size = conn.execute(
        "SELECT COALESCE(SUM(quantity),0) AS n FROM deck_cards "
        "WHERE deck_id = ? AND section IN ('main','commander')", (deck["id"],)
    ).fetchone()["n"]

    bracket = (f"bracket {deck['target_bracket']} ({BRACKET_NAMES.get(deck['target_bracket'], '?')})"
               if deck["target_bracket"] else "bracket not set")
    print(f"{deck['name']}  [{deck['slug']}]")
    print(f"  commander: {commander['name'] if commander else '(not identified)'}")
    print(f"  identity:  {fmt_identity(deck['color_identity'])}")
    print(f"  size:      {size} cards")
    print(f"  target:    {bracket}")
    print(f"  status:    {'registered' if deck['is_registered'] else 'unregistered'}")

    if args.roles:
        roles = conn.execute(
            """
            SELECT r.name AS role, count(*) AS n FROM deck_cards dc
              JOIN card_roles cr ON cr.oracle_id = dc.oracle_id
              JOIN roles r ON r.id = cr.role_id
             WHERE dc.deck_id = ? AND dc.section IN ('main','commander')
             GROUP BY r.id ORDER BY n DESC, r.name
            """,
            (deck["id"],),
        ).fetchall()
        print("\nRoles")
        if not roles:
            print("  (none tagged yet — card_roles is empty)")
        for row in roles:
            print(f"  {row['n']:3d}  {row['role']}")

    gcs = conn.execute(
        """
        SELECT c.name FROM deck_cards dc JOIN cards c ON c.oracle_id = dc.oracle_id
         WHERE dc.deck_id = ? AND c.is_game_changer = 1 ORDER BY c.name
        """,
        (deck["id"],),
    ).fetchall()
    print(f"\nGame Changers: {len(gcs)}")
    for row in gcs:
        print(f"  ⚡ {row['name']}")

    print("\nDecklist")
    for section in ("commander", "main", "sideboard"):
        rows = conn.execute(
            """
            SELECT dc.quantity, dc.card_name, c.mana_cost, c.type_line,
                   c.color_identity, c.is_game_changer
              FROM deck_cards dc LEFT JOIN cards c ON c.oracle_id = dc.oracle_id
             WHERE dc.deck_id = ? AND dc.section = ?
             ORDER BY c.mana_value, dc.card_name
            """,
            (deck["id"], section),
        ).fetchall()
        if not rows:
            continue
        print(f"\n  -- {section} ({sum(r['quantity'] for r in rows)}) --")
        for row in rows:
            print(f"  {gc(row['is_game_changer'])}{row['quantity']}x {row['card_name']:<34} "
                  f"{(row['mana_cost'] or ''):<14} {row['type_line'] or ''}")
    return 0


def cmd_card(conn, args) -> int:
    rows = conn.execute(
        "SELECT * FROM cards WHERE name = ? COLLATE NOCASE OR name LIKE ? ORDER BY name LIMIT 10",
        (args.name, f"%{args.name}%"),
    ).fetchall()
    if not rows:
        print(f"no card matching '{args.name}' in the database")
        return 1

    for card in rows:
        print(f"\n{gc(card['is_game_changer'])}{card['name']}   {card['mana_cost'] or ''}")
        print(f"    {card['type_line']}")
        if card["power"] is not None:
            print(f"    {card['power']}/{card['toughness']}")
        if card["loyalty"]:
            print(f"    loyalty {card['loyalty']}")
        print(f"    identity: {fmt_identity(card['color_identity'])}   MV {card['mana_value']:g}")
        for line in (card["oracle_text"] or "").split("\n"):
            for wrapped in textwrap.wrap(line, 74) or [""]:
                print(f"    {wrapped}")

        where = conn.execute(
            """
            SELECT l.slug, l.type, p.set_code, p.collector_number, cp.is_foil, cp.language
              FROM copies cp JOIN locations l ON l.id = cp.location_id
              JOIN printings p ON p.scryfall_id = cp.printing_id
             WHERE cp.oracle_id = ?
            """,
            (card["oracle_id"],),
        ).fetchall()
        if where:
            for row in where:
                foil = " *F*" if row["is_foil"] else ""
                lang = "" if row["language"] == "en" else f" [{row['language']}]"
                print(f"    owned: {row['slug']} ({row['type']}) — "
                      f"{row['set_code']} {row['collector_number']}{foil}{lang}")
        else:
            print("    owned: not in the collection")

        listed = conn.execute(
            """
            SELECT d.slug FROM deck_cards dc JOIN decks d ON d.id = dc.deck_id
             WHERE dc.oracle_id = ? ORDER BY d.slug
            """,
            (card["oracle_id"],),
        ).fetchall()
        if listed:
            print(f"    listed in: {', '.join(r['slug'] for r in listed)}")
    return 0


def cmd_combos(conn, args) -> int:
    sql = """
        SELECT cb.id, cb.name, cb.kind, cb.payoff, cb.power_level, cb.notes, d.slug
          FROM combos cb LEFT JOIN decks d ON d.id = cb.deck_id
    """
    params: tuple = ()
    if args.deck:
        sql += " WHERE d.slug = ?"
        params = (args.deck,)
    sql += " ORDER BY d.slug, cb.name"

    combos = conn.execute(sql, params).fetchall()
    if not combos:
        print("no combos registered" + (f" for deck '{args.deck}'" if args.deck else ""))
        return 0

    for combo in combos:
        print(f"\n{combo['name']}  ({combo['kind']})  [{combo['slug'] or 'no deck'}]")
        if combo["payoff"]:
            print(f"  payoff: {combo['payoff']}")
        if combo["power_level"]:
            print(f"  power:  {combo['power_level']}")

        print("  pieces:")
        for row in conn.execute(
            """
            SELECT c.name, cp.owned, cp.note,
                   (SELECT l.slug FROM copies co JOIN locations l ON l.id = co.location_id
                     WHERE co.oracle_id = cp.oracle_id LIMIT 1) AS at
              FROM combo_pieces cp JOIN cards c ON c.oracle_id = cp.oracle_id
             WHERE cp.combo_id = ? ORDER BY c.name
            """,
            (combo["id"],),
        ).fetchall():
            mark = "✓" if row["at"] else "✗"
            where = f" (in {row['at']})" if row["at"] else " (NOT OWNED)"
            print(f"    {mark} {row['name']}{where}")

        disablers = conn.execute(
            """
            SELECT c.name, cd.note FROM combo_disablers cd
              JOIN cards c ON c.oracle_id = cd.oracle_id
             WHERE cd.combo_id = ? ORDER BY c.name
            """,
            (combo["id"],),
        ).fetchall()
        print(f"  disablers ({len(disablers)}):" if disablers else "  disablers: none recorded")
        for row in disablers:
            note = f" — {row['note']}" if row["note"] else ""
            print(f"    ⊘ {row['name']}{note}")

        if combo["notes"]:
            print(f"  notes: {combo['notes']}")
    return 0


def cmd_pool(conn, args) -> int:
    # Donor decks are parts bins, so their cards are available inventory too.
    # Pass --pools-only to see just the loose binders.
    donor_clause = "" if args.pools_only else """
           OR l.id IN (SELECT location_id FROM decks WHERE status = 'donor')"""

    sql = f"""
        SELECT c.name, c.mana_cost, c.type_line, c.color_identity, c.is_game_changer,
               l.slug AS location, p.set_code, p.collector_number,
               (SELECT status FROM decks WHERE location_id = l.id) AS deck_status
          FROM copies cp
          JOIN locations l ON l.id = cp.location_id
          JOIN cards c ON c.oracle_id = cp.oracle_id
          JOIN printings p ON p.scryfall_id = cp.printing_id
         WHERE c.is_basic_land = 0 AND (l.type = 'pool'{donor_clause})
    """
    params: list = []
    if args.location:
        sql += " AND l.slug = ?"
        params.append(args.location)
    sql += " ORDER BY c.name"

    rows = conn.execute(sql, params).fetchall()

    if args.color_identity is not None:
        allowed = set(args.color_identity.upper())
        rows = [r for r in rows if set(r["color_identity"] or "") <= allowed]

    if args.type:
        rows = [r for r in rows if args.type.lower() in (r["type_line"] or "").lower()]

    label = f" within {args.color_identity.upper()}" if args.color_identity else ""
    print(f"{len(rows)} available card(s){label}\n")
    for row in rows:
        where = row["location"] + (" (donor)" if row["deck_status"] == "donor" else "")
        print(f"  {gc(row['is_game_changer'])}{row['name']:<34} {(row['mana_cost'] or ''):<14} "
              f"{fmt_identity(row['color_identity']):<5} {row['type_line']:<40} "
              f"[{where}]")
    return 0


def cmd_available(conn, args) -> int:
    """Owned cards that are legal in a format — the deck-building working set.

    Free cards come from pools and donor decks. Cards sitting in an assembled
    deck are shown only with --borrow, because taking one costs that deck.
    """
    fmt = formats.get(args.format)
    rows = conn.execute(
        """
        SELECT c.oracle_id, c.name, c.mana_cost, c.mana_value, c.type_line,
               c.color_identity, c.oracle_text, c.legalities, c.is_game_changer,
               count(*) AS copies,
               group_concat(DISTINCT l.slug) AS locations,
               MIN(CASE WHEN l.type = 'pool' THEN 1
                        WHEN (SELECT status FROM decks WHERE location_id = l.id) IN ('donor','draft','retired') THEN 1
                        ELSE 0 END) AS borrowed,
               (SELECT group_concat(DISTINCT p.rarity) FROM printings p
                 WHERE p.oracle_id = c.oracle_id) AS rarities,
               (SELECT group_concat(ro.slug) FROM card_roles cr
                  JOIN roles ro ON ro.id = cr.role_id
                 WHERE cr.oracle_id = c.oracle_id) AS roles
          FROM copies cp
          JOIN cards c ON c.oracle_id = cp.oracle_id
          JOIN locations l ON l.id = cp.location_id
         WHERE c.is_basic_land = 0 AND c.is_token = 0
         GROUP BY c.oracle_id ORDER BY c.mana_value, c.name
        """
    ).fetchall()

    identity = set((args.colors or "").upper())
    out = []
    for r in rows:
        card = dict(r)
        if json.loads(card["legalities"] or "{}").get(fmt.legality_key) != "legal":
            continue
        if fmt.allowed_rarities:
            printed = set((card["rarities"] or "").split(","))
            if not (printed & fmt.allowed_rarities):
                continue
        if identity and set(card["color_identity"] or "") - identity:
            continue
        # borrowed == 1 means at least one copy is free (pool or donor).
        if not args.borrow and not card["borrowed"]:
            continue
        card["roles"] = (card["roles"] or "").split(",") if card["roles"] else []
        if args.role and args.role not in card["roles"]:
            continue
        if args.type and args.type.lower() not in (card["type_line"] or "").lower():
            continue
        out.append(card)

    scope = "free (pools and donor decks)" if not args.borrow else "including cards in assembled decks"
    where = f" within {args.colors.upper()}" if args.colors else ""
    print(f"{len(out)} card(s) legal in {fmt.name}{where} — {scope}")
    print(f"  {fmt.notes}\n")

    for card in out:
        free = "" if card["borrowed"] else "  ⚠ in an assembled deck"
        copies = f" x{card['copies']}" if card["copies"] > 1 else ""
        print(f"  {gc(card['is_game_changer'])}{card['name']:<32}{copies:<4} "
              f"{(card['mana_cost'] or ''):<13} {fmt_identity(card['color_identity']):<5} "
              f"{(card['type_line'] or '')[:34]:<34} [{card['locations']}]{free}")
        if args.text and card["oracle_text"]:
            for line in card["oracle_text"].split("\n"):
                print(f"        {line}")
    return 0


def cmd_requests(conn, args) -> int:
    rows = conn.execute(
        """
        SELECT r.*, d.slug AS deck_slug FROM deck_requests r
          LEFT JOIN decks d ON d.id = r.deck_id
         WHERE (? = 'all' OR r.status = ?) ORDER BY r.created_at
        """,
        (args.status, args.status),
    ).fetchall()
    print(f"{len(rows)} deck request(s)\n")
    for r in rows:
        fmt = formats.get(r["format"])
        print(f"  #{r['id']}  {fmt.name}  [{r['status']}]  {r['created_at']}")
        if r["colors"]:
            print(f"      colours:   {r['colors']}")
        if r["commander_hint"]:
            print(f"      commander: {r['commander_hint']}")
        if r["strategy"]:
            print(f"      strategy:  {r['strategy']}")
        print(f"      borrowing from assembled decks: "
              f"{'yes' if r['allow_borrowing'] else 'no'}   "
              f"buying: {'yes' if r['allow_buying'] else 'no'}")
        if r["notes"]:
            print(f"      notes:     {r['notes']}")
        if r["deck_slug"]:
            print(f"      -> draft:  {r['deck_slug']}")
        if r["response"]:
            print(f"      response:  {r['response']}")
    return 0


def cmd_wishlist(conn, args) -> int:
    rows = conn.execute(
        """
        SELECT w.card_name, w.price_ceiling_eur, w.priority, w.status, w.notes, d.slug
          FROM wishlist w LEFT JOIN decks d ON d.id = w.deck_id
         ORDER BY w.priority, w.card_name
        """
    ).fetchall()
    print(f"{len(rows)} wishlist entr(y/ies)\n")
    for row in rows:
        ceiling = f"≤ €{row['price_ceiling_eur']:.2f}" if row["price_ceiling_eur"] else "no ceiling"
        deck = f" for {row['slug']}" if row["slug"] else ""
        print(f"  P{row['priority']}  {row['card_name']:<34} {ceiling:<12} "
              f"{row['status']}{deck}")
        if row["notes"]:
            print(f"       {row['notes']}")
    return 0


def cmd_conflicts(conn, args) -> int:
    rows = conn.execute(
        "SELECT * FROM copy_conflicts ORDER BY reason, card_name"
    ).fetchall()
    print(f"{len(rows)} inventory conflict(s)\n")
    for row in rows:
        kept = f" (copy kept in '{row['kept_location_slug']}')" if row["kept_location_slug"] else ""
        print(f"  {row['card_name']:<34} in '{row['location_slug']}'{kept}")
        print(f"       {row['reason']}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Query the MTG collection database.",
        epilog="Runs inside the container. Use `make query ARGS='...'`.",
    )
    parser.add_argument("--db", type=Path, default=db.DB_PATH, help="database path")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("decks", help="list every deck").set_defaults(func=cmd_decks)

    p = sub.add_parser("deck", help="show one deck")
    p.add_argument("slug")
    p.add_argument("--roles", action="store_true", help="include a role breakdown")
    p.set_defaults(func=cmd_deck)

    p = sub.add_parser("card", help="look up a card")
    p.add_argument("name")
    p.set_defaults(func=cmd_card)

    p = sub.add_parser("combos", help="show registered combos, pieces and disablers")
    p.add_argument("--deck", help="limit to one deck slug")
    p.set_defaults(func=cmd_combos)

    p = sub.add_parser("pool", help="cards available to draw on: loose pools plus donor decks")
    p.add_argument("--color-identity", help="only cards inside this identity, e.g. BRG")
    p.add_argument("--location", help="limit to one pool or deck slug")
    p.add_argument("--type", help="substring match on the type line")
    p.add_argument("--pools-only", action="store_true",
                   help="exclude donor decks, showing only the loose binders")
    p.set_defaults(func=cmd_pool)

    p = sub.add_parser("available", help="owned cards legal in a format — for building")
    p.add_argument("--format", default="commander", choices=formats.choices())
    p.add_argument("--colors", help="restrict to this colour identity, e.g. BG")
    p.add_argument("--role", help="only cards tagged with this role")
    p.add_argument("--type", help="substring match on the type line")
    p.add_argument("--borrow", action="store_true",
                   help="also show cards sitting in assembled decks")
    p.add_argument("--text", action="store_true", help="include oracle text")
    p.set_defaults(func=cmd_available)

    p = sub.add_parser("requests", help="deck-building requests from the app")
    p.add_argument("--status", default="pending",
                   choices=["pending", "building", "ready", "dismissed", "all"])
    p.set_defaults(func=cmd_requests)

    sub.add_parser("wishlist", help="cards to buy").set_defaults(func=cmd_wishlist)
    sub.add_parser("conflicts", help="physical inventory conflicts").set_defaults(func=cmd_conflicts)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    conn = db.connect(args.db)
    try:
        return args.func(conn, args)
    finally:
        conn.close()


if __name__ == "__main__":
    raise SystemExit(main())
