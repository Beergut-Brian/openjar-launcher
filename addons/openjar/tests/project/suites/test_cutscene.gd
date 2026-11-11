## CutscenePlayer (addons/openjar/cutscene) against the demo host: the sample scene loads and
## every line it speaks exists, a full play locks and unlocks input and frees spawned actors, a skip
## still runs every "always" step, context filling, {char} lines, the time cap, a freed host, and
## sounds going through the host. Time is stepped by hand (_process with a fixed delta).
class_name TestCutscene
extends GdUnitTestSuite

const DEMO := "res://addons/openjar/cutscene/demo/cutscene_demo.tscn"
const KNOWN := ["camera", "camera_back", "spawn", "walk", "hop", "face", "show", "hide", "line",
		"bubble", "item", "hold", "drop", "sound", "fade", "bars", "call", "wait"]

var _host: Node2D
var _cp: CutscenePlayer
var _beats: Array = []
var _done: Array = []


func before_test() -> void:
	_beats.clear()
	_done.clear()
	_host = auto_free(load(DEMO).instantiate())
	add_child(_host)              # not the tree root: the demo does not auto-play
	_cp = _host.player
	_cp.set_process(false)
	_cp.beat.connect(func(k: String, d: String) -> void: _beats.append([k, d]))
	_cp.finished.connect(func(id: StringName, skipped: bool) -> void: _done.append([id, skipped]))


func _run(secs: float, dt := 0.05) -> void:
	var t := 0.0
	while t < secs and _cp.is_playing():
		_cp._process(dt)
		t += dt


func _kinds() -> Array:
	return _beats.map(func(b: Array) -> String: return b[0])


func test_sample_loads_and_every_line_it_speaks_exists() -> void:
	var d := CutscenePlayer.load_scene(&"sample")
	assert_str(String(d.get("id", ""))).is_equal("sample")
	for s: Dictionary in d.steps:
		assert_array(KNOWN).contains([String(s.do)])
		if String(s.do) == "line":
			var l := CutscenePlayer.line(String(s.line), "nobody")
			assert_dict(l).is_not_empty()
			for p in s.get("pics", []):
				assert_bool(PictoBubble.has_picture(StringName(p))).is_true()
	assert_dict(CutscenePlayer.load_scene(&"no_such_scene")).is_empty()


func test_full_play_locks_runs_every_step_and_hands_back() -> void:
	assert_bool(_cp.play(&"sample")).is_true()
	assert_bool(_host.locked).is_true()
	assert_bool(_cp.play(&"sample")).is_false()      # one at a time
	assert_str(String(_cp.current())).is_equal("sample")
	_run(0.7)                                         # camera wait 0.6, then the spawn
	var guest: Node2D = _cp._actor("guest")
	assert_object(guest).is_not_null()
	_run(30.0)
	assert_bool(_cp.is_playing()).is_false()
	assert_bool(_host.locked).is_false()
	assert_array(_done).is_equal([[&"sample", false]])
	assert_array(_host.calls).is_equal([["mark_seen", {"flag": "sample"}]])
	for k in ["camera", "spawn", "walk", "line", "hop", "item", "hold", "call", "camera_back", "end"]:
		assert_array(_kinds()).contains([k])
	assert_bool(guest.is_queued_for_deletion()).is_true()
	# Walk reached its target: 28 px left of the host actor.
	assert_float(guest.global_position.x).is_equal_approx(_host.actors.host.global_position.x - 28.0, 0.01)


func test_skip_runs_always_steps_and_unlocks_at_once() -> void:
	_cp.play(&"sample")
	_run(0.3)
	_cp.skip()
	assert_bool(_cp.is_playing()).is_false()
	assert_bool(_host.locked).is_false()
	assert_array(_done).is_equal([[&"sample", true]])
	assert_array(_host.calls).is_equal([["mark_seen", {"flag": "sample"}]])
	assert_array(_kinds()).contains(["skip"])


