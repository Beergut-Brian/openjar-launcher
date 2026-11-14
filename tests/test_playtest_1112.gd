## Playtest 2026-11-12 (Kaden): "Players should be able to walk around independently. Right now we're
## stuck together. Either player can launch a game." and "Dev mode shows multiple versions of the game.
## It should only show the dev version." Throwaway Save profile, picks file and OPENJAR_ROOT.
class_name TestPlaytest1112
extends GdUnitTestSuite

const PROFILE := "test_pt1112"
const HUB := "res://scenes/hub/hub.tscn"
const PICKS := "user://test_pt1112/players.json"
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
	Roster.data_path = "res://tests/fixtures/roster_three.json"   # a fixture, never the real roster's contents
	Roster.args_override = PackedStringArray(["--test-pt1112"])
	Roster.reload()   # picks from this test's own file (empty: the roster defaults), not from an earlier test
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
## The fake game waits a little before it logs, like a real game on a slow box: the launcher's
## RUNNING screen comes the moment the process is started, long before the game has read its
## arguments, so a test must wait for the log line (_wait_for_log), never read it at RUNNING.
func _games(manifests: Dictionary) -> void:
	root = OS.get_cache_dir().path_join("openjar_pt1112_%d" % Time.get_ticks_usec())
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
		f.store_string("#!/bin/sh\nsleep 0.4\necho \"%s $@\" >> \"%s\"\nsleep 0.3\n" % [folder, log_path])
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


## Bounded waits on state, by the clock (the hub runs on real time here, not on _step).
func _wait_for_screen(hub: Node3D, screen: int, limit: float) -> bool:
	var until := Time.get_ticks_msec() + int(limit * 1000.0)
	while hub.screen != screen and Time.get_ticks_msec() < until:
		await get_tree().create_timer(0.05).timeout
	return hub.screen == screen


## The first whole line the fake game logged ("" if none came within `limit` seconds).
func _wait_for_log(limit: float) -> String:
	var until := Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < until:
		var text := FileAccess.get_file_as_string(log_path) if FileAccess.file_exists(log_path) else ""
		if text.contains("\n"):
			return text.get_slice("\n", 0).strip_edges()
		await get_tree().create_timer(0.05).timeout
	return ""


# ---------------------------------------------------------------- PT1112-1: walk on your own

func test_two_players_walk_apart_on_opposite_sticks() -> void:
	var hub := await _hub(ProjectSettings.globalize_path("res://tests/fixtures/hub_8"))
	hub.join_second_player()
	var p1: HubJarling = hub.jarling_for(Players.P1)
	var p2: HubJarling = hub.jarling_for(Players.P2)
	var start := _flat(p1.position, p2.position)
	_stick(Players.P1, Vector2(-1, 0.4))
	_stick(Players.P2, Vector2(1, 0.4))
	_step(hub, 150)   # 2.5 s of opposite sticks
	_stick(Players.P1, Vector2.ZERO)
	_stick(Players.P2, Vector2.ZERO)
	_step(hub, 30)
	var apart := _flat(p1.position, p2.position)
	assert_float(apart).is_greater(OLD_FOLLOW_REACH * 4.0)
	assert_float(apart).is_greater(start + 10.0)
	assert_float(p1.position.x).is_less(-4.0)    # each went its own way, all the way
	assert_float(p2.position.x).is_greater(4.0)
	# and they stay apart: nothing pulls them back together once the sticks are let go
	var held_at := [p1.position, p2.position]
	_step(hub, 120)
	assert_float(_flat(p1.position, held_at[0])).is_less(0.05)
	assert_float(_flat(p2.position, held_at[1])).is_less(0.05)


