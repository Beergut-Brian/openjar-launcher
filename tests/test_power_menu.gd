## NS-1 / NS-2 (Kaden 2026-11-14: no Steam on the TV box, the launcher is its home screen).
## Holding Start opens the power menu (never quits) on every launcher screen; Back closes it; Sleep and
## Shut down go through a fake PowerActions, once each; nothing while a game runs; the dev quit only
## with --allow-quit. And the emulator jar: a `command`-only manifest with `"profiles": false` launches
## through the process seam with none of the launcher's own args, and the hub comes back after it.
## Own Save profile, a fixture roster, a scratch picks file, temp jars in the OS cache dir.
class_name TestPowerMenu
extends GdUnitTestSuite

const PROFILE := "test_power_menu"
const HUB := "res://scenes/hub/hub.tscn"
const PICKS := "user://test_power_menu/players.json"
const DT := 1.0 / 60.0


class FakePower extends PowerActions:
	var sleeps := 0
	var shut_downs := 0
	var quits := 0

	func sleep() -> int:
		sleeps += 1
		return 0

	func shut_down() -> int:
		shut_downs += 1
		return 0

	func quit(_tree: SceneTree) -> void:
		quits += 1


var root := ""
var _saved_profile: String
var _saved_env: String


func before_test() -> void:
	_saved_env = OS.get_environment("OPENJAR_ROOT")
	_saved_profile = Save.profile
	Save.profile = PROFILE
	Save.wipe()
	Roster.picks_path = PICKS
	Roster.data_path = "res://tests/fixtures/roster_three.json"
	Roster.args_override = PackedStringArray(["--test-power-menu"])
	Roster.reload()


func after_test() -> void:
	Audio.release_all()
	for a in ["launcher_quit", "p1_action", "p1_jump", "p1_move_left", "p1_move_right"]:
		Input.action_release(a)
	Save.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % PROFILE))
	Save.profile = _saved_profile
	Save._load()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PICKS))
	Roster.picks_path = Roster.TEST_PICKS
	Roster.data_path = "res://data/roster.json"
	Roster.args_override = PackedStringArray()
	Roster.profile_override = ""
	Roster.reload()
	OS.set_environment("OPENJAR_ROOT", _saved_env)
	OS.low_processor_usage_mode = false
	if not root.is_empty():
		for d in DirAccess.get_directories_at(root):
			for f in DirAccess.get_files_at(root.path_join(d)):
				DirAccess.remove_absolute(root.path_join(d).path_join(f))
			DirAccess.remove_absolute(root.path_join(d))
		for f in DirAccess.get_files_at(root):
			DirAccess.remove_absolute(root.path_join(f))
		DirAccess.remove_absolute(root)
		root = ""


## manual: the hub only runs when the test steps it (its own _process would see a test's "just
## pressed" again in the next real frame).
func _hub(openjar_root: String = "", allow_quit: bool = false, manual: bool = true) -> Node3D:
	if openjar_root.is_empty():
		openjar_root = ProjectSettings.globalize_path("res://tests/fixtures/hub_2")
	OS.set_environment("OPENJAR_ROOT", openjar_root)
	var hub: Node3D = auto_free(load(HUB).instantiate())
	hub.really_quit = false
	hub.power = FakePower.new()
	hub.allow_quit = allow_quit
	add_child(hub)
	await get_tree().process_frame
	hub.set_process(not manual)
	return hub


## The hub's own frames, by hand, at 60 fps.
func _step(hub: Node3D, frames: int) -> void:
	hub.process_mode = Node.PROCESS_MODE_DISABLED
	for i in frames:
		hub._process(DT)
		for j: HubJarling in hub.jarlings:
			j._process(DT)
	hub.process_mode = Node.PROCESS_MODE_INHERIT


## A press held for `frames` hub frames. "Just pressed" lasts the whole engine frame (even after the
## release), so the release waits for the next real frame before the hub is stepped again.
func _press(hub: Node3D, action: String, frames: int = 1) -> void:
	Input.action_press(action)
	_step(hub, frames)
	Input.action_release(action)
	await get_tree().process_frame
	_step(hub, 1)


