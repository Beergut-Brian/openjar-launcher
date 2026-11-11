## V-04: the vendored openjar-addons tree is the v0.2.1 tag, and the launcher uses its house theme.
## Reads only res:// files; settings and players.json are untouched (scripts/tools/test.sh
## points user:// and XDG_DATA_HOME at .scratch/ anyway).
class_name TestOpenjarAddon
extends GdUnitTestSuite

const ADDON := "res://addons/openjar/"
const ADDON_THEME := ADDON + "theme/openjar_theme.tres"
const GENERATED_THEME := "res://scenes/ui/theme.tres"


func test_addon_version_is_0_2_1() -> void:
	var cfg := ConfigFile.new()
	assert_int(cfg.load(ADDON + "plugin.cfg")).is_equal(OK)
	assert_str(str(cfg.get_value("plugin", "version", ""))).is_equal("0.2.1")


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


## The launcher theme is the addon's house theme (v0.2.1 ships theme/openjar_theme.tres).
func test_theme_resource_loads() -> void:
	var theme := load(ADDON_THEME) as Theme
	assert_object(theme).is_not_null()
	assert_object(theme.get_stylebox("panel", "PanelContainer")).is_not_null()


## One source, one shipped copy: scenes/ui/theme.tres is art/gen/build.py's output and the addon's
## theme is a verbatim copy of it. Fails if either changes without the other.
func test_addon_theme_matches_generator_output() -> void:
	var shipped := FileAccess.get_file_as_bytes(ADDON_THEME)
	var generated := FileAccess.get_file_as_bytes(GENERATED_THEME)
	assert_int(shipped.size()).is_greater(0)
	assert_int(shipped.size()).is_equal(generated.size())
	assert_bool(shipped == generated).is_true()
