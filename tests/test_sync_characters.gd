## scripts/tools/sync_characters.sh against a throwaway characters repo and a throwaway game
## (SYNC_CHARACTERS_ROOT): it marks what it writes, removes only synced folders whose id left the
## roster, warns about anything else in assets/characters/ (a game's gun belt), and refuses to
## overwrite an unsynced folder that has a roster id. Needs bash, git and python3 (skips without).
class_name TestSyncCharacters
extends GdUnitTestSuite

const BASE := "user://test_sync_characters"

var _base := ""
var _lib := ""
var _game := ""


func before() -> void:
	_base = ProjectSettings.globalize_path(BASE)
	_lib = _base.path_join("lib")
	_game = _base.path_join("game")


func after() -> void:
	_wipe()


func before_test() -> void:
	_wipe()
	DirAccess.make_dir_recursive_absolute(_lib)
	_put(_lib.path_join("models/sprocket.glb"), "not really a glb")
	_put(_lib.path_join("characters.json"), JSON.stringify({ "roster": ["sprocket"],
			"defaults": { "P1": "sprocket" }, "player_colours": {},
			"characters": [{ "id": "sprocket", "name": "Sprocket", "playable": true,
				"model_3d": "models/sprocket.glb" }] }))
	_sh("cd '%s' && git init -q && git add -A && git -c user.name=t -c user.email=t@t.invalid " % _lib
			+ "-c commit.gpgsign=false commit -qm fixture && git tag v9.0.0")
	_put(_game.path_join("assets/CREDITS.md"), "# Credits\n")
	_put(_game.path_join("assets/characters/gear/belt.txt"), "the game's own gun belt")
	_put(_game.path_join("assets/characters/oldguy/.synced"), "openjar-characters v8\n")
	_put(_game.path_join("assets/characters/oldguy/oldguy.glb"), "x")
	_put(_game.path_join("assets/characters/legacy/legacy.glb"), "synced before the marker")
	_put(_game.path_join("data/roster.json"), JSON.stringify({ "roster": ["legacy"] }))


func _wipe() -> void:
	if _base != "" and _base.ends_with("test_sync_characters") and DirAccess.dir_exists_absolute(_base):
		OS.execute("rm", ["-rf", "--", _base])


func _put(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _sh(cmd: String, out: Array = []) -> int:
	return OS.execute("bash", ["-c", cmd + " 2>&1"], out)


func _tools_missing() -> bool:
	return _sh("command -v git && command -v python3") != 0


func _sync(tag := "v9.0.0") -> Dictionary:
	var out := []
	var tool := ProjectSettings.globalize_path("res://scripts/tools/sync_characters.sh")
	var code := _sh("SYNC_CHARACTERS_ROOT='%s' bash '%s' '%s' %s" % [_game, tool, _lib, tag], out)
	return { "code": code, "log": "\n".join(out) }


func _has(rel: String) -> bool:
	var p := _game.path_join(rel)
	return FileAccess.file_exists(p) or DirAccess.dir_exists_absolute(p)


func test_keeps_folders_it_did_not_make() -> void:
	if _tools_missing():
		push_warning("test_sync_characters: no git/python3 here, skipped")
		return
	var r := _sync()
	assert_int(r.code).override_failure_message(r.log).is_equal(0)
	assert_bool(_has("assets/characters/gear/belt.txt")).override_failure_message(r.log).is_true()
	assert_str(r.log).contains("left assets/characters/gear alone")
	assert_bool(_has("assets/characters/oldguy")).is_false()     # synced (marker), left the roster
	assert_bool(_has("assets/characters/legacy")).is_false()     # in the last roster.json
	assert_bool(_has("assets/characters/sprocket/sprocket.glb")).is_true()
	assert_bool(_has("assets/characters/sprocket/.synced")).is_true()
	var d = JSON.parse_string(FileAccess.get_file_as_string(_game.path_join("data/roster.json")))
	assert_array(d.roster).is_equal(["sprocket"])
	assert_str(d.characters_tag).is_equal("v9.0.0")
	# A second run still leaves the belt alone and keeps Sprocket.
	r = _sync()
	assert_int(r.code).is_equal(0)
	assert_bool(_has("assets/characters/gear/belt.txt")).is_true()
	assert_bool(_has("assets/characters/sprocket/.synced")).is_true()


func test_refuses_to_overwrite_an_unsynced_folder_with_a_roster_id() -> void:
	if _tools_missing():
		push_warning("test_sync_characters: no git/python3 here, skipped")
		return
	_put(_game.path_join("assets/characters/sprocket/mine.txt"), "the game's, not the library's")
	var r := _sync()
	assert_int(r.code).is_not_equal(0)
	assert_str(r.log).contains("not a synced folder")
	assert_bool(_has("assets/characters/sprocket/mine.txt")).is_true()


## A character with voice/lib/catchphrase_big.ogg gets voice/catchphrase.ogg and a "catchphrase"
## path (only that file from lib/, and it is not a bark); one without gets "".
func test_vendors_the_catchphrase() -> void:
	if _tools_missing():
		push_warning("test_sync_characters: no git/python3 here, skipped")
		return
	for f in ["cheer.ogg", "lib/catchphrase_big.ogg", "lib/catchphrase_calm.ogg", "lib/sigh.ogg"]:
		_put(_lib.path_join("voices/whistle/" + f), "ogg " + f)
	_put(_lib.path_join("characters.json"), JSON.stringify({ "roster": ["sprocket", "whistle"],
			"defaults": { "P1": "sprocket", "P2": "whistle" }, "player_colours": {},
			"characters": [{ "id": "sprocket", "name": "Sprocket", "playable": true,
				"model_3d": "models/sprocket.glb" },
				{ "id": "whistle", "name": "Whistle", "playable": true, "voice": "voices/whistle/" }] }))
	_sh("cd '%s' && git add -A && git -c user.name=t -c user.email=t@t.invalid " % _lib
			+ "-c commit.gpgsign=false commit -qm voice && git tag v9.1.0")
	var r := _sync("v9.1.0")
	assert_int(r.code).override_failure_message(r.log).is_equal(0)
	var d = JSON.parse_string(FileAccess.get_file_as_string(_game.path_join("data/roster.json")))
	var w: Dictionary = d.characters.whistle
	assert_str(w.catchphrase).is_equal("res://assets/characters/whistle/voice/catchphrase.ogg")
	assert_array(w.barks).is_equal(["cheer"])
	assert_str(d.characters.sprocket.catchphrase).is_equal("")
	var phrase := _game.path_join("assets/characters/whistle/voice/catchphrase.ogg")
	assert_str(FileAccess.get_file_as_string(phrase)).is_equal("ogg lib/catchphrase_big.ogg")
	assert_bool(_has("assets/characters/whistle/voice/lib")).is_false()
	assert_bool(_has("assets/characters/whistle/voice/sigh.ogg")).is_false()
	assert_bool(_has("assets/characters/whistle/voice/catchphrase_calm.ogg")).is_false()
	var credits := FileAccess.get_file_as_string(_game.path_join("assets/CREDITS.md"))
	assert_str(credits).contains("characters/whistle/voice/catchphrase.ogg")
