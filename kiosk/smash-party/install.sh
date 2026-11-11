#!/usr/bin/env bash
# Install Smash Party (the browser game) as a jar under the games folder:
#   kiosk/smash-party/install.sh [source] [root]
# source: a local checkout of smash-party, or a git URL (default: the GitHub repo, shallow clone).
# root:   the games folder (default $OPENJAR_ROOT, else ~/Games/openjar).
# Re-run it to update. It only ever writes <root>/smash-party/. The Godot rebuild, once it ships
# Releases, is pulled by openjar-tv/update.sh into the same folder and replaces this one.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
src="${1:-https://github.com/Beergut-Brian/smash-party.git}"
root="${2:-${OPENJAR_ROOT:-$HOME/Games/openjar}}"
dest="$root/smash-party"
if [[ -f "$dest/.release" ]]; then
  echo "install.sh: $dest holds a released build ($(cat "$dest/.release")); leaving it alone" >&2
  exit 1
fi
mkdir -p "$dest/store"
stage="$dest/.game-new"
rm -rf "$stage"
if [[ -d "$src" ]]; then
  mkdir -p "$stage"
  tar -C "$src" --exclude=.git --exclude=tools --exclude=agents --exclude=node_modules -cf - . | tar -C "$stage" -xf -
else
  git clone --quiet --depth 1 "$src" "$stage"
  rm -rf "$stage/.git"
fi
[[ -f "$stage/index.html" ]] || { echo "install.sh: no index.html in $src" >&2; rm -rf "$stage"; exit 2; }
rm -rf "$dest/game"
mv "$stage" "$dest/game"
cp "$here/openjar.json" "$here/smash-party.sh" "$dest/"
cp "$here/store/jar.tscn" "$dest/store/"
chmod +x "$dest/smash-party.sh"
echo "installed Smash Party $(grep -o '"version": *"[^"]*"' "$dest/game/version.json" 2>/dev/null | cut -d'"' -f4) in $dest"
