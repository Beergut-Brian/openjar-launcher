# Contracts: openjar-addons

The public API of each module. A game codes against this, not against the files. Changing
anything here is a version bump (see `CHANGELOG.md`). Copied from The Hill's `docs/contracts.md`
(origin/dev 4f38a74) for TileWorld and split screen; the cutscene and PictoBubble sections are new.

## Module: TileWorld (`addons/openjar/tileworld/`)

A chunked, diggable 2D tile world. Game-agnostic: The Hill uses it with a rectangle, Life of a
Worm will use a disk. Cells are `Vector2i` on one plain Cartesian grid (`cell_size` px squares, y
down) for every shape; tile ids are `int`, `0` is air, and index a palette of `TileDef`.

```gdscript
class_name TileDef extends Resource         # one kind of tile
@export var id: StringName
@export var color: Color
@export var solid: bool = true
@export var breakable: bool = true

class_name WorldShape extends RefCounted    # which cells exist, how they group, which way is down
var cell_size: int = 16
func contains(cell: Vector2i) -> bool
func chunk_of(cell: Vector2i) -> Vector2i                  # the chunk key
func chunk_cells(key: Vector2i) -> Array[Vector2i]         # every cell of that chunk
func neighbourhood(key: Vector2i, radius: int = 1) -> Array[Vector2i]   # live chunks around a tracked node
func gravity_at(pos: Vector2) -> Vector2                   # px/s^2 at a world position
func below(cell: Vector2i) -> Vector2i                     # the cell that supports this one
func sides(cell: Vector2i) -> Array[Vector2i]              # the two cells level with it (water spreads there)
func depth_of(cell: Vector2i) -> int                       # tiles below the surface
func cell_at(pos: Vector2) -> Vector2i
func center_of(cell: Vector2i) -> Vector2
# RectShape.new(width, height, chunk_size = 32): keys are (cx, cy), gravity straight down.
# DiskShape.new(radius, band = 32): keys are (ring, sector), gravity toward the origin.

class_name WorldGenerator extends RefCounted   # the seeded base world; the game subclasses it
func setup(shape: WorldShape, world_seed: int) -> void
func base_tile(cell: Vector2i) -> int          # deterministic; must not depend on call order
func base_water(cell: Vector2i) -> bool        # true: this air cell starts full of water
func base_chunk(cells: Array[Vector2i]) -> PackedInt32Array   # a chunk at once: base_tile | WATER_BIT if base_water; override for speed

class_name TileWorld extends Node2D
signal tile_dug(cell: Vector2i, block: StringName, player: int)       # block = TileDef.id
signal dig_blocked(cell: Vector2i, block: StringName, player: int)    # unbreakable: bounce + sparkle
signal chunk_loaded(key: Vector2i)
signal chunk_freed(key: Vector2i)
signal body_landed(body: Node2D, speed: float)                        # fall / bonk cue
signal prop_broke(prop: Node2D, pieces: Array)
signal water_entered(cell: Vector2i)                                  # a pocket opened: flood cue

var shape: WorldShape
var max_awake_bodies: int = 60
var chunk_radius: int = 1                     # 1 = 3x3 around each tracked node
func setup(shape: WorldShape, generator: WorldGenerator, palette: Array[TileDef], world_seed: int) -> void
func get_tile(cell: Vector2i) -> int          # edits over the base; 0 outside the shape
func is_solid(cell: Vector2i) -> bool
func set_tile(cell: Vector2i, id: int) -> void             # records an edit (or clears it if id == base)
func dig(cell: Vector2i, shape: Array[Vector2i] = [Vector2i.ZERO], player: int = -1) -> Array[Vector2i]
     # removes every breakable solid tile at cell + offset; returns the cells removed
func track(node: Node2D) -> void              # keep chunks alive around it
func untrack(node: Node2D) -> void
func loaded_chunks() -> Array[Vector2i]
func update_chunks() -> void                  # runs every physics frame; tests call it directly
func add_body(body: FallingBody) -> void      # also done by FallingBody on entering the tree under a TileWorld
func awake_bodies() -> int
func has_water(cell: Vector2i) -> bool
func set_water(cell: Vector2i, on: bool) -> void
func water_count() -> int
func buoyancy_at(pos: Vector2) -> Vector2     # ZERO when dry; else against gravity_at(pos), stronger
func step_water() -> void                     # one cellular tick (10 Hz by default)
var drain_per_second: float = 0.0             # cells removed per second from open water (Water Towers raise it)
@export var flow_reach: int = 8               # cells water looks along a level line for a drop
func set_darkness(bands: Array) -> void       # [{from: int, to: int, darkness: float, tint: Color}] by depth_of
func darkness_at(depth: int) -> float
func add_light(node: Node2D, radius_px: float, strength: float = 1.0) -> void    # a headlamp: a hole in the dark that follows node
func remove_light(node: Node2D) -> void
func to_save() -> Dictionary                  # {"seed", "edits": [x, y, id, ...], "water": [x, y, on, ...]}: only differences from the base
func load_save(data: Dictionary) -> void

class_name FallingBody extends RigidBody2D    # boulders, treasures, prop pieces
# Uses shape.gravity_at(position), never the project gravity. Sleeps when resting on a solid tile;
# wakes when a tile it rests on is removed (dig or set_tile), never on its own. Frozen while its
# chunk is not loaded. Never more than max_awake_bodies awake (also when physics wakes them); the rest wait their turn.

class_name BreakableProp extends Node2D       # a multi-tile prop: the car, the gnome room's wall
@export var footprint: Vector2i               # tiles
@export var support_needed: float = 0.5       # breaks when less than this share of the cells under it is solid
# On breaking: one FallingBody piece per footprint cell, prop_broke, then the prop frees itself.
```

