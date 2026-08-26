.PHONY: build up down shell pi pi-models pi-version restart logs prune

build:
	docker compose build

up:
	docker compose up -d

down:
	docker compose down

shell:
	docker compose exec node sh

# Launch the Pi interactive coding agent
pi:
	docker compose exec node pi

# Refresh Pi's provider model catalog (fetches latest model lists from providers)
pi-models:
	docker compose exec node sh -c "pi update --models"

# Print the installed Pi version
pi-version:
	docker compose exec node sh -c "pi --version"

restart: down up

logs:
	docker compose logs -f

prune:
	docker compose down --rmi all --volumes
