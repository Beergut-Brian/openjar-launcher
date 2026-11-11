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

### `Roster` (`scripts/autoload/Roster.gd`)

Who each player is: the playable characters (from `openjar-characters`, vendored by
`scripts/tools/sync_characters.sh` into `assets/characters/<id>/` and `data/roster.json`) and each
slot's pick. Player colours stay with the slot (`Players.COLOR`), never the character.

```gdscript
signal pick_changed(player: int, id: String)
signal said(player: int, id: String, path: String)   # a voice line started (-1: shared voice)

var data_path := "res://data/roster.json"   # tests point this at a fixture, then reload()
var picks_path: String                       # the shared file; tests point this at user://
var characters_tag: String                   # the openjar-characters tag the roster came from

func roster() -> Array[String]               # playable ids in chooser order
func has(id: String) -> bool
func info(id: String) -> Dictionary          # {} if unknown, else:
	# id, name ("Jeff"), glb ("res://assets/characters/jeff/jeff.glb" or ""),
	# pixel ("res://assets/characters/jeff/pixel.png" or ""), voice ("res://.../voice/" or ""),
	# catchphrase ("res://.../voice/catchphrase.ogg" or ""),
	# barks (Array of file stems in voice/), default_for (1, 2 or 0)
func default_for(player: int) -> String      # data/roster.json defaults.P1 / .P2
func pick(player: int) -> String             # never "" while the roster has a character
func set_pick(player: int, id: String) -> bool   # false (no change) if unknown or the other's pick
func next_free(player: int, dir: int) -> String  # dir +1 / -1 through roster(), skipping the
                                                 # other player's pick; pick(player) if none free
func taken(id: String, by_other_than: int) -> bool
func reload() -> void                        # re-read roster.json, args, the shared file
func bark(id: String, player := -1) -> bool  # plays a random voice bark; false if it has none
func catchphrase(id: String, player := -1) -> bool   # voice/catchphrase.ogg, else a bark; false if neither
func voice_player(player := -1) -> AudioStreamPlayer # P1 / P2: that slot's own voice (bus VoiceP1 / VoiceP2,
                                                     # panned -0.3 / +0.3, sends to SFX); -1: the shared one
var last_said: Dictionary                    # player (or -1) -> the last res:// path that voice started
```

**Resolving a slot** at start (`reload()`), first hit that is in `roster()`:
1. `--p1-char=<id>` / `--p2-char=<id>` (either side of `--`)
2. the shared file `players.json[Save.profile]["P1" | "P2"]`
3. `defaults.P1` / `defaults.P2`
4. the first roster id the other player has not got

Unknown, removed or resident ids are skipped, never an error. If both slots resolve to the same
id, P2 moves to `next_free(P2, 1)`. No two players are ever the same character.

**The shared picks file** (`picks_path`): `OS.get_data_dir() + "/openjar/players.json"` (Linux
`~/.local/share/openjar/players.json`), outside every game's `user://`. Shared with every Open Jar
game and the launcher:

```json
{ "p1": { "P1": "jeff", "P2": "chuck" }, "kid": { "P1": "chuck", "P2": "jeff" } }
```

Keyed by save profile, then slot. Written the moment a pick changes (`set_pick`): read the file,
change only this profile's slot, keep every other key, write `players.json.tmp`, rename over
`players.json` (folder created if missing). A missing or broken file reads as empty. Roster never
touches the game's own `user://` saves.

**Launch args**: the launcher passes `--profile=<id> --p1-char=<id> --p2-char=<id>`. They win over
the file; a pick changed in the game is still written to the file.

**Launcher additions** (same file otherwise; candidates to upstream to the template):

```gdscript
var profile_override := ""     # the picks entry to use instead of Save.profile ("" = Save.profile)
func set_pick(player: int, id: String, bump: bool = false) -> bool
	# bump: if the other slot has id, it gets your old character instead of refusing (one write)
const TEST_PICKS := "user://test_players.json"   # picks_path in a gdUnit4 run
```

