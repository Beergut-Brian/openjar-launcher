#!/usr/bin/env bash
# Usage: scripts/tools/rename_project.sh "Ball Kicker" ball-kicker
set -euo pipefail
NAME="${1:?display name}"; SLUG="${2:?slug}"
sed -i "s|config/name=\".*\"|config/name=\"$NAME\"|" project.godot
sed -i "s|export_path=\"build/.*\"|export_path=\"build/$SLUG.x86_64\"|" export_presets.cfg
sed -i "1s|.*|# $NAME|" GAME.md
echo "Renamed to $NAME ($SLUG). Now fill in GAME.md and docs/art-direction.md."
