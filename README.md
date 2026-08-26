# Node 22 Dev Environment

A minimal development environment running **Node.js 22** in Docker, with no app code assumed. Drop into a ready-to-use container and install or run whatever you need.

## Current Features

- **Node.js 22** (Alpine) — no build step, uses the official `node:22-alpine` image
- **Self-contained** — no host mounts; everything runs inside the container
- **Makefile shortcuts** — common `docker compose` commands wrapped for convenience
- **Interactive shell** — `make shell` drops you into a shell inside the container

## Quick Start

Start the environment:

```bash
make up
```

Open a shell inside the container:

```bash
make shell
```

Inside the container, check the Node version:

```bash
node --version
```

## Make Targets

| Command         | Description                              |
|-----------------|------------------------------------------|
| `make up`      | Start the Node 22 container in the background |
| `make down`    | Stop and remove the container            |
| `make shell`   | Open an interactive shell in the container |
| `make restart` | `down` then `up`                      |
| `make logs`    | Follow container logs                    |
| `make prune`   | Full cleanup — remove container, images, and volumes |

## Files

- `docker-compose.yml` — service definition using `node:22-alpine`
- `Makefile` — convenience wrappers around compose commands

## Notes

There is no `Dockerfile` or application code — the container uses the pre-built `node:22-alpine` image directly. Add app files or change the service command in `docker-compose.yml` as needed.
