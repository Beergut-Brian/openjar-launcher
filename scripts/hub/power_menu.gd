## NS-1: holding Start opens this instead of quitting (there is no Steam to go back to: the box boots
## straight into the launcher). Big round buttons, pictures only, nothing to read (K-01):
##   Back (a curling arrow, focused when it opens), Sleep (a moon), Shut down (the power sign),
##   and, only with --allow-quit, a dev quit (the open door of the Start badge).
## Shut down needs A held SHUTDOWN_HOLD s while a ring fills round it; let go early and nothing
## happens. Input comes from the hub (it owns the pads); this only draws, steps and counts.
class_name PowerMenu
extends Control

enum Item { BACK, SLEEP, SHUT_DOWN, QUIT }

signal chosen(item: Item)

const SHUTDOWN_HOLD := 1.5
const RADIUS := 104.0
const GAP := 90.0
const INK := Color("2b2140")
const CREAM := Color("fff4dc")
const FILL := Color("ffd23f")   # the Start badge's ring colour; never a player's green or red
const TINTS := {
	Item.BACK: Color("fff4dc"),
	Item.SLEEP: Color("8fb8ff"),
	Item.SHUT_DOWN: Color("ff9a3d"),
	Item.QUIT: Color("b9b4ff"),
}

var items: Array[Item] = [Item.BACK, Item.SLEEP, Item.SHUT_DOWN]
var focus := 0
var confirm := 0.0          # 0..1 while A is held on Shut down
var _open := false
var _shown := 0.0
var _bump := 0.0            # the focused button's little pop on every step
var _nudge := 0.0           # a side-to-side "no" shake
var _holding := false
var _clock := 0.0


func _ready() -> void:
	name = "PowerMenu"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func set_allow_quit(on: bool) -> void:
	items = [Item.BACK, Item.SLEEP, Item.SHUT_DOWN]
	if on:
		items.append(Item.QUIT)


func is_open() -> bool:
	return _open


func focused() -> Item:
	return items[focus]


func open() -> void:
	_open = true
	focus = 0   # Back: an accidental open is undone with one press of A
	confirm = 0.0
	_holding = false
	_bump = 1.0
	visible = true


func close() -> void:
	_open = false
	confirm = 0.0
	_holding = false


## Move the focus one button left (-1) or right (+1). Stops at the ends with a nudge.
## True if it moved.
func step(dir: int) -> bool:
	var to := clampi(focus + dir, 0, items.size() - 1)
	confirm = 0.0
	_holding = false
	if to == focus:
		nudge()
		return false
	focus = to
	_bump = 1.0
	return true


## A pressed. Back, Sleep and the dev quit are chosen at once; Shut down starts its hold.
func press() -> void:
	if focused() == Item.SHUT_DOWN:
		_holding = true
		confirm = 0.0
		_bump = 1.0
		return
	chosen.emit(focused())


## A's state each frame while open. True on the frame the Shut down hold completes.
func update_confirm(a_down: bool, delta: float) -> bool:
	if not _holding:
		return false
	if not a_down:
		_holding = false
		confirm = 0.0
		return false
	confirm = minf(confirm + delta / SHUTDOWN_HOLD, 1.0)
	if confirm >= 1.0:
		_holding = false
		chosen.emit(Item.SHUT_DOWN)
		return true
	return false


func holding() -> bool:
	return _holding


func nudge() -> void:
	_nudge = 1.0


func _process(delta: float) -> void:
	_clock += delta
	_shown = move_toward(_shown, 1.0 if _open else 0.0, delta * (7.0 if _open else 5.0))
	_bump = move_toward(_bump, 0.0, delta * 4.0)
	_nudge = move_toward(_nudge, 0.0, delta * 3.5)
	visible = _shown > 0.0
	if visible:
		queue_redraw()


## Centre of button i on screen.
func button_centre(i: int) -> Vector2:
	var size_px := get_viewport_rect().size
	var span := items.size() * RADIUS * 2.0 + (items.size() - 1) * GAP
	var x := size_px.x * 0.5 - span * 0.5 + RADIUS + i * (RADIUS * 2.0 + GAP)
	return Vector2(x, size_px.y * 0.5)


