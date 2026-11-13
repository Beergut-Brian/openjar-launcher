## Player-flow QA (2026-11-12): what a person on the couch with a pad tries, pinned. Throwaway Save
## profile, picks file and OPENJAR_ROOT. Report: handoff/PLAYER-FLOW.md.
class_name TestPlayerFlow
extends GdUnitTestSuite

const PROFILE := "test_pflow"
const HUB := "res://scenes/hub/hub.tscn"
const HubScript := preload("res://scripts/hub/hub.gd")
const PICKS := "user://test_pflow/players.json"
const DT := 1.0 / 60.0
const OLD_FOLLOW_REACH := 1.9   # the old tag-along never let the friend get further away than this

var root := ""
var log_path := ""
var _saved_profile: String
var _saved_env: String


func before_test() -> void:
	_saved_env = OS.get_environment("OPENJAR_ROOT")
	_saved_profile = Save.profile
	Save.profile = PROFILE
	Save.wipe()
	Roster.picks_path = PICKS
	Roster.data_path = "res://data/roster.json"
	Roster.args_override = PackedStringArray(["--test-pflow"])
	LauncherState.reset_session()
	root = ""


func after_test() -> void:
	Audio.release_all()
	for a in ["p1_move_left", "p1_move_right", "p1_move_up", "p1_move_down", "p1_action",
			"p2_move_left", "p2_move_right", "p2_move_up", "p2_move_down", "p2_action"]:
		Input.action_release(a)
	Save.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % PROFILE))
	Save.profile = _saved_profile
	Save._load()
	for f in [PICKS, PICKS + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	Roster.picks_path = Roster.TEST_PICKS
	Roster.args_override = PackedStringArray()
	Roster.profile_override = ""
	Roster.reload()
	LauncherState.reset_session()
	OS.set_environment("OPENJAR_ROOT", _saved_env)
	OS.low_processor_usage_mode = false
	if root.is_empty():
		return
	for d in DirAccess.get_directories_at(root):
		for f in DirAccess.get_files_at(root.path_join(d)):
			DirAccess.remove_absolute(root.path_join(d).path_join(f))
		DirAccess.remove_absolute(root.path_join(d))
	for f in DirAccess.get_files_at(root):
		DirAccess.remove_absolute(root.path_join(f))
	DirAccess.remove_absolute(root)


func _hub(openjar_root: String) -> Node3D:
	OS.set_environment("OPENJAR_ROOT", openjar_root)
	var hub: Node3D = auto_free(load(HUB).instantiate())
	add_child(hub)
	await get_tree().process_frame
	return hub


## A temp OPENJAR_ROOT: folder -> manifest; every game is a script that logs its arguments.
func _games(manifests: Dictionary) -> void:
	root = OS.get_cache_dir().path_join("openjar_pflow_%d" % Time.get_ticks_usec())
	log_path = root.path_join("launched.log")
	for folder: String in manifests:
		var dir := root.path_join(folder)
		DirAccess.make_dir_recursive_absolute(dir)
		var m: Dictionary = manifests[folder].duplicate()
		m["binary"] = "game.sh"
		var f := FileAccess.open(dir.path_join("openjar.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(m))
		f.close()
		f = FileAccess.open(dir.path_join("game.sh"), FileAccess.WRITE)
		f.store_string("#!/bin/sh\necho \"%s $@\" >> \"%s\"\nsleep 0.3\n" % [folder, log_path])
		f.close()


## The hub and its Jarlings stepped by hand at 60 fps (same on a slow box as on the TV).
func _step(hub: Node3D, frames: int) -> void:
	hub.process_mode = Node.PROCESS_MODE_DISABLED
	for i in frames:
		hub._process(DT)
		for j: HubJarling in hub.jarlings:
			j._process(DT)
	hub.process_mode = Node.PROCESS_MODE_INHERIT


func _stick(player: int, v: Vector2) -> void:
	var s := [maxf(-v.x, 0.0), maxf(v.x, 0.0), maxf(-v.y, 0.0), maxf(v.y, 0.0)]
	var names := ["move_left", "move_right", "move_up", "move_down"]
	for i in 4:
		var a := Players.action(player, names[i])
		if s[i] > 0.0:
			Input.action_press(a, s[i])
		else:
			Input.action_release(a)


## Steer `player`'s own Jarling to jar `index` with their stick until it is in focus, then let go.
func _walk_to_jar(hub: Node3D, player: int, index: int) -> void:
	var j: HubJarling = hub.jarling_for(player)
	var frames := 0
	while hub.focus[hub.jarlings.find(j)] != index and frames < 480:
		var to: Vector3 = hub.spots[index].stand_point - j.position
		_stick(player, Vector2(to.x, to.z).normalized())
		_step(hub, 6)
		frames += 6
	_stick(player, Vector2.ZERO)
	_step(hub, 18)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _wait_for_screen(hub: Node3D, screen: int, limit: float) -> void:
	var waited := 0.0
	while hub.screen != screen and waited < limit:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1


# ---------------------------------------------------------------- PF-1: how do I start a game?

func test_a_jar_in_focus_shows_the_jump_in_button() -> void:
	var hub := await _hub(ProjectSettings.globalize_path("res://tests/fixtures/hub_8"))
	var p1: HubJarling = hub.jarling_for(Players.P1)
	_step(hub, 30)
	assert_int(hub.focus[hub.jarlings.find(p1)]).is_greater_equal(0)   # boots standing at a jar
	assert_bool(p1.go_hint_visible()).is_true()
	assert_int(p1.go_hint_kind).is_equal(HintGlyph.Kind.SPACE)        # no pad here: the key it needs
	# walk away from the row: no jar, no "jump in"
	_stick(Players.P1, Vector2(0, 1))
	_step(hub, 90)
	_stick(Players.P1, Vector2.ZERO)
	_step(hub, 30)
	assert_int(hub.focus[hub.jarlings.find(p1)]).is_equal(-1)
	assert_bool(p1.go_hint_visible()).is_false()
	# back to a jar: it is there again, and gone while the launch plays
	_walk_to_jar(hub, Players.P1, 2)
	assert_bool(p1.go_hint_visible()).is_true()
	hub.press_action(Players.P1)
	_step(hub, 20)
	assert_bool(p1.go_hint_visible()).is_false()


func test_the_jump_in_button_follows_the_players_pad_or_key() -> void:
	var hub := await _hub(ProjectSettings.globalize_path("res://tests/fixtures/hub_8"))
	hub.join_second_player()
	_step(hub, 2)
	assert_int(hub.jarling_for(Players.P1).go_hint_kind).is_equal(HintGlyph.Kind.SPACE)
	assert_int(hub.jarling_for(Players.P2).go_hint_kind).is_equal(HintGlyph.Kind.ENTER)
	for kind: HintGlyph.Kind in HintGlyph.GO_KINDS:
		assert_object(HintGlyph.texture(kind, Players.COLOR[Players.P1])).is_not_null()
	hub.jarling_for(Players.P1).set_go_glyph(HintGlyph.Kind.A)
	assert_int(hub.jarling_for(Players.P1).go_hint_kind).is_equal(HintGlyph.Kind.A)


func test_the_empty_jar_never_offers_jump_in() -> void:
	var hub := await _hub(ProjectSettings.globalize_path("res://tests/fixtures/hub_0"))
	var p1: HubJarling = hub.jarling_for(Players.P1)
	_step(hub, 40)
	assert_int(hub.focus[hub.jarlings.find(p1)]).is_greater_equal(0)
	assert_bool(p1.go_hint_visible()).is_false()


# ---------------------------------------------------------------- PF-2: a game that never starts

func test_an_error_exit_straight_away_counts_as_never_started() -> void:
	assert_bool(HubScript.failed_to_start(3, 300)).is_true()
	assert_bool(HubScript.failed_to_start(0, 300)).is_false()       # a quick, clean quit is a quit
	assert_bool(HubScript.failed_to_start(1, 60000)).is_false()     # played a minute, then crashed: they played


func test_a_game_that_crashes_at_once_brings_you_back_with_a_no_not_a_cheer() -> void:
	_games({"a-game": {"slug": "a-game"}, "b-game": {"slug": "b-game"}})
	var f := FileAccess.open(root.path_join("b-game").path_join("game.sh"), FileAccess.WRITE)
	f.store_string("#!/bin/sh\necho \"b-game $@\" >> \"%s\"\nexit 3\n" % log_path)
	f.close()
	var hub := await _hub(root)
	_walk_to_jar(hub, Players.P1, 1)
	hub.press_action(Players.P1)
	assert_bool(hub.launch.active).is_true()
	await _wait_for_screen(hub, hub.Screen.RUNNING, 5.0)
	await _wait_for_screen(hub, hub.Screen.HUB, 5.0)
	assert_bool(hub.last_return_failed).is_true()
	# and a game that runs and quits cleanly still gets the happy return
	await get_tree().create_timer(1.4).timeout
	_walk_to_jar(hub, Players.P1, 0)
	hub.press_action(Players.P1)
	await _wait_for_screen(hub, hub.Screen.RUNNING, 5.0)
	await _wait_for_screen(hub, hub.Screen.HUB, 5.0)
	assert_bool(hub.last_return_failed).is_false()


# ---------------------------------------------------------------- PF-3: the D-pad walks

func test_every_move_action_has_its_dpad_button() -> void:
	var want := {"move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN,
			"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT}
	for p: int in [Players.P1, Players.P2]:
		for a: String in want:
			var found := false
			for ev in InputMap.action_get_events(Players.action(p, a)):
				if ev is InputEventJoypadButton and ev.button_index == want[a]:
					found = true
			assert_bool(found).override_failure_message("%s has no D-pad" % Players.action(p, a)).is_true()


func test_a_dpad_press_joins_and_walks_player_one() -> void:
	var hub := await _hub(ProjectSettings.globalize_path("res://tests/fixtures/hub_8"))
	var p1: HubJarling = hub.jarling_for(Players.P1)
	var at := p1.position
	var press := InputEventJoypadButton.new()
	press.device = 0
	press.button_index = JOY_BUTTON_DPAD_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	assert_int(Players.device_of(Players.P1)).is_equal(0)   # the D-pad press claimed the pad
	assert_float(Players.move_vector(Players.P1).x).is_less(-0.9)
	_step(hub, 40)
	var release := press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame
	_step(hub, 20)
	assert_float(p1.position.x).is_less(at.x - 1.0)
	# hand the pad back so other suites start with nobody joined
	Players._device_of[Players.P1] = -1
	Players._bind(Players.P1, -1)