func test_skip_press_is_ignored_during_the_grace_then_skips() -> void:
	var d := {"id": "long", "steps": [{"do": "wait", "time": 20.0}, {"do": "call", "fn": "x", "always": true}]}
	var presser: _Presser = auto_free(_Presser.new())
	presser.inner = _host
	_cp.host = presser
	assert_bool(_cp.play_data(d)).is_true()
	presser.pressed = true
	_cp._process(0.2)                                 # inside SKIP_GRACE
	assert_bool(_cp.is_playing()).is_true()
	_run(1.0)
	assert_bool(_cp.is_playing()).is_false()
	assert_array(_done).is_equal([[&"long", true]])
	assert_array(_host.calls).is_equal([["x", {}]])


func test_time_cap_ends_any_scene() -> void:
	_cp.play_data({"id": "stuck", "steps": [{"do": "wait", "time": 1000.0}]})
	_run(CutscenePlayer.MAX_SECS + 2.0, 0.5)
	assert_bool(_cp.is_playing()).is_false()
	assert_array(_done).is_equal([[&"stuck", true]])


func test_freed_host_skips() -> void:
	var h := _Presser.new()
	h.inner = _host
	_cp.host = h
	_cp.play_data({"id": "orphan", "steps": [{"do": "wait", "time": 10.0}]})
	h.free()
	_cp._process(0.05)
	assert_bool(_cp.is_playing()).is_false()


func test_context_fills_values_and_gates_steps() -> void:
	var d := {"id": "ctx", "steps": [
		{"do": "call", "fn": "{who}_hi", "args": "@payload"},
		{"do": "call", "fn": "only_if", "if": "flag"},
		{"do": "call", "fn": "only_unless", "unless": "flag"},
		{"do": "call", "fn": "needs_ghost", "needs": "ghost"},
	]}
	_cp.play_data(d, {"who": "host", "payload": {"n": 3}, "flag": true})
	_run(5.0)
	assert_array(_host.calls).is_equal([["host_hi", {"n": 3}], ["only_if", {}]])


func test_char_lines_fall_back_to_any() -> void:
	assert_str(String(CutscenePlayer.line("sample_bye_{char}", "guest").get("id", ""))).is_equal("sample_bye_any")
	assert_dict(CutscenePlayer.line("missing_{char}", "guest")).is_empty()
	assert_float(CutscenePlayer.line_secs({"id": "x", "text": "one two three"})).is_between(1.6, 4.2)


func test_sounds_go_through_the_host() -> void:
	_cp.cues["start"] = "go"
	_cp.play_data({"id": "snd", "steps": [{"do": "sound", "cue": "boom"}, {"do": "line", "who": "host", "line": "sample_hello"}]})
	_run(10.0)
	assert_array(_host.sounds).contains_exactly(["go", "boom", "ui_confirm"])
	assert_array(_cp.said).is_equal([["sample_hello", "guest", "sfx"]])


func test_player_lines_follow_player_characters() -> void:
	assert_bool(_cp._is_player_line({"character": "any"})).is_true()
	assert_bool(_cp._is_player_line({"character": "jeff"})).is_false()
	_cp.player_characters = PackedStringArray(["jeff"])
	assert_bool(_cp._is_player_line({"character": "jeff"})).is_true()


func test_camera_eases_to_the_anchor_and_back() -> void:
	var cam: Camera2D = _host.camera
	_cp.play_data({"id": "cam", "steps": [{"do": "camera", "to": "right", "zoom": 3.0, "time": 0.5, "wait": 2.0}, {"do": "wait", "time": 0.1}]})
	for i in 40:
		_cp._process(0.05)
	assert_float(cam.position.x).is_equal_approx(120.0, 1.0)
	assert_float(cam.zoom.x).is_equal_approx(3.0, 0.05)


class _Presser extends Node:
	var inner: Node
	var pressed := false

	func cutscene_skip_pressed() -> bool:
		return pressed

	func cutscene_call(fn: String, args: Dictionary) -> void:
		inner.cutscene_call(fn, args)

	func cutscene_views() -> Array:
		return inner.cutscene_views()
