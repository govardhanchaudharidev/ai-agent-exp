# ai-agent-exp

Runs [pi_agent_rust](https://github.com/Dicklesworthstone/pi_agent_rust) — a
native AI coding agent CLI written in Rust — inside Docker Compose.

The upstream source lives in [`./pi_agent_rust`](./pi_agent_rust) (shallow
clone); the container build and runtime configuration live in this directory.

## Prerequisites

Docker Engine + the compose plugin (not installed by default on this machine):

```bash
sudo apt install docker.io docker-compose-v2
sudo usermod -aG docker "$USER"   # then log out & back in (or newgrp docker)
```

> **`permission denied ... /var/run/docker.sock` in one terminal but not
> another?** Group membership is snapshotted at login: terminals opened
> *before* the `usermod -aG docker` step can't reach the daemon, while apps
> restarted *after* it (e.g. VS Code) work. In the affected terminal run
> `newgrp docker`, or `sg docker -c 'make build'`; the permanent fix is to
> fully log out of the desktop session and back in (or reboot). The Makefile
> detects this condition and prints these hints automatically.

## Setup

```bash
# 0. Fetch the upstream source if missing (kept out of git):
[ -d pi_agent_rust ] || git clone --depth 1 \
    https://github.com/Dicklesworthstone/pi_agent_rust.git pi_agent_rust
# 1. Point the agent at your project files (anything you put here is what the
#    agent sees as /workspace inside the container):
cp -r /path/to/your-project/. workspace/

# 2. Add at least one provider API key:
$EDITOR .env                       # e.g. uncomment ANTHROPIC_API_KEY=...

# 3. Build the image (first build downloads the pinned nightly toolchain
#    nightly-2026-07-05 and compiles the dependency graph; expect roughly
#    10-30 minutes on 12 cores, far less on rebuilds thanks to cache mounts):
docker compose build
```

## Usage

With `make` (recommended — see `make help`):

| Command | What it does |
|---|---|
| `make doctor` | Verify docker/compose/daemon/source clone/API key |
| `make build` | Build the image (cached) |
| `make rebuild` | Full rebuild without cache |
| `make update` | Pull latest upstream source + rebuild |
| `make tui` | Interactive agent session in `./workspace` |
| `make continue` | Resume the last session |
| `make ask P="..."` | One-shot non-interactive prompt |
| `make shell` | Bash inside the runtime image |
| `make status` | List project containers |
| `make down` | Remove containers (keeps sessions volume) |
| `make destroy` | ⚠ Also wipes the `pi_home` sessions/settings volume |

Equivalent raw commands:

Interactive TUI session:

```bash
docker compose run --rm pi
```

One-shot, non-interactive prompt (`-p/--print`):

```bash
docker compose run --rm pi -p "Explain what this repo does"
```

Useful flags (see `docker compose run --rm pi --help`):

```bash
docker compose run --rm pi --model claude-opus-4 -p "Fix the failing test"
docker compose run --rm pi --continue   # resume the previous session
```

Everything the agent writes lands in `./workspace/` on the host; settings,
sessions and skills persist in the named volume `pi_home`
(`~/.pi/agent` inside the container).

## Updating the vendored source

```bash
git -C pi_agent_rust fetch --depth 1 origin main
git -C pi_agent_rust reset --hard FETCH_HEAD
docker compose build                 # cached layers make this quick
```

## Notes

- **Build profile**: upstream pins `lto=true` / `codegen-units=1`, which makes
  release builds extremely slow. The Dockerfile defaults to
  `RELEASE_LTO=false`, `RELEASE_CODEGEN_UNITS=16` for tractable build times.
  Reproduce the exact upstream profile with:

  ```bash
  docker compose build --build-arg RELEASE_LTO=true
  ```

- **vergen**: `build.rs` normally reads git metadata; the image sets
  `VERGEN_GIT_SHA`/`VERGEN_GIT_DIRTY` so no `.git` directory is needed inside
  the build. Override with `--build-arg VERGEN_GIT_SHA=<sha>`.

- **Files embedded at compile time**: `build.rs` embeds `CHANGELOG.md`,
  two JSON files from `docs/` and
  `legacy_pi_mono_code/pi-mono/packages/ai/src/models.generated.ts` — keep
  them in the build context (the provided `.dockerignore` already does).

