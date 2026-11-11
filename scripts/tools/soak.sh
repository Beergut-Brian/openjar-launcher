#!/usr/bin/env bash
# Soak the launcher: a scripted session on a loop (walk to a jar, launch it, come back, change
# character, P2 drops in and out, profile swap) for SECONDS, logging engine monitors every EVERY s.
#   scripts/tools/soak.sh [seconds=1800] [log=.scratch/soak/soak.tsv] [every=10]
#   SOAK_HEADLESS=1 scripts/tools/soak.sh ...   # no renderer: full speed, for leaks
#   SOAK_RES=960x540 scripts/tools/soak.sh ...  # smaller frames (the software GPU does ~3 fps at 1080p)
# Uses the fixture jars (tests/fixtures/hub_8, games that exit at once) and keeps user data in
# .scratch/xdg, so no real save or shared picks file is touched. Renders like shots.sh (godot-render
# when it exists, else the real display). The summary line at the end comes from Debug.gd.
set -euo pipefail
SECS="${1:-1800}"; LOG="${2:-$PWD/.scratch/soak/soak.tsv}"; EVERY="${3:-10}"
mkdir -p "$(dirname "$LOG")" "$PWD/.scratch/xdg"
# one 40 s cycle per jar, round and round; P2 is in for cycles 2-4 of every 6
script="follow"
t=1; n=0
while (( t < SECS )); do
  jar=$(( n % 8 ))
  case $(( n % 6 )) in
    1) script+=";$((t)):p2" ;;
    4) script+=";$((t)):p2off" ;;
  esac
  script+=";$((t+1)):go:$jar;$((t+8)):a;$((t+22)):change;$((t+25)):change2;$((t+28)):swap;$((t+31)):walk:0.7:0.4:1.5;$((t+34)):a"
  t=$(( t + 40 )); n=$(( n + 1 ))
done
if [[ -n "${SOAK_HEADLESS:-}" ]]; then RUN="godot --headless"
elif command -v godot-render >/dev/null; then RUN=godot-render
elif [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then RUN=godot
else RUN="godot --headless"; fi
export XDG_DATA_HOME="$PWD/.scratch/xdg" OPENJAR_ROOT="$PWD/tests/fixtures/hub_8" HUB_DEMO="$script"
$RUN --path . --resolution "${SOAK_RES:-1920x1080}" -- --soak-log="$LOG" --soak-every="$EVERY" --soak-seconds="$SECS"
