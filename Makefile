# =============================================================================
# prime-agent in Docker — convenience targets
#
# Thin wrappers around `docker compose` for the most common operations.
# Run `make help` for the list.
# =============================================================================

COMPOSE ?= docker compose

.DEFAULT_GOAL := help
.PHONY: help build rebuild run up logs shell status down destroy config

help: ## List available targets
	@printf "\nUsage: make \033[1;36m<target>\033[0m\n\n"
	@awk 'BEGIN { FS = ":.*##" } \
		/^[A-Za-z0-9_-]+:/ && NF > 1 && $$2 != "" \
		{ printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

build: ## Build the image (incremental)
	$(COMPOSE) build

rebuild: ## Full rebuild without cache
	$(COMPOSE) build --no-cache

run: ## Run the prime-agent interactively
	$(COMPOSE) run --rm prime-agent

up: ## Start the prime-agent in the background
	$(COMPOSE) up -d

logs: ## Tail the logs of the running agent
	$(COMPOSE) logs -f prime-agent

shell: ## Open a bash shell inside the prime-agent container
	$(COMPOSE) run --rm --entrypoint /bin/bash prime-agent

status: ## Show all compose containers for this project
	$(COMPOSE) ps -a

down: ## Remove containers & network (KEEPS the prime-data volume)
	$(COMPOSE) down --remove-orphans

destroy: ## WARNING: also deletes the prime-data volume (sessions/settings lost!)
	$(COMPOSE) down -v --remove-orphans

config: ## Print the fully resolved compose configuration
	$(COMPOSE) config
