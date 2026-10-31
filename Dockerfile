# =============================================================================
# Stage 1: install Rust toolchain, clone prime-agent, and build the release binary
# =============================================================================
FROM node:22.8-bookworm AS deps

ARG PRIME_AGENT_REPO=https://github.com/PrimeIntellect-ai/prime-agent.git
ARG PRIME_AGENT_REF=main

# Install system dependencies and Rust toolchain
RUN apt-get update && \
    apt-get install -y git curl build-essential pkg-config libssl-dev && \
    rm -rf /var/lib/apt/lists/* && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable

ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /app

RUN git clone --branch "${PRIME_AGENT_REF}" --single-branch "${PRIME_AGENT_REPO}" .

RUN cargo build --release

# =============================================================================
# Stage 2: runtime image with the built binary and runtime files
# =============================================================================
FROM node:22.8-bookworm

# Install runtime dependencies: python3, uv (required by prime-agent binary), git, curl
RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv git curl && \
    rm -rf /var/lib/apt/lists/* && \
    curl -LsSf https://astral.sh/uv/install.sh | sh

ENV PATH="/root/.local/bin:${PATH}"

WORKDIR /app

# Copy the built binary and runtime files from the build stage
COPY --from=deps /app/target/release/prime-agent /app/prime-agent
COPY --from=deps /app/prime-agent-runtime /app/prime-agent-runtime
COPY --from=deps /app/skills /app/skills

ENV PRIME_AGENT_CODING_AGENT_DIR=/app/data/config
ENV PRIME_AGENT_SESSION_DIR=/app/data/sessions

ENTRYPOINT ["/app/prime-agent"]