The launcher keeps its own `Save` profile (its save keys) but sets `profile_override` to the hub's
`profile` (`p1`/`p2`), so the hub reads and writes the same `players.json` entry the game it
launches will use. A gdUnit4 run never touches the real shared file, and a `--demo` / `HUB_DEMO`
run uses `user://demo_players.json` (fresh each run).

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
  "jar": "store/jar.glb",
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
| `jar` | string | no | the game's own tiny 3D world, shown inside its jar: a `.glb` / `.gltf` or a self-contained `.tscn` (see "Jar world" below). Missing or unusable → the generated fallback world |
| `grid` | string | no | 600x900 poster. Only used when there is no `jar`: its average colour tints the fallback world and it hangs as a small backdrop at the back of the jar |
| `hero`, `clip` | string | no | 920x430 banner / looping clip (not used yet) |
| `dev` | bool | no (default `false`) | only shown when the dev toggle is on; the jar gets a dark lid with a beacon |

A manifest that is not valid JSON, is not an object, has neither a usable `binary` nor
`command`, or points at a missing `binary`, is skipped with a warning. The launcher never crashes
on a bad manifest.

### Jar world: the `jar` field

Every game is a jar on the island with a tiny 3D world inside it (a castle, a planet, a snow
globe...). A game ships its own world as `store/jar.glb` (preferred) or `store/jar.tscn` and names
it in the manifest. The launcher loads it at runtime from the install folder.

- **Shape:** Y up, origin at the centre of the floor, front towards +Z. Design it to fit a
  cylinder of radius 0.8 m and height 1.9 m; the launcher scales any size uniformly to fit that
  cylinder and stands it on the jar floor. It sits on a slow turntable, so it must read from
  every side. No text.
- **Budget:** at most 5,000 triangles, 8 materials, textures 512 px or smaller. The jar adds its
  own light; unshaded or emissive materials are fine.
- **Data only:** lights, cameras, audio players and scripts are removed. A `.tscn` must be
  self-contained (built-in meshes and materials only): one that has an `ext_resource` or a
  script is rejected. `.glb` has neither problem.
- **Animation:** if there is an `AnimationPlayer`, its autoplay animation (else `idle`, else the
  first one) is looped.
- **Fallback:** no `jar`, or one that fails to load (warning, never a crash) → a world generated
  by the launcher (`JarWorld`, 8 kinds picked from the slug, neighbours never alike) in the
  game's colours: the average colour of `grid`, or a colour from the slug when there is no
  `grid`. No text is generated. 0 games → one sleepy empty jar.

`ManifestScanner` entries gain the key `jar` (absolute path, `""` when absent).

### `--profile=<id>` handshake

The launcher starts an entry with `OS.create_process`:

- `binary`: `<folder>/<binary> --profile=<id> --p1-char=<c1> --p2-char=<c2> <args...>`
- `command`: `<program> <command[1:]...> --profile=<id> --p1-char=<c1> --p2-char=<c2> <args...>`

`<id>` is `p1` or `p2`: the save profile of the Jarling that jumped into the jar. In solo play that
is the profile player 1 picked (B); with two players it is the profile of whoever pressed A. A
profile id is not a player slot. `<c1>` / `<c2>` are the two players' `Roster` picks as shown in the
hub (P1's held Jarling, P2's or the tag-along); the game's `Roster` reads them before the shared
file. A pick that is not a plain identifier is left out.
The argument is passed **without** a `--` separator, so a Godot game must look for it in both
`OS.get_cmdline_args()` and `OS.get_cmdline_user_args()` (`Save.gd` does). The working directory
is inherited from the launcher; games must not rely on it.

While the game runs the launcher hides, ignores input and idles. With `MINIMIZE_WHILE_RUNNING`
(const in `hub.gd`, default `true`) it also minimises its own window, and restores its
previous mode (fullscreen) and focus when the game exits. It never changes the game's window. When the process exits (any exit
code) the launcher shows the hub again, the Jarling pops back out of that jar and the lid drops back
on. Start in the hub quits the launcher with exit code 0 (back to Steam).

