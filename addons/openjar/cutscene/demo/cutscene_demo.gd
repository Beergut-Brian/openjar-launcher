## A tiny host for CutscenePlayer: two shape actors on a strip of ground, one Camera2D, and the
## host interface (docs/cutscene-format.md). Plays demo/sample.json once and quits.
##   godot --path tests/project res://addons/openjar/cutscene/demo/cutscene_demo.tscn
## Args after `--`: --no-quit (stay on the last frame), --speed=<x>.
extends Node2D

const DEMO_DIR := "res://addons/openjar/cutscene/demo/"

var player: CutscenePlayer
var camera: Camera2D
var actors: Dictionary = {}       # name -> Node2D
var anchors := {"left": Vector2(-120, 0), "middle": Vector2(0, 0), "right": Vector2(120, 0)}
var locked := false
var calls: Array = []             # [fn, args] the scene asked for
var sounds: Array = []            # cues the scene played
var quit_at_end := true


class Actor extends Node2D:
	var color := Color.WHITE
	var facing := 1:
		set(v):
			facing = v
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-8, -24, 16, 24), color.darkened(0.4))
		draw_rect(Rect2(-7, -23, 14, 22), color)
		draw_circle(Vector2(3 * facing, -17), 2.0, Color("3a2a44"))


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--no-quit":
			quit_at_end = false
	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	add_child(camera)
	actors["host"] = _actor(Color("e4393c"), Vector2(60, 0), -1)
	var ui := CanvasLayer.new()
	add_child(ui)
	CutscenePlayer.scene_dir = DEMO_DIR
	CutscenePlayer.lines_path = DEMO_DIR + "sample_lines.json"
	CutscenePlayer.voice_dir = DEMO_DIR
	player = CutscenePlayer.new()
	player.host = self
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--speed="):
			player.speed = float(a.get_slice("=", 1))
	ui.add_child(player)
	player.finished.connect(_on_finished)
	if get_parent() == get_tree().root:
		player.play.call_deferred(&"sample")


func _actor(col: Color, pos: Vector2, face: int) -> Node2D:
	var a := Actor.new()
	a.color = col
	a.position = pos
	a.facing = face
	add_child(a)
	return a


func _draw() -> void:
	draw_rect(Rect2(-400, -300, 800, 300), Color("8fd3ff"))
	draw_rect(Rect2(-400, 0, 800, 200), Color("6dbb4a"))
	draw_rect(Rect2(-400, 6, 800, 200), Color("8a5a3c"))


func _on_finished(_id: StringName, _skipped: bool) -> void:
	if quit_at_end and get_parent() == get_tree().root:
		get_tree().quit()


# --- host interface ------------------------------------------------------------------------------

func cutscene_actor(n: String) -> Node2D:
	return actors.get(n)


func cutscene_spawn(_n: String, _sheet: String, _scene: String, pos: Vector2) -> Node2D:
	var a := _actor(Color("3cc24a"), pos, 1)
	return a


func cutscene_anchor(n: String) -> Vector2:
	return anchors.get(n, Vector2.INF)


func cutscene_views() -> Array:
	return [{"camera": camera, "rect": get_viewport_rect()}]


func cutscene_lock(on: bool) -> void:
	locked = on


func cutscene_call(fn: String, args: Dictionary) -> void:
	calls.append([fn, args])


func cutscene_skip_pressed() -> bool:
	return Input.is_action_just_pressed(&"ui_accept")


func cutscene_character(actor: String) -> String:
	return actor


func cutscene_sound(cue: String) -> void:
	sounds.append(cue)


func cutscene_head(_actor: String) -> Vector2:
	return Vector2(0, -27)
