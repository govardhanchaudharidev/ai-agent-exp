# =============================================================================
# FreeToken in Docker — convenience targets
#
# Thin wrappers around `docker compose` for the most common operations.
# Run `make help` for the list.
# =============================================================================

COMPOSE ?= docker compose

# Host-side port the engine API is published on (keep in sync with FT_PORT
# in .env — the container's internal port uses the same number).
PORT ?= 1919
BASE_URL := http://localhost:$(PORT)

# Pass host uid/gid into the build so bind-mounted files keep your ownership.
# docker-compose.yml reads these; plain `docker compose` falls back to 1000.
export HOST_UID := $(shell id -u 2>/dev/null || echo 1000)
export HOST_GID := $(shell id -g 2>/dev/null || echo 1000)

# Prompt text for `make query P="..."`
P ?=

.DEFAULT_GOAL := help
.PHONY: help doctor guard-daemon build rebuild update serve logs stop down \
        destroy health models query chat shell version status config image

# Docker-touching targets fail fast with fix hints when the daemon socket is
# unreachable (typical cause: the shell's session predates the
# 'usermod -aG docker' group change).
build rebuild update serve logs stop down destroy health models query chat \
shell version status config image: guard-daemon

help: ## List available targets
	@printf "\nUsage: make \033[1;36m<target>\033[0m   (one-shot test prompt: make query P=\"...\")\n\n"
	@awk 'BEGIN { FS = ":.*##" } \
		/^[A-Za-z0-9_-]+:/ && NF > 1 && $$2 != "" \
		{ printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

doctor: ## Check prerequisites (docker, compose, daemon, GPU, source clone, .env)
	@echo "==> docker binary:"; command -v docker >/dev/null 2>&1 && docker --version || echo "     MISSING — sudo apt install docker.io docker-compose-v2"
	@echo "==> compose plugin:"; docker compose version >/dev/null 2>&1 && docker compose version --short || echo "     MISSING — sudo apt install docker-compose-v2"
	@echo "==> daemon reachable:"; docker info >/dev/null 2>&1 && echo "     OK" || echo "     NO — is the docker daemon running / are you in the docker group?"
	@echo "==> NVIDIA driver:"; nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || echo "     MISSING — FreeToken needs an NVIDIA RTX 30/40/50 GPU with driver r580+"
	@echo "==> nvidia container runtime:"; docker info 2>/dev/null | grep -qi nvidia && echo "     OK" || echo "     LIKELY MISSING — sudo apt install nvidia-container-toolkit && sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker"
	@echo "==> upstream clone:"; test -f FreeToken/pyproject.toml && echo "     OK" || echo "     MISSING — git clone --depth 1 https://github.com/FlashML-org/FreeToken FreeToken"
	@echo "==> .env model:"; grep -Eq '^FT_MODEL=.+' .env 2>/dev/null && echo "     OK ($(shell grep -E '^FT_MODEL=' .env 2>/dev/null | cut -d= -f2))" || echo "     NONE SET — set FT_MODEL in .env (ids: FreeToken/docs/models.md)"

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
	git -C FreeToken fetch --depth 1 origin main
	git -C FreeToken reset --hard FETCH_HEAD
	$(COMPOSE) build

serve: ## Start the API server in the background (docker compose up -d)
	$(COMPOSE) up -d ft

logs: ## Follow the server logs (model load progress shows here)
	$(COMPOSE) logs -f ft

stop: ## Stop the server (keeps the container for a quick restart)
	$(COMPOSE) stop ft

down: ## Remove containers & network (KEEPS the hf_cache/ft_cache volumes)
	$(COMPOSE) down --remove-orphans

destroy: ## WARNING: also deletes hf_cache (downloaded models!) and ft_cache volumes
	$(COMPOSE) down -v --remove-orphans

health: ## Show server health / load progress (GET /health)
	@curl -sS "$(BASE_URL)/health"; echo

models: ## List the served model id (OpenAI-compatible /v1/models)
	@curl -sS "$(BASE_URL)/v1/models" | jq .

query: ## One-shot test completion against the running server: make query P="hi"
	@if [ -z "$(P)" ]; then echo 'usage: make query P="your prompt"' >&2; exit 2; fi
	@m=$$(curl -sS "$(BASE_URL)/v1/models" | jq -r '.data[0].id'); \
	curl -sS "$(BASE_URL)/v1/chat/completions" -H 'Content-Type: application/json' \
	  -d "$$(jq -n --arg model "$$m" --arg prompt '$(P)' \
	    '{model: $$model, messages: [{role: "user", content: $$prompt}], max_tokens: 256}')"

chat: ## Interactive TUI attached to the running server (attach mode needs no GPU)
	$(COMPOSE) run --rm ft shell --server http://ft:$(PORT)

shell: ## Open a bash shell inside the runtime image
	$(COMPOSE) run --rm --entrypoint /bin/bash ft

version: ## Print the ft CLI version inside the image
	$(COMPOSE) run --rm ft --version

status: ## Show all compose containers for this project
	$(COMPOSE) ps -a

config: ## Print the fully resolved compose configuration
	$(COMPOSE) config

image: ## Show the locally built freetoken image
	docker image ls freetoken:local