## LaunchArgs: the --profile= handshake and manifest args.
class_name TestLaunchArgs
extends GdUnitTestSuite


func test_binary_gets_profile_then_args() -> void:
	var entry := {"dir": "/games/kick-off", "binary": "/games/kick-off/game.x86_64",
		"command": PackedStringArray(), "args": PackedStringArray(["--level=2"])}
	var out := LaunchArgs.build(entry, "p2")
	assert_str(out.path).is_equal("/games/kick-off/game.x86_64")
	assert_array(Array(out.args)).contains_exactly(["--profile=p2", "--level=2"])


func test_command_keeps_its_own_args_first() -> void:
	var entry := {"dir": "/games/smash", "binary": "",
		"command": PackedStringArray(["/usr/bin/chromium", "--kiosk", "http://localhost:8080"]),
		"args": PackedStringArray(["--x"])}
	var out := LaunchArgs.build(entry, "p1")
	assert_str(out.path).is_equal("/usr/bin/chromium")
	assert_array(Array(out.args)).contains_exactly(["--kiosk", "http://localhost:8080", "--profile=p1", "--x"])


func test_command_resolves_program_in_folder() -> void:
	var dir := OS.get_cache_dir().path_join("openjar_args_test_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(dir)
	FileAccess.open(dir.path_join("start.sh"), FileAccess.WRITE).close()
	var entry := {"dir": dir, "command": PackedStringArray(["start.sh"])}
	assert_str(LaunchArgs.build(entry, "p1").path).is_equal(dir.path_join("start.sh"))
	var on_path := {"dir": dir, "command": PackedStringArray(["xdg-open"])}
	assert_str(LaunchArgs.build(on_path, "p1").path).is_equal("xdg-open")
	DirAccess.remove_absolute(dir.path_join("start.sh"))
	DirAccess.remove_absolute(dir)


func test_unknown_profile_falls_back_to_p1() -> void:
	var entry := {"binary": "/g/game", "args": PackedStringArray()}
	assert_array(Array(LaunchArgs.build(entry, "../evil").args)).contains_exactly(["--profile=p1"])


func test_save_reads_profile_with_or_without_separator() -> void:
	var save_script: GDScript = load("res://scripts/autoload/Save.gd")
	assert_str(save_script.profile_from_args(PackedStringArray(["--profile=p2"]), "p1")).is_equal("p2")
	assert_str(save_script.profile_from_args(PackedStringArray(["-s", "x"]), "p1")).is_equal("p1")
	assert_str(save_script.profile_from_args(PackedStringArray(["--profile=../x"]), "p1")).is_equal("p1")
