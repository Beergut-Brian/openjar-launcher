## Launch-readiness: one whole session through hub.tscn (intro, skip, walk, launch, return, P2 in,
## a two-player launch, P2 out, profile swap, quit) never softlocks, Start held quits from every
## screen and never leaves a game running behind it, P2 dropping out is heard and seen, the chooser
## has its own swap sound, A away from a jar cheers (P-07) and the corner shows the release version.
## Own Save profile, fixture roster (roster_three), own picks file, temp fake games.
class_name TestLaunchReady
extends GdUnitTestSuite

const PROFILE := "test_launch_ready"
const HUB := "res://scenes/hub/hub.tscn"
const PICKS := "user://test_launch_ready/players.json"
const THREE := "res://tests/fixtures/roster_three.json"
const DT := 1.0 / 60.0
const MOVES := ["p1_move_left", "p1_move_right", "p1_move_up", "p1_move_down"]

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
	Roster.data_path = THREE
	Roster.args_override = PackedStringArray(["--test-launch-ready"])
	Roster.reload()
	_fake_games()


func after_test() -> void:
	Audio.release_all()
	Save.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % PROFILE))
	Save.profile = _saved_profile
	Save._load()
	for f in [PICKS, PICKS + ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	Roster.picks_path = Roster.TEST_PICKS
	Roster.data_path = "res://data/roster.json"
	Roster.args_override = PackedStringArray()
	Roster.profile_override = ""
	Roster.reload()
	for a in MOVES + ["p1_action", "p1_jump"]:
		Input.action_release(a)
	OS.low_processor_usage_mode = false
	OS.set_environment("OPENJAR_ROOT", _saved_env)
	for d in DirAccess.get_directories_at(root):
		for f in DirAccess.get_files_at(root.path_join(d)):
			DirAccess.remove_absolute(root.path_join(d).path_join(f))
		DirAccess.remove_absolute(root.path_join(d))
	DirAccess.remove_absolute(log_path)
	DirAccess.remove_absolute(root)


## Two fake games in a temp root that log their arguments and exit after 0.3 s.
func _fake_games() -> void:
	root = OS.get_cache_dir().path_join("openjar_launch_ready_%d" % Time.get_ticks_usec())
	log_path = root.path_join("launched.log")
	for slug: String in ["a-game", "b-game"]:
		var dir := root.path_join(slug)
		DirAccess.make_dir_recursive_absolute(dir)
		var f := FileAccess.open(dir.path_join("openjar.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"slug": slug, "binary": "game.sh"}))
		f.close()
		f = FileAccess.open(dir.path_join("game.sh"), FileAccess.WRITE)
		f.store_string("#!/bin/sh\necho \"%s $@\" >> \"%s\"\nsleep 0.3\n" % [slug, log_path])
		f.close()


func _hub() -> Node3D:
	OS.set_environment("OPENJAR_ROOT", root)
	var hub: Node3D = auto_free(load(HUB).instantiate())
	hub.really_quit = false
	add_child(hub)
	await get_tree().process_frame
	return hub


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _step(hub: Node3D, seconds: float) -> void:
	hub.process_mode = Node.PROCESS_MODE_DISABLED
	var t := 0.0
	while t < seconds:
		hub._process(DT)
		for j: HubJarling in hub.jarlings:
			j._process(DT)
		t += DT
	hub.process_mode = Node.PROCESS_MODE_INHERIT


func _stick(v: Vector2) -> void:
	var s := [maxf(-v.x, 0.0), maxf(v.x, 0.0), maxf(-v.y, 0.0), maxf(v.y, 0.0)]
	for i in 4:
		if s[i] > 0.0:
			Input.action_press(MOVES[i], s[i])
		else:
			Input.action_release(MOVES[i])


func _walk_to_jar(hub: Node3D, index: int) -> void:
	var t := 0.0
	var lead: HubJarling = hub.lead_jarling()
	while hub.focus[hub.jarlings.find(lead)] != index and t < 8.0:
		var to: Vector3 = hub.spots[index].stand_point - lead.position
		_stick(Vector2(to.x, to.z).normalized())
		_step(hub, 0.1)
		t += 0.1
	_stick(Vector2.ZERO)
	_step(hub, 0.3)


func _wait_for(cond: Callable, limit: float) -> bool:
	var waited := 0.0
	while not cond.call() and waited < limit:
		await _wait(0.1)
		waited += 0.1
	return cond.call()


## Launch the jar in focus and wait for the game to run and the hub to come back.
func _launch_and_return(hub: Node3D, player: int) -> void:
	hub.press_action(player)
	assert_bool(hub.launch.active).is_true()
	assert_bool(await _wait_for(func() -> bool: return hub.screen == hub.Screen.RUNNING, 5.0)).is_true()
	assert_bool(await _wait_for(func() -> bool: return hub.screen == hub.Screen.HUB, 5.0)).is_true()
	await _wait(1.8)   # return grace, the pop back out and the lid
	for j: HubJarling in hub.jarlings:
		assert_bool(j.busy).is_false()


func _log_lines() -> PackedStringArray:
	return FileAccess.get_file_as_string(log_path).strip_edges().split("\n", false)


func test_a_whole_session_never_softlocks() -> void:
	var hub := await _hub()
	var launches := [0]
	var quit := [false]
	hub.launched.connect(func(_s: String, _p: String) -> void: launches[0] += 1)
	hub.quitting.connect(func() -> void: quit[0] = true)
	# boot: the intro plays, A skips it and the Jarlings pop in
	var intro: HubIntro = hub.play_intro()
	assert_bool(hub.intro_playing()).is_true()
	await _wait(0.3)
	intro.skip()
	await get_tree().process_frame
	assert_bool(hub.intro_playing()).is_false()
	assert_bool(hub.jarlings[0].visible).is_true()
	# solo: walk to a jar, launch it, come back
	_walk_to_jar(hub, 1)
	await _launch_and_return(hub, Players.P1)
	assert_int(launches[0]).is_equal(1)
	# P2 drops in, changes character, and the two of them launch the other jar
	hub.join_second_player()
	assert_bool(hub.two_players).is_true()
	await _wait(0.5)
	assert_bool(hub.change_character(Players.P2)).is_true()
	await _wait(0.6)
	_walk_to_jar(hub, 0)
	await _launch_and_return(hub, Players.P1)
	assert_int(launches[0]).is_equal(2)
	var lines := _log_lines()
	assert_int(lines.size()).is_equal(2)
	assert_str(lines[0]).starts_with("b-game --profile=p1")
	assert_str(lines[1]).starts_with("a-game --profile=p1")
	assert_str(lines[1]).contains("--p2-char=")
	# P2 drops out: back to tagging along, and solo B swaps the profile
	hub._on_player_left(Players.P2)
	assert_bool(hub.two_players).is_false()
	assert_object(hub.jarlings[1].follow).is_same(hub.jarlings[0])
	await _wait(0.6)
	hub.pick_profile("p2")
	assert_str(hub.profile).is_equal("p2")
	await _wait(0.6)
	# still drivable: A at a jar still launches
	_walk_to_jar(hub, 1)
	await _launch_and_return(hub, Players.P1)
	assert_int(launches[0]).is_equal(3)
	assert_str(_log_lines()[2]).starts_with("b-game --profile=p2")
	# and Start held leaves
	for i in 20:
		hub.update_quit(true, 0.1)
	assert_bool(quit[0]).is_true()


func test_start_held_during_the_intro_quits() -> void:
	var hub := await _hub()
	var quit := [false]
	hub.quitting.connect(func() -> void: quit[0] = true)
	hub.set_process(false)
	hub.play_intro()
	for i in 16:
		hub.update_quit(true, 0.1)
	assert_bool(quit[0]).is_true()


func test_start_held_through_a_launch_never_leaves_a_game_running() -> void:
	var hub := await _hub()
	var launches := [0]
	hub.launched.connect(func(_s: String, _p: String) -> void: launches[0] += 1)
	_walk_to_jar(hub, 1)
	hub.press_action(Players.P1)
	assert_bool(hub.launch.active).is_true()
	hub.quit_to_steam()   # the hold completed mid-animation
	_step(hub, LaunchSequence.T_GO + 0.5)
	assert_int(launches[0]).is_equal(0)
	assert_int(hub.screen).is_equal(hub.Screen.HUB)
	assert_bool(FileAccess.file_exists(log_path)).is_false()
	assert_bool(hub.launch.active).is_false()
	hub.press_action(Players.P1)   # and A after that never starts one either
	assert_bool(hub.launch.active).is_false()


func test_p2_dropping_out_is_heard_and_seen() -> void:
	var hub := await _hub()
	hub._on_player_left(Players.P2)   # nobody to drop: nothing happens
	assert_bool(hub.two_players).is_false()
	hub.join_second_player()
	await _wait(1.0)
	var p2: HubJarling = hub.jarling_for(Players.P2)
	Audio.last_cue = ""
	hub._on_player_left(Players.P2)
	assert_bool(hub.two_players).is_false()
	assert_str(Audio.last_cue).is_equal(hub.LEAVE_SOUND)
	assert_bool(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % hub.LEAVE_SOUND)).is_true()
	assert_object(p2.follow).is_same(hub.lead_jarling())
	assert_bool(p2._shape_tween != null and p2._shape_tween.is_valid()).is_true()   # the hop


func test_the_chooser_has_its_own_swap_sound() -> void:
	var hub := await _hub()
	assert_str(hub.CHANGE_SOUND).is_not_equal("intro_pop")
	assert_bool(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % hub.CHANGE_SOUND)).is_true()
	await _wait(0.5)
	Audio.last_cue = ""
	assert_bool(hub.change_character(Players.P1)).is_true()
	assert_str(Audio.last_cue).is_equal(hub.CHANGE_SOUND)


func test_a_away_from_a_jar_is_a_happy_cheer() -> void:
	var hub := await _hub()
	var lead: HubJarling = hub.lead_jarling()
	lead.position = Vector3(0, 0, 7.5)   # out on the plaza, nowhere near a jar
	_step(hub, 0.2)
	assert_int(hub.focus[hub.jarlings.find(lead)]).is_equal(-1)
	Audio.last_cue = ""
	hub.press_action(Players.P1)
	assert_str(Audio.last_cue).is_equal("ui_move")
	assert_bool(hub.launch.active).is_false()
	assert_bool(lead._shape_tween != null and lead._shape_tween.is_valid()).is_true()


func test_the_corner_shows_the_release_version() -> void:
	var script: GDScript = load("res://scripts/hub/hub.gd")
	assert_str(script.version_text("0.1.0")).is_equal("v0.1.0")
	assert_str(script.version_text("v0.1.0-dev.3")).is_equal("v0.1.0-dev.3")
	assert_str(script.version_text("")).is_equal("v?")
	var hub := await _hub()
	assert_object(hub.version_label).is_not_null()
	assert_str(hub.version_label.text).is_equal(
			"v" + str(ProjectSettings.get_setting("application/config/version")).trim_prefix("v"))
	assert_float(hub.version_label.get_theme_color("font_color").a).is_less(0.6)   # quiet, not for kids
