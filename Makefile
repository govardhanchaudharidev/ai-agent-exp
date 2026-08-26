.PHONY: build up down shell restart logs prune web

build:
	docker compose build

up:
	docker compose up -d

down:
	docker compose down

shell:
	docker compose exec node sh

# Boot the DSH web GUI
# Uses node --expose-internals because the HMR plugin requires it at the
# Node.js runtime level (not a DSH CLI flag). DSH binary is globally installed.
web:
	docker compose exec -d node sh -c "node --expose-internals /usr/local/bin/dsh --profile web --no-open"

restart: down up

logs:
	docker compose logs -f

prune:
	docker compose down --rmi all --volumes
