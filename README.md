# Pi Agent Dev Environment

A Docker-based development environment running **Node.js 22** (Alpine) with the
[@earendil-works/pi-coding-agent](https://github.com/earendil-works/pi) coding
agent pre-installed.

## Overview

This environment provides a ready-to-use Pi coding agent inside an isolated
Docker container. The project directory is bind-mounted at `/workspace` so you
get live file access, and Pi's configuration (sessions, settings, packages) is
persisted across container rebuilds via a named Docker volume.

## Features

- **Node.js 22** (Alpine) — built from the official `node:22-alpine` image
- **Pi pre-installed** — `@earendil-works/pi-coding-agent` installed globally
  at build time, so the container runs offline after the first build
- **Host bind mount** — the project directory is mounted at `/workspace` inside
  the container for live file access
- **Config persistence** — Pi's config directory (`~/.pi/agent`) is backed by a
  named Docker volume so sessions and settings survive container rebuilds
- **Makefile shortcuts** — common `docker compose` commands wrapped for
  convenience

## Quick Start

1. **Set your API key** — copy the example env file and add your OpenRouter key:

   ```bash
   cp .env.example .env
   # Edit .env and set OPENROUTER_API_KEY
   ```

2. **Build and start** the environment:

   ```bash
   make build
   make up
   ```

3. **Launch the Pi agent**:

   ```bash
   make pi
   ```

   Inside the container you can also run `pi` directly after opening a shell:

   ```bash
   make shell
   pi "List all files in /workspace"
   ```

## Make Targets

| Command           | Description                                       |
|-------------------|---------------------------------------------------|
| `make build`      | Build (or rebuild) the Docker image               |
| `make up`         | Start the container in the background              |
| `make down`       | Stop and remove the container                      |
| `make shell`      | Open an interactive shell in the container        |
| `make pi`         | Launch the Pi interactive coding agent            |
| `make pi-models`  | Refresh Pi's provider model catalog                |
| `make pi-version` | Print the installed Pi version                     |
| `make restart`    | `down` then `up`                                  |
| `make logs`       | Follow container logs                              |
| `make prune`      | Full cleanup — remove container, images, and volumes |

## Configuration

### API Keys

Pi supports 20+ LLM providers. Copy `.env.example` to `.env` and set the
appropriate API keys. The most common:

| Provider   | Environment Variable       |
|------------|----------------------------|
| OpenRouter | `OPENROUTER_API_KEY`       |
| OpenAI     | `OPENAI_API_KEY`           |
| Anthropic  | `ANTHROPIC_API_KEY`        |
| Google     | `GOOGLE_API_KEY`           |
| DeepSeek   | `DEEPSEEK_API_KEY`         |

See Pi's [provider documentation](https://pi.dev/docs/latest/) for the full list.

### Environment Variables

| Variable              | Description                                          |
|-----------------------|------------------------------------------------------|
| `OPENROUTER_API_KEY`  | OpenRouter API key for LLM access                    |
| `PI_CODING_AGENT_DIR` | Override config directory (default: `~/.pi/agent`)  |
| `PI_OFFLINE`          | Set to `true` to disable startup network operations   |
| `PI_CACHE_RETENTION`  | Set to `long` for extended prompt cache               |

### Pi Config Persistence

Pi stores sessions, settings, and installed packages in `~/.pi/agent` inside
the container. This directory is backed by a Docker named volume (`pi-config`),
so your data persists across `make down` / `make up` cycles.

To start fresh (e.g., to reset sessions):

```bash
make down
docker volume rm ai-agent-exp_pi-config
make up
```

## Files

- `Dockerfile` — extends `node:22-alpine`, installs `@earendil-works/pi-coding-agent` globally
- `docker-compose.yml` — service definition with bind mount and config volume
- `Makefile` — convenience wrappers around compose commands
- `.env.example` — template for environment configuration
- `.env` — local environment configuration (gitignored)

## Notes

- The `Dockerfile` installs Pi at build time so the container runs offline
  afterward.
- If you switch providers or change API keys, run `make pi-models` to refresh
  the model catalog.
- Pi is launched from within the container via `make pi` or `make shell` +
  `pi`.

## License

MIT
