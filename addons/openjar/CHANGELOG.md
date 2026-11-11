# Changelog

Games pin a tag (`addons/openjar` submodule). Every change bumps the tag; `plugin.cfg` matches it.

## 0.2.0 (2026-11-10, branch feature/extract-hill-engine; tag by Gary)

**Layout change:** the repo root is now the addon root (`plugin.cfg` at the top). Games mount the
repo at `addons/openjar/`, so every module is `res://addons/openjar/<module>/`. Up to 0.1.0 the
files sat under `addons/openjar/` in this repo.

Engine modules extracted from The Hill (`the-hill` origin/dev 4f38a74). Full signatures in
`docs/contracts.md`; tests in `tests/project/suites/` (`tests/run.sh`).

### `tileworld/` (verbatim from The Hill)
- `TileWorld` (Node2D): `setup(shape, generator, palette, seed)`, `get_tile`, `set_tile`, `dig`,
  `is_solid`, `base_tile_of`, `track`/`untrack`, `update_chunks(budget)`, `loaded_chunks`,
  `has_water`/`set_water`/`water_count`/`water_cells`/`step_water`/`buoyancy_at`,
  `set_darkness`/`darkness_at`/`add_light`/`remove_light`, `add_body`/`awake_bodies`,
  `to_save`/`load_save`; vars `max_awake_bodies`, `chunk_radius`, `chunk_budget_per_frame`,
  `flow_reach`, `water_hz`, `drain_per_second`, `tile_art`, `tile_set_override`, `water_texture`,
  `darkness_floor`, `darkness_night`, `collision_layer`; signals `tile_dug`, `dig_blocked`,
  `chunk_loaded`, `chunk_freed`, `body_landed`, `prop_broke`, `water_entered`.
- `WorldShape` interface, `RectShape(width, height, chunk_size)`, `DiskShape(radius, band)`.
- `WorldGenerator` (`base_tile`, `base_water`, `base_chunk`, `WATER_BIT`), `LayeredGenerator`.
- `EditStore` (edit-only save `{"seed", "edits", "water"}`), `TileDef`, `TileArt`.
- `FallingBody` (RigidBody2D, shape gravity, sleep/wake cap), `BreakableProp` (footprint, support).
- Internals: `body_index.gd`, `water_sim.gd`, `darkness_overlay.gd`. Demos: `shape_demo`, `stress`.

### `split_screen/` (verbatim from The Hill)
- `ScreenDirector` (Control): `add_scene`, `scene_root`, `add_player`, `remove_player`,
  `move_player`, `scene_of`, `is_split`, `camera_of`, `view_rect_of`, static `wants_split`;
  exports `tween_time`, `zoom`, `join_at`, `split_at`, `forward_input`; `colors`,
  `split_amount`; signals `split_changed`, `entered_scene`. Demo `split_demo`.

### `cutscene/` (new here; from The Hill's `scripts/gameplay/cutscene_player.gd`)
- `CutscenePlayer` (Control): `play(id, ctx)`, **new** `play_data(data, ctx, id)`, `skip`,
  `is_playing`, `current`, `context`, `pop_bubble`; static `load_scene`, `line`, `line_secs`;
  **new** static vars `scene_dir`, `lines_path`, `voice_dir` (defaults are The Hill's paths);
  **new** vars `player_characters`, `cues`; `host`, `speed`, `said`; signals `started`,
  `finished`, `beat`. Host interface (duck-typed): `cutscene_actor`, `cutscene_spawn`,
  `cutscene_anchor`, `cutscene_views`, `cutscene_lock`, `cutscene_call`, `cutscene_skip_pressed`,
  `cutscene_character`, `cutscene_head`, `cutscene_anim`, **new** `cutscene_sound`,
  `cutscene_duck`, `cutscene_bark`.
- Changed from The Hill: no `Audio` autoload in code (host methods first, else an `Audio` node
  found at runtime); Jeff/Chuck rule is `player_characters`; sound cue names are `cues`
  (generic defaults); a freed host now actually skips the scene (bug fix: the old
  `host != null` test is false for a freed object in Godot 4).
- Sample `demo/sample.json` + `sample_lines.json`, demo host `cutscene_demo.tscn`, format doc
  `docs/cutscene-format.md`.

### `picto_bubble/` (new here; from The Hill's `scripts/gameplay/picto_bubble.gd`)
- `PictoBubble` (static): `size_for`, `draw`, `picture`, `CELL`, `PAD`, colours; **new**
  `BUILTIN`, `register`, `register_prefix`, `has_picture`, `clear_registry`, `texture_picture`.
- Hill-only pictures removed (`wall`, `ice`, `shaken_hill`, `deed`, `shaft`, `ruin:`/`home:`/
  `vehicle:` via The Hill's `SpriteArt`): a game registers them.

### Tests
- `tests/project` harness (own `project.godot`, kept out of games by `tests/.gdignore`),
  `tests/run.sh`. Ported from The Hill: `test_tileworld`, `test_art_tileworld`, `test_split`.
  New: `test_cutscene`, `test_picto_bubble`, `test_worm_today`. 76 cases.

## 0.1.0
- Addon skeleton: `plugin.cfg`, `theme/`, `ui/`, `launcher/` placeholders.
