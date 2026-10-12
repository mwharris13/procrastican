#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/web
# Stop Godot from importing its own build output back into the project.
touch build/.gdignore
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-release "Web" build/web/index.html
# Keep link metadata and the CLI-written token file out of the public upload.
printf '.env*\n.gitignore\n' > build/web/.vercelignore
test -f build/web/index.html && test -f build/web/index.wasm
echo "Web build ready in build/web"
