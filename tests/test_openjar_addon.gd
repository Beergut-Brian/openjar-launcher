## V-04: the vendored openjar-addons tree is the v0.2.0 tag, and the launcher theme loads.
## Reads only res:// files; settings and players.json are untouched (scripts/tools/test.sh
## points user:// and XDG_DATA_HOME at .scratch/ anyway).
class_name TestOpenjarAddon
extends GdUnitTestSuite

const ADDON := "res://addons/openjar/"


func test_addon_version_is_0_2_0() -> void:
	var cfg := ConfigFile.new()
	assert_int(cfg.load(ADDON + "plugin.cfg")).is_equal(OK)
	assert_str(str(cfg.get_value("plugin", "version", ""))).is_equal("0.2.0")


func test_addon_is_a_plain_tree_not_a_submodule() -> void:
	assert_bool(FileAccess.file_exists(ADDON + "README.md")).is_true()
	assert_bool(FileAccess.file_exists(ADDON + "VENDORED.md")).is_true()
	assert_bool(FileAccess.file_exists(ADDON + ".git")).is_false()
	assert_bool(DirAccess.dir_exists_absolute(ADDON + ".git")).is_false()
	assert_bool(FileAccess.file_exists("res://.gitmodules")).is_false()


func test_addon_modules_load() -> void:
	for path in ["tileworld/tile_world.gd", "split_screen/screen_director.gd",
			"cutscene/cutscene_player.gd", "picto_bubble/picto_bubble.gd"]:
		var s := load(ADDON + path) as Script
		assert_object(s).is_not_null()
		assert_bool(s.can_instantiate()).is_true()


## The launcher theme: the addon's own theme when the vendored tag ships one, else the launcher's.
## v0.2.0 ships theme/.gitkeep only, so today this loads scenes/ui/theme.tres.
func test_theme_resource_loads() -> void:
	var addon_theme := ADDON + "theme/openjar_theme.tres"
	var path := addon_theme if ResourceLoader.exists(addon_theme) else "res://scenes/ui/theme.tres"
	var theme := load(path) as Theme
	assert_object(theme).is_not_null()
	assert_object(theme.get_stylebox("panel", "PanelContainer")).is_not_null()
