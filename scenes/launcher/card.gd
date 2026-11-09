## One game card: 600x900 grid art, or a coloured placeholder with an emblem when the art is missing.
## API in docs/contracts.md, "Launcher scenes". The row sets scale/position; the card animates itself.
extends Control

const PALETTE := [Color("ff8a3d"), Color("4cc3ff"), Color("b07cff"), Color("ffd23f"),
	Color("ff6fae"), Color("5fe0a0"), Color("7f8cff"), Color("ff5e5b")]
const NORMAL_SCALE := 0.6
const HIGHLIGHT_SCALE := 0.72

var entry: Dictionary = {}
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
	var tint: Color = PALETTE[absi(slug.hash()) % PALETTE.size()] if not slug.is_empty() else Color("55506a")
	placeholder.color = tint
	emblem.kind = [PlaceholderShape.Kind.CIRCLE, PlaceholderShape.Kind.SQUARE,
		PlaceholderShape.Kind.TRIANGLE][absi(slug.hash() / 7) % 3]
	emblem.color = tint.lightened(0.45)
	caption.text = e.get("name", "")
	dev_badge.visible = e.get("dev", false)
	art.texture = _load_texture(e.get("grid", ""))
	art.visible = art.texture != null


func set_highlighted(on: bool) -> void:
	frame.visible = on
	z_index = 1 if on else 0
	_scale_to(HIGHLIGHT_SCALE if on else NORMAL_SCALE, 0.12)


## Visual for a cursor move onto this card.
func bounce() -> void:
	_kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * HIGHLIGHT_SCALE * 1.12, 0.07)
	_tween.tween_property(self, "scale", Vector2.ONE * HIGHLIGHT_SCALE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Visual for "can't go further" / "can't launch": a quick side-to-side wobble.
func wobble() -> void:
	_kill()
	scale = Vector2.ONE * HIGHLIGHT_SCALE
	_tween = create_tween()
	for a in [0.08, -0.08, 0.05, -0.03, 0.0]:
		_tween.tween_property(self, "rotation", a, 0.05)


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
