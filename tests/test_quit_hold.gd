## K-02: Start only leaves the launcher when held QUIT_HOLD s; a tap ticks, shows the badge and
## does nothing else. Ignored while a game runs. Own Save profile, fixture roster, fixture jars.
class_name TestQuitHold
extends GdUnitTestSuite

const PROFILE := "test_quit_hold"
const HUB := "res://scenes/hub/hub.tscn"

var _saved_profile: String
var _saved_env: String


func before_test() -> void:
	_saved_env = OS.get_environment("OPENJAR_ROOT")
	_saved_profile = Save.profile
	Save.profile = PROFILE
	Save.wipe()
	Roster.picks_path = "user://test_quit_hold/players.json"
	Roster.data_path = "res://tests/fixtures/roster_three.json"
	Roster.args_override = PackedStringArray(["--test-quit-hold"])
	Roster.reload()


func after_test() -> void:
	Audio.release_all()
	Save.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % PROFILE))
	Save.profile = _saved_profile
	Save._load()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_quit_hold/players.json"))
	Roster.picks_path = Roster.TEST_PICKS
	Roster.data_path = "res://data/roster.json"
	Roster.args_override = PackedStringArray()
	Roster.reload()
	OS.set_environment("OPENJAR_ROOT", _saved_env)


func _hub() -> Node3D:
	OS.set_environment("OPENJAR_ROOT", ProjectSettings.globalize_path("res://tests/fixtures/hub_2"))
	var hub: Node3D = auto_free(load(HUB).instantiate())
	hub.really_quit = false
	add_child(hub)
	await get_tree().process_frame
	hub.set_process(false)   # the test feeds Start by hand
	return hub


func test_a_tap_on_start_does_not_quit_but_shows_the_badge() -> void:
	var hub: Node3D = await _hub()
	var quit := [false]
	hub.quitting.connect(func() -> void: quit[0] = true)
	assert_bool(hub.update_quit(true, 0.2)).is_false()
	assert_float(hub.quit_meter.progress).is_greater(0.0)
	assert_bool(hub.update_quit(false, 0.016)).is_false()
	assert_float(hub.quit_meter.progress).is_equal(0.0)
	for i in 10:   # mashing never adds up
		hub.update_quit(i % 2 == 0, 0.3)
	assert_bool(quit[0]).is_false()


func test_holding_start_quits() -> void:
	var hub: Node3D = await _hub()
	var quit := [false]
	hub.quitting.connect(func() -> void: quit[0] = true)
	var t := 0.0
	while t < hub.QUIT_HOLD - 0.1:
		assert_bool(hub.update_quit(true, 0.1)).is_false()
		t += 0.1
	assert_float(hub.quit_meter.progress).is_greater(0.8)
	hub.update_quit(true, 0.2)
	assert_bool(quit[0]).is_true()


func test_start_is_ignored_while_a_game_runs() -> void:
	var hub: Node3D = await _hub()
	hub.screen = hub.Screen.RUNNING
	for i in 30:
		assert_bool(hub.update_quit(true, 0.1)).is_false()
	assert_float(hub.quit_meter.progress).is_equal(0.0)
	hub.screen = hub.Screen.HUB
