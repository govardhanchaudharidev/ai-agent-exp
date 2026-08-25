# ai-agent-exp

Runs [FreeToken](https://github.com/FlashML-org/FreeToken) — an edge-native MoE
LLM **serving engine** — inside Docker Compose. The engine exposes
OpenAI-compatible (`/v1/chat/completions`, `/v1/responses`, `/v1/models`) and
Anthropic-compatible (`/v1/messages`) APIs on port **1919**, so any client or
coding agent that speaks either protocol can be pointed at it.

The upstream source lives in [`./FreeToken`](./FreeToken) (shallow clone); the
container build and runtime configuration live in this directory.

## Prerequisites

Docker Engine + the compose plugin:

```bash
sudo apt install docker.io docker-compose-v2
sudo usermod -aG docker "$USER"   # then log out & back in (or newgrp docker)
```

An NVIDIA GPU (RTX 30/40/50 series supported) with driver **r580+** (CUDA 13):

```bash
nvidia-smi   # check driver version
```

And the NVIDIA container runtime so containers can reach the GPU:

```bash
sudo apt install nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
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
[ -d FreeToken ] || git clone --depth 1 \
    https://github.com/FlashML-org/FreeToken.git FreeToken

# 1. Create your config from the committed sample, then pick a model to serve —
#    a Hugging Face repo id, or a local checkpoint in ./models referenced as
#    /models/<name> (full HF dir; GGUFs unsupported). Model sizing guidance is
#    in the sample + README "Limitations"; full list: FreeToken/docs/models.md
cp -n .env.example .env && $EDITOR .env    # e.g. FT_MODEL=openai/gpt-oss-20b

# 2. Build the image (first build downloads the torch/cu130 wheels and compiles
#    FreeToken's CUDA extensions against the toolkit; expect roughly 15-45
#    minutes, far less on rebuilds thanks to cache mounts):
docker compose build

# 3. Start the server in the background:
docker compose up -d ft            # or: make serve
```

## Usage

With `make` (recommended — see `make help`):

| Command | What it does |
|---|---|
| `make doctor` | Verify docker/compose/daemon/GPU/runtime/source clone/model |
| `make build` | Build the image (cached) |
| `make rebuild` | Full rebuild without cache |
| `make update` | Pull latest upstream source + rebuild |
| `make serve` | Start the API server in the background |
| `make logs` | Follow server logs (model load progress) |
| `make health` | `GET /health` — status + load progress |
| `make models` | `GET /v1/models` — served model id |
| `make query P="..."` | One-shot test chat completion via curl |
| `make chat` | Interactive `ft shell` attached to the server |
| `make shell` | Bash inside the runtime image |
| `make version` | Print the `ft` CLI version |
| `make status` | List project containers |
| `make stop` | Stop the server (restartable) |
| `make down` | Remove containers (keeps model caches) |
| `make destroy` | ⚠ Also wipes `hf_cache`/`ft_cache` volumes (models re-download!) |

Equivalent raw commands:

```bash
docker compose up -d ft                     # serve in the background
docker compose logs -f ft                   # wait for "API server is ready"
curl http://localhost:1919/v1/models        # served model id
```

Talk to it with either API dialect:

```bash
# OpenAI-style
curl http://localhost:1919/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"openai/gpt-oss-20b","messages":[{"role":"user","content":"hi"}]}'

# Anthropic-style
curl http://localhost:1919/v1/messages \
  -H 'Content-Type: application/json' \
  -d '{"model":"openai/gpt-oss-20b","max_tokens":128,"messages":[{"role":"user","content":"hi"}]}'
```

Point existing tools at it:

```bash
# Claude Code against the local Anthropic-compatible endpoint:
ANTHROPIC_BASE_URL=http://localhost:1919 ANTHROPIC_AUTH_TOKEN=local claude

# Any OpenAI SDK / coding CLI: base URL http://localhost:1919/v1

# Or let FreeToken configure & launch an agent inside the container
# (works on files in ./workspace, mounted at /workspace):
docker compose run --rm ft launch claude     # codex/opencode/dsh/hermes/…
```

Everything under `./workspace/` is what in-container agent sessions see as
`/workspace`; downloaded models persist in the named volume `hf_cache`
(`~/.cache/huggingface` inside the container).

## Updating the vendored source

```bash
git -C FreeToken fetch --depth 1 origin main
git -C FreeToken reset --hard FETCH_HEAD
docker compose build                 # cached layers make this quick
```

(or just `make update`)

## Limitations

Check these *before* spending hours downloading a 20 GB file:

- **Checkpoint format — no generic GGUF support.** FreeToken loads Hugging
  Face safetensors checkpoints (BF16, FP8, NVFP4, MXFP4). GGUF loading exists
  **for Gemma-4 only** (`FreeToken/docs/models.md`; the loader is
  `python/freetoken/models/gemma4/gguf.py`). A llama.cpp quant such as
  `Qwen3.6-35B-A3B-UD-Q4_K_M.gguf` placed in `./models/` will NOT load — serve
  that file with llama.cpp/Ollama instead, and pick an HF repo id in `.env`
  for this stack.

- **MoE offload keeps ALL experts in host RAM.** The default `offload` backend
  pins every expert weight in system memory and streams the hot subset to the
  GPU over PCIe (only an LRU slice lives in VRAM). There is no
  stream-from-disk mode, so system RAM — not VRAM — is usually the binding
  constraint. Approximate sizing:

  | Checkpoint | Download | Pinned experts | Comfortable host RAM |
  |---|---|---|---|
  | `openai/gpt-oss-20b` (MXFP4) | ~13 GB | ~11 GB | 32 GB |
  | `Qwen/Qwen3.6-35B-A3B-FP8` | ~35 GB | ~30 GB | 64 GB |
  | `Qwen/Qwen3.6-35B-A3B` (BF16) | ~70 GB | ~62 GB | 96 GB |

  Measured example: a 12 GB GPU (RTX 3080 Ti) + 32 GB RAM serves gpt-oss-20b
  comfortably, but the 35B-A3B tier OOMs while loading expert banks.

- **NVFP4 checkpoints are Blackwell-first.** Running NVFP4 (e.g.
  `nvidia/Qwen3.6-35B-A3B-NVFP4`) on pre-Blackwell GPUs needs the Marlin
  W4A16 path, which requires `vllm>=0.14,<0.15` installed separately (see the
  note in `FreeToken/pyproject.toml`) — deliberately absent from this image.
  Use the FP8/BF16 variants unless you're on an RTX 50.

## Notes

- **Image size**: the runtime keeps the *devel* CUDA toolkit on purpose —
  FreeToken JIT-compiles uncovered CUDA kernels on first use, which needs
  `nvcc`. Expect ~22 GB on disk (~7.5 GB compressed): CUDA devel base +
  torch/cu130 + sglang-kernel/flashinfer. Inherent to a GPU serving stack,
  not a bug.

- **First start**: the chosen checkpoint downloads into the `hf_cache` volume
  (can be tens of GB), then kernels JIT-warm up. Later starts are much faster;
  warm-up artifacts persist in `ft_cache`. To shift some cost from first-start
  to build-time, prebuild the kernel-cache wheel:

  ```bash
  docker compose build --build-arg FREETOKEN_PREBUILD_KERNEL_CACHE=true
  ```

- **Model sizing**: MoE checkpoints default to the `offload` backend — experts
  stream from host RAM over PCIe with an LRU slice on GPU, so big models run on
  modest cards. Run `docker compose run --rm ft bench bw` once per machine to
  let `--moe-backend auto` pick `hybrid` when beneficial. See
  `FreeToken/docs/models.md`.

- **Tuning**: put extra `ft serve` flags in `.env`, e.g.
  `FT_SERVE_ARGS=--gpu 1 --max-running-requests 2`. All flags:
  `FreeToken/docs/cli.md`.

- **Gated models** (e.g. Gemma): accept the license on Hugging Face and set
  `HF_TOKEN=` in `.env`.

- **`ipc: host`**: inference engines share tensors through shared memory; the
  host IPC namespace avoids `/dev/shm` limits. Remove it in a compose override
  if your threat model dislikes it.

- **Local checkpoints**: place them in `./models/` and set
  `FT_MODEL=/models/<name>` to skip downloading. `<name>` must be a **full HF
  checkpoint directory** (`config.json` + `*.safetensors` + tokenizer files);
  a lone `.gguf` file is ignored by the engine (see Limitations above).