#### Tile art and the light pass (Art lane, 2026-11-10)

Additive; with neither set, a TileWorld looks and behaves exactly as before.

```gdscript
var tile_art: TileArt      # set before setup(); null = the generated flat-colour TileSet
class_name TileArt extends RefCounted
func tile_set() -> TileSet                                           # source 0: solid tiles (collision), source 1: back walls (no collision)
func solid_coords(cell: Vector2i, id: int, open: int) -> Vector2i     # open: neighbour bits 1 up, 2 right, 4 down, 8 left are not solid
func wall_coords(cell: Vector2i, base_id: int, ceiling: bool) -> Vector2i   # an air cell; (-1, -1) = no wall (shows the backdrop)
```

TileWorld redraws a cell and its four neighbours on every `set_tile`/`dig`. A dug cell (base solid,
now air) gets a back wall; a cell that was air in the base world (caves, the Bottom cavern)
returns what `wall_coords` says (The Hill: none, so the parallax backdrop shows through).

Light pass: `set_darkness` and `darkness_at` keep their meaning (0 daylight .. 1 darkest). The
overlay never draws pure black: darkness 1 renders as `darkness_floor` (default 0.8) of the band
tint mixed toward `darkness_night` (a dim navy). Light is worked out per cell and blended softly
from cell to cell; light reaching into solid ground falls off faster than through open space.

```gdscript
var darkness_floor: float = 0.8
func add_light(node: Node2D, radius_px: float, strength: float = 1.0) -> void   # up to 32; the nearest to tracked nodes win
```

Rules worth knowing: only chunks within `chunk_radius` of a tracked node have `TileMapLayer`
nodes and collision; `get_tile`/`set_tile`/`dig`/save work everywhere. The chunk manager only
ever talks to `WorldShape` (`chunk_of`, `chunk_cells`, `neighbourhood`), so a new shape is a new
`WorldShape` subclass and nothing else. Water is a set of full cells: it moves to `below`, else
toward the nearest drop (a free `sides` cell from which a free `below` is within `flow_reach`,
default 8, along the level line), else sideways when pressed from above, so it settles level; the
count never grows, it never enters a solid tile, an unloaded chunk or leaves the shape.

## Module: split screen (`addons/openjar/split_screen/`)

```gdscript
class_name ScreenDirector extends Control     # full-rect; the game adds one (The Hill: in the play scene)
signal split_changed(is_split: bool)          # when the decision flips (the tween starts)
signal entered_scene(player: int, scene: StringName)

@export var tween_time: float = 0.3
@export var zoom: float = 2.0                 # whole numbers for pixel art
@export var join_at: float = 0.6              # join when both fit inside this share of one screen...
@export var split_at: float = 0.8             # ...split when they pass this share (no flicker in between)
var colors: Array[Color]                      # per player; default green, red
var split_amount: float                       # 0 one view .. 1 fully split (read-only; the tween)

func add_scene(id: StringName, root: Node) -> void        # the director hosts it; it keeps ticking, seen or not
func scene_root(id: StringName) -> Node
func add_player(player: int, node: Node2D, scene: StringName) -> void   # reparents node under that scene
func remove_player(player: int) -> void
func move_player(player: int, scene: StringName, position: Vector2) -> void   # the elevator; emits entered_scene
func scene_of(player: int) -> StringName
func is_split() -> bool
func camera_of(player: int) -> Camera2D
func view_rect_of(player: int) -> Rect2       # where that player's view is on screen right now (HUD anchoring)
static func wants_split(was_split: bool, same_scene: bool, offset: Vector2, screen_world: Vector2,
		players: int, join_at: float = 0.6, split_at: float = 0.8) -> bool
```

| Situation | Screen |
| --- | --- |
| One player | Full screen, always |
| Same scene, both inside `join_at` of one screen | One camera on the midpoint |
| Same scene, past `split_at` of one screen on either axis | Split |
| Between the two | Whatever it was |
| Different scenes | Split, each half its own scene |

Split is always player 0 left, player 1 right, with a divider in the two players' colours. Each
scene lives in its own world (own physics space), so two scenes never collide with each other.

## Module: cutscene (`cutscene/`)

`class_name CutscenePlayer extends Control`. Full contract (data format, host interface, API):
`docs/cutscene-format.md`. The host interface there is the contract a game implements.

## Module: PictoBubble (`picto_bubble/`)

```gdscript
class_name PictoBubble extends RefCounted     # static draw helpers, call from _draw()
const CELL := 22.0; const PAD := 4.0
const BUILTIN: Array[StringName]
static func size_for(n: int, k := 1.0) -> Vector2
static func draw(ci: CanvasItem, tip: Vector2, pics: Array, alpha := 1.0, k := 1.0) -> void
static func picture(ci: CanvasItem, id: StringName, c: Vector2, s: float, a := 1.0) -> void
static func texture_picture(ci: CanvasItem, tex: Texture2D, region: Rect2, c: Vector2, s: float, a := 1.0) -> void
static func register(id: StringName, drawer: Callable) -> void          # drawer(ci, id, c, s, a)
static func register_prefix(prefix: String, drawer: Callable) -> void
static func has_picture(id: StringName) -> bool
static func clear_registry() -> void
```
