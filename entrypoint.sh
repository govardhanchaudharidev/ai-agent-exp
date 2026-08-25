#!/bin/sh
# Entrypoint for the FreeToken container.
#
# Dispatch rules for the command the container is started with:
#   (none)         -> `ft serve` driven by FT_MODEL / FT_HOST / FT_PORT /
#                     FT_SERVE_ARGS from the environment (.env)
#   serve [flags]  -> same, keeping your extra flags
#   ft …           -> executed verbatim
#   anything else  -> `ft <args>`  (shell, ctl, launch, checkpoint, bench,
#                                   --version, …)
# For a raw shell use: docker compose run --rm --entrypoint /bin/bash ft
set -eu

HOST="${FT_HOST:-0.0.0.0}"
PORT="${FT_PORT:-1919}"

if [ "$#" -eq 0 ]; then
    MODEL="${FT_MODEL:?FT_MODEL is not set — add it to .env (ids: FreeToken/docs/models.md)}"
    # Unquoted FT_SERVE_ARGS is deliberate: it is a user-supplied flag list.
    # shellcheck disable=SC2086
    exec ft serve --model "$MODEL" --host "$HOST" --port "$PORT" ${FT_SERVE_ARGS:-}
fi

case "$1" in
    ft)    exec "$@" ;;
    serve) shift
           exec ft serve --host "$HOST" --port "$PORT" "$@" ;;
    *)     exec ft "$@" ;;
esac