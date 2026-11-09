## Pure look rules for game cards and the profile picker, kept out of the scenes so they can be tested.
## Fallback tiles: card_tiles.gdshader picks tile (r + 2g + 4b) % 5 from the Placeholder colour's
## bytes, and the empty-slot tile when the colour is its empty_tint. TILE_TINTS[i] lands on tile i,
## so card.gd chooses the tile and the shader just follows. See docs/contracts.md, "Launcher scenes".
class_name CardLook
extends RefCounted

const TILE_COUNT := 5
## One palette colour per tile of card_tiles.png; (r + 2g + 4b) % 5 of each is its index.
const TILE_TINTS: Array[Color] = [Color("ff8a3d"), Color("4cc3ff"), Color("ffd23f"),
	Color("ff6fae"), Color("b07cff")]
## Must equal card_tiles.gdshader's empty_tint (tests check it).
const EMPTY_TINT := Color("55506a")

## Bounce on a cursor move, as multiples of the highlight scale: squash wide, stretch tall, settle.
const BOUNCE_KEYS: Array[Vector2] = [Vector2(1.18, 1.06), Vector2(1.08, 1.12), Vector2.ONE]
const BOUNCE_TIMES: Array[float] = [0.06, 0.07, 0.16]
## Wobble ("can't go there"): a quick squash under the side-to-side shake.
const WOBBLE_SQUASH := Vector2(1.06, 0.95)

## Profile picker: seconds between A (picked, happy face) and `confirmed`.
const PICK_HOLD := 0.35


static func placeholder_index(slug: String) -> int:
	return absi(slug.hash()) % TILE_COUNT


static func tint_for(index: int) -> Color:
	return TILE_TINTS[posmod(index, TILE_COUNT)]


## The tile card_tiles.gdshader shows for a Placeholder colour; -1 means the empty-slot tile.
static func shader_tile(tint: Color) -> int:
	if Vector3(tint.r, tint.g, tint.b).distance_to(Vector3(EMPTY_TINT.r, EMPTY_TINT.g, EMPTY_TINT.b)) <= 0.02:
		return -1
	return (tint.r8 + tint.g8 * 2 + tint.b8 * 4) % TILE_COUNT


## Placeholder indices for a row of slugs, in order: each slug's own index, bumped as little as
## possible so no two neighbours share a tile. Stable for a given row.
static func spread(slugs: Array) -> Array[int]:
	var out: Array[int] = []
	for i in slugs.size():
		var base := placeholder_index(slugs[i])
		var next := placeholder_index(slugs[i + 1]) if i + 1 < slugs.size() else -1
		var idx := base
		for k in TILE_COUNT:
			idx = (base + k) % TILE_COUNT
			var prev_ok := out.is_empty() or out[-1] != idx
			if prev_ok and (idx != next or k == TILE_COUNT - 1):
				break
		out.append(idx)
	return out
