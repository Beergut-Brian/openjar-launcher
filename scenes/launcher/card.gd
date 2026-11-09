## One game card: 600x900 grid art, or a fallback tile from card_tiles.png when the art is missing.
## API in docs/contracts.md, "Launcher scenes". The row sets scale/position; the card animates itself.
## Tile choice and squash keys live in CardLook (scripts/launcher/card_look.gd).
extends Control

const NORMAL_SCALE := 0.6
const HIGHLIGHT_SCALE := 0.72

var entry: Dictionary = {}
## True for the "no games installed" slot. Set by setup({}) or set_empty().
var empty := false
## Fallback tile 0..CardLook.TILE_COUNT-1 (ignored while empty).
var placeholder_index := 0
var _tween: Tween

@onready var placeholder: ColorRect = $Placeholder
@onready var emblem: PlaceholderShape = $Emblem
@onready var caption: Label = $Caption
@onready var art: TextureRect = $Art
@onready var frame: ReferenceRect = $Frame
@onready var dev_badge: Polygon2D = $DevBadge


func _ready() -> void:
	pivot_offset = size / 2.0
	scale = Vector2.ONE * NORMAL_SCALE


func setup(e: Dictionary) -> void:
	entry = e
	var slug: String = e.get("slug", "")
	placeholder_index = CardLook.placeholder_index(slug)
	emblem.kind = [PlaceholderShape.Kind.CIRCLE, PlaceholderShape.Kind.SQUARE,
		PlaceholderShape.Kind.TRIANGLE][absi(slug.hash() / 7) % 3]
	set_empty(e.is_empty())
	caption.text = e.get("name", "")
	dev_badge.visible = e.get("dev", false)
	art.texture = _load_texture(e.get("grid", ""))
	art.visible = art.texture != null


## The empty slot gets its own tile and tint (CardLook.EMPTY_TINT, the shader's empty_tint).
func set_empty(on: bool) -> void:
	empty = on
	_apply_tint()


func set_placeholder_index(i: int) -> void:
	placeholder_index = posmod(i, CardLook.TILE_COUNT)
	_apply_tint()


func _apply_tint() -> void:
	var tint := CardLook.EMPTY_TINT if empty else CardLook.tint_for(placeholder_index)
	placeholder.color = tint
	emblem.color = tint.lightened(0.45)


func set_highlighted(on: bool) -> void:
	frame.visible = on
	z_index = 1 if on else 0
	_scale_to(HIGHLIGHT_SCALE if on else NORMAL_SCALE, 0.12)


## Visual for a cursor move onto this card: squash wide, stretch tall, settle (CardLook.BOUNCE_KEYS).
func bounce() -> void:
	_kill()
	rotation = 0.0
	_tween = create_tween()
	for i in CardLook.BOUNCE_KEYS.size():
		var step := _tween.tween_property(self, "scale", CardLook.BOUNCE_KEYS[i] * HIGHLIGHT_SCALE,
			CardLook.BOUNCE_TIMES[i])
		if i == CardLook.BOUNCE_KEYS.size() - 1:
			step.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Visual for "can't go further" / "can't launch": a quick side-to-side wobble.
func wobble() -> void:
	_kill()
	scale = CardLook.WOBBLE_SQUASH * HIGHLIGHT_SCALE
	_tween = create_tween()
	var shake := [0.08, -0.08, 0.05, -0.03, 0.0]
	for i in shake.size():
		# The squash eases back to round over the same five steps as the shake.
		var squash := CardLook.WOBBLE_SQUASH.lerp(Vector2.ONE, float(i + 1) / shake.size())
		_tween.tween_property(self, "rotation", shake[i], 0.05)
		_tween.parallel().tween_property(self, "scale", squash * HIGHLIGHT_SCALE, 0.05)


## Visual for launching: zoom up towards the screen.
func launch_zoom() -> Tween:
	_kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * 0.95, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	return _tween


func badge_pop() -> void:
	if not dev_badge.visible:
		return
	dev_badge.scale = Vector2.ZERO
	create_tween().tween_property(dev_badge, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _scale_to(s: float, t: float) -> void:
	_kill()
	rotation = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * s, t)


func _kill() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		push_warning("Card: could not load grid art %s" % path)
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
