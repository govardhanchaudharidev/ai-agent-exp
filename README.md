# Prime Agent Experiment

This project provides an isolated, Docker-based environment for running an AI coding agent based on [Prime Intellect's prime-agent](https://github.com/PrimeIntellect-ai/prime-agent).

## Overview

- **Dockerfile**: Multi-stage build for the Rust-based `prime-agent`. Stage 1 installs the Rust toolchain, clones `prime-agent`, and runs `cargo build --release`. Stage 2 copies the built binary and runtime files into a lean runtime image. Use build args to pin the `prime-agent` version.
- **docker-compose.yml**: Defines the `prime-agent` service. It mounts the current directory into `/workspace` so the agent can interact with your local files and uses a `.env` file for configuration.
- **Makefile**: Provides convenient wrappers around `docker compose` for building, running, and managing the agent container.

## Configuration

Environment variables, such as API keys and model preferences, should be set in a `.env` file. You can copy the provided `sample.env` to get started:

```bash
cp sample.env .env
```

Update `.env` with your API keys (e.g., `OPENROUTER_API_KEY`).

To pin a specific version of `prime-agent`, set `PRIME_AGENT_REF` to a branch, tag, or commit SHA (defaults to `main`). You can also override `PRIME_AGENT_REPO` to use a fork:

```bash
PRIME_AGENT_REPO=https://github.com/your-org/prime-agent.git
PRIME_AGENT_REF=v0.1.2
```

These are passed as Docker build args, so changing them triggers a rebuild of the affected stage.

## Usage

You can use the provided `make` commands to easily interact with the agent:

- **`make build`**: Build the docker image.
- **`make run`**: Run the agent interactively in your terminal.
- **`make up`**: Start the agent in the background.
- **`make shell`**: Open a bash shell inside the container for debugging.
- **`make logs`**: Tail the logs of the running agent.
- **`make down`**: Stop and remove the containers (keeps your data).
- **`make help`**: View all available commands.