## Hold Start through _process long enough to open the menu, then let go.
func _hold_start(hub: Node3D) -> void:
	await _press(hub, "launcher_quit", int(hub.QUIT_HOLD * 60.0) + 6)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _wait_for_screen(hub: Node3D, screen: int, limit: float) -> void:
	var t := 0.0
	while hub.screen != screen and t < limit:
		await _wait(0.1)
		t += 0.1


# ---------------------------------------------------------------- the power menu

func test_holding_start_in_the_hub_opens_the_menu_and_never_quits() -> void:
	var hub := await _hub()
	var quit := [false]
	hub.quitting.connect(func() -> void: quit[0] = true)
	assert_bool(hub.power_menu.is_open()).is_false()
	await _hold_start(hub)
	assert_bool(hub.power_menu.is_open()).is_true()
	assert_int(hub.power_menu.focused()).is_equal(PowerMenu.Item.BACK)   # an accident is one A away
	assert_bool(quit[0]).is_false()
	assert_bool(hub._quitting).is_false()
	assert_int(hub.power_menu.items.size()).is_equal(3)   # no dev quit without --allow-quit
	var fake: FakePower = hub.power
	assert_int(fake.sleeps + fake.shut_downs + fake.quits).is_equal(0)


func test_a_tap_on_start_does_not_open_it() -> void:
	var hub := await _hub()
	await _press(hub, "launcher_quit", 10)
	assert_bool(hub.power_menu.is_open()).is_false()
	assert_float(hub.quit_meter.progress).is_equal(0.0)


func test_holding_start_during_the_intro_opens_the_menu() -> void:
	var hub := await _hub()
	hub.play_intro()
	assert_bool(hub.intro_playing()).is_true()
	await _hold_start(hub)
	assert_bool(hub.power_menu.is_open()).is_true()
	await _press(hub, "p1_action")   # A in the menu picks Back: it never also skips the intro
	assert_bool(hub.power_menu.is_open()).is_false()
	assert_bool(hub.intro_playing()).is_true()


func test_holding_start_during_a_launch_opens_the_menu_and_no_game_starts_behind_it() -> void:
	var hub := await _hub()
	var launches := [0]
	hub.launched.connect(func(_s: String, _p: String) -> void: launches[0] += 1)
	hub.lead_jarling().position = hub.spots[0].stand_point
	_step(hub, 2)
	hub.press_action(Players.P1)
	assert_bool(hub.launch.active).is_true()
	await _hold_start(hub)
	assert_bool(hub.power_menu.is_open()).is_true()
	_step(hub, int(LaunchSequence.T_GO * 60.0) + 30)
	assert_int(launches[0]).is_equal(0)
	assert_int(hub.screen).is_equal(hub.Screen.HUB)
	assert_bool(hub.launch.active).is_false()
	assert_bool(hub.power_menu.is_open()).is_true()


func test_back_closes_it_by_a_on_back_by_b_and_by_a_fresh_start() -> void:
	var hub := await _hub()
	await _hold_start(hub)
	await _press(hub, "p1_action")   # A on Back
	assert_bool(hub.power_menu.is_open()).is_false()
	await _hold_start(hub)
	await _press(hub, "p1_jump")     # B
	assert_bool(hub.power_menu.is_open()).is_false()
	await _hold_start(hub)
	await _press(hub, "launcher_quit")   # a tap of Start
	assert_bool(hub.power_menu.is_open()).is_false()
	_step(hub, 120)   # and that Start tap never starts a new hold: the menu stays shut
	assert_bool(hub.power_menu.is_open()).is_false()
	var fake: FakePower = hub.power
	assert_int(fake.sleeps + fake.shut_downs + fake.quits).is_equal(0)


func test_the_start_hold_that_opened_it_does_not_close_it() -> void:
	var hub := await _hub()
	Input.action_press("launcher_quit")
	_step(hub, int(hub.QUIT_HOLD * 60.0) + 60)   # still held a second after it opened
	assert_bool(hub.power_menu.is_open()).is_true()
	Input.action_release("launcher_quit")
	_step(hub, 5)
	assert_bool(hub.power_menu.is_open()).is_true()


