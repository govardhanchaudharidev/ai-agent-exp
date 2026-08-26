.PHONY: up down shell restart logs prune

up:
	docker compose up -d

down:
	docker compose down

shell:
	docker compose run --rm node sh

restart: down up

logs:
	docker compose logs -f

prune:
	docker compose down --rmi all --volumes
