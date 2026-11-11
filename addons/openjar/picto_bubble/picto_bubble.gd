## Picture speech bubbles: no words, no numbers. A bubble is a rounded white panel with a tail
## pointing down at the speaker, holding a row of pictures; the last one is usually a face. Pure
## draw helpers (call from a CanvasItem's _draw()).
##   PictoBubble.draw(self, mouth, [&"shovel", &"face_sheepish"], alpha)
## Built-in pictures (game-agnostic): &"shovel", &"heart", &"house", &"star", &"question",
## &"face_sheepish", &"face_hopeful", &"face_happy", &"tree", &"rock", &"exclaim", &"zzz",
## &"sparkle", &"hardhat". Anything else is a gold dot unless the game registers it:
##   PictoBubble.register(&"deed", func(ci, id, c, s, a): ...)          # one id
##   PictoBubble.register_prefix("vehicle:", func(ci, id, c, s, a): ...) # every "vehicle:<x>"
## A drawer draws picture `id` centred at c inside a box of side s with alpha a (u = s / 22 is one
## design unit). texture_picture() fits a sprite frame into the box. A registered id wins over a
## built-in one of the same name. From The Hill's scripts/gameplay/picto_bubble.gd.
class_name PictoBubble
extends RefCounted

const CELL := 22.0
const BUILTIN: Array[StringName] = [&"shovel", &"heart", &"house", &"star", &"question", &"face_sheepish", &"face_hopeful", &"face_happy", &"tree", &"rock", &"exclaim", &"zzz", &"sparkle", &"hardhat"]
const PAD := 4.0
const OUTLINE := Color("3a2a44")
const PAPER := Color("fffaf0")
const SKIN := Color("ffd9a8")
const GOLD := Color("ffd23f")
const PINK := Color("ff8fb1")

static var _drawers: Dictionary = {}    # StringName -> Callable(ci, id, c, s, a)
static var _prefixes: Dictionary = {}   # String -> Callable(ci, id, c, s, a)


## The game's own picture for `id` (replaces a built-in of the same name).
static func register(id: StringName, drawer: Callable) -> void:
	_drawers[id] = drawer


## A drawer for every id starting with `prefix` (e.g. "vehicle:"); it gets the full id.
static func register_prefix(prefix: String, drawer: Callable) -> void:
	_prefixes[prefix] = drawer


## Forgets every registered drawer (tests; a game switching scenes keeps them).
static func clear_registry() -> void:
	_drawers.clear()
	_prefixes.clear()


## True when `id` draws as something other than the gold-dot fallback.
static func has_picture(id: StringName) -> bool:
	if _drawers.has(id) or id in BUILTIN:
		return true
	for p: String in _prefixes:
		if String(id).begins_with(p):
			return true
	return false


## Size of a bubble with n pictures (without the tail), at scale k.
static func size_for(n: int, k := 1.0) -> Vector2:
	return Vector2(n * CELL + (n + 1) * PAD, CELL + 2 * PAD) * k


## Draws the bubble whose tail tip is at `tip` (the speaker's head), pictures left to right.
## `pop` 0..1 scales it in (0.6 -> 1 with a little overshoot handled by the caller's curve).
static func draw(ci: CanvasItem, tip: Vector2, pics: Array, alpha := 1.0, k := 1.0) -> void:
	if alpha <= 0.01 or pics.is_empty():
		return
	var sz := size_for(pics.size(), k)
	var r := Rect2(tip + Vector2(-sz.x * 0.5, -sz.y - 7.0 * k), sz)
	var ol := Color(OUTLINE, alpha)
	var paper := Color(PAPER, alpha)
	var tail := PackedVector2Array([tip, tip + Vector2(-5, -8) * k, tip + Vector2(5, -8) * k])
	_round_rect(ci, r.grow(1.5 * k), 5.0 * k, ol)
	ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 1.5) * k, tip + Vector2(-7, -8.5) * k, tip + Vector2(7, -8.5) * k]), ol)
	_round_rect(ci, r, 4.0 * k, paper)
	ci.draw_colored_polygon(tail, paper)
	for i in pics.size():
		var c := r.position + Vector2(PAD + i * (CELL + PAD) + CELL * 0.5, PAD + CELL * 0.5) * k
		picture(ci, StringName(str(pics[i])), c, CELL * k, alpha)


