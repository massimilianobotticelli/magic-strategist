# Every target runs inside the container. Nothing here touches the host.
# Pass script arguments with ARGS, e.g.:
#   make query ARGS='deck blight-curse --roles'

COMPOSE ?= docker compose
RUN     := $(COMPOSE) run --rm app

.PHONY: build shell app import enrich sync-gc seed validate query dump sql rebuild help

help:
	@echo 'make build      Build the container image'
	@echo 'make app        Start the web app on http://localhost:8000'
	@echo 'make shell      Interactive bash shell inside the container'
	@echo 'make import     Import ManaBox CSVs / decklists   (ARGS=...)'
	@echo 'make enrich     Fetch card data from Scryfall     (ARGS=...)'
	@echo 'make sync-gc    Refresh the Game Changers list'
	@echo 'make seed       Apply data/seed.sql (brackets, commanders, combos)'
	@echo 'make validate   Run all deck and collection checks'
	@echo 'make query      Query the collection              (ARGS=...)'
	@echo 'make dump       Regenerate data/collection.sql text dump'
	@echo 'make sql        Open the sqlite3 CLI on the database'
	@echo 'make rebuild    Rebuild the database from data/ and decks/ end to end'

build:
	$(COMPOSE) build

shell:
	$(RUN) bash

# The web app: browse decks, mark cards, review combos. Reads and writes the
# same data/collection.db the scripts use, so it and a session stay in sync.
app:
	@echo 'magic-strategist -> http://localhost:8000  (ctrl-c to stop)'
	$(COMPOSE) run --rm --service-ports app \
	  uvicorn main:app --host 0.0.0.0 --port 8000 --app-dir app --reload

import:
	$(RUN) python scripts/import_manabox.py $(ARGS)

enrich:
	$(RUN) python scripts/enrich.py $(ARGS)

sync-gc:
	$(RUN) python scripts/sync_gamechangers.py $(ARGS)

seed:
	$(RUN) sh -c 'sqlite3 data/collection.db < data/seed.sql'
	@echo 'Applied data/seed.sql'

validate:
	$(RUN) python scripts/validate.py $(ARGS)

# Cards that must exist in `cards` without being owned - combo disablers, which
# data/seed.sql references by name. Kept here so a rebuild cannot lose them.
EXTRA_CARDS := "Melira, Sylvok Outcast" "Solemnity" "Pithing Needle"

# Full rebuild from the committed raw exports and decklists. Uses the cached
# Scryfall responses, so it works with no network.
#
# Only the NEWEST dump under data/manabox/ is imported. Each export is a full
# snapshot of the collection, not a delta, so feeding two of them in doubles
# the wishlist and leaves copies split between the old binder names and the
# new ones. Older dumps stay committed as history; they are not inputs.
rebuild:
	$(RUN) sh -c 'rm -f data/collection.db && \
	  latest=$$(ls -d data/manabox/*/ | sort | tail -1) && \
	  echo "importing snapshot $$latest" && \
	  python scripts/import_manabox.py $$latest*.csv decks/*/decklist.txt --no-materialize && \
	  python scripts/enrich.py --offline --names $(EXTRA_CARDS) && \
	  python scripts/sync_gamechangers.py --offline && \
	  sqlite3 data/collection.db < data/seed.sql && \
	  test -f data/app-state.sql && sqlite3 data/collection.db < data/app-state.sql || true'
	@echo 'Rebuilt data/collection.db'

query:
	$(RUN) python scripts/query.py $(ARGS)

# Both halves matter: collection.sql is the readable full snapshot, and
# app-state.sql is the only committed home for the tables the web app writes.
# Without it a rebuild drops every proposal and deck request.
dump:
	$(RUN) sh -c 'sqlite3 data/collection.db .dump > data/collection.sql'
	$(RUN) python scripts/export_state.py
	@echo 'Wrote data/collection.sql'

sql:
	$(RUN) sqlite3 data/collection.db
