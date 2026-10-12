#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
./build_web.sh
vercel deploy --cwd build/web --prod --yes
