## End to end through launcher.tscn: picker → card row → launch a fake game → back on the same card,
## then the LB + RB hold toggles dev builds. Uses a temp OPENJAR_ROOT and a throwaway Save profile.
class_name TestLauncherFlow
extends GdUnitTestSuite

const PROFILE := "test_launcher_flow"

var root: String
var log_path: String
var _saved_profile: String
var _saved_env: String


func before_test() -> void:
	root = OS.get_cache_dir().path_join("openjar_flow_test_%d" % Time.get_ticks_usec())
	log_path = root.path_join("launched.log")
	_game("a-game", false)
	_game("b-game", false)
	_game("c-game-dev", true)
	_saved_env = OS.get_environment("OPENJAR_ROOT")
	OS.set_environment("OPENJAR_ROOT", root)
	_saved_profile = Save.profile
	Save.profile = PROFILE
	Save.wipe()
	LauncherState.mark_intro_played(Save, LauncherState.today())   # straight to the picker
	LauncherState.set_profile(Save, "p2")


func after_test() -> void:
	Audio.release_all()   # no music left playing when the test run quits
	Save.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % PROFILE))
	Save.profile = _saved_profile
	Save._load()
	OS.set_environment("OPENJAR_ROOT", _saved_env)
	Input.action_release("launcher_lb")
	Input.action_release("launcher_rb")
	OS.low_processor_usage_mode = false
	for d in DirAccess.get_directories_at(root):
		for f in DirAccess.get_files_at(root.path_join(d)):
			DirAccess.remove_absolute(root.path_join(d).path_join(f))
		DirAccess.remove_absolute(root.path_join(d))
	DirAccess.remove_absolute(log_path)
	DirAccess.remove_absolute(root)


func _game(slug: String, dev: bool) -> void:
	var dir := root.path_join(slug)
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("openjar.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"slug": slug, "name": slug, "binary": "game.sh", "dev": dev, "args": ["--from-test"]}))
	f.close()
	f = FileAccess.open(dir.path_join("game.sh"), FileAccess.WRITE)
	f.store_string("#!/bin/sh\necho \"%s $@\" >> \"%s\"\nsleep 0.3\n" % [slug, log_path])
	f.close()
	# Deliberately not executable: the launcher must fix the bit (zips can lose it).


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)
	await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func test_pick_launch_return_and_dev_toggle() -> void:
	var launcher: Control = auto_free(load("res://scenes/launcher/launcher.tscn").instantiate())
	add_child(launcher)
	await _wait(0.3)
	assert_int(launcher.screen).is_equal(launcher.Screen.PICKER)
	assert_int(launcher.picker.index).is_equal(1)    # remembered p2

	await _press("launcher_confirm")
	assert_int(launcher.screen).is_equal(launcher.Screen.CARDS)
	assert_int(launcher.card_row.entries.size()).is_equal(2)   # dev entry hidden
	await _wait(0.3)

	await _press("launcher_right")
	await _press("launcher_right")                     # clamped at the end
	assert_int(launcher.card_row.index).is_equal(1)

	await _press("launcher_confirm")
	await _wait(0.5)
	assert_int(launcher.screen).is_equal(launcher.Screen.RUNNING)
	assert_bool(launcher.visible).is_false()
	await _press("launcher_left")                      # ignored while the game runs
	var waited := 0.0
	while launcher.screen == launcher.Screen.RUNNING and waited < 5.0:
		await _wait(0.1)
		waited += 0.1
	assert_int(launcher.screen).is_equal(launcher.Screen.CARDS)
	assert_bool(launcher.visible).is_true()
	assert_int(launcher.card_row.index).is_equal(1)
	assert_str(launcher.card_row.selected_entry().slug).is_equal("b-game")
	assert_str(LauncherState.last_card(Save)).is_equal("b-game")
	assert_str(FileAccess.get_file_as_string(log_path).strip_edges()).is_equal("b-game --profile=p2 --from-test")

	await _wait(0.7)                                   # return grace
	Input.action_press("launcher_lb")
	Input.action_press("launcher_rb")
	await _wait(1.3)
	Input.action_release("launcher_lb")
	Input.action_release("launcher_rb")
	assert_bool(LauncherState.show_dev(Save)).is_true()
	assert_int(launcher.card_row.entries.size()).is_equal(3)
	assert_str(launcher.card_row.selected_entry().slug).is_equal("b-game")

	await _press("launcher_back")
	assert_int(launcher.screen).is_equal(launcher.Screen.PICKER)
	await _wait(0.3)
	await _press("launcher_back")
	assert_int(launcher.screen).is_equal(launcher.Screen.CARDS)


func test_card_row_step_clamps() -> void:
	var row_script: GDScript = load("res://scenes/launcher/card_row.gd")
	assert_int(row_script.step(0, -1, 3)).is_equal(0)
	assert_int(row_script.step(0, 1, 3)).is_equal(1)
	assert_int(row_script.step(2, 1, 3)).is_equal(2)
	assert_int(row_script.step(0, 1, 0)).is_equal(0)


func test_intro_first_boot_of_day_and_skip() -> void:
	Save.set_value(LauncherState.INTRO_DATE, "2000-01-01")
	var launcher: Control = auto_free(load("res://scenes/launcher/launcher.tscn").instantiate())
	add_child(launcher)
	await _wait(0.2)
	assert_int(launcher.screen).is_equal(launcher.Screen.INTRO)
	assert_str(LauncherState.intro_date(Save)).is_equal(LauncherState.today())
	await _press("launcher_confirm")
	assert_int(launcher.screen).is_equal(launcher.Screen.PICKER)
	await _wait(0.3)
	assert_int(launcher.screen).is_equal(launcher.Screen.PICKER)   # the skip press did not also confirm


func test_intro_finishes_on_its_own() -> void:
	var intro: Control = auto_free(load("res://scenes/launcher/intro.tscn").instantiate())
	add_child(intro)
	var done := [false]
	intro.finished.connect(func(): done[0] = true)
	intro.play()
	await _wait(2.0)
	assert_bool(done[0]).is_false()
	await _wait(1.5)
	assert_bool(done[0]).is_true()
	assert_bool(intro.visible).is_false()
