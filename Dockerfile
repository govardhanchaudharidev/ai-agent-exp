# syntax=docker/dockerfile:1

###############################################################################
# pi_agent_rust — https://github.com/Dicklesworthstone/pi_agent_rust
#
# Multi-stage build:
#   Stage 1 (builder): pinned nightly-2026-07-05 toolchain, release build of `pi`
#   Stage 2 (runtime): slim Debian image with just the binary + agent tooling
#
# Build context is this repository root; the upstream source is expected in
# ./pi_agent_rust (a clone of the GitHub repo).
###############################################################################

# ---------------------------------------------------------------------------
# Stage 1 — Builder
# ---------------------------------------------------------------------------
# The base image ships gcc/git/ca-certificates and a stable bootstrap cargo.
# The nightly pinned in rust-toolchain.toml (nightly-2026-07-05) is downloaded
# automatically by rustup on the first cargo invocation.
FROM rust:1-bookworm AS builder

# vergen-gix collects git metadata for build.rs; providing values up-front lets
# the build succeed without a .git directory inside the image.
ARG VERGEN_GIT_SHA=docker-build

# Upstream pins lto=true / codegen-units=1 (tiny binaries, very slow builds).
# These ARGs relax that for practical container build times; set
# RELEASE_LTO=true to reproduce the exact upstream release profile.
ARG RELEASE_LTO=false
ARG RELEASE_CODEGEN_UNITS=16

ENV CARGO_TERM_COLOR=never \
    CARGO_PROFILE_RELEASE_LTO=${RELEASE_LTO} \
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS=${RELEASE_CODEGEN_UNITS} \
    VERGEN_GIT_SHA=${VERGEN_GIT_SHA} \
    VERGEN_GIT_DIRTY=false

# ring / zstd-sys / onig_sys compile bundled C sources (cc + make come with
# build-essential); pkg-config locates system libraries. rquickjs uses
# pre-generated bindings on Linux, so libclang/bindgen is NOT required.
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy the upstream source tree. build.rs embeds CHANGELOG.md plus files from
# docs/ and legacy_pi_mono_code/ — keep those in the build context
# (see .dockerignore).
COPY pi_agent_rust/ ./

# Build the `pi` binary. Cache mounts keep the cargo registry/git checkouts and
# the target directory warm across rebuilds; the finished binary is copied out
# of the cache-mounted target dir within the same RUN step.
RUN --mount=type=cache,id=cargo-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=cargo-git,target=/usr/local/cargo/git \
    --mount=type=cache,id=pi-target,target=/build/target \
    cargo build --release --bin pi \
    && cp target/release/pi /usr/local/bin/pi

# ---------------------------------------------------------------------------
# Stage 2 — Runtime
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim AS runtime

# Match the host user so files created in the bind-mounted workspace keep sane
# ownership (defaults fit uid/gid 1000).
ARG UID=1000
ARG GID=1000

# Tools the agent shells out to during coding sessions.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates bash git ripgrep less procps curl jq python3 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g "${GID}" pi \
    && useradd -m -u "${UID}" -g "${GID}" -s /bin/bash pi \
    && mkdir -p /workspace /home/pi/.pi \
    && chown -R pi:pi /workspace /home/pi

COPY --from=builder /usr/local/bin/pi /usr/local/bin/pi

USER pi
WORKDIR /workspace

# Bare `docker compose run pi` starts the interactive TUI in /workspace;
# extra args are appended (e.g. `docker compose run --rm pi -p "summarize"`).
ENTRYPOINT ["/usr/local/bin/pi"]
