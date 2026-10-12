#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
# Import refreshes the class_name cache so new scripts are visible to tests.
godot --headless --path . --import >/dev/null 2>&1 || true
args=(-gexit)
if [[ "$*" != *-gtest=* ]]; then
	args+=(-gdir=res://test -ginclude_subdirs)
fi
log=$(mktemp)
godot --headless --path . -s addons/gut/gut_cmdln.gd "${args[@]}" "$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
# GUT only warns when a test script fails to load, so treat script errors as failures.
if grep -qE "SCRIPT ERROR|Parse Error" "$log"; then
	echo "run_tests: script errors detected, failing run"
	status=1
fi
rm -f "$log"
exit "$status"
