# Contracts

Shared signals and APIs that lanes code against. Systems lane owns this file. Change it in its
own PR before changing code; every other lane reads the merged version.

## Autoloads (always available)

### `Game` (`scripts/autoload/Game.gd`)

State machine for the whole session.

```gdscript
enum State { TITLE, PLAYING, PAUSED, ROUND_END }
var state: State
signal state_changed(from: State, to: State)
signal round_started(round_index: int)
signal round_ended(round_index: int, result: Dictionary)   # result is game-defined

func start_round() -> void
func end_round(result: Dictionary = {}) -> void
func pause() -> void
func resume() -> void
func restart() -> void          # back to a fresh round, no questions asked
```

### `Players` (`scripts/autoload/Players.gd`)

Who is holding which controller. Never read device ids directly.

```gdscript
const P1 := 0
const P2 := 1
const COLOR := { P1: Color("3cc24a"), P2: Color("e4393c") }   # green, red

signal player_joined(player: int, device: int)
signal player_left(player: int)

func is_active(player: int) -> bool
func device_of(player: int) -> int
func action(player: int, action: String) -> String   # "p1_move_left" etc. for Input.*
```

Input map actions (defined in `project.godot`, per player, prefix `p1_` / `p2_`):
`move_left`, `move_right`, `move_up`, `move_down`, `action`, `jump`.
Global: `pause`, `restart`, `debug_overlay`, `debug_screenshot`.

### `Save` (`scripts/autoload/Save.gd`)

JSON under `user://saves/<profile>.json`. Autosave at every natural stopping point.

```gdscript
var profile: String                 # set by the launcher via --profile=<id>, default "p1"
signal saved()
signal loaded()

func get_value(key: String, default = null)
func set_value(key: String, value) -> void   # marks dirty
func flush() -> void                         # writes if dirty; Game.end_round() calls this
func wipe() -> void
```

### `Audio` (`scripts/autoload/Audio.gd`)

```gdscript
func play(cue: String, position = null) -> void   # cue = file stem in assets/audio/sfx/
func music(track: String, fade: float = 0.5) -> void
func stop_music(fade: float = 0.5) -> void
func bark(character: String, bark: String) -> void   # from openjar-characters voice packs
func release_all() -> void                    # stop every player, drop streams and the cue cache
func quit(exit_code: int = 0) -> void         # release_all(), wait 0.1 s, then get_tree().quit()
```

Every action must call `Audio.play`. Missing cue files log a warning, never crash.
Quit with `Audio.quit()`, never `get_tree().quit()` directly: a stream still playing at quit is
reported as leaked at exit. The window close button goes through `Audio.quit()` as well
(`Audio` turns off `auto_accept_quit`).

### `Debug` (`scripts/autoload/Debug.gd`)

F3 toggles the overlay (fps, state, player count). F12 saves `user://screenshots/<timestamp>.png`
and prints the path. `--screenshot-after=<seconds>` CLI flag does it headlessly for the Reviewer.

## Launcher handshake

The launcher starts a game with `--profile=<id>` and expects the game to:

- read `store/openjar.json` at export time (name, version, card art, clip) — produced by CI;
- exit with code 0 on a clean quit (Start → Quit on the pause menu);
- not change display mode (the launcher owns fullscreen).

## Game-specific contracts

Add this game's own signals and APIs below. Keep the same format.

## Launcher

The `openjar-launcher` game. Other repos code against this section, not the launcher's code.

### `OPENJAR_ROOT`

Install root the launcher scans on boot. Env var; default `~/Games/openjar`. Every direct
subfolder holding an `openjar.json` is one game spot (a jar in the hub). The launcher's own folders
(`openjar-launcher`, `openjar-launcher-dev`) are skipped. Folders are sorted by name.

### Manifest: `<OPENJAR_ROOT>/<folder>/openjar.json`

Written by CI (`.github/workflows/release.yml`), or by hand for non-Godot entries.
All paths are relative to the manifest's folder.

```json
{ "slug": "smash-party", "name": "Smash Party", "version": "v1.2.0",
  "binary": "game.x86_64",
  "command": ["/usr/bin/chromium", "--kiosk", "http://localhost:8080"],
  "args": ["--fullscreen"],
  "grid": "store/grid.png", "hero": "store/hero.png", "clip": "store/clip.mp4",
  "dev": false }
```

