## C-14: Smash Party (the browser game) as a jar. The real kiosk manifest scans as a `command` entry,
## its jar world loads, and its launch script serves the game, opens it in a browser of its own and
## exits when that window closes (or when the launcher asks it to stop). A fake browser stands in.
class_name TestSmashParty
extends GdUnitTestSuite

const KIOSK := "res://kiosk/smash-party"
const GAME := "res://tests/fixtures/smash_party/game"
const FAKE := "res://tests/fixtures/smash_party/fake_browser.sh"
const TMP := "user://test_smash_party"

var tmp: String


func before_test() -> void:
	tmp = ProjectSettings.globalize_path(TMP)
	DirAccess.make_dir_recursive_absolute(tmp)


func after_test() -> void:
	for f: String in DirAccess.get_files_at(tmp):
		DirAccess.remove_absolute(tmp.path_join(f))


func _env(browser_seconds: float = 0.0) -> PackedStringArray:
	return PackedStringArray([
		"SMASH_PARTY_GAME=" + ProjectSettings.globalize_path(GAME),
		"SMASH_PARTY_BROWSER=" + ProjectSettings.globalize_path(FAKE),
		"SMASH_PARTY_LOG=" + tmp.path_join("smash.log"),
		"FAKE_BROWSER_OUT=" + tmp.path_join("fake"),
		"FAKE_BROWSER_SECONDS=%s" % browser_seconds,
		"XDG_CACHE_HOME=" + tmp.path_join("cache"),
		"bash", ProjectSettings.globalize_path(KIOSK).path_join("smash-party.sh"),
		"--profile=p1", "--p1-char=jeff", "--p2-char=chuck",   # what the launcher passes; ignored
	])


func _read(suffix: String) -> String:
	return FileAccess.get_file_as_string(tmp.path_join("fake" + suffix)).strip_edges()


func _alive(pid: int) -> bool:
	return OS.execute("kill", ["-0", str(pid)]) == 0


func test_the_kiosk_manifest_is_a_command_jar_with_its_own_world() -> void:
	var dir := ProjectSettings.globalize_path(KIOSK)
	var entry := ManifestScanner.read_manifest(dir)
	assert_str(entry.slug).is_equal("smash-party")
	assert_str(entry.binary).is_empty()
	assert_array(Array(entry.command)).is_equal(["smash-party.sh"])
	assert_str(entry.jar).is_equal(dir.path_join("store/jar.tscn"))
	assert_bool(entry.dev).is_false()
	var cmd := LaunchArgs.build(entry, "p2", {0: "jeff", 1: "chuck"})
	assert_str(cmd.path).is_equal(dir.path_join("smash-party.sh"))   # resolved in its own folder
	assert_array(Array(cmd.args)).is_equal(["--profile=p2", "--p1-char=jeff", "--p2-char=chuck"])
	var world: Node3D = auto_free(JarWorld.load_custom(entry.jar))
	assert_object(world).is_not_null()
	assert_bool(world.find_children("*", "MeshInstance3D", true, false).size() >= 10).is_true()
	assert_int(world.find_children("*", "AnimationPlayer", true, false).size()).is_equal(1)
	assert_array(world.find_children("*", "Label3D", true, false)).is_empty()   # no text


func test_the_script_serves_the_game_full_screen_and_exits_when_the_window_closes() -> void:
	var out := []
	var code := OS.execute("env", _env(), out, true)
	assert_int(code).override_failure_message(str(out)).is_equal(0)
	assert_str(_read(".page")).contains("SMASH-FIXTURE-OK")   # the browser got the game over http
	var url := _read(".url")
	assert_str(url).starts_with("http://127.0.0.1:")
	var args := _read(".args").split("\n")
	assert_array(Array(args)).contains(["--kiosk", "--start-fullscreen", url])
	assert_bool(args[0].begins_with("--user-data-dir=" + tmp.path_join("cache"))).is_true()   # a profile of its own
	for a: String in args:
		assert_bool(a.begins_with("--profile") or a.contains("-char=")).is_false()   # launcher args not passed on
	# the server went with it
	var port := int(url.get_slice(":", 2).get_slice("/", 0))
	assert_int(OS.execute("bash", ["-c", "exec 3<>/dev/tcp/127.0.0.1/%d" % port])).is_not_equal(0)


func test_term_from_the_launcher_takes_the_browser_down_too() -> void:
	var pid := OS.create_process("env", _env(30.0))
	assert_int(pid).is_greater(0)
	var t := 0.0
	while not FileAccess.file_exists(tmp.path_join("fake.pid")) and t < 8.0:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	var browser := int(_read(".pid"))
	assert_bool(_alive(browser)).is_true()
	OS.execute("kill", ["-TERM", str(pid)])
	t = 0.0
	while (OS.is_process_running(pid) or _alive(browser)) and t < 3.0:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	assert_bool(OS.is_process_running(pid)).is_false()
	assert_bool(_alive(browser)).is_false()


func test_no_game_folder_fails_fast_with_a_log_line() -> void:
	var env := _env()
	env[0] = "SMASH_PARTY_GAME=" + tmp.path_join("missing")
	var code := OS.execute("env", env, [], true)
	assert_int(code).is_equal(3)
	assert_str(FileAccess.get_file_as_string(tmp.path_join("smash.log"))).contains("no game at")
