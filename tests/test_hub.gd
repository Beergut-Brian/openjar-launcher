## End to end through hub.tscn: jars from the 0/1/2/8 fixtures, the stick hop, launching a fake game
## and coming back, and picking a Jarling (profile). Uses a throwaway Save profile.
class_name TestHub
extends GdUnitTestSuite

const PROFILE := "test_hub"
const HUB := "res://scenes/hub/hub.tscn"

var root: String
var log_path: String
var _saved_profile: String
var _saved_env: String


func before_test() -> void:
	_saved_env = OS.get_environment("OPENJAR_ROOT")
	_saved_profile = Save.profile
	Save.profile = PROFILE
	Save.wipe()
	root = ""


func after_test() -> void:
	Audio.release_all()   # no music left playing when the test run quits
	Save.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % PROFILE))
	Save.profile = _saved_profile
	Save._load()
	OS.set_environment("OPENJAR_ROOT", _saved_env)
	for a in ["p1_move_left", "p1_move_right", "p1_action", "p1_jump"]:
		Input.action_release(a)
	OS.low_processor_usage_mode = false
	if root.is_empty():
		return
	for d in DirAccess.get_directories_at(root):
		for f in DirAccess.get_files_at(root.path_join(d)):
			DirAccess.remove_absolute(root.path_join(d).path_join(f))
		DirAccess.remove_absolute(root.path_join(d))
	DirAccess.remove_absolute(log_path)
	DirAccess.remove_absolute(root)


func _fixture(n: int) -> String:
	return ProjectSettings.globalize_path("res://tests/fixtures/hub_%d" % n)


func _hub(openjar_root: String) -> Node3D:
	OS.set_environment("OPENJAR_ROOT", openjar_root)
	var hub: Node3D = auto_free(load(HUB).instantiate())
	add_child(hub)
	await get_tree().process_frame
	return hub


