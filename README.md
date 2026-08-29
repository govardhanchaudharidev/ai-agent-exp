# Prime Agent Experiment

This project provides an isolated, Docker-based environment for running an AI coding agent based on [Prime Intellect's prime-agent](https://github.com/PrimeIntellect-ai/prime-agent).

## Overview

- **Dockerfile**: Sets up a Node-based environment, installs necessary dependencies (Python, Git), clones the `prime-agent` repository, and builds it.
- **docker-compose.yml**: Defines the `prime-agent` service. It mounts the current directory into `/workspace` so the agent can interact with your local files and uses a `.env` file for configuration.
- **Makefile**: Provides convenient wrappers around `docker compose` for building, running, and managing the agent container.

## Configuration

Environment variables, such as API keys and model preferences, should be set in a `.env` file. You can copy the provided `sample.env` to get started:

```bash
cp sample.env .env
```

Update `.env` with your API keys (e.g., `OPENROUTER_API_KEY`).

## Usage

You can use the provided `make` commands to easily interact with the agent:

- **`make build`**: Build the docker image.
- **`make run`**: Run the agent interactively in your terminal.
- **`make up`**: Start the agent in the background.
- **`make shell`**: Open a bash shell inside the container for debugging.
- **`make logs`**: Tail the logs of the running agent.
- **`make down`**: Stop and remove the containers (keeps your data).
- **`make help`**: View all available commands.
