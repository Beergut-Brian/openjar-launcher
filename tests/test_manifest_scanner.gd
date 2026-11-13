## ManifestScanner against a temp dir of fixture folders.
class_name TestManifestScanner
extends GdUnitTestSuite

var root: String


func before_test() -> void:
	root = OS.get_cache_dir().path_join("openjar_scan_test_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(root)


func after_test() -> void:
	_rm(root)


func _game(folder: String, manifest, files: Array = []) -> String:
	var dir := root.path_join(folder)
	DirAccess.make_dir_recursive_absolute(dir)
	if manifest != null:
		var text: String = manifest if manifest is String else JSON.stringify(manifest)
		var f := FileAccess.open(dir.path_join("openjar.json"), FileAccess.WRITE)
		f.store_string(text)
		f.close()
	for file: String in files:
		DirAccess.make_dir_recursive_absolute(dir.path_join(file).get_base_dir())
		FileAccess.open(dir.path_join(file), FileAccess.WRITE).close()
	return dir


func _rm(path: String) -> void:
	for d in DirAccess.get_directories_at(path):
		_rm(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _slugs(entries: Array[Dictionary]) -> Array:
	return entries.map(func(e): return e.slug)


func test_good_binary_manifest() -> void:
	var dir := _game("kick-off", {"slug": "kick-off", "name": "Kick Off", "version": "v0.1.0",
		"binary": "game.x86_64", "grid": "store/grid.png", "hero": "store/hero.png",
		"clip": "store/clip.mp4", "dev": false}, ["game.x86_64"])
	var entries := ManifestScanner.scan(root)
	assert_int(entries.size()).is_equal(1)
	var e := entries[0]
	assert_str(e.slug).is_equal("kick-off")
	assert_str(e.name).is_equal("Kick Off")
	assert_str(e.version).is_equal("v0.1.0")
	assert_str(e.binary).is_equal(dir.path_join("game.x86_64"))
	assert_str(e.grid).is_equal(dir.path_join("store/grid.png"))
	assert_bool(e.dev).is_false()
	assert_int(e.command.size()).is_equal(0)


func test_jar_field_is_optional() -> void:
	var dir := _game("a-with-jar", {"slug": "a-with-jar", "binary": "game.x86_64", "jar": "store/jar.glb"},
		["game.x86_64", "store/jar.glb"])
	_game("b-without-jar", {"slug": "b-without-jar", "binary": "game.x86_64"}, ["game.x86_64"])
	var entries := ManifestScanner.scan(root)
	assert_array(_slugs(entries)).is_equal(["a-with-jar", "b-without-jar"])
	assert_str(entries[0].jar).is_equal(dir.path_join("store/jar.glb"))
	assert_str(entries[1].jar).is_empty()


func test_defaults_from_folder_name() -> void:
	_game("bare", {"binary": "run"}, ["run"])
	var e := ManifestScanner.scan(root)[0]
	assert_str(e.slug).is_equal("bare")
	assert_str(e.name).is_equal("bare")
	assert_str(e.grid).is_equal("")
	assert_bool(e.dev).is_false()


func test_command_instead_of_binary() -> void:
	_game("smash-party", {"slug": "smash-party", "name": "Smash Party",
		"command": ["/usr/bin/chromium", "--kiosk", "http://localhost:8080"], "args": ["--x"]})
	var e := ManifestScanner.scan(root)[0]
	assert_str(e.binary).is_equal("")
	assert_array(Array(e.command)).contains_exactly(["/usr/bin/chromium", "--kiosk", "http://localhost:8080"])
	assert_array(Array(e.args)).contains_exactly(["--x"])


func test_malformed_manifests_are_skipped() -> void:
	_game("a-not-json", "{ this is not json", ["game.x86_64"])
	_game("b-array", "[1, 2, 3]")
	_game("c-no-binary", {"slug": "c"})
	_game("d-binary-missing-on-disk", {"binary": "game.x86_64"})
	_game("e-bad-command", {"command": "chromium --kiosk"})
	_game("f-empty-command", {"command": []})
	_game("g-bad-args", {"binary": "game.x86_64", "args": "--x"}, ["game.x86_64"])
	_game("h-binary-number", {"binary": 7})
	_game("z-good", {"binary": "game.x86_64"}, ["game.x86_64"])
	assert_array(_slugs(ManifestScanner.scan(root))).contains_exactly(["z-good"])


func test_missing_manifest_and_missing_root() -> void:
	_game("no-manifest", null, ["game.x86_64"])
	assert_int(ManifestScanner.scan(root).size()).is_equal(0)
	assert_int(ManifestScanner.scan(root.path_join("does-not-exist")).size()).is_equal(0)


func test_launcher_folders_are_skipped() -> void:
	_game("openjar-launcher", {"binary": "game.x86_64"}, ["game.x86_64"])
	_game("openjar-launcher-dev", {"binary": "game.x86_64", "dev": true}, ["game.x86_64"])
	_game("renamed", {"slug": "openjar-launcher", "binary": "game.x86_64"}, ["game.x86_64"])
	_game("kick-off", {"binary": "game.x86_64"}, ["game.x86_64"])
	assert_array(_slugs(ManifestScanner.scan(root))).contains_exactly(["kick-off"])


func test_dev_filtering_and_sorted_order() -> void:
	_game("b-game-dev", {"slug": "b-game-dev", "binary": "g", "dev": true}, ["g"])
	_game("a-game", {"slug": "a-game", "binary": "g", "dev": false}, ["g"])
	_game("c-game", {"slug": "c-game", "binary": "g", "dev": "yes"}, ["g"])   # not a bool → not dev
	var all := ManifestScanner.scan(root)
	assert_array(_slugs(all)).contains_exactly(["a-game", "b-game-dev", "c-game"])
	assert_array(_slugs(ManifestScanner.filter_dev(all, false))).contains_exactly(["a-game", "c-game"])
	assert_array(_slugs(ManifestScanner.filter_dev(all, true))).contains_exactly(["a-game", "b-game-dev", "c-game"])


func test_expand_home() -> void:
	var home := OS.get_environment("HOME")
	assert_str(ManifestScanner.expand_home("~/Games/openjar")).is_equal(home + "/Games/openjar")
	assert_str(ManifestScanner.expand_home("/srv/games")).is_equal("/srv/games")
	assert_str(ManifestScanner.default_root()).is_not_empty()


## Playtest 2026-11-12: "Dev mode shows multiple versions of the game. It should only show the dev version."
func test_dev_on_shows_one_entry_per_game_dev_first() -> void:
	_game("kick-off", {"slug": "kick-off", "binary": "g"}, ["g"])
	_game("kick-off-dev", {"slug": "kick-off", "binary": "g", "dev": true}, ["g"])
	_game("solo-stable", {"binary": "g"}, ["g"])
	_game("worm-dev", {"slug": "worm", "binary": "g", "dev": true}, ["g"])
	var all := ManifestScanner.scan(root)
	assert_int(all.size()).is_equal(4)
	var off := ManifestScanner.filter_dev(all, false)
	assert_array(_slugs(off)).contains_exactly(["kick-off", "solo-stable"])
	assert_bool(off[0].dev).is_false()
	var on := ManifestScanner.filter_dev(all, true)
	assert_array(_slugs(on)).contains_exactly(["kick-off", "solo-stable", "worm"])   # one per slug
	assert_bool(on[0].dev).is_true()                      # the dev build, not the stable one
	assert_str(on[0].dir.get_file()).is_equal("kick-off-dev")
	assert_bool(on[1].dev).is_false()                     # no dev build: the stable one
	assert_bool(on[2].dev).is_true()                      # dev only: still there


func test_dev_order_does_not_matter_and_a_dev_suffix_slug_is_the_same_game() -> void:
	var stable := {"slug": "kick-off", "dev": false}
	var dev := {"slug": "kick-off-dev", "dev": true}
	var list: Array[Dictionary] = [dev, stable]
	assert_array(ManifestScanner.filter_dev(list, true)).is_equal([dev])
	list = [stable, dev]
	assert_array(ManifestScanner.filter_dev(list, true)).is_equal([dev])
	assert_array(ManifestScanner.filter_dev(list, false)).is_equal([stable])
	assert_str(ManifestScanner.game_of(dev)).is_equal("kick-off")
	assert_str(ManifestScanner.game_of({"slug": "not-a-dev", "dev": false})).is_equal("not-a-dev")
