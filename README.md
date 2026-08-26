# Node 22 Dev Environment (DSH)

A Docker-based development environment running **Node.js 22** (Alpine) with
**@deepseek-ai/dsh** (DeepSeek Harness) pre-installed.

## Current Features

- **Node.js 22** (Alpine) — built from the official `node:22-alpine` image via `Dockerfile`
- **DSH pre-installed** — `@deepseek-ai/dsh` is installed globally at build time, so the container runs offline after the first build
- **Host bind mount** — the project directory is mounted at `/workspace` inside the container for live file access
- **Makefile shortcuts** — common `docker compose` commands wrapped for convenience
- **Interactive shell** — `make shell` drops you into a shell inside the container

## Quick Start

Build and start the environment:

```bash
make build
make up
```

Open a shell inside the container:

```bash
make shell
```

Inside the container, check the versions:

```bash
node --version      # v22.x
dsh --version      # 0.1.1-rc.2
```

Boot the DSH web GUI inside the container:

```bash
make web
```

> **Note:** DSH's web server binds to `127.0.0.1` inside the container for security
> (it intentionally blocks `0.0.0.0`). It is accessible from inside the container
> via `make shell` + `curl http://127.0.0.1:3080`, or from the host if port 3080
> is free (no other process on the host should use it).

## Make Targets

| Command         | Description                              |
|-----------------|------------------------------------------|
| `make build`   | Build (or rebuild) the Docker image      |
| `make up`      | Start the container in the background    |
| `make down`    | Stop and remove the container            |
| `make shell`   | Open an interactive shell in the container |
| `make web`     | Start the DSH web GUI inside the container |
| `make restart` | `down` then `up`                        |
| `make logs`    | Follow container logs                    |
| `make prune`   | Full cleanup — remove container, images, and volumes |

## Files

- `Dockerfile` — extends `node:22-alpine`, installs `@deepseek-ai/dsh` globally
- `docker-compose.yml` — service definition with bind mount, port mapping (`3080:3080`), and TTY
- `Makefile` — convenience wrappers around compose commands
- `.env` — environment variables (FreeToken config, legacy `pi_agent_rust` keys)

## Notes

- The `Dockerfile` installs DSH at build time so the container runs offline afterward.
- DSH requires the Node.js `--expose-internals` flag at runtime for its HMR plugin.
  The `make web` target handles this by launching DSH via `node --expose-internals`.
- Port 3080 on the host maps to port 3080 in the container. If port 3080 is already
  in use on the host, stop the conflicting process or change the port mapping in
  `docker-compose.yml`.
- The `.gitignore` is inherited from a previous `pi_agent_rust` project and may
  contain stale entries.
