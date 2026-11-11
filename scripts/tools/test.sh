#!/usr/bin/env bash
# The gdUnit4 run with every user path in this checkout's .scratch/: user:// (saves, the test picks
# file) and the shared players.json (<XDG_DATA_HOME>/openjar/) never touch the real ones.
#   scripts/tools/test.sh [extra GdUnitCmdTool args]
set -uo pipefail
cd "$(dirname "$0")/../.."
S="$PWD/.scratch/xdg"
mkdir -p "$S/godot" "$PWD/.scratch/xdgc"
T="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates"   # exports still find the templates
[[ -d "$T" && ! -e "$S/godot/export_templates" ]] && ln -s "$T" "$S/godot/export_templates"
export XDG_DATA_HOME="$S" XDG_CONFIG_HOME="$PWD/.scratch/xdgc"
godot --headless --path . --import >/dev/null 2>&1
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --ignoreHeadlessMode --continue "$@"