func test_one_stick_moves_only_its_own_jarling() -> void:
	var hub := await _hub(ProjectSettings.globalize_path("res://tests/fixtures/hub_8"))
	hub.join_second_player()
	var p1: HubJarling = hub.jarling_for(Players.P1)
	var p2: HubJarling = hub.jarling_for(Players.P2)
	var p2_at := p2.position
	_stick(Players.P1, Vector2(0, 1))
	_step(hub, 120)
	_stick(Players.P1, Vector2.ZERO)
	_step(hub, 30)
	assert_float(_flat(p2.position, p2_at)).is_less(0.05)   # P1 walking never drags P2
	assert_float(_flat(p1.position, p2.position)).is_greater(OLD_FOLLOW_REACH * 3.0)


func test_the_jarling_nobody_holds_waits_and_never_tags_along() -> void:
	var hub := await _hub(ProjectSettings.globalize_path("res://tests/fixtures/hub_8"))
	var p1: HubJarling = hub.jarling_for(Players.P1)
	var friend: HubJarling = hub.jarlings[1 - hub.jarlings.find(p1)]
	assert_bool(friend.is_held()).is_false()
	var at := friend.position
	_stick(Players.P1, Vector2(-1, 0.5))
	_step(hub, 150)
	_stick(Players.P1, Vector2.ZERO)
	_step(hub, 30)
	assert_float(_flat(friend.position, at)).is_less(0.05)
	assert_float(_flat(p1.position, friend.position)).is_greater(OLD_FOLLOW_REACH * 3.0)
	# P2 pushes their own stick: that alone joins, and they walk off from where they waited
	_stick(Players.P2, Vector2(1, 0))
	_step(hub, 60)
	_stick(Players.P2, Vector2.ZERO)
	assert_bool(hub.two_players).is_true()
	assert_object(hub.jarling_for(Players.P2)).is_same(friend)
	assert_float(_flat(friend.position, at)).is_greater(2.0)


func test_a_stick_push_joins_a_pad_and_p2_is_parked_until_then() -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.8
	assert_bool(Players.joins(motion)).is_true()
	motion.axis_value = -0.3   # a resting stick, a little drift: no
	assert_bool(Players.joins(motion)).is_false()
	motion.axis = JOY_AXIS_RIGHT_X
	motion.axis_value = 1.0    # the right stick and the triggers never join
	assert_bool(Players.joins(motion)).is_false()
	var press := InputEventJoypadButton.new()
	press.pressed = true
	assert_bool(Players.joins(press)).is_true()
	press.pressed = false
	assert_bool(Players.joins(press)).is_false()
	if Players.is_active(Players.P2):
		return
	for a in Players.ACTIONS:   # before P2 has a pad, P1's pad never also drives p2_*
		for ev in InputMap.action_get_events(Players.action(Players.P2, a)):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				assert_int(ev.device).is_equal(Players.PARKED)
	# two pads, sticks only: the first becomes P1, the next P2, each bound to its own pad
	var saved: Dictionary = Players._device_of.duplicate()
	var joined := []
	var on_join := func(p: int, d: int) -> void: joined.append([p, d])
	Players.player_joined.connect(on_join)
	for p in [Players.P1, Players.P2]:
		Players._device_of[p] = -1
	for dev in [7, 7, 8]:
		var m := InputEventJoypadMotion.new()
		m.device = dev
		m.axis = JOY_AXIS_LEFT_Y
		m.axis_value = 0.9
		Players._input(m)
	Players.player_joined.disconnect(on_join)
	assert_array(joined).is_equal([[Players.P1, 7], [Players.P2, 8]])
	for ev in InputMap.action_get_events("p2_move_left"):
		if ev is InputEventJoypadMotion:
			assert_int(ev.device).is_equal(8)
	Players._device_of = saved
	Players._bind(Players.P1, saved[Players.P1])
	Players._bind(Players.P2, saved[Players.P2] if saved[Players.P2] >= 0 else Players.PARKED)