**Launch sequence.** A at a jar does not start the game at once: it starts `LaunchSequence`
(`scripts/hub/launch_sequence.gd`, pure, about 2.3 s): jar rattles → lid spins off → Jarling
leaps in → splash → camera dives into the tiny world → `GO`. The process is created and
`launched` is emitted only on `GO`. While the sequence runs all input is ignored, so pressing A
again (either player) can never start a second game.

### Launcher hub (`scenes/hub/hub.tscn`, root script `scripts/hub/hub.gd`)

The launcher is one 3D scene, the hub: each entry is a jar (`GameSpot`) on an arc, the two
profile Jarlings (`HubJarling`, `jarlings[0]` = profile `p1`, `jarlings[1]` = profile `p2`) walk
between them. Each is dressed as a `Roster` pick: the lead (player 1's, the hub `profile`) is
`Roster.pick(P1)`, the other `Roster.pick(P2)` (`HubJarling.character_id`). Jeff and Chuck stand on
the island as `residents` (never controlled); a resident who is the same character as a held
Jarling is hidden. Layout maths is pure and lives in `HubLayout` (`scripts/hub/hub_layout.gd`).

```gdscript
signal launched(slug: String, profile_id: String)
var entries: Array[Dictionary]        # visible manifest entries, sorted by folder
var spots: Array[GameSpot]            # one jar per entry; one empty jar when there are none
var focus: Array[int]                 # per Jarling: index of the jar it stands at, or -1
var profile: String                   # "p1" / "p2": the Jarling player 1 is
var two_players: bool
var launch: LaunchSequence            # launch.active while the launch animation plays
func set_entries(list: Array[Dictionary], select_slug: String = "") -> void
func selected_entry() -> Dictionary   # entry of the lead Jarling's jar, {} when roaming
func press_action(player: int) -> void           # A: start the launch sequence / wobble (empty jar) / cheer
func pick_profile(id: String) -> void            # B in solo play: the other profile and its picks
func change_character(player: int) -> bool       # the in-line chooser: next Roster character
func say_soon(player: int) -> void               # chooser voice: catchphrase SAY_SETTLE (0.3 s) after the swap lands
func cancel_say(player: int) -> void             # drop a pending line (leave, launch)
func say_pending(player: int) -> bool
func voice_step(delta: float) -> void            # counts the settles down (from _process)
func apply_characters(animate := false, always_lead := false) -> void   # dress Jarlings as the picks
func current_chars() -> Dictionary               # {P1: id, P2: id} for --p1-char / --p2-char
func join_second_player() -> void                # P2 takes the Jarling player 1 did not pick
func quit_to_steam() -> void
```

Input: the stick walks freely (see GAME.md "Controls"). A at a jar launches it with the profile of
the Jarling that jumps in. B in solo play swaps profile (saved at once): you stay where you are and
become that profile's P1 pick. Select / Back on your own pad (keys: Tab for P1, `/` for P2) changes
your character in place: next in roster order; with two players the other's pick is skipped
(nobody free: a head shake); solo, landing on the tag-along's character trades with it. Ignored
during the launch sequence and mid-swap. The pick is written to the shared file at once, and the
hub re-reads that file when a game exits. Start quits.
With two players, player 1 (green ring) keeps the picked Jarling and player 2 (red ring) holds the
other one. Holding LB+RB for 1 s toggles dev entries. `GameSpot` API used by the hub:
`setup(entry, index, world_kind)`, `place(position, stand_point)`, `set_highlighted(on, color)`,
`bounce()`, `wobble()`, `launch_pose(t, lid_target)`, `drop_lid()`, `mouth_position()`,
`inside_position()`, `var empty`, `var custom_world` (true when the game's own `jar` loaded),
`var world_kind` (`JarWorld.Kind` of the fallback world, -1 otherwise).

`HUB_DEMO` (env, semicolon-separated `time:command[:args]`) drives the hub without a controller
for `scripts/tools/shots.sh`; see `_run_demo()` in `hub.gd`.

### Launcher save keys (launcher's own `Save`, default profile)

`launcher.last_card` (slug), `launcher.profile` (`p1`/`p2`), `launcher.show_dev` (bool).
`launcher.intro_date` is no longer written (the hub has no separate intro).
