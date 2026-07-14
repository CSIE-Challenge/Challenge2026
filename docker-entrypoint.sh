#!/usr/bin/env sh
set -eu

GODOT_BIN="${GODOT_BIN:-godot}"
GODOT_PROJECT_PATH="${GODOT_PROJECT_PATH:-/app}"
IMPORT_MARKER="${GODOT_PROJECT_PATH}/.godot/global_script_class_cache.cfg"

if [ -f "$IMPORT_MARKER" ] && [ -s "$IMPORT_MARKER" ]; then
    echo "[entrypoint] Godot import cache found, skipping import."
else
    echo "[entrypoint] Godot import cache not found or empty, running import..."
    "$GODOT_BIN" --headless --import --path "$GODOT_PROJECT_PATH"
    echo "[entrypoint] Godot import complete."
fi

./set_upload.sh 0
exec dumb-init -- node matchmaker/server.js
