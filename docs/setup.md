# Setup

## Godot

Pinned version: see `.godot-version`. Install that exact version (the standard build; use the
.NET build only if this game uses C# for hot paths). Put the binary on `PATH` as `godot`.

Offline docs: download the matching `godot-docs-html-stable.zip` from the Godot docs
releases, unzip to `~/godot-docs/<version>/`, and export `GODOT_DOCS=~/godot-docs/<version>`.
Agents read the API from there instead of guessing.

## gdUnit4

Install via the Asset Library or clone into `addons/gdUnit4/` (the folder is gitignored
except for `tests/`). Enable the plugin in Project Settings → Plugins.

## Shared addons

```
git submodule add https://github.com/Beergut-Brian/openjar-addons addons/openjar
git submodule update --init --recursive
```

Pin to a tag in `.gitmodules` before the first release.

## Export templates

`godot --headless --export-release "Linux" build/game.x86_64` needs the export templates for the
pinned version installed once per machine (Editor → Manage Export Templates). CI installs them
in `.github/workflows/release.yml`.

## New game from this template

1. GitHub → "Use this template" → `Beergut-Brian/<game>`.
2. Clone, then `scripts/tools/rename_project.sh "<Game Name>" <slug>`.
3. Fill in `GAME.md` and `docs/art-direction.md` (design sprint with Kaden).
4. Create the `dev` branch from `main`. Protect both.
5. Add the `openjar-game` topic to the repo so the TV updater finds it.
