## LauncherState through a real Save node: last card / profile / dev toggle / intro date survive a reload.
class_name TestLauncherState
extends GdUnitTestSuite

const SAVE := preload("res://scripts/autoload/Save.gd")
const PROFILE := "test_launcher_state"


func _fresh_save() -> Node:
	var s: Node = SAVE.new()
	s.profile = PROFILE
	s._load()
	return s


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % PROFILE))


func test_defaults_when_empty() -> void:
	var s := _fresh_save()
	s.wipe()
	assert_str(LauncherState.last_card(s)).is_equal("")
	assert_str(LauncherState.profile(s)).is_equal("p1")
	assert_bool(LauncherState.show_dev(s)).is_false()
	assert_bool(LauncherState.should_play_intro(s, "2026-11-09")).is_true()
	s.free()


func test_round_trip() -> void:
	var a := _fresh_save()
	a.wipe()
	LauncherState.set_last_card(a, "kick-off")
	LauncherState.set_profile(a, "p2")
	LauncherState.set_show_dev(a, true)
	LauncherState.mark_intro_played(a, "2026-11-09")
	a.flush()
	a.free()
	var b := _fresh_save()
	assert_str(LauncherState.last_card(b)).is_equal("kick-off")
	assert_str(LauncherState.profile(b)).is_equal("p2")
	assert_str(LauncherState.intro_date(b)).is_equal("2026-11-09")
	assert_bool(LauncherState.should_play_intro(b, "2026-11-09")).is_false()
	assert_bool(LauncherState.should_play_intro(b, "2026-11-10")).is_true()
	b.free()


func test_dev_builds_are_hidden_at_every_boot() -> void:
	# A save from the old launcher that remembered "show dev" must not show them at boot.
	var a := _fresh_save()
	a.wipe()
	a.set_value(LauncherState.SHOW_DEV, true)
	a.flush()
	LauncherState.reset_session()
	assert_bool(LauncherState.show_dev(a)).is_false()
	# Holding LB + RB turns them on for this run only.
	LauncherState.set_show_dev(a, true)
	assert_bool(LauncherState.show_dev(a)).is_true()
	a.free()
	# The next boot starts hidden again.
	LauncherState.reset_session()
	var b := _fresh_save()
	assert_bool(LauncherState.show_dev(b)).is_false()
	b.free()


func test_bad_stored_profile_falls_back() -> void:
	var s := _fresh_save()
	s.set_value(LauncherState.PROFILE, "p9")
	assert_str(LauncherState.profile(s)).is_equal("p1")
	s.free()
