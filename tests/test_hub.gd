## End to end through hub.tscn: jars from the 0/1/2/8 fixtures, walking up to jars, launching a fake game
## and coming back, picking a profile, and the in-line character chooser (Roster picks). Uses a
## throwaway Save profile and a throwaway shared picks file.
class_name TestHub
extends GdUnitTestSuite

const PROFILE := "test_hub"
const HUB := "res://scenes/hub/hub.tscn"
const PICKS := "user://test_hub/players.json"
const THREE := "res://tests/fixtures/roster_three.json"

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
	Roster.picks_path = PICKS
	Roster.data_path = "res://data/roster.json"
	Roster.args_override = PackedStringArray(["--test-hub"])
	_wipe_picks()


func after_test() -> void:
	Audio.release_all()   # no music left playing when the test run quits
	Save.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % PROFILE))
	Save.profile = _saved_profile
	Save._load()
	_wipe_picks()
	Roster.picks_path = Roster.TEST_PICKS
	Roster.data_path = "res://data/roster.json"
	Roster.args_override = PackedStringArray()
	Roster.profile_override = ""
	Roster.reload()
	for a in ["p1_change", "p2_change"]:
		Input.action_release(a)
	OS.set_environment("OPENJAR_ROOT", _saved_env)
	for a in ["p1_move_left", "p1_move_right", "p1_move_up", "p1_move_down", "p1_action", "p1_jump"]:
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


func _wipe_picks() -> void:
	for f in [PICKS, PICKS + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


func _write_picks(d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(PICKS.get_base_dir())
	var f := FileAccess.open(PICKS, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()


func _picks_file() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(PICKS)) if FileAccess.file_exists(PICKS) else {}


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


const DT := 1.0 / 60.0
const MOVES := ["p1_move_left", "p1_move_right", "p1_move_up", "p1_move_down"]


## Simulated time: the hub and its Jarlings are stepped by hand at 60 fps, so walking is the same
## on a slow test box as on the TV. The tree does not process them meanwhile.
func _step(hub: Node3D, seconds: float, until: Callable = Callable()) -> float:
	hub.process_mode = Node.PROCESS_MODE_DISABLED
	var t := 0.0
	while t < seconds and not (until.is_valid() and until.call()):
		hub._process(DT)
		for j: HubJarling in hub.jarlings:
			j._process(DT)
		t += DT
	hub.process_mode = Node.PROCESS_MODE_INHERIT
	return t


## Push the stick (the real move actions, with analogue strength) like a kid would.
func _stick(v: Vector2) -> void:
	var s := [maxf(-v.x, 0.0), maxf(v.x, 0.0), maxf(-v.y, 0.0), maxf(v.y, 0.0)]
	for i in 4:
		if s[i] > 0.0:
			Input.action_press(MOVES[i], s[i])
		else:
			Input.action_release(MOVES[i])


## Steer player 1's Jarling to jar `index` with the stick until it comes into focus, then let go.
func _walk_to_jar(hub: Node3D, index: int) -> float:
	var t := 0.0
	var lead: HubJarling = hub.lead_jarling()
	while hub.focus[hub.jarlings.find(lead)] != index and t < 8.0:
		var to: Vector3 = hub.spots[index].stand_point - lead.position
		_stick(Vector2(to.x, to.z).normalized())
		t += _step(hub, 0.1)
	_stick(Vector2.ZERO)
	_step(hub, 0.3)
	return t


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


func test_held_jarlings_are_the_picks_and_jeff_and_chuck_are_residents() -> void:
	var hub := await _hub(_fixture(2))
	assert_int(hub.jarlings.size()).is_equal(2)
	assert_str(hub.jarlings[0].profile_id).is_equal("p1")
	assert_str(hub.jarlings[1].profile_id).is_equal("p2")
	assert_str(hub.lead_jarling().character_id).is_equal("jeff")   # the defaults: P1 Jeff, P2 Chuck
	assert_str(hub.jarlings[1].character_id).is_equal("chuck")
	assert_bool(hub.jarlings[1].height < hub.jarlings[0].height).is_true()   # Chuck is the kid
	assert_int(hub.residents.size()).is_equal(2)
	assert_str(hub.residents[0].character_id).is_equal("jeff")
	assert_str(hub.residents[1].character_id).is_equal("chuck")
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


func test_holding_right_walks_past_the_jars_instead_of_snapping() -> void:
	var hub := await _hub(_fixture(8))
	var j: HubJarling = hub.jarlings[0]
	assert_int(hub.focus[0]).is_equal(3)
	Input.action_press("p1_move_right")
	var t := _step(hub, 3.0, func() -> bool: return hub.focus[0] == 4)
	assert_int(hub.focus[0]).is_equal(4)                  # walked up to the next jar: in focus
	assert_float(t).is_less(1.5)
	assert_bool(j.moving).is_true()                       # and it keeps going: no stop at the jar
	_step(hub, 0.5)
	assert_float(j.position.distance_to(HubLayout.stand_position(4, 8))).is_greater(0.5)
	_step(hub, 4.0)                                       # all the way over: past the row's end
	Input.action_release("p1_move_right")
	_step(hub, 0.5)
	assert_bool(j.moving).is_false()
	assert_float(j.position.length()).is_less_equal(HubLayout.WALK_RADIUS + 0.001)
	assert_float(j.position.x).is_greater(HubLayout.stand_position(7, 8).x)
	# the tag-along friend never takes a jar of its own
	assert_int(hub.focus[1]).is_equal(-1)


func test_full_tilt_runs_and_a_small_tilt_walks() -> void:
	var hub := await _hub(_fixture(1))
	var j: HubJarling = hub.jarlings[0]
	_stick(Vector2(0, 1))                                 # towards the camera, away from the jar
	_step(hub, 1.0)
	var run := j.position.z - HubLayout.stand_position(0, 1).z
	hub.set_entries(hub.entries)
	_stick(Vector2(0, 0.45))
	var tilt := Players.move_vector(Players.P1).length()   # after the stick's deadzone
	_step(hub, 1.0)
	_stick(Vector2.ZERO)
	var walk := j.position.z - HubLayout.stand_position(0, 1).z
	assert_float(run).is_between(HubJarling.RUN_SPEED * 0.8, HubJarling.RUN_SPEED)
	assert_float(tilt).is_between(0.2, HubJarling.RUN_FROM)
	assert_float(walk).is_between(tilt * HubJarling.WALK_SPEED * 0.8, tilt * HubJarling.WALK_SPEED)


func test_every_direction_walks_and_jars_are_solid() -> void:
	var hub := await _hub(_fixture(2))
	var j: HubJarling = hub.jarlings[0]
	var start := j.position
	for v: Vector2 in [Vector2(0, 1), Vector2(-1, 0), Vector2(0.7, 0.7)]:
		hub.set_entries(hub.entries)
		_stick(v)
		_step(hub, 0.6)
		_stick(Vector2.ZERO)
		var moved := Vector2(j.position.x - start.x, j.position.z - start.z)
		assert_float(moved.length()).is_greater(1.5)
		assert_float(moved.normalized().dot(v.normalized())).is_greater(0.95)
	# run straight at the jar: it bumps into the plinth, stays out of the glass, and the jar is in focus
	hub.set_entries(hub.entries)
	_stick(Vector2(0, -1))
	_step(hub, 2.0)
	_stick(Vector2.ZERO)
	_step(hub, 0.3)
	var jar: Vector3 = hub.spots[0].position
	assert_float(Vector2(j.position.x - jar.x, j.position.z - jar.z).length()).is_greater_equal(HubLayout.BLOCK_RADIUS - 0.01)
	assert_int(hub.focus[0]).is_equal(0)


func test_walk_away_then_walk_up_to_another_jar_to_focus_it() -> void:
	var hub := await _hub(_fixture(8))
	_stick(Vector2(0, 1))
	_step(hub, 1.0)
	_stick(Vector2.ZERO)
	_step(hub, 0.3)
	assert_int(hub.focus[0]).is_equal(-1)                 # roaming: A just cheers
	assert_dict(hub.selected_entry()).is_empty()
	assert_float(_walk_to_jar(hub, 6)).is_less(3.0)
	assert_int(hub.focus[0]).is_equal(6)
	assert_bool(hub.spots[6].highlighted).is_true()
	assert_str(hub.selected_entry().slug).is_equal(hub.spots[6].entry.slug)


func test_demo_walks_between_jars() -> void:
	assert_str(load("res://scripts/hub/hub.gd").demo_script("", PackedStringArray(["--demo"]))).is_not_empty()
	assert_str(load("res://scripts/hub/hub.gd").demo_script("", PackedStringArray())).is_empty()
	assert_str(load("res://scripts/hub/hub.gd").demo_script("go:1", PackedStringArray(["--demo"]))).is_equal("go:1")
	var hub := await _hub(_fixture(8))
	hub._parse_demo("go:6")
	_step(hub, 4.0, func() -> bool: return hub.focus[0] == 6 and not hub.jarlings[0].moving)
	assert_int(hub.focus[0]).is_equal(6)
	assert_float(hub.jarlings[0].position.distance_to(hub.spots[6].stand_point)).is_less(1.0)
	hub._parse_demo("tour")                               # keeps going to the next jar and on
	var seen := {}
	_step(hub, 12.0, func() -> bool:
		if hub.focus[0] >= 0:
			seen[hub.focus[0]] = true
		return seen.size() >= 3)
	assert_int(seen.size()).is_greater_equal(3)


func test_launch_hand_off_return_and_profile_pick() -> void:
	_fake_games()
	var hub := await _hub(root)
	assert_int(hub.spots.size()).is_equal(2)
	assert_str(hub.profile).is_equal("p1")
	_walk_to_jar(hub, 1)
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
	assert_str(FileAccess.get_file_as_string(log_path).strip_edges()).is_equal(
			"b-game --profile=p1 --p1-char=jeff --p2-char=chuck --from-test")

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
	_walk_to_jar(hub, 1)                               # the kid walks up to the same jar
	await _tap("p1_action")
	await _wait_for_screen(hub, hub.Screen.RUNNING, 4.0)
	await _wait_for_screen(hub, hub.Screen.HUB, 5.0)
	var lines := FileAccess.get_file_as_string(log_path).strip_edges().split("\n")
	assert_str(lines[lines.size() - 1]).is_equal("b-game --profile=p2 --p1-char=jeff --p2-char=chuck --from-test")


## C-14: a `command` jar (the real Smash Party manifest, a fake browser) launches, and holding Start
## while it runs closes it and brings you home. Start still held on the way back never quits.
const QUIT_WAIT := 1.9


func test_a_command_jar_launches_and_the_home_hold_brings_you_back() -> void:
	root = ProjectSettings.globalize_path("user://test_hub_kiosk_%d" % Time.get_ticks_usec())
	var dir := root.path_join("smash-party")
	DirAccess.make_dir_recursive_absolute(dir)
	for f: String in ["openjar.json", "smash-party.sh"]:   # copied, so the script loses its x bit
		var src := FileAccess.get_file_as_string("res://kiosk/smash-party".path_join(f))
		var w := FileAccess.open(dir.path_join(f), FileAccess.WRITE)
		w.store_string(src)
		w.close()
	var out := root.path_join("fake")
	var saved_cache := OS.get_environment("XDG_CACHE_HOME")
	OS.set_environment("SMASH_PARTY_GAME", ProjectSettings.globalize_path("res://tests/fixtures/smash_party/game"))
	OS.set_environment("SMASH_PARTY_BROWSER", ProjectSettings.globalize_path("res://tests/fixtures/smash_party/fake_browser.sh"))
	OS.set_environment("FAKE_BROWSER_OUT", out)
	OS.set_environment("FAKE_BROWSER_SECONDS", "30")
	OS.set_environment("XDG_CACHE_HOME", root.path_join("cache"))
	var hub := await _hub(root)
	hub.really_quit = false
	assert_int(hub.spots.size()).is_equal(1)
	assert_bool(hub.update_home(true, 5.0)).is_false()   # nothing running: Start is the quit hold
	_walk_to_jar(hub, 0)
	await _tap("p1_action")
	await _wait_for_screen(hub, hub.Screen.RUNNING, 4.0)
	var t := 0.0
	while not FileAccess.file_exists(out + ".pid") and t < 8.0:
		await _wait(0.1)
		t += 0.1
	assert_str(FileAccess.get_file_as_string(out + ".page")).contains("SMASH-FIXTURE-OK")
	var browser := FileAccess.get_file_as_string(out + ".pid").strip_edges()
	assert_bool(hub.update_home(true, 1.0)).is_false()   # a short press is the game's own pause
	assert_bool(hub.update_home(false, 0.1)).is_false()
	assert_bool(hub.update_home(true, 1.0)).is_false()
	assert_bool(hub.update_home(false, 0.1)).is_false()
	var quits := [0]
	hub.quitting.connect(func() -> void: quits[0] += 1)
	Input.action_press("launcher_quit")                  # the real hold, through _process
	await _wait(1.0)
	assert_int(hub.screen).is_equal(hub.Screen.RUNNING)   # not yet
	await _wait_for_screen(hub, hub.Screen.HUB, 5.0)
	assert_int(hub.screen).is_equal(hub.Screen.HUB)
	assert_int(OS.execute("kill", ["-0", browser])).is_not_equal(0)   # the browser went too
	await _wait(2.0)                                     # Start still down from the hold: no quit
	Input.action_release("launcher_quit")
	await _wait(0.1)
	assert_int(quits[0]).is_equal(0)
	Input.action_press("launcher_quit")                  # a fresh hold still quits
	await _wait(QUIT_WAIT)
	Input.action_release("launcher_quit")
	assert_int(quits[0]).is_equal(1)
	for v: String in ["SMASH_PARTY_GAME", "SMASH_PARTY_BROWSER", "FAKE_BROWSER_OUT", "FAKE_BROWSER_SECONDS"]:
		OS.unset_environment(v)
	if saved_cache.is_empty():
		OS.unset_environment("XDG_CACHE_HOME")
	else:
		OS.set_environment("XDG_CACHE_HOME", saved_cache)


func test_the_home_hold_never_stops_a_godot_game() -> void:
	_fake_games()
	var hub := await _hub(root)
	_walk_to_jar(hub, 0)
	await _tap("p1_action")
	await _wait_for_screen(hub, hub.Screen.RUNNING, 4.0)
	assert_bool(hub.update_home(true, 5.0)).is_false()
	await _wait_for_screen(hub, hub.Screen.HUB, 5.0)


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


# ---------------------------------------------------------------- the in-line character chooser

func test_picks_from_the_shared_file_build_the_jarlings() -> void:
	_write_picks({"p1": {"P1": "chuck", "P2": "jeff"}})
	var hub := await _hub(_fixture(2))
	assert_str(hub.jarling_for(Players.P1).character_id).is_equal("chuck")
	assert_str(hub.jarlings[1].character_id).is_equal("jeff")
	assert_that(hub.jarling_for(Players.P1).color).is_equal(Players.COLOR[Players.P1])   # still green


func test_solo_change_trades_with_the_tag_along_and_is_remembered() -> void:
	var hub := await _hub(_fixture(2))
	var me: HubJarling = hub.jarling_for(Players.P1)
	var pos: Vector3 = me.position
	assert_bool(hub.change_character(Players.P1)).is_true()
	assert_bool(me.swapping).is_true()
	assert_bool(hub.change_character(Players.P1)).is_false()   # mid-swap presses are ignored
	await _wait(0.6)
	assert_bool(me.swapping).is_false()
	assert_str(me.character_id).is_equal("chuck")
	assert_str(hub.jarlings[1].character_id).is_equal("jeff")  # the friend took the old one
	assert_bool(me.tag_visible()).is_true()
	assert_str(me._tag.text).is_equal("Chuck")
	assert_vector(me.position).is_equal(pos)                 # changed in place
	assert_dict(_picks_file()).is_equal({"p1": {"P1": "chuck", "P2": "jeff"}})
	await _wait(1.3)
	assert_bool(me.tag_visible()).is_false()                 # the tag is gone after ~1.5 s


func test_the_change_button_cycles_but_not_during_a_launch() -> void:
	_fake_games()
	var hub := await _hub(root)
	Input.action_press("p1_change")
	_step(hub, DT * 2)
	Input.action_release("p1_change")
	_step(hub, DT * 2)
	assert_str(Roster.pick(Players.P1)).is_equal("chuck")
	await _wait(0.6)
	_walk_to_jar(hub, 0)
	hub.press_action(Players.P1)
	assert_bool(hub.launch.active).is_true()
	assert_bool(hub.change_character(Players.P1)).is_false()
	assert_str(Roster.pick(Players.P1)).is_equal("chuck")
	hub.launch.cancel()


func test_two_players_skip_the_other_pick() -> void:
	Roster.data_path = THREE
	var hub := await _hub(_fixture(2))
	hub.join_second_player()
	assert_bool(hub.change_character(Players.P1)).is_true()   # jeff -> pip: chuck is P2's
	await _wait(0.6)
	assert_str(hub.jarling_for(Players.P1).character_id).is_equal("pip")
	assert_str(hub.jarling_for(Players.P2).character_id).is_equal("chuck")
	assert_bool(hub.change_character(Players.P2)).is_true()   # chuck -> jeff
	await _wait(0.6)
	assert_str(hub.jarling_for(Players.P2).character_id).is_equal("jeff")
	assert_bool(hub.change_character(Players.P1)).is_true()   # pip -> (jeff taken) -> chuck
	await _wait(0.6)
	assert_str(Roster.pick(Players.P1)).is_equal("chuck")
	assert_that(hub.jarling_for(Players.P2).color).is_equal(Players.COLOR[Players.P2])


func test_two_players_and_nobody_free_shakes_and_stays() -> void:
	Roster.data_path = "res://tests/fixtures/roster_two.json"   # Jeff and Chuck only
	Roster.reload()
	var hub := await _hub(_fixture(2))
	hub.join_second_player()
	assert_bool(hub.change_character(Players.P1)).is_false()
	assert_str(Roster.pick(Players.P1)).is_equal("jeff")
	assert_str(Roster.pick(Players.P2)).is_equal("chuck")
	assert_bool(FileAccess.file_exists(PICKS)).is_false()


func test_a_resident_who_is_on_screen_already_is_hidden() -> void:
	Roster.data_path = THREE
	_write_picks({"p1": {"P1": "pip", "P2": "chuck"}})
	var hub := await _hub(_fixture(2))
	assert_bool(hub.residents[0].visible).is_true()          # Jeff: nobody is playing him
	assert_bool(hub.residents[1].visible).is_false()         # Chuck: P2's Jarling already is Chuck
	hub.change_character(Players.P1)                         # pip -> jeff (solo: next in order, wraps)
	await _wait(0.6)
	assert_str(Roster.pick(Players.P1)).is_equal("jeff")
	assert_bool(hub.residents[0].visible).is_false()
	assert_bool(hub.residents[1].visible).is_false()


func test_profile_swap_switches_to_that_profiles_picks_in_place() -> void:
	Roster.data_path = "res://tests/fixtures/roster_two.json"   # Jeff and Chuck only: the change swaps to the other one
	Roster.reload()
	_write_picks({"p1": {"P1": "jeff", "P2": "chuck"}, "p2": {"P1": "chuck", "P2": "jeff"}})
	var hub := await _hub(_fixture(2))
	var at: Vector3 = hub.lead_jarling().position
	hub.pick_profile("p2")
	await _wait(0.6)
	assert_str(Roster.profile_override).is_equal("p2")
	assert_str(hub.lead_jarling().character_id).is_equal("chuck")
	assert_vector(hub.lead_jarling().position).is_equal(at)   # you stay where you were
	assert_object(hub.lead_jarling()).is_same(hub.jarlings[1])
	hub.change_character(Players.P1)                          # a change now lands in p2's entry
	await _wait(0.6)
	assert_dict(_picks_file()).is_equal({"p1": {"P1": "jeff", "P2": "chuck"}, "p2": {"P1": "jeff", "P2": "chuck"}})


func test_launch_passes_the_picks_and_return_rereads_the_file() -> void:
	_fake_games()
	_write_picks({"p1": {"P1": "chuck", "P2": "jeff"}})
	var hub := await _hub(root)
	_walk_to_jar(hub, 0)
	hub.press_action(Players.P1)
	await _wait_for_screen(hub, hub.Screen.RUNNING, 4.0)
	_write_picks({"p1": {"P1": "jeff", "P2": "chuck"}})   # changed inside the game
	await _wait_for_screen(hub, hub.Screen.HUB, 5.0)
	assert_str(FileAccess.get_file_as_string(log_path).strip_edges()).is_equal(
			"a-game --profile=p1 --p1-char=chuck --p2-char=jeff --from-test")
	assert_str(hub.lead_jarling().character_id).is_equal("jeff")
	assert_str(hub.jarlings[1].character_id).is_equal("chuck")


func test_the_hint_shows_by_the_ring_when_you_stand_still() -> void:
	var hub := await _hub(_fixture(2))
	var me: HubJarling = hub.jarling_for(Players.P1)
	_step(hub, 0.5)
	assert_bool(me.hint_visible()).is_false()
	_step(hub, 1.6)
	assert_bool(me.hint_visible()).is_true()
	assert_object(me._hint.texture).is_not_null()   # a picture of the button, no words (K-01)
	assert_str(me._hint.get_class()).is_equal("Sprite3D")
	assert_bool(hub.jarlings[1]._hint.visible).is_false()    # the tag-along has no hint
	_stick(Vector2(1, 0))
	_step(hub, 0.25)
	_stick(Vector2.ZERO)
	assert_bool(me.hint_visible()).is_false()
