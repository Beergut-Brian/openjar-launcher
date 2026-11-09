## WindowPolicy: minimise while a game runs, restore the earlier mode (never minimised) on return,
## and leave the window alone when the setting is off.
class_name TestWindowPolicy
extends GdUnitTestSuite

const FULL := DisplayServer.WINDOW_MODE_FULLSCREEN
const MIN := DisplayServer.WINDOW_MODE_MINIMIZED


func test_minimise_on_start_restore_on_exit() -> void:
	assert_int(WindowPolicy.mode_for(true, true, FULL)).is_equal(MIN)
	assert_int(WindowPolicy.mode_for(false, true, FULL)).is_equal(FULL)
	assert_int(WindowPolicy.mode_for(false, true, DisplayServer.WINDOW_MODE_WINDOWED)) \
		.is_equal(DisplayServer.WINDOW_MODE_WINDOWED)


func test_never_restores_into_minimised() -> void:
	assert_int(WindowPolicy.mode_for(false, true, MIN)).is_equal(FULL)
	assert_int(WindowPolicy.mode_for(false, true, -1)).is_equal(FULL)


func test_off_leaves_window_alone() -> void:
	assert_int(WindowPolicy.mode_for(true, false, FULL)).is_equal(WindowPolicy.LEAVE)
	assert_int(WindowPolicy.mode_for(false, false, FULL)).is_equal(WindowPolicy.LEAVE)


func test_launcher_default_is_minimise() -> void:
	var script: GDScript = load("res://scripts/hub/hub.gd")
	assert_bool(script.MINIMIZE_WHILE_RUNNING).is_true()
