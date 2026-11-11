# Cutscene format (`cutscene/`, `CutscenePlayer`)

Adapted from The Hill's `docs/cutscenes.md` (Story lane, 2026-11-10), minus The Hill's own scenes.
`cutscene/cutscene_player.gd`, `class_name CutscenePlayer extends Control`. Nothing in it knows
about a game: the game talks to it through a small duck-typed host interface. Pictures in bubbles
come from `PictoBubble` (`picto_bubble/`).

## What a scene does

1. Locks input (the host's `cutscene_lock(true)`).
2. Slides black letterbox bars in (11% of the screen each, 0.45 s) and shows the **A** glyph with a
   fast-forward arrow in the bottom bar (no words). The player draws the bars itself (it is a
   full-rect Control: put it in a `CanvasLayer` above the game).
3. Runs its steps: the camera eases to the moment and zooms, actors walk, hop and turn, a voiced line
   plays per beat with a picture bubble over the speaker, items arc from one actor to another, the
   screen fades, the host is called for game changes.
4. Slides the bars out, hands the camera back (eased) and unlocks input.

**A skips the whole scene** (`cutscene_skip_pressed()`, after a 0.5 s grace so the press that
started it does not skip it). A skip runs every remaining step marked `"always": true` at once
(state changes), so a skipped scene leaves the game exactly where the full scene would. A scene
never runs longer than `MAX_SECS` (90 s): past that it skips itself. If the host is freed, it skips.
So it never softlocks.

## Split screen

Every view whose camera looks at the actors' world eases to the moment (both halves show it). A view
showing another world keeps its own camera under the bars; input is locked for everyone. The bars
and the fade cover the whole screen. Bubbles are drawn per view, in screen space, clamped inside
their view and below the top bar. A game without split screen returns one view.

## Data: `<scene_dir>/<id>.json`

`CutscenePlayer.scene_dir` defaults to `res://data/cutscenes/`. Sample: `cutscene/demo/sample.json`.

```json
{"id": "sample", "scene": "demo", "steps": [
  {"do": "camera", "to": "middle", "dy": -10, "zoom": 3.0, "time": 0.8, "wait": 0.6},
  {"do": "spawn", "who": "guest", "sheet": "", "at": "left", "dx": -60, "face": 1},
  {"do": "walk", "who": "guest", "to": "host", "dx": -28, "time": 1.2},
  {"do": "line", "who": "guest", "line": "sample_hello", "pics": ["face_happy", "star"]},
  {"do": "call", "fn": "mark_seen", "args": {"flag": "sample"}, "always": true}
]}
```

`scene` is passed to `cutscene_spawn` (where spawned actors go; any string the host understands,
or a context value such as `@where`). Steps run in order; each blocks for its `wait` (default: its
own `time`, except `camera`, `hop`, `face`, `show`/`hide`, `hold`/`drop`, `sound` and `bars`, which
do not block unless given a `wait`; `walk` and `bubble` given `then` do not block either).

| `do` | Fields | What happens |
| --- | --- | --- |
| `camera` | `to` (actor, anchor or `[x, y]`), `dx`, `dy`, `zoom`, `time` | Eases the camera(s) there; follows a moving actor |
| `camera_back` | | Eases back to the game's camera |
| `spawn` | `who`, `sheet`, `at`, `dx`, `dy`, `face` | A temporary actor from `cutscene_spawn` (freed at the end) |
| `walk` | `who`, `to` or `dx`, `time`, `fly` | Walks there with a little bob (`cutscene_anim(who, "walk")`, then `"idle"`); keeps its height unless `fly` |
| `hop` | `who`, `height`, `times`, `time`, `sound` | Hops in place |
| `face` | `who`, `dir` or `toward` | Turns (`Sprite2D.flip_h`, else a `facing` property) |
| `show` / `hide` | `who` | |
| `line` | `who`, `line` (id), `pics`, `time` | Plays the voiced line and shows the bubble for its length |
| `bubble` | `who`, `pics`, `time` | A picture bubble with no voice |
| `item` | `pic`, `from`, `to`, `time`, `sound` | A picture arcs from one actor to another with sparkles |
| `hold` / `drop` | `who`, `pic` | A picture held at the actor's hands |
| `sound` | `cue` | Plays a sound cue (see Sound) |
| `fade` | `to` (0..1), `time` | Fades to / from black |
| `bars` | `on` | Bars in or out mid-scene |
| `call` | `fn`, `args`, `always` | `host.cutscene_call(fn, args)` |
| `wait` | `time` | |

Any step can have `"needs": "<actor>"` (skipped when that actor is missing, e.g. P2 not joined),
`"if": "<ctx key>"` / `"unless": "<ctx key>"`. Values are filled from the play context: `"@key"`
becomes `ctx[key]` (any type), and `"{key}"` inside a string becomes `str(ctx[key])`. In a line id,
`{char}` becomes the speaker's character id (`cutscene_character`), falling back to `any` (so
`bye_{char}` is the picked character's own line when it exists, else `bye_any`).

## Lines: `lines_path`

`CutscenePlayer.lines_path` defaults to `res://data/story/lines.json`:
`{"lines": [{id, character, text, delivery, fallback}]}`. `text` is a script for the voice
(never shown on screen); `delivery` is direction for whoever records it. Sample:
`cutscene/demo/sample_lines.json`.

Playback, in order: `<voice_dir>/<id>.ogg` if it exists (`voice_dir` defaults to
`res://assets/story/voice/`); else `fallback`: `bark:<cue>` is the speaker's library bark and
`sfx:<cue>` a sound cue. A line whose `character` is in `player_characters` (or is `any`) is voiced
for whoever the player picked: its own file plays only when that character is the speaker's pick,
else the pick's bark. Music ducks under a line (-8 dB). The picture bubble always shows, voiced or
not. `said` records `[line id, character, "file" | "bark" | "sfx" | "none"]` per line.

A line holds its bubble for the voice file's length + 0.35 s (1.2 to 6 s), else 0.9 s + 0.3 s per
word (1.6 to 4.2 s), unless the step gives `time`.

## Sound

Cues: `cues` (`start`, `skip`, `hop`, `item`, `no_bark`: the cue when a bark fallback finds no
stream; `""` = silent). Each cue, duck and bark goes to the host's `cutscene_sound(cue)`,
`cutscene_duck(db, secs)`, `cutscene_bark(character, cue) -> AudioStream` when it has them, else to
an autoload named `Audio` with `play` / `duck` / `bark_stream` if the game has one, else nowhere.
Voice files play on a bus named `Voice` when it exists, else `Master`.

## Host interface (duck-typed; every method optional, missing ones are no-ops)

```gdscript
func cutscene_actor(name: String) -> Node2D                     # an existing actor, or null
func cutscene_spawn(name, sheet, scene, pos: Vector2) -> Node2D # a temporary actor (the player frees it)
func cutscene_anchor(name: String) -> Vector2                   # a named world point; INF when unknown
func cutscene_views() -> Array                                  # [{camera: Camera2D, rect: Rect2}] screen views
func cutscene_lock(on: bool) -> void                            # lock / unlock every player's input
func cutscene_call(fn: String, args: Dictionary) -> void        # game changes ("always" ones run on skip)
func cutscene_skip_pressed() -> bool                            # A just pressed by anyone
func cutscene_character(actor: String) -> String                # the voice an actor speaks with ("" = none)
func cutscene_head(actor: String) -> Vector2                    # bubble tip offset from the feet (default (0, -34))
func cutscene_anim(actor: String, anim: String) -> void         # "walk" / "idle"
func cutscene_sound(cue: String) -> void
func cutscene_duck(db: float, secs: float) -> void
func cutscene_bark(character: String, cue: String) -> AudioStream
```

Camera target lookup is `cutscene_actor` then `cutscene_anchor`; actor lookup checks the scene's
spawned actors first. A point is an actor's feet, an anchor, or `[x, y]`, plus `dx` / `dy`; an
unknown point is the current view centre.

## API

```gdscript
static var scene_dir: String; static var lines_path: String; static var voice_dir: String
static func load_scene(id) -> Dictionary; static func line(id, character = "") -> Dictionary
static func line_secs(line: Dictionary) -> float
var host: Object; var speed := 1.0; var player_characters: PackedStringArray; var cues: Dictionary
func play(id: StringName, ctx := {}) -> bool          # false when one is playing or no such scene
func play_data(data: Dictionary, ctx := {}, id := &"") -> bool
func skip(); func is_playing() -> bool; func current() -> StringName; func context() -> Dictionary
func pop_bubble(actor: String, pics: Array, secs := 1.6)   # a bubble outside any scene
signal started(id); signal finished(id, skipped); signal beat(kind, detail)
```

## Demo

`cutscene/demo/cutscene_demo.tscn`: a host with two block actors plays `sample.json` and quits.
`godot --path tests/project res://addons/openjar/cutscene/demo/cutscene_demo.tscn -- --no-quit`.
