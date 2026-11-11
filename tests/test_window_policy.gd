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


func test_the_log_line_says_when_the_window_manager_ignores_us() -> void:
	assert_str(WindowPolicy.report(true, MIN, MIN)).contains("done")
	assert_str(WindowPolicy.report(false, FULL, FULL)).contains("restore after the game, done")
	assert_str(WindowPolicy.report(true, MIN, DisplayServer.WINDOW_MODE_WINDOWED)) \
		.contains("the window manager kept mode 0")


func test_the_log_line_says_how_long_the_window_manager_took_and_if_it_took_two_tries() -> void:
	assert_str(WindowPolicy.report(true, MIN, MIN, 240)).is_equal(
			"window: minimise while the game runs, done (mode %d) after 240 ms" % MIN)
	assert_str(WindowPolicy.report(false, FULL, FULL, 1700, true)).ends_with("after 1700 ms, on the second try")
	assert_str(WindowPolicy.report(false, FULL, MIN, 3000, true)) \
		.contains("the window manager kept mode %d after 3000 ms" % MIN)


func test_a_restore_that_did_not_take_goes_through_windowed() -> void:
	var WIN := DisplayServer.WINDOW_MODE_WINDOWED
	assert_array(WindowPolicy.retry_steps(FULL)).is_equal([WIN, FULL])
	assert_array(WindowPolicy.retry_steps(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)) \
		.is_equal([WIN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN])
	assert_array(WindowPolicy.retry_steps(WIN)).is_equal([WIN])


func test_the_settle_wait_is_short() -> void:
	assert_float(WindowPolicy.SETTLE_STEP * WindowPolicy.SETTLE_CHECKS).is_less_equal(2.0)
