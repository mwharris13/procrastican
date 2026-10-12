#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# Refresh the class cache so the baker's class_name resolves, then bake and re-import the PNGs.
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --script tools/bake_art.gd
godot --headless --path . --import >/dev/null 2>&1 || true