## A temp OPENJAR_ROOT with two fake games that log their arguments (not executable on purpose:
## the launcher must fix the bit, zips can lose it).
func _fake_games() -> void:
	root = OS.get_cache_dir().path_join("openjar_hub_test_%d" % Time.get_ticks_usec())
	log_path = root.path_join("launched.log")
	for slug: String in ["a-game", "b-game"]:
		var dir := root.path_join(slug)
		DirAccess.make_dir_recursive_absolute(dir)
		var f := FileAccess.open(dir.path_join("openjar.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"slug": slug, "binary": "game.sh", "args": ["--from-test"]}))
		f.close()
		f = FileAccess.open(dir.path_join("game.sh"), FileAccess.WRITE)
		f.store_string("#!/bin/sh\necho \"%s $@\" >> \"%s\"\nsleep 0.3\n" % [slug, log_path])
		f.close()


func _tap(action: String, hold: float = 0.08) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(hold)
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame


## Stick pushes are level-based, so they go straight into the action state.
func _push(action: String, hold: float = 0.08) -> void:
	Input.action_press(action)
	await _wait(hold)
	Input.action_release(action)
	await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _wait_for_screen(hub: Node3D, screen: int, limit: float) -> void:
	var waited := 0.0
	while hub.screen != screen and waited < limit:
		await _wait(0.1)
		waited += 0.1


func test_spots_built_from_0_1_2_8_manifests() -> void:
	for n: int in [0, 1, 2, 8]:
		var hub := await _hub(_fixture(n))
		assert_int(hub.entries.size()).is_equal(n)
		assert_int(hub.spots.size()).is_equal(maxi(n, 1))
		assert_bool(hub.spots[0].empty).is_equal(n == 0)
		for i in hub.spots.size():
			assert_vector(hub.spots[i].position).is_equal_approx(HubLayout.jar_position(i, hub.spots.size()), Vector3.ONE * 0.001)
		# the lead Jarling starts at a jar, so A works at once
		assert_int(hub.focus[0]).is_equal((hub.spots.size() - 1) / 2)
		assert_bool(hub.spots[hub.focus[0]].highlighted).is_true()
		remove_child(hub)


func test_eight_jars_are_sorted_and_each_holds_a_tiny_world() -> void:
	var hub := await _hub(_fixture(8))
	var slugs: Array = hub.spots.map(func(s: GameSpot) -> String: return s.entry.slug)
	assert_array(slugs).is_equal(["ball-bash", "bubble-pop", "comet-kick", "dino-dash", "jelly-jump", "moon-golf", "no-art-yet", "smash-party"])
	for i in hub.spots.size():
		var s: GameSpot = hub.spots[i]
		# moon-golf ships its own jar world ("jar" in its manifest); the rest get a generated one
		assert_bool(s.custom_world).is_equal(s.entry.slug == "moon-golf")
		if s.custom_world:
			assert_int(s.world_kind).is_equal(-1)
		else:
			assert_int(s.world_kind).is_between(0, JarWorld.KINDS - 1)
		if i > 0:                                         # neighbours never look the same
			assert_int(s.world_kind).is_not_equal(hub.spots[i - 1].world_kind)
		assert_bool(s._inside.find_children("*", "MeshInstance3D", true, false).size() >= 3).is_true()
		assert_array(s.find_children("*", "Label3D", true, false)).is_empty()


func test_profile_jarlings_are_generic_and_jeff_and_chuck_are_residents() -> void:
	var hub := await _hub(_fixture(2))
	assert_int(hub.jarlings.size()).is_equal(2)
	assert_str(hub.jarlings[0].profile_id).is_equal("p1")
	assert_str(hub.jarlings[1].profile_id).is_equal("p2")
	assert_bool(hub.jarlings[1].height < hub.jarlings[0].height).is_true()   # a grown-up and a kid
	assert_int(hub.residents.size()).is_equal(2)
	for r: HubJarling in hub.residents:
		assert_bool(hub.jarlings.has(r)).is_false()       # never held, never a profile
		assert_bool(r._ring.visible).is_false()
	# Jeff (P1's) stands on the left, Chuck (P2's) on the right
	assert_bool(hub.residents[0].position.x < 0.0).is_true()
	assert_bool(hub.residents[1].position.x > 0.0).is_true()


func test_empty_hub_a_wobbles_and_never_launches() -> void:
	var hub := await _hub(_fixture(0))
	hub.press_action(Players.P1)
	await _wait(0.2)
	assert_int(hub.screen).is_equal(hub.Screen.HUB)
	assert_bool(hub.launch.active).is_false()


func test_remembered_jar_is_where_you_start() -> void:
	LauncherState.set_last_card(Save, "moon-golf")
	var hub := await _hub(_fixture(8))
	assert_int(hub.focus[0]).is_equal(5)


func test_stick_hop_order() -> void:
	var hub := await _hub(_fixture(8))
	assert_int(hub.focus[0]).is_equal(3)
	await _push("p1_move_right")
	await _wait(0.5)
	assert_int(hub.focus[0]).is_equal(4)
	for i in 2:
		await _push("p1_move_left")
		await _wait(0.5)
	assert_int(hub.focus[0]).is_equal(2)
	# holding the stick keeps hopping, and stops at the end of the row
	Input.action_press("p1_move_left")
	await _wait(2.2)
	Input.action_release("p1_move_left")
	await _wait(0.5)
	assert_int(hub.focus[0]).is_equal(0)
	assert_vector(hub.jarlings[0].position).is_equal_approx(HubLayout.stand_position(0, 8), Vector3.ONE * 0.01)
	# the tag-along friend never takes a jar of its own
	assert_int(hub.focus[1]).is_equal(-1)


func test_launch_hand_off_return_and_profile_pick() -> void:
	_fake_games()
	var hub := await _hub(root)
	assert_int(hub.spots.size()).is_equal(2)
	assert_str(hub.profile).is_equal("p1")
	await _push("p1_move_right")
	await _wait(0.5)
	assert_str(hub.selected_entry().slug).is_equal("b-game")

	var fired := [0]
	hub.launched.connect(func(_slug: String, _profile: String) -> void: fired[0] += 1)
	await _tap("p1_action")
	assert_bool(hub.launch.active).is_true()
	for i in 6:                                        # A spam while the lid spins off
		await _tap("p1_action", 0.05)
		hub.press_action(Players.P1)
	# the game only starts on the animation's last beat
	assert_bool(hub.launch.active).is_true()
	assert_bool(hub.launch.t < LaunchSequence.T_GO).is_true()
	assert_int(hub.screen).is_equal(hub.Screen.HUB)
	assert_int(fired[0]).is_equal(0)
	assert_bool(FileAccess.file_exists(log_path)).is_false()
	await _wait_for_screen(hub, hub.Screen.RUNNING, 4.0)
	assert_int(hub.screen).is_equal(hub.Screen.RUNNING)
	assert_bool(hub.launch.active).is_false()
	assert_int(fired[0]).is_equal(1)
	assert_bool(hub.visible).is_false()
	await _push("p1_move_left")                        # ignored while the game runs
	await _wait_for_screen(hub, hub.Screen.HUB, 5.0)
	assert_int(hub.screen).is_equal(hub.Screen.HUB)
	assert_bool(hub.visible).is_true()
	assert_str(hub.selected_entry().slug).is_equal("b-game")
	assert_str(LauncherState.last_card(Save)).is_equal("b-game")
	# one line: the spam did not start it twice
	assert_str(FileAccess.get_file_as_string(log_path).strip_edges()).is_equal("b-game --profile=p1 --from-test")

	await _wait(1.8)                                   # return grace, the jump back out, the lid bonk
	assert_bool(hub.jarlings[0].visible).is_true()
	assert_bool(hub.jarlings[0].busy).is_false()
	assert_float(hub.spots[1]._lid.position.y).is_less(GameSpot.LID_REST + 2.0)   # the lid is back on
	assert_int(fired[0]).is_equal(1)
	await _tap("p1_jump")                              # B: be the other Jarling
	assert_str(hub.profile).is_equal("p2")
	assert_str(LauncherState.profile(Save)).is_equal("p2")
	assert_object(hub.lead_jarling()).is_same(hub.jarlings[1])
	assert_object(hub.jarlings[0].follow).is_same(hub.jarlings[1])
	await _wait(0.2)
	hub.hop(Players.P1, 1)                            # the kid runs up to the same jar
	await _wait(0.6)
	await _tap("p1_action")
	await _wait_for_screen(hub, hub.Screen.RUNNING, 4.0)
	await _wait_for_screen(hub, hub.Screen.HUB, 5.0)
	var lines := FileAccess.get_file_as_string(log_path).strip_edges().split("\n")
	assert_str(lines[lines.size() - 1]).is_equal("b-game --profile=p2 --from-test")


func test_picked_jarling_is_remembered() -> void:
	LauncherState.set_profile(Save, "p2")
	var hub := await _hub(_fixture(2))
	assert_str(hub.profile).is_equal("p2")
	assert_object(hub.jarling_for(Players.P1)).is_same(hub.jarlings[1])
	assert_object(hub.jarling_for(Players.P2)).is_null()


func test_second_player_takes_the_other_jarling_and_rings_are_by_player() -> void:
	LauncherState.set_profile(Save, "p2")
	var hub := await _hub(_fixture(2))
	hub.join_second_player()
	# P1 keeps the Jarling they picked (the kid), P2 gets the other one; green is P1, red is P2
	assert_object(hub.jarling_for(Players.P1)).is_same(hub.jarlings[1])
	assert_object(hub.jarling_for(Players.P2)).is_same(hub.jarlings[0])
	assert_that(hub.jarlings[1].color).is_equal(Players.COLOR[Players.P1])
	assert_that(hub.jarlings[0].color).is_equal(Players.COLOR[Players.P2])
	assert_object(hub.jarlings[0].follow).is_null()
	assert_object(hub.jarlings[1].follow).is_null()
	hub.pick_profile("p1")                            # no swapping once both are held
	assert_str(hub.profile).is_equal("p2")