func test_p2_at_a_jar_presses_a_and_launches_it_and_nobody_is_moved() -> void:
	_games({"a-game": {"slug": "a-game"}, "b-game": {"slug": "b-game"}})
	var hub := await _hub(root)
	hub.join_second_player()
	var p1: HubJarling = hub.jarling_for(Players.P1)
	var p2: HubJarling = hub.jarling_for(Players.P2)
	_walk_to_jar(hub, Players.P1, 0)
	_walk_to_jar(hub, Players.P2, 1)
	assert_int(hub.focus[hub.jarlings.find(p2)]).is_equal(1)
	var p1_at := p1.position
	var p2_at := p2.position
	var fired := []
	hub.launched.connect(func(slug: String, prof: String) -> void: fired.append([slug, prof]))
	Input.action_press("p2_action")   # P2's A, read by the hub as a real press
	_step(hub, 1)
	Input.action_release("p2_action")
	assert_bool(hub.launch.active).is_true()
	assert_int(hub._launcher_index).is_equal(hub.jarlings.find(p2))
	assert_bool(await _wait_for_screen(hub, hub.Screen.RUNNING, 10.0)).is_true()
	assert_array(fired).is_equal([["b-game", p2.profile_id]])
	assert_str(p2.profile_id).is_equal("p2")
	# the launch request the hub made: P2's profile, both players' picks, as always
	var want := "--profile=p2 --p1-char=%s --p2-char=%s" % [Roster.pick(Players.P1), Roster.pick(Players.P2)]
	assert_str(Roster.pick(Players.P1)).is_not_empty()
	assert_str(Roster.pick(Players.P2)).is_not_empty()
	assert_str(" ".join(hub._launch_cmd.args)).is_equal(want)
	# and what the game itself got (it logs once it is up, which is after RUNNING)
	assert_str(await _wait_for_log(10.0)).is_equal("b-game " + want)
	assert_bool(await _wait_for_screen(hub, hub.Screen.HUB, 10.0)).is_true()
	await get_tree().create_timer(1.4).timeout   # return grace and the jump back out
	assert_float(_flat(p1.position, p1_at)).is_less(0.05)   # P1 was never pulled over to P2's jar
	assert_float(_flat(p2.position, p2_at)).is_less(0.3)    # P2 pops out where it stood
	assert_bool(p2.busy).is_false()


func test_p1_launches_too_with_p2_far_away() -> void:
	_games({"a-game": {"slug": "a-game"}, "b-game": {"slug": "b-game"}})
	var hub := await _hub(root)
	hub.join_second_player()
	_walk_to_jar(hub, Players.P2, 1)
	_walk_to_jar(hub, Players.P1, 0)
	hub.press_action(Players.P1)
	assert_bool(hub.launch.active).is_true()
	assert_int(hub._launcher_index).is_equal(hub.jarlings.find(hub.jarling_for(Players.P1)))
	assert_str(hub._launch_spot.entry.slug).is_equal("a-game")
	hub.launch.cancel()


# ---------------------------------------------------------------- PT1112-2: one jar per game in dev

func test_dev_view_shows_one_jar_per_game() -> void:
	_games({
		"a-game": {"slug": "a-game"},
		"a-game-dev": {"slug": "a-game", "dev": true},
		"b-game": {"slug": "b-game"},
		"c-game-dev": {"slug": "c-game", "dev": true},   # only a dev build installed
		"d-game": {"slug": "d-game"},
		"d-game-dev": {"dev": true},                     # hand-written: slug from the folder, d-game-dev
	})
	var hub := await _hub(root)
	var slugs := func() -> Array: return hub.spots.map(func(s: GameSpot) -> String: return s.entry.slug)
	var devs := func() -> Array: return hub.spots.map(func(s: GameSpot) -> bool: return s.entry.dev)
	assert_array(slugs.call()).is_equal(["a-game", "b-game", "d-game"])
	assert_array(devs.call()).is_equal([false, false, false])
	hub._toggle_dev()
	assert_array(slugs.call()).is_equal(["a-game", "b-game", "c-game", "d-game-dev"])
	assert_array(devs.call()).is_equal([true, false, true, true])
	assert_str(hub.spots[0].entry.dir.get_file()).is_equal("a-game-dev")
	hub._toggle_dev()
	assert_array(slugs.call()).is_equal(["a-game", "b-game", "d-game"])
