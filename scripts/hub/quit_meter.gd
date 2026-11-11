## K-02: Start leaves the launcher only when held (QUIT_HOLD s), so a five-year-old mashing it never
## drops the TV back to Steam. While Start is down a round badge in the top corner shows an open
## door with a sunny ring filling round it; let go and it shrinks away, nothing happens. No words.
class_name QuitMeter
extends Control

const RADIUS := 54.0
const MARGIN := 40.0
const INK := Color("2b2140")
const CREAM := Color("fff4dc")
const FILL := Color("ffd23f")   # never a player's green or red

var progress := 0.0     # 0..1, the hub sets it from its HoldCombo
var _shown := 0.0       # eases the badge in and out


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var want := 1.0 if progress > 0.0 else 0.0
	_shown = move_toward(_shown, want, delta * (6.0 if want > 0.0 else 4.0))
	visible = _shown > 0.0
	if visible:
		queue_redraw()


func shown() -> bool:
	return _shown > 0.0


func _draw() -> void:
	var r := RADIUS * (0.6 + 0.4 * _shown)
	var c := Vector2(get_viewport_rect().size.x - MARGIN - RADIUS, MARGIN + RADIUS)
	draw_circle(c, r + 10.0, Color(CREAM, _shown))
	draw_circle(c, r, Color(INK, _shown))
	if progress > 0.0:
		draw_arc(c, r + 4.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, Color(FILL, _shown), 12.0, true)
	# an open door with a little step out of it
	var s := r / RADIUS
	var door := Rect2(c + Vector2(-20, -28) * s, Vector2(28, 56) * s)
	draw_rect(door, Color(CREAM, _shown), false, 5.0 * s)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-20, -28) * s, c + Vector2(-2, -20) * s,
			c + Vector2(-2, 34) * s, c + Vector2(-20, 28) * s]), Color(FILL, _shown))
	draw_line(c + Vector2(14, 0) * s, c + Vector2(34, 0) * s, Color(CREAM, _shown), 6.0 * s)
	draw_colored_polygon(PackedVector2Array([c + Vector2(30, -9) * s, c + Vector2(42, 0) * s,
			c + Vector2(30, 9) * s]), Color(CREAM, _shown))