| Key | Type | Required | Meaning |
| --- | --- | --- | --- |
| `slug` | string | no (defaults to folder name) | stable id; the launcher remembers the last game by slug |
| `name` | string | no (defaults to slug) | not shown in the hub (no text); kept for logs and tools |
| `version` | string | no | informational |
| `binary` | string | one of `binary` / `command` | executable, relative to the folder; must exist |
| `command` | array of strings | one of `binary` / `command` | `[program, arg...]`; `program` is resolved against the folder if that file exists, else used as-is (PATH lookup). Wins over `binary` if both are present |
| `args` | array of strings | no | extra arguments, appended after `--profile=` |
| `grid` | string | no | 600x900 poster shown inside the jar; missing file → a toy shape instead |
| `hero`, `clip` | string | no | 920x430 banner / looping clip (not used yet) |
| `dev` | bool | no (default `false`) | only shown when the dev toggle is on; the jar gets a dark lid with a beacon |

A manifest that is not valid JSON, is not an object, has neither a usable `binary` nor
`command`, or points at a missing `binary`, is skipped with a warning. The launcher never crashes
on a bad manifest.

### `--profile=<id>` handshake

The launcher starts an entry with `OS.create_process`:

- `binary`: `<folder>/<binary> --profile=<id> <args...>`
- `command`: `<program> <command[1:]...> --profile=<id> <args...>`

`<id>` is `p1` or `p2`: the Jarling that jumped into the jar (`p1` Jeff, `p2` Chuck). In solo play
that is the Jarling the player picked; with two players it is whoever pressed A.
The argument is passed **without** a `--` separator, so a Godot game must look for it in both
`OS.get_cmdline_args()` and `OS.get_cmdline_user_args()` (`Save.gd` does). The working directory
is inherited from the launcher; games must not rely on it.

While the game runs the launcher hides, ignores input and idles. With `MINIMIZE_WHILE_RUNNING`
(const in `hub.gd`, default `true`) it also minimises its own window, and restores its
previous mode (fullscreen) and focus when the game exits. It never changes the game's window. When the process exits (any exit
code) the launcher shows the hub again and the Jarling pops back out of that jar. Start in the hub quits the
launcher with exit code 0 (back to Steam).

### Launcher hub (`scenes/hub/hub.tscn`, root script `scripts/hub/hub.gd`)

The launcher is one 3D scene, the hub: each entry is a jar (`GameSpot`) on an arc, the two
Jarlings (`HubJarling`, `jarlings[0]` Jeff = profile `p1`, `jarlings[1]` Chuck = profile `p2`)
walk between them. Layout maths is pure and lives in `HubLayout` (`scripts/hub/hub_layout.gd`).

```gdscript
signal launched(slug: String, profile_id: String)
var entries: Array[Dictionary]        # visible manifest entries, sorted by folder
var spots: Array[GameSpot]            # one jar per entry; one empty jar when there are none
var focus: Array[int]                 # per Jarling: index of the jar it stands at, or -1
var profile: String                   # "p1" / "p2": the Jarling a solo player is
var two_players: bool
func set_entries(list: Array[Dictionary], select_slug: String = "") -> void
func selected_entry() -> Dictionary   # entry of the lead Jarling's jar, {} when roaming
func hop(player: int, dir: int) -> void          # stick left/right: run to the next jar
func press_action(player: int) -> void           # A: launch / wobble (empty jar) / cheer
func pick_profile(id: String) -> void            # B in solo play: be the other Jarling
func join_second_player() -> void                # P1 becomes Jeff, P2 becomes Chuck
func quit_to_steam() -> void
```

Input: a mostly-sideways stick push hops to the next jar (repeats while held, stops at the ends);
any other stick direction walks freely. A at a jar launches it with the profile of the Jarling
that jumps in. B in solo play swaps Jarling, which is the profile pick, saved at once. Start quits.
Holding LB+RB for 1 s toggles dev entries. `GameSpot` API used by the hub: `setup(entry, index,
previous_toy)`, `place(position, stand_point)`, `set_highlighted(on, color)`, `bounce()`,
`wobble()`, `launch_flash()`, `mouth_position()`, `var empty`, `var toy_index` (-1 when the jar
shows `grid` art, else the fallback toy; neighbours never share one).

`HUB_DEMO` (env, semicolon-separated `time:command[:args]`) drives the hub without a controller
for `scripts/tools/shots.sh`; see `_run_demo()` in `hub.gd`.

### Launcher save keys (launcher's own `Save`, default profile)

`launcher.last_card` (slug), `launcher.profile` (`p1`/`p2`), `launcher.show_dev` (bool).
`launcher.intro_date` is no longer written (the hub has no separate intro).
