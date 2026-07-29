# Every target runs inside the container. Nothing here touches the host.
# Pass script arguments with ARGS, e.g.:
#   make query ARGS='deck blight-curse --roles'

COMPOSE ?= docker compose
RUN     := $(COMPOSE) run --rm app

.PHONY: build shell import enrich sync-gc seed validate query dump sql rebuild help

help:
	@echo 'make build      Build the container image'
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
rebuild:
	$(RUN) sh -c 'rm -f data/collection.db && \
	  python scripts/import_manabox.py data/manabox/*/*.csv decks/*/decklist.txt --no-materialize && \
	  python scripts/enrich.py --offline --names $(EXTRA_CARDS) && \
	  python scripts/sync_gamechangers.py --offline && \
	  sqlite3 data/collection.db < data/seed.sql'
	@echo 'Rebuilt data/collection.db'

query:
	$(RUN) python scripts/query.py $(ARGS)

dump:
	$(RUN) sh -c 'sqlite3 data/collection.db .dump > data/collection.sql'
	@echo 'Wrote data/collection.sql'

sql:
	$(RUN) sqlite3 data/collection.db