func test_sleep_calls_power_sleep_once_and_closes() -> void:
	var hub := await _hub()
	await _hold_start(hub)
	await _press(hub, "p1_move_right")
	assert_int(hub.power_menu.focused()).is_equal(PowerMenu.Item.SLEEP)
	await _press(hub, "p1_action")
	_step(hub, 30)
	var fake: FakePower = hub.power
	assert_int(fake.sleeps).is_equal(1)
	assert_int(fake.shut_downs).is_equal(0)
	assert_bool(hub.power_menu.is_open()).is_false()   # you wake up in the hub


func test_shut_down_needs_the_hold_and_calls_power_once() -> void:
	var hub := await _hub()
	var fake: FakePower = hub.power
	await _hold_start(hub)
	await _press(hub, "p1_move_right")
	await _press(hub, "p1_move_right")
	assert_int(hub.power_menu.focused()).is_equal(PowerMenu.Item.SHUT_DOWN)
	await _press(hub, "p1_move_right")   # the end of the row: a nudge, it stays on Shut down
	assert_int(hub.power_menu.focused()).is_equal(PowerMenu.Item.SHUT_DOWN)
	await _press(hub, "p1_action", 20)   # a short press: the ring starts, let go, nothing
	assert_int(fake.shut_downs).is_equal(0)
	assert_float(hub.power_menu.confirm).is_equal(0.0)
	assert_bool(hub.power_menu.is_open()).is_true()
	Input.action_press("p1_action")
	_step(hub, int(PowerMenu.SHUTDOWN_HOLD * 60.0) - 10)
	assert_int(fake.shut_downs).is_equal(0)
	assert_float(hub.power_menu.confirm).is_greater(0.8)
	_step(hub, 40)   # past the hold, and held on: still only once
	Input.action_release("p1_action")
	_step(hub, 5)
	assert_int(fake.shut_downs).is_equal(1)
	assert_int(fake.sleeps).is_equal(0)


func test_nothing_happens_while_a_game_runs() -> void:
	var hub := await _hub()
	hub.screen = hub.Screen.RUNNING
	Input.action_press("launcher_quit")
	_step(hub, int(hub.QUIT_HOLD * 60.0) * 3)
	Input.action_release("launcher_quit")
	_step(hub, 1)
	assert_bool(hub.power_menu.is_open()).is_false()
	assert_float(hub.quit_meter.progress).is_equal(0.0)
	var fake: FakePower = hub.power
	assert_int(fake.sleeps + fake.shut_downs + fake.quits).is_equal(0)
	hub.screen = hub.Screen.HUB


func test_the_menu_holds_the_jarlings_still() -> void:
	var hub := await _hub()
	await _hold_start(hub)
	var at: Vector3 = hub.lead_jarling().position
	Input.action_press("p1_move_up")
	_step(hub, 30)
	Input.action_release("p1_move_up")
	assert_vector(hub.lead_jarling().position).is_equal_approx(at, Vector3.ONE * 0.01)
	assert_bool(hub.launch.active).is_false()


func test_the_dev_quit_is_only_there_with_allow_quit() -> void:
	var hub := await _hub("", true)
	var quit := [false]
	hub.quitting.connect(func() -> void: quit[0] = true)
	await _hold_start(hub)
	assert_int(hub.power_menu.items.size()).is_equal(4)
	for i in 3:
		await _press(hub, "p1_move_right")
	assert_int(hub.power_menu.focused()).is_equal(PowerMenu.Item.QUIT)
	await _press(hub, "p1_action")
	await get_tree().process_frame
	var fake: FakePower = hub.power
	assert_int(fake.quits).is_equal(1)
	assert_bool(quit[0]).is_true()
	assert_int(fake.sleeps + fake.shut_downs).is_equal(0)


func test_quit_launcher_without_allow_quit_does_nothing() -> void:
	var hub := await _hub()
	hub.quit_launcher()
	var fake: FakePower = hub.power
	assert_int(fake.quits).is_equal(0)
	assert_bool(hub._quitting).is_false()


func test_power_actions_dry_run_never_calls_systemctl() -> void:
	var p := PowerActions.new()
	p.dry_run = true
	assert_int(p.sleep()).is_equal(0)
	assert_int(p.shut_down()).is_equal(0)
	p.quit(get_tree())   # dry: logs, never quits the test run
	assert_array(p.asked).contains_exactly(["sleep", "shut_down", "quit"])


