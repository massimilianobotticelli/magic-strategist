"""Minimal, well-behaved Scryfall API client.

Scryfall asks API consumers to identify themselves and to stay well under
10 requests/second. Both are enforced here rather than left to callers.
Every response is cached under data/scryfall/ so re-runs only fetch genuinely
new cards, and so the repo works offline.
"""

from __future__ import annotations

import json
import os
import time
from collections.abc import Iterable, Iterator
from typing import Any

import requests

from db import SCRYFALL_CACHE

API = "https://api.scryfall.com"

# Scryfall's documented ceiling for the collection endpoint.
MAX_IDENTIFIERS_PER_REQUEST = 75

# 120ms between requests => ~8.3 req/s sustained, comfortably under the limit.
REQUEST_DELAY_SECONDS = 0.12

# Scryfall uses the User-Agent to reach whoever is making the requests, so it
# is REQUIRED and has no default on purpose. A default would be this
# repository's, and every fork that never read the docs would quietly send its
# traffic under someone else's name — the failure would be invisible to the
# person causing it and land on somebody who cannot fix it.
#
# So it is treated like a credential: set it, or the request does not happen.
#
#     cp .env.example .env    # then set SCRYFALL_USER_AGENT
#
# Nothing offline needs it. `--offline`, `make rebuild`, `make validate` and CI
# never reach this code, so requiring it costs them nothing.
USER_AGENT_VAR = "SCRYFALL_USER_AGENT"

# What .env.example ships. Copying the file without editing it is the ordinary
# mistake, and it would put a fake URL in front of Scryfall, so it is caught
# with the same error as leaving the variable unset.
PLACEHOLDER_USER_AGENT = "my-collection/1.0 (+https://github.com/you/my-collection)"

_MISSING_USER_AGENT = f"""
{USER_AGENT_VAR} is not set, so this request was not made.

Scryfall asks every caller to identify itself, and uses that string to get in
touch about its traffic. There is deliberately no default: it would be this
repository's, and your requests would be attributed to its owner.

    cp .env.example .env

then edit one line:

    {USER_AGENT_VAR}=my-thing/1.0 (+https://github.com/you/my-thing)

Include something that can be used to reach you — a repository URL is the usual
choice. Docker Compose reads .env on its own, so there is nothing else to do.

Only live requests need this. `--offline`, `make rebuild` and `make validate`
work without it.
"""


class MissingUserAgent(RuntimeError):
    """Raised instead of making an unidentified request to Scryfall."""


def user_agent() -> str:
    """The configured User-Agent, or refuse to make the request."""
    value = os.environ.get(USER_AGENT_VAR, "").strip()
    if not value or value == PLACEHOLDER_USER_AGENT:
        raise MissingUserAgent(_MISSING_USER_AGENT)
    return value


def headers() -> dict[str, str]:
    """Request headers. Built per call, so the check cannot be bypassed."""
    return {"User-Agent": user_agent(), "Accept": "application/json"}


CARD_CACHE = SCRYFALL_CACHE / "cards"
ALIAS_PATH = SCRYFALL_CACHE / "aliases.json"

_last_request_at = 0.0


def _throttle() -> None:
    global _last_request_at
    elapsed = time.monotonic() - _last_request_at
    if elapsed < REQUEST_DELAY_SECONDS:
        time.sleep(REQUEST_DELAY_SECONDS - elapsed)
    _last_request_at = time.monotonic()


def chunked(items: list[Any], size: int = MAX_IDENTIFIERS_PER_REQUEST) -> Iterator[list[Any]]:
    for start in range(0, len(items), size):
        yield items[start : start + size]


# ---------------------------------------------------------------------------
# Cache
# ---------------------------------------------------------------------------
def load_aliases() -> dict[str, str]:
    """Maps 'set/collector_number' -> scryfall id, so set+number lookups hit cache."""
    if ALIAS_PATH.exists():
        return json.loads(ALIAS_PATH.read_text())
    return {}


def save_aliases(aliases: dict[str, str]) -> None:
    ALIAS_PATH.parent.mkdir(parents=True, exist_ok=True)
    ALIAS_PATH.write_text(json.dumps(aliases, indent=1, sort_keys=True))


def cached_card(scryfall_id: str) -> dict | None:
    path = CARD_CACHE / f"{scryfall_id}.json"
    if path.exists():
        return json.loads(path.read_text())
    return None


def cache_card(card: dict) -> None:
    CARD_CACHE.mkdir(parents=True, exist_ok=True)
    (CARD_CACHE / f"{card['id']}.json").write_text(json.dumps(card, indent=1, sort_keys=True))


def alias_key(set_code: str, collector_number: str) -> str:
    return f"{set_code.lower()}/{collector_number}"


def name_key(name: str) -> str:
    """Alias for a card looked up by name, so --offline can serve it from cache."""
    return f"name:{name.strip().lower()}"


# ---------------------------------------------------------------------------
# Requests
# ---------------------------------------------------------------------------
def fetch_collection(identifiers: list[dict]) -> tuple[list[dict], list[dict]]:
    """POST /cards/collection for up to 75 identifiers.

    Returns (found, not_found). Callers must NOT assume positional alignment
    between `identifiers` and `found`: Scryfall returns hits in request order,
    but every miss shifts the mapping, so results are matched on the returned
    card's own id / set+number instead.
    """
    if len(identifiers) > MAX_IDENTIFIERS_PER_REQUEST:
        raise ValueError(f"at most {MAX_IDENTIFIERS_PER_REQUEST} identifiers per request")

    _throttle()
    response = requests.post(
        f"{API}/cards/collection",
        json={"identifiers": identifiers},
        headers=headers(),
        timeout=30,
    )
    response.raise_for_status()
    payload = response.json()
    return payload.get("data", []), payload.get("not_found", [])


def search(query: str) -> Iterable[dict]:
    """Yield every card matching a Scryfall search query, following pagination."""
    url = f"{API}/cards/search"
    params: dict | None = {"q": query, "unique": "cards"}

    while url:
        _throttle()
        response = requests.get(url, params=params, headers=headers(), timeout=30)
        if response.status_code == 404:  # no matches at all
            return
        response.raise_for_status()
        payload = response.json()
        yield from payload.get("data", [])
        url = payload.get("next_page")
        params = None


def named(name: str) -> dict | None:
    """Exact card lookup by name, for combo pieces and disablers not owned."""
    _throttle()
    response = requests.get(
        f"{API}/cards/named", params={"exact": name}, headers=headers(), timeout=30
    )
    if response.status_code == 404:
        return None
    response.raise_for_status()
    return response.json()