static func _round_rect(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	ci.draw_rect(Rect2(r.position.x + rad, r.position.y, r.size.x - 2 * rad, r.size.y), col)
	ci.draw_rect(Rect2(r.position.x, r.position.y + rad, r.size.x, r.size.y - 2 * rad), col)
	for p in [r.position + Vector2(rad, rad), Vector2(r.end.x - rad, r.position.y + rad),
			Vector2(r.position.x + rad, r.end.y - rad), r.end - Vector2(rad, rad)]:
		ci.draw_circle(p, rad, col)


## One picture centred at c, fitting a box of side s.
static func picture(ci: CanvasItem, id: StringName, c: Vector2, s: float, a := 1.0) -> void:
	var u := s / 22.0
	var ol := Color(OUTLINE, a)
	var sid := String(id)
	var drawer: Callable = _drawers.get(id, Callable())
	if not drawer.is_valid():
		for p: String in _prefixes:
			if sid.begins_with(p):
				drawer = _prefixes[p]
				break
	if drawer.is_valid():
		drawer.call(ci, id, c, s, a)
		return
	match id:
		&"shovel":
			# Handle up-right, blade down-left.
			ci.draw_line(c + Vector2(7, -9) * u, c + Vector2(-2, 2) * u, ol, 4.0 * u)
			ci.draw_line(c + Vector2(7, -9) * u, c + Vector2(-2, 2) * u, Color("a47148", a), 2.0 * u)
			ci.draw_line(c + Vector2(5, -10) * u, c + Vector2(9, -7) * u, ol, 3.0 * u)
			var blade := PackedVector2Array([c + Vector2(-1, 0) * u, c + Vector2(-8, 4) * u, c + Vector2(-8, 9) * u, c + Vector2(-3, 9) * u, c + Vector2(2, 3) * u])
			ci.draw_colored_polygon(blade, Color("b8c4cc", a))
			ci.draw_polyline(_loop(blade), ol, 1.2 * u)
		&"heart":
			ci.draw_circle(c + Vector2(-3.5, -2) * u, 4.5 * u, Color(PINK, a))
			ci.draw_circle(c + Vector2(3.5, -2) * u, 4.5 * u, Color(PINK, a))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -0.5) * u, c + Vector2(8, -0.5) * u, c + Vector2(0, 8) * u]), Color(PINK, a))
		&"house":
			ci.draw_rect(Rect2(c + Vector2(-7, -1) * u, Vector2(14, 9) * u), Color("f2d7a0", a))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -1) * u, c + Vector2(0, -9) * u, c + Vector2(9, -1) * u]), Color("c8372d", a))
			ci.draw_rect(Rect2(c + Vector2(-2, 2) * u, Vector2(4, 6) * u), Color("8a5a2b", a))
		&"star":
			var pts := PackedVector2Array()
			for i in 10:
				var rr := (9.0 if i % 2 == 0 else 4.0) * u
				pts.append(c + Vector2.from_angle(-PI * 0.5 + i * PI / 5.0) * rr)
			ci.draw_colored_polygon(pts, Color(GOLD, a))
			ci.draw_polyline(_loop(pts), ol, 1.0 * u)
		&"question":
			ci.draw_arc(c + Vector2(0, -3) * u, 5.0 * u, PI * 1.05, TAU + PI * 0.45, 10, ol, 3.0 * u)
			ci.draw_line(c + Vector2(1.5, 1.5) * u, c + Vector2(0, 4) * u, ol, 3.0 * u)
			ci.draw_circle(c + Vector2(0, 8) * u, 1.8 * u, ol)
		&"face_sheepish", &"face_hopeful", &"face_happy":
			_face(ci, id, c, u, a)
		&"tree":
			ci.draw_rect(Rect2(c + Vector2(-1.5, 2) * u, Vector2(3, 7) * u), Color("8a5a2b", a))
			ci.draw_circle(c + Vector2(0, -3) * u, 7.0 * u, ol)
			ci.draw_circle(c + Vector2(0, -3) * u, 6.0 * u, Color("4f9e3a", a))
			ci.draw_circle(c + Vector2(-2, -5) * u, 2.0 * u, Color("6dbb4a", a))
		&"rock":
			var rk := PackedVector2Array([c + Vector2(-8, 7) * u, c + Vector2(-6, -2) * u, c + Vector2(-1, -6) * u, c + Vector2(6, -3) * u, c + Vector2(8, 7) * u])
			ci.draw_colored_polygon(rk, Color("9aa3a8", a))
			ci.draw_polyline(_loop(rk), ol, 1.2 * u)
			ci.draw_line(c + Vector2(-3, -2) * u, c + Vector2(-1, -4) * u, Color(1, 1, 1, a * 0.7), 1.2 * u)
		&"exclaim":
			ci.draw_line(c + Vector2(0, -9) * u, c + Vector2(0, 3) * u, Color("e4393c", a), 4.0 * u)
			ci.draw_circle(c + Vector2(0, 8) * u, 2.2 * u, Color("e4393c", a))
		&"zzz":
			for i in 3:
				var o := c + Vector2(-6 + i * 5, 5 - i * 5) * u
				var zs := (3.0 + i) * u
				ci.draw_polyline(PackedVector2Array([o + Vector2(-zs, -zs), o + Vector2(zs, -zs), o + Vector2(-zs, zs), o + Vector2(zs, zs)]), ol, 1.4 * u)
		&"sparkle":
			for i in 3:
				var spots: Array[Vector2] = [Vector2(-4, -3), Vector2(5, -5), Vector2(2, 6)]
				var sizes: Array[float] = [5.0, 3.5, 3.0]
				var o: Vector2 = c + spots[i] * u
				var r: float = sizes[i] * u
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(0, -r), o + Vector2(r * 0.3, 0), o + Vector2(0, r), o + Vector2(-r * 0.3, 0)]), Color(GOLD, a))
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-r, 0), o + Vector2(0, r * 0.3), o + Vector2(r, 0), o + Vector2(0, -r * 0.3)]), Color(GOLD, a))
		&"hardhat":
			ci.draw_circle(c + Vector2(0, 2) * u, 7.0 * u, Color(GOLD, a))
			ci.draw_rect(Rect2(c + Vector2(-10, 2) * u, Vector2(20, 3) * u), Color(GOLD, a))
			ci.draw_rect(Rect2(c + Vector2(-10, 2) * u, Vector2(20, 3) * u), ol, false, 0.9 * u)
			ci.draw_arc(c + Vector2(0, 2) * u, 7.0 * u, PI, TAU, 12, ol, 1.0 * u)
			ci.draw_rect(Rect2(c + Vector2(-1, -5) * u, Vector2(2, 7) * u), Color(Color("e0b020"), a))
		_:
			ci.draw_circle(c, 6.0 * u, Color(GOLD, a))