func test_a_test_run_hub_is_a_dry_run_even_without_a_fake() -> void:
	OS.set_environment("OPENJAR_ROOT", ProjectSettings.globalize_path("res://tests/fixtures/hub_2"))
	var hub: Node3D = auto_free(load(HUB).instantiate())
	hub.really_quit = false
	add_child(hub)
	await get_tree().process_frame
	assert_bool(hub.power.dry_run).is_true()


# ---------------------------------------------------------------- the emulator jar (NS-2)

## A temp OPENJAR_ROOT with one emulator manifest: `command` only (a bare program name looked up on
## PATH, as `flatpak` is), `"profiles": false`, no `jar`, no grid. The "emulator" logs its args.
func _emulator_root() -> String:
	root = OS.get_cache_dir().path_join("openjar_power_test_%d" % Time.get_ticks_usec())
	var dir := root.path_join("retro-games")
	DirAccess.make_dir_recursive_absolute(dir)
	var fake := root.path_join("fake-retrodeck.sh")
	var f := FileAccess.open(fake, FileAccess.WRITE)
	f.store_string("#!/bin/sh\necho \"emulator $@\" >> \"%s\"\nsleep 0.6\n" % root.path_join("launched.log"))
	f.close()
	f = FileAccess.open(dir.path_join("openjar.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"slug": "retro-games", "name": "Retro Games",
			"command": ["sh", fake, "--fullscreen"], "profiles": false}))
	f.close()
	return root


func test_a_command_only_manifest_shows_as_a_retro_jar() -> void:
	var hub := await _hub(_emulator_root())
	assert_int(hub.entries.size()).is_equal(1)
	var e: Dictionary = hub.entries[0]
	assert_str(e.binary).is_empty()
	assert_bool(e.profiles).is_false()
	var spot: GameSpot = hub.spots[0]
	assert_bool(spot.empty).is_false()
	assert_int(spot.world_kind).is_equal(JarWorld.RETRO)
	assert_bool(spot.custom_world).is_false()


func test_the_emulator_launches_hides_the_hub_and_comes_back_with_no_profile() -> void:
	var hub := await _hub(_emulator_root(), false, false)
	var launched := [""]
	hub.launched.connect(func(s: String, _p: String) -> void: launched[0] = s)
	hub.lead_jarling().position = hub.spots[0].stand_point
	await get_tree().process_frame
	hub.press_action(Players.P1)
	await _wait_for_screen(hub, hub.Screen.RUNNING, 5.0)
	assert_int(hub.screen).is_equal(hub.Screen.RUNNING)
	assert_str(launched[0]).is_equal("retro-games")
	assert_bool(hub.visible).is_false()   # hidden while it runs, exactly like a game
	assert_bool(hub._running_command).is_true()   # the home hold can close it
	await _wait_for_screen(hub, hub.Screen.HUB, 5.0)
	assert_int(hub.screen).is_equal(hub.Screen.HUB)
	assert_bool(hub.visible).is_true()
	var line := FileAccess.get_file_as_string(root.path_join("launched.log")).strip_edges()
	assert_str(line).is_equal("emulator --fullscreen")   # no --profile=, no --pN-char=
	assert_bool(hub.last_return_failed).is_false()


func test_profiles_false_passes_no_profile_or_chars() -> void:
	var entry := {"dir": "/games/retro", "binary": "", "profiles": false,
		"command": PackedStringArray(["flatpak", "run", "net.retrodeck.retrodeck"]), "args": PackedStringArray()}
	var out := LaunchArgs.build(entry, "p2", {0: "jeff", 1: "chuck"})
	assert_str(out.path).is_equal("flatpak")
	assert_array(Array(out.args)).contains_exactly(["run", "net.retrodeck.retrodeck"])
	entry.profiles = true
	assert_array(Array(LaunchArgs.build(entry, "p2", {0: "jeff"}).args)).contains_exactly(
			["run", "net.retrodeck.retrodeck", "--profile=p2", "--p1-char=jeff"])


func test_the_retro_world_has_no_words() -> void:
	var w := JarWorld.build_retro()
	var stack: Array[Node] = [w]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		assert_bool(n is Label3D or n is Label).is_false()
		stack.append_array(n.get_children())
	assert_int(w.get_child_count()).is_greater(10)
	w.free()
