## The exported pack: gdUnit4 (installed per machine and by release.yml before it exports) must stay
## out of it. With it in, `--export-release "Linux"` writes the binary and then aborts (exit 134),
## which fails the release job; it also added ~1.7 MB to every cold start's pack.
class_name TestExport
extends GdUnitTestSuite


func _preset_value(key: String) -> String:
	var cfg := ConfigFile.new()
	assert_int(cfg.load("res://export_presets.cfg")).is_equal(OK)
	return str(cfg.get_value("preset.0", key, ""))


func test_the_linux_preset_leaves_the_test_framework_and_tests_out() -> void:
	assert_str(_preset_value("name")).is_equal("Linux")
	var excluded := _preset_value("exclude_filter").split(",")
	for f: String in ["addons/gdUnit4/*", "tests/*"]:
		assert_bool(f in excluded).override_failure_message("%s is exported" % f).is_true()


func test_the_release_still_ships_the_game() -> void:
	var excluded := _preset_value("exclude_filter")
	for f: String in ["scenes/hub", "scripts/", "assets/", "data/roster"]:
		assert_bool(excluded.contains(f)).override_failure_message("%s is excluded" % f).is_false()
