#!/usr/bin/env bash
# Runs the addon's tests headless in tests/project (a Godot project of its own).
#   tests/run.sh                 every suite in tests/suites
#   tests/run.sh suites/test_split.gd
# GDUNIT4=<path to an addons/gdUnit4 folder> (default: the template's local install).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)/project"
gd="${GDUNIT4:-$HOME/openjar/openjar-template/addons/gdUnit4}"
mkdir -p "$here/addons"
[ -e "$here/addons/openjar" ] || ln -s ../../.. "$here/addons/openjar"
if [ ! -e "$here/addons/gdUnit4" ]; then
	[ -f "$gd/plugin.cfg" ] || { echo "gdUnit4 not found at $gd (set GDUNIT4=...)" >&2; exit 2; }
	ln -s "$gd" "$here/addons/gdUnit4"
fi
godot --headless --path "$here" --import 2>&1 | grep -E "ERROR|WARNING" || true
godot --headless --path "$here" -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --continue -a "${1:-suites}"
