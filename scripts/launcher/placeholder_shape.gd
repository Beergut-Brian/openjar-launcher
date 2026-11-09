## Grey-box shape with a thick outline (house style) for launcher placeholders.
## The Art lane swaps these nodes for sprites; keep the node names.
@tool
class_name PlaceholderShape
extends Control

enum Kind { CIRCLE, SQUARE, TRIANGLE, FACE }

@export var kind: Kind = Kind.SQUARE:
	set(v):
		kind = v
		queue_redraw()
@export var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()
@export var outline := Color("1b1530")
@export var outline_width := 12.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)


func _draw() -> void:
	var w := outline_width
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - w / 2.0
	match kind:
		Kind.CIRCLE, Kind.FACE:
			draw_circle(c, r, color)
			draw_arc(c, r, 0.0, TAU, 64, outline, w, true)
			if kind == Kind.FACE:
				var eye := r * 0.12
				draw_circle(c + Vector2(-r * 0.35, -r * 0.2), eye, outline)
				draw_circle(c + Vector2(r * 0.35, -r * 0.2), eye, outline)
				draw_arc(c + Vector2(0, r * 0.05), r * 0.5, 0.2 * PI, 0.8 * PI, 24, outline, w, true)
		Kind.SQUARE:
			var rect := Rect2(Vector2(w, w) / 2.0, size - Vector2(w, w))
			draw_rect(rect, color)
			draw_rect(rect, outline, false, w)
		Kind.TRIANGLE:
			var pts := PackedVector2Array([
				Vector2(c.x, w), Vector2(size.x - w, size.y - w), Vector2(w, size.y - w)])
			draw_colored_polygon(pts, color)
			pts.append(pts[0])
			draw_polyline(pts, outline, w, true)