func _draw() -> void:
	var a := smoothstep(0.0, 1.0, _shown)
	draw_rect(get_viewport_rect(), Color(INK.darkened(0.4), 0.72 * a))
	var shake := sin(_clock * 60.0) * 14.0 * _nudge
	for i in items.size():
		var item := items[i]
		var on := i == focus
		var r := RADIUS * (0.7 + 0.3 * a) * (1.18 if on else 0.92) * (1.0 + 0.08 * sin(_bump * PI) if on else 1.0)
		var c := button_centre(i) + Vector2(shake if on else 0.0, 0.0)
		if on:
			c.y += sin(_clock * 3.0) * 5.0   # the focused one floats a little
			draw_circle(c, r + 22.0, Color(FILL, a))
		draw_circle(c, r + 9.0, Color(CREAM, a * (1.0 if on else 0.55)))
		draw_circle(c, r, Color(INK, a))
		var tint: Color = TINTS[item]
		if on and item == Item.SHUT_DOWN and (confirm > 0.0 or _holding):   # the hold's ring, outside the focus ring
			draw_arc(c, r + 44.0, 0.0, TAU, 64, Color(CREAM, 0.35 * a), 16.0, true)
			draw_arc(c, r + 44.0, -PI / 2.0, -PI / 2.0 + TAU * confirm, 64, Color(tint, a), 16.0, true)
		var ink := Color(tint, a * (1.0 if on else 0.6))
		_icon(item, c, r / RADIUS, ink, a)
	if _open and focus < items.size():   # the pad's A under the focused button: press it (hold it on Shut down)
		var c := button_centre(focus) + Vector2(0, RADIUS * 1.18 + (96.0 if focused() == Item.SHUT_DOWN else 70.0))
		draw_circle(c, 34.0, Color(CREAM, a))
		draw_circle(c, 28.0, Color(INK, a))
		var font := ThemeDB.fallback_font
		var fs := 40
		var w := font.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, c + Vector2(-w.x * 0.5, w.y * 0.32), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(FILL, a))


func _icon(item: Item, c: Vector2, s: float, ink: Color, a: float) -> void:
	match item:
		Item.BACK:   # an arrow curling back round to the left: "never mind"
			draw_arc(c + Vector2(6, 6) * s, 40.0 * s, -PI * 0.5, PI * 0.5, 32, ink, 14.0 * s, true)
			draw_line(c + Vector2(6, 46) * s, c + Vector2(-22, 46) * s, ink, 14.0 * s, true)
			draw_line(c + Vector2(6, -34) * s, c + Vector2(-20, -34) * s, ink, 14.0 * s, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-52, -34) * s, c + Vector2(-18, -62) * s,
					c + Vector2(-18, -6) * s]), ink)
		Item.SLEEP:   # a crescent moon and two little stars
			draw_circle(c + Vector2(-6, 4) * s, 50.0 * s, ink)
			draw_circle(c + Vector2(18, -14) * s, 44.0 * s, Color(INK, a))
			for st: Vector3 in [Vector3(36, -42, 9), Vector3(52, 6, 6)]:
				_star(c + Vector2(st.x, st.y) * s, st.z * s, ink)
		Item.SHUT_DOWN:   # the power sign: a ring open at the top, a bar through the gap
			draw_arc(c + Vector2(0, 6) * s, 46.0 * s, -PI * 0.5 + 0.62, PI * 1.5 - 0.62, 40, ink, 15.0 * s, true)
			draw_line(c + Vector2(0, -50) * s, c + Vector2(0, 4) * s, ink, 15.0 * s, true)
			draw_circle(c + Vector2(0, -50) * s, 7.5 * s, ink)
			draw_circle(c + Vector2(0, 4) * s, 7.5 * s, ink)
		Item.QUIT:   # dev only: the Start badge's open door with a step out of it
			draw_rect(Rect2(c + Vector2(-34, -48) * s, Vector2(48, 96) * s), ink, false, 8.0 * s)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-34, -48) * s, c + Vector2(-4, -34) * s,
					c + Vector2(-4, 58) * s, c + Vector2(-34, 48) * s]), ink)
			draw_line(c + Vector2(24, 0) * s, c + Vector2(52, 0) * s, ink, 10.0 * s)
			draw_colored_polygon(PackedVector2Array([c + Vector2(48, -15) * s, c + Vector2(66, 0) * s,
					c + Vector2(48, 15) * s]), ink)


func _star(c: Vector2, r: float, ink: Color) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		var ang := k * PI / 4.0 - PI / 2.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * (r * 1.6 if k % 2 == 0 else r * 0.5))
	draw_colored_polygon(pts, ink)
