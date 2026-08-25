# syntax=docker/dockerfile:1

###############################################################################
# FreeToken — https://github.com/FlashML-org/FreeToken
#
# Multi-stage build:
#   Stage 1 (builder): CUDA 13 toolkit + Python 3.12 + uv; installs the
#                      `freetoken` package (the `ft` CLI) into /opt/ft
#   Stage 2 (runtime): same CUDA devel base (nvcc must stay available because
#                      FreeToken JIT-compiles kernels on first use), non-root
#                      user, entrypoint that serves FT_MODEL by default
#
# Build context is this repository root; the upstream source is expected in
# ./FreeToken (a clone of the GitHub repo).
###############################################################################

ARG CUDA_VERSION=13.0.3
ARG UBUNTU_VERSION=24.04

# ---------------------------------------------------------------------------
# Stage 1 — Builder
# ---------------------------------------------------------------------------
# The -devel image ships nvcc + gcc/g++, required to build FreeToken's
# C++/CUDA extension modules (setup.py links against libtorch + cudart) and,
# later at runtime, for first-use JIT of kernels not covered by the wheel.
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION} AS builder

ARG CUDA_VERSION
ARG UBUNTU_VERSION
# Optional: also prebuild the multi-arch "kernel cache" wheel during the image
# build (much slower build, noticeably faster first server start). See README.
ARG FREETOKEN_PREBUILD_KERNEL_CACHE=false

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential ninja-build git ca-certificates \
        python3 python3-venv python3-dev \
    && rm -rf /var/lib/apt/lists/*

# uv drives the install (upstream's recommended method); the static binaries
# need no dependencies of their own.
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Ubuntu 24.04's system python IS 3.12 — the interpreter upstream targets.
# unsafe-best-match mirrors upstream install.sh: the extra indexes carry the
# cu130 torch/sglang-kernel wheels and flashinfer's prebuilt-kernel channel.
# UV_HTTP_TIMEOUT: uv's default 30s per-request timeout can abort the whole
# install when a slow/flaky registry link stalls metadata fetches (a cold
# build here died ~128s in that way) — give requests more slack.
ENV UV_PYTHON=/usr/bin/python3 \
    UV_LINK_MODE=copy \
    UV_INDEX_STRATEGY=unsafe-best-match \
    UV_HTTP_TIMEOUT=120

WORKDIR /build

# Copy the upstream source tree. setup.py compiles python/freetoken/kernel/csrc
# against the CUDA toolkit; pyproject.toml embeds README.md + LICENSE — all are
# kept in the build context (see .dockerignore).
COPY FreeToken/ ./

# Install freetoken + native kernel extras into a self-contained venv.
# Cache mount keeps the (large) cu130 wheel downloads warm across rebuilds.
RUN --mount=type=cache,id=uv-cache,target=/root/.cache/uv \
    uv venv /opt/ft \
    && uv pip install --python /opt/ft/bin/python \
        --extra-index-url https://download.pytorch.org/whl/cu130 \
        --extra-index-url https://docs.sglang.io/whl/cu130 \
        --extra-index-url https://flashinfer.ai/whl \
        --extra-index-url https://flashinfer.ai/whl/cu130 \
        ".[accel]"

# Optional kernel-cache prebuild: without it the engine JIT-compiles uncovered
# kernels at first server start (works — nvcc is in the image — just slower).
RUN if [ "${FREETOKEN_PREBUILD_KERNEL_CACHE}" = "true" ]; then \
        uv build --wheel --out-dir /build/dist freetoken-kernel-cache \
        && uv pip install --python /opt/ft/bin/python \
            /build/dist/freetoken_kernel_cache-*.whl ; \
    else \
        echo "Skipping kernel-cache prebuild (FREETOKEN_PREBUILD_KERNEL_CACHE != true)" ; \
    fi

# ---------------------------------------------------------------------------
# Stage 2 — Runtime
# ---------------------------------------------------------------------------
# Same devel base ON PURPOSE: FreeToken JIT-compiles CUDA kernels on first use
# (needs nvcc + g++ on PATH). Expect a large image — inherent to a GPU serving
# stack that bundles the CUDA toolkit plus torch/cu130.
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION} AS runtime

ARG CUDA_VERSION
ARG UBUNTU_VERSION

# Match the host user so files created in bind mounts keep sane ownership
# (defaults fit uid/gid 1000).
ARG UID=1000
ARG GID=1000

# Tools used while operating/debugging the server.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates bash git curl jq less procps python3 \
    && rm -rf /var/lib/apt/lists/*

# Create the ft user mapped to the host's uid/gid. Ubuntu 24.04 bases ship a
# stock 'ubuntu' user/group at uid/gid 1000 — evict whoever occupies the
# requested ids first, or groupadd/useradd fail with "already exists".
RUN set -eux; \
    if getent passwd ubuntu >/dev/null; then userdel --remove ubuntu; fi; \
    if getent group ubuntu >/dev/null; then groupdel ubuntu; fi; \
    if getent group "${GID}" >/dev/null; then \
        groupdel "$(getent group "${GID}" | cut -d: -f1)"; \
    fi; \
    if getent passwd "${UID}" >/dev/null; then \
        userdel --remove "$(getent passwd "${UID}" | cut -d: -f1)"; \
    fi; \
    groupadd -g "${GID}" ft; \
    useradd -m -u "${UID}" -g "${GID}" -s /bin/bash ft; \
    mkdir -p /workspace /models /home/ft/.cache; \
    chown -R ft:ft /workspace /models /home/ft

# Self-contained venv from the builder (its python symlinks to /usr/bin/python3,
# the same interpreter present here). `ft` lands on PATH via the venv bin dir.
COPY --from=builder /opt/ft/ /opt/ft/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && ln -sf /opt/ft/bin/ft /usr/local/bin/ft

ENV PATH="/opt/ft/bin:${PATH}" \
    HF_HOME=/home/ft/.cache/huggingface

USER ft
WORKDIR /workspace

# Bare `docker compose up -d ft` serves FT_MODEL from .env; `ft shell`,
# `ft ctl`, `ft --version` etc. pass through — see entrypoint.sh.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]