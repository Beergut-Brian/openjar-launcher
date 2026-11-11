# openjar-addons

Shared Godot 4 addon for every Open Jar Games title. Games pull it in as a git submodule at
`addons/openjar/`, pinned to a tag:

```
git submodule add https://github.com/Beergut-Brian/openjar-addons addons/openjar
cd addons/openjar && git checkout v0.2.0
git submodule add https://github.com/Beergut-Brian/openjar-characters addons/openjar/characters
```

## Layout and mount

**The repository root is the addon root.** A game mounts the whole repo at `addons/openjar/`, so
every file here appears in the game at `res://addons/openjar/<path>`:

```
openjar-addons/ (repo)          ->  <game>/addons/openjar/ (submodule)
  plugin.cfg, plugin.gd         ->  res://addons/openjar/plugin.cfg
  tileworld/tile_world.gd       ->  res://addons/openjar/tileworld/tile_world.gd
  split_screen/, cutscene/, picto_bubble/, theme/, ui/, launcher/
  docs/                         ->  markdown only, nothing to import
  tests/                        ->  skipped by the game (tests/.gdignore); holds the addon's own
                                    test project, see "Testing the addon"
```

Up to v0.1.0 the files sat under `addons/openjar/` inside this repo, which would have mounted as
`res://addons/openjar/addons/openjar/...`; 0.2.0 moves them to the root (see Decisions).

## What belongs here

Only things that are identical across games and that the template would otherwise copy:

| Folder | Holds | Status |
| --- | --- | --- |
| `tileworld/` | `TileWorld`: chunked diggable tile world, rect or disk shape, water, falling bodies, darkness, edit-only saves | 0.2.0 |
| `split_screen/` | `ScreenDirector`: dynamic two-player split across several 2D scenes | 0.2.0 |
| `cutscene/` | `CutscenePlayer`: data-driven cutscenes behind a host interface (`docs/cutscene-format.md`) | 0.2.0 |
| `picto_bubble/` | `PictoBubble`: wordless picture speech bubbles, game pictures by registration | 0.2.0 |
| `theme/` | The big-button UI theme (`openjar_theme.tres`), fonts, P1/P2 colour constants | TODO: first real asset from the launcher |
| `ui/` | Pause menu, restart prompt, profile picker scenes used as-is by every game | TODO |
| `launcher/` | `openjar_manifest.gd`: writes `store/openjar.json` at export; `launcher_bridge.gd`: reads `--profile=` and exits cleanly | TODO |
| `characters/` | Submodule → `openjar-characters` | wire up after first tag |

The autoloads (`Players`, `Game`, `Save`, `Audio`, `Debug`) live in the **template**, not here, so a
game can edit them freely. If one proves identical across three games, move it here then.

Public API per module: `docs/contracts.md`; history: `CHANGELOG.md`. The modules use
`class_name` globals (`TileWorld`, `ScreenDirector`, `CutscenePlayer`, `PictoBubble`, ...), so a
game must not define classes with the same names. No module names an autoload in code.

## Testing the addon

The addon is tested on its own, outside any game:

```
tests/run.sh                          # every suite in tests/project/suites; exit 0 = green
tests/run.sh suites/test_split.gd     # one suite
GDUNIT4=/path/to/addons/gdUnit4 tests/run.sh
```

`tests/project/` is a Godot project of its own. `tests/run.sh` symlinks the repo root in as
`res://addons/openjar` (so paths match a game exactly) and a local gdUnit4 (gitignored, installed
per machine like the template's; default `~/openjar/openjar-template/addons/gdUnit4`), imports, and
runs `GdUnitCmdTool.gd --ignoreHeadlessMode --continue`. `tests/.gdignore` hides `tests/` from a
consuming game (and stops the symlink recursing). Demos run there too, e.g.
`godot --path tests/project res://addons/openjar/tileworld/demo/shape_demo.tscn -- --shape=disk`;
add `-- --shots=2,4 --shot-dir=<abs dir>` under `godot-render` for real frames
(`tests/project/tools/shots.gd`).

## Rules
- Never break a tagged version. Games pin tags; bump the tag when anything changes.
- No game-specific logic. If only one game needs it, it goes in that game.
- Godot 4.7.2, same guardrails as the template `CLAUDE.md`.

## Decisions

- 2026-11-10: the repo root is the addon root (plugin.cfg at the top), because games mount the
  repo itself at `addons/openjar/` and The Hill already references `res://addons/openjar/<module>/`.
- 2026-11-10: the test harness is `tests/project/` (its own project.godot) behind `tests/.gdignore`,
  with the addon linked in by `tests/run.sh`. A `project.godot` directly in `tests/` also works
  but makes every game's editor log "Detected another project.godot ... will be ignored".
- 2026-11-10: tileworld and split_screen copied verbatim (they were already game-agnostic), with
  their `.uid` files, so The Hill's uid references keep resolving after it adopts the submodule.
- 2026-11-10: `CutscenePlayer` keeps The Hill's data paths as defaults (`res://data/cutscenes/`,
  `res://data/story/lines.json`, `res://assets/story/voice/`), now static vars a game can change.
  Sound goes to host methods, else a runtime-found `Audio` node, never a compile-time autoload, so
  the addon parses in a project without the template autoloads. Sound cue names are generic
  (`cutscene_start`, ...); The Hill sets its own (`split`, `pop`, `jump`, `resident_hm`).
- 2026-11-10: `PictoBubble` keeps game-neutral pictures; Hill-only ones (deed, shaft, wall, ice,
  shaken_hill, building/vehicle sprites via `SpriteArt`) move to a registry the game fills.
- 2026-11-10: The Hill's `test_story_cutscenes.gd` is not ported (it drives `HillGame`/`HillStory`);
  `test_cutscene.gd` covers the player against the demo host instead.
