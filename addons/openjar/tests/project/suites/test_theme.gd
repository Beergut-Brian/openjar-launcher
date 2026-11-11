## Theme (addons/openjar/theme): openjar_theme.tres loads on its own (no launcher, no external
## resources) and carries the button, label, panel and progress-bar styles the launcher uses.
class_name TestTheme
extends GdUnitTestSuite

const PATH := "res://addons/openjar/theme/openjar_theme.tres"
const INK := Color(0.0392, 0.0392, 0.0784, 1.0)


func _theme() -> Theme:
	return load(PATH) as Theme


func test_theme_loads_as_theme() -> void:
	assert_bool(ResourceLoader.exists(PATH)).is_true()
	var t := _theme()
	assert_object(t).is_not_null()
	assert_int(t.default_font_size).is_equal(44)


func test_theme_has_no_external_dependencies() -> void:
	# Must load without the launcher: no fonts, textures or styleboxes from other paths.
	assert_array(ResourceLoader.get_dependencies(PATH)).is_empty()
	var text := FileAccess.get_file_as_string(PATH)
	assert_bool(text.contains("ext_resource")).is_false()
	assert_bool(text.contains("res://")).is_false()


func test_button_styles() -> void:
	var t := _theme()
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		assert_bool(t.has_stylebox(s, "Button")).is_true()
		assert_object(t.get_stylebox(s, "Button")).is_instanceof(StyleBoxFlat)
	var normal := t.get_stylebox("normal", "Button") as StyleBoxFlat
	assert_int(normal.border_width_left).is_equal(8)
	assert_int(normal.corner_radius_top_left).is_equal(32)
	assert_bool((t.get_stylebox("focus", "Button") as StyleBoxFlat).draw_center).is_false()
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_disabled_color"]:
		assert_bool(t.has_color(c, "Button")).is_true()
	assert_bool(t.get_color("font_color", "Button").is_equal_approx(INK)).is_true()


func test_label_styles() -> void:
	var t := _theme()
	assert_bool(t.get_color("font_color", "Label").is_equal_approx(INK)).is_true()
	assert_bool(t.has_color("font_outline_color", "Label")).is_true()
	assert_int(t.get_constant("outline_size", "Label")).is_equal(0)
	assert_str(str(t.get_type_variation_base(&"LabelOnSky"))).is_equal("Label")
	assert_int(t.get_constant("outline_size", "LabelOnSky")).is_equal(16)


func test_panel_styles() -> void:
	var t := _theme()
	for type in ["Panel", "PanelContainer", "PanelAccent", "PanelDark"]:
		assert_object(t.get_stylebox("panel", type)).is_instanceof(StyleBoxFlat)
	assert_str(str(t.get_type_variation_base(&"PanelAccent"))).is_equal("PanelContainer")
	assert_str(str(t.get_type_variation_base(&"PanelDark"))).is_equal("PanelContainer")
	var p := t.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	assert_int(p.border_width_top).is_equal(10)
	assert_int(p.corner_radius_top_left).is_equal(36)


func test_progress_bar_styles() -> void:
	var t := _theme()
	assert_object(t.get_stylebox("background", "ProgressBar")).is_instanceof(StyleBoxFlat)
	assert_object(t.get_stylebox("fill", "ProgressBar")).is_instanceof(StyleBoxFlat)


func test_controls_pick_up_the_theme() -> void:
	var root := Control.new()
	root.theme = _theme()
	var b := Button.new()
	var pc := PanelContainer.new()
	pc.theme_type_variation = &"PanelDark"
	root.add_child(b)
	root.add_child(pc)
	add_child(auto_free(root))
	await get_tree().process_frame
	assert_object(b.get_theme_stylebox("normal")).is_same(root.theme.get_stylebox("normal", "Button"))
	assert_int(b.get_theme_font_size("font_size")).is_equal(44)
	assert_object(pc.get_theme_stylebox("panel")).is_same(root.theme.get_stylebox("panel", "PanelDark"))
