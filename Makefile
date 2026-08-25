# =============================================================================
# pi_agent_rust in Docker — convenience targets
#
# Thin wrappers around `docker compose` for the most common operations.
# Run `make help` for the list.
# =============================================================================

COMPOSE ?= docker compose

# Pass host uid/gid into the build so files created in ./workspace keep your
# ownership. docker-compose.yml reads these; plain `docker compose` invocations
# fall back to 1000.
export HOST_UID := $(shell id -u 2>/dev/null || echo 1000)
export HOST_GID := $(shell id -g 2>/dev/null || echo 1000)

# Prompt text for `make ask P="..."`
P ?=

.DEFAULT_GOAL := help
.PHONY: help doctor guard-daemon build rebuild update tui continue ask \
        version shell status down destroy config image

# Docker-touching targets fail fast with fix hints when the daemon socket is
# unreachable (typical cause: the shell's session predates the
# 'usermod -aG docker' group change).
build rebuild update tui continue ask version shell status down destroy \
config image: guard-daemon

help: ## List available targets
	@printf "\nUsage: make \033[1;36m<target>\033[0m   (one-shot prompt: make ask P=\"...\")\n\n"
	@awk 'BEGIN { FS = ":.*##" } \
		/^[A-Za-z0-9_-]+:/ && NF > 1 && $$2 != "" \
		{ printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

doctor: ## Check prerequisites (docker, compose, daemon, source clone, .env key)
	@echo "==> docker binary:"; command -v docker >/dev/null 2>&1 && docker --version || echo "     MISSING — sudo apt install docker.io docker-compose-v2"
	@echo "==> compose plugin:"; docker compose version >/dev/null 2>&1 && docker compose version --short || echo "     MISSING — sudo apt install docker-compose-v2"
	@echo "==> daemon reachable:"; docker info >/dev/null 2>&1 && echo "     OK" || echo "     NO — is the docker daemon running / are you in the docker group?"
	@echo "==> upstream clone:"; test -f pi_agent_rust/Cargo.toml && echo "     OK" || echo "     MISSING — git clone --depth 1 https://github.com/Dicklesworthstone/pi_agent_rust pi_agent_rust"
	@echo "==> .env API key:"; grep -Eq '^[A-Z_]*API_KEY=.+' .env 2>/dev/null && echo "     OK" || echo "     NONE ACTIVE — uncomment a provider key in .env"

guard-daemon: ## Fail fast with fix hints if the Docker daemon is unreachable
	@if ! docker info >/dev/null 2>&1; then \
		echo "ERROR: cannot connect to the Docker daemon (permission denied on docker.sock?)."; \
		echo ""; \
		echo "Group membership is captured at LOGIN — 'usermod -aG docker' does not"; \
		echo "affect terminals/sessions that were already open (other apps that"; \
		echo "were restarted afterwards, e.g. VS Code, may still work). Fixes:"; \
		echo "  quick       newgrp docker                # then rerun your make command"; \
		echo "  quick       sg docker -c 'make <target>'"; \
		echo "  permanent   fully log out of the desktop session and back in (or reboot)"; \
		exit 1; \
	fi

build: ## Build the image (incremental, BuildKit cache mounts)
	$(COMPOSE) build

rebuild: ## Full rebuild without cache
	$(COMPOSE) build --no-cache

update: ## Refresh vendored source to latest upstream main, then rebuild
	git -C pi_agent_rust fetch --depth 1 origin main
	git -C pi_agent_rust reset --hard FETCH_HEAD
	$(COMPOSE) build

tui: ## Interactive agent session working on ./workspace
	$(COMPOSE) run --rm pi

continue: ## Interactively resume the most recent session
	$(COMPOSE) run --rm pi --continue

ask: ## One-shot non-interactive query: make ask P="explain this repo"
	@if [ -z "$(P)" ]; then echo 'usage: make ask P="your prompt"' >&2; exit 2; fi
	$(COMPOSE) run --rm pi -p "$(P)"

version: ## Print the pi binary version inside the image
	$(COMPOSE) run --rm pi --version

shell: ## Open a bash shell inside the runtime image
	$(COMPOSE) run --rm --entrypoint /bin/bash pi

status: ## Show all compose containers for this project
	$(COMPOSE) ps -a

down: ## Remove containers & network (KEEPS the pi_home data volume)
	$(COMPOSE) down --remove-orphans

destroy: ## WARNING: also deletes the pi_home volume (sessions/settings lost!)
	$(COMPOSE) down -v --remove-orphans

config: ## Print the fully resolved compose configuration
	$(COMPOSE) config

image: ## Show the locally built pi-agent-rust image
	docker image ls pi-agent-rust:local