static func _face(ci: CanvasItem, id: StringName, c: Vector2, u: float, a: float) -> void:
	var ol := Color(OUTLINE, a)
	ci.draw_circle(c, 9.5 * u, ol)
	ci.draw_circle(c, 8.5 * u, Color(Color("ffe27a"), a))
	match id:
		&"face_sheepish":
			# Eyes looking aside, a wobbly little mouth, one sweat drop. Funny-sad, never crying.
			ci.draw_circle(c + Vector2(-2, -2) * u, 1.3 * u, ol)
			ci.draw_circle(c + Vector2(3.5, -2) * u, 1.3 * u, ol)
			var m := PackedVector2Array()
			for i in 6:
				m.append(c + Vector2(-3.5 + i * 1.4, 4.0 + (0.8 if i % 2 == 0 else -0.8)) * u)
			ci.draw_polyline(m, ol, 1.2 * u)
			ci.draw_circle(c + Vector2(7, -5) * u, 1.6 * u, Color(0.55, 0.8, 1.0, a))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(5.6, -5.4) * u, c + Vector2(8.4, -5.4) * u, c + Vector2(7, -8.5) * u]), Color(0.55, 0.8, 1.0, a))
		&"face_hopeful":
			# Big round eyes with a shine, a small open smile, brows up.
			for ex in [-3.2, 3.2]:
				ci.draw_circle(c + Vector2(ex, -1.5) * u, 2.0 * u, ol)
				ci.draw_circle(c + Vector2(ex + 0.6, -2.2) * u, 0.7 * u, Color(1, 1, 1, a))
				ci.draw_line(c + Vector2(ex - 1.8, -5.5) * u, c + Vector2(ex + 1.8, -6.2) * u, ol, 1.0 * u)
			ci.draw_arc(c + Vector2(0, 2.5) * u, 2.6 * u, 0.15, PI - 0.15, 8, ol, 1.3 * u)
		_:
			ci.draw_arc(c + Vector2(-3, -1.5) * u, 1.6 * u, PI, TAU, 6, ol, 1.2 * u)
			ci.draw_arc(c + Vector2(3, -1.5) * u, 1.6 * u, PI, TAU, 6, ol, 1.2 * u)
			ci.draw_arc(c + Vector2(0, 1.5) * u, 4.5 * u, 0.2, PI - 0.2, 10, ol, 1.6 * u)


## Draws a region of a texture (a sprite's first frame) scaled to fit the box of side s at c.
## region size ZERO: the whole texture. For registered drawers.
static func texture_picture(ci: CanvasItem, tex: Texture2D, region: Rect2, c: Vector2, s: float, a := 1.0) -> void:
	if tex == null:
		picture(ci, &"star", c, s, a)
		return
	var fs := region.size if region.size != Vector2.ZERO else Vector2(tex.get_size())
	var src := Rect2(region.position, fs)
	var k := minf(s / fs.x, s / fs.y)
	var sz := fs * k
	ci.draw_texture_rect_region(tex, Rect2(c - sz * 0.5, sz), src, Color(1, 1, 1, a))


static func _loop(p: PackedVector2Array) -> PackedVector2Array:
	var l := p.duplicate()
	l.append(p[0])
	return l
