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
subfolder holding an `openjar.json` is one card. The launcher's own folders
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
| `slug` | string | no (defaults to folder name) | stable id; the launcher remembers the last card by slug |
| `name` | string | no (defaults to slug) | shown only as a small caption on placeholder cards |
| `version` | string | no | informational |
| `binary` | string | one of `binary` / `command` | executable, relative to the folder; must exist |
| `command` | array of strings | one of `binary` / `command` | `[program, arg...]`; `program` is resolved against the folder if that file exists, else used as-is (PATH lookup). Wins over `binary` if both are present |
| `args` | array of strings | no | extra arguments, appended after `--profile=` |
| `grid` | string | no | 600x900 card art; missing file → coloured placeholder card |
| `hero`, `clip` | string | no | 920x430 banner / looping clip (not used by Build 0) |
| `dev` | bool | no (default `false`) | only shown when the dev toggle is on; gets a corner badge |

A manifest that is not valid JSON, is not an object, has neither a usable `binary` nor
`command`, or points at a missing `binary`, is skipped with a warning. The launcher never crashes
on a bad manifest.

### `--profile=<id>` handshake

The launcher starts an entry with `OS.create_process`:

- `binary`: `<folder>/<binary> --profile=<id> <args...>`
- `command`: `<program> <command[1:]...> --profile=<id> <args...>`

`<id>` is `p1` or `p2` (the two faces in the profile picker; profiles are not players).
The argument is passed **without** a `--` separator, so a Godot game must look for it in both
`OS.get_cmdline_args()` and `OS.get_cmdline_user_args()` (`Save.gd` does). The working directory
is inherited from the launcher; games must not rely on it.

While the game runs the launcher hides, ignores input and idles. With `MINIMIZE_WHILE_RUNNING`
(const in `launcher.gd`, default `true`) it also minimises its own window, and restores its
previous mode (fullscreen) and focus when the game exits. It never changes the game's window. When the process exits (any exit
code) the launcher shows the card row with that card highlighted. Start on the card row quits the
launcher with exit code 0 (back to Steam).

### Launcher scenes (replaceable by the Art lane, keep file and node names)

| Scene | Root script API |
| --- | --- |
| `scenes/launcher/intro.tscn` | `signal finished()`, `func play() -> void`, `func skip() -> void` |
| `scenes/launcher/profile_picker.tscn` | `signal confirmed(profile_id: String)`, `signal back_requested()`, `signal picked(profile_id: String)`, `func open(selected_id: String) -> void`, `var picked_id: String` |
| `scenes/launcher/card.tscn` | `func setup(entry: Dictionary) -> void`, `func set_highlighted(on: bool) -> void`, `func bounce() -> void`, `func wobble() -> void`, `func set_empty(on: bool) -> void`, `func set_placeholder_index(i: int) -> void`, `var empty: bool`, `var placeholder_index: int` |

Picker: A emits `picked` at once (the face pops and stays happy; `picked_id` is set until the
next `open()`), then `confirmed` `CardLook.PICK_HOLD` (0.35 s) later. Input is ignored in between.

Card fallback art (`CardLook`, `scripts/launcher/card_look.gd`): a card without grid art shows
tile `placeholder_index` (0..4) of `card_tiles.png`, `slug.hash() % 5`, bumped by the card row so
two neighbours never share a tile. `card.gd` encodes it in the `Placeholder` colour so that
`card_tiles.gdshader`'s `(r + 2g + 4b) % 5` lands on that index exactly; the empty slot
(`set_empty(true)`, set by `setup({})`) uses `CardLook.EMPTY_TINT`, the shader's `empty_tint`.
`bounce()` squashes to `(1.18, 1.06)` then stretches to `(1.08, 1.12)` of the highlight scale
before settling; `wobble()` adds a small squash to the side-to-side shake.

### Launcher save keys (launcher's own `Save`, default profile)

`launcher.last_card` (slug), `launcher.profile` (`p1`/`p2`), `launcher.show_dev` (bool),
`launcher.intro_date` (`YYYY-MM-DD`, local date the intro last played).
