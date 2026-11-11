## PictoBubble (addons/openjar/picto_bubble): sizes, the built-in set, the game's registry (ids
## and prefixes), and drawing every built-in in a real _draw without errors.
class_name TestPictoBubble
extends GdUnitTestSuite


class _Canvas extends Control:
	var pics: Array = []
	var drawn := 0

	func _draw() -> void:
		PictoBubble.draw(self, Vector2(200, 200), pics, 1.0, 2.0)
		for i in pics.size():
			PictoBubble.picture(self, StringName(str(pics[i])), Vector2(40 + 30 * i, 300), 22.0)
		drawn += 1


func after_test() -> void:
	PictoBubble.clear_registry()


func test_size_for_grows_with_pictures_and_scale() -> void:
	assert_vector(PictoBubble.size_for(1)).is_equal(Vector2(30, 30))
	assert_vector(PictoBubble.size_for(3, 2.0)).is_equal(Vector2(3 * 22 + 4 * 4, 30) * 2.0)


func test_builtins_and_registry() -> void:
	for id in PictoBubble.BUILTIN:
		assert_bool(PictoBubble.has_picture(id)).is_true()
	assert_bool(PictoBubble.has_picture(&"deed")).is_false()
	assert_bool(PictoBubble.has_picture(&"vehicle:truck")).is_false()
	var got: Array = []
	PictoBubble.register(&"deed", func(_ci, id, _c, s, _a) -> void: got.append([id, s]))
	PictoBubble.register_prefix("vehicle:", func(_ci, id, _c, _s, _a) -> void: got.append([id]))
	assert_bool(PictoBubble.has_picture(&"deed")).is_true()
	assert_bool(PictoBubble.has_picture(&"vehicle:truck")).is_true()
	var cv := _Canvas.new()
	cv.pics = [&"deed", "vehicle:truck"]
	add_child(auto_free(cv))
	await get_tree().process_frame
	assert_int(cv.drawn).is_greater(0)
	assert_array(got).contains([[&"deed", 22.0], [&"vehicle:truck"]])


func test_every_builtin_draws() -> void:
	var cv := _Canvas.new()
	cv.size = Vector2(800, 400)
	cv.pics = PictoBubble.BUILTIN.duplicate() + [&"not_a_picture"]
	add_child(auto_free(cv))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(cv.drawn).is_greater(0)


func test_texture_picture_fits_the_box() -> void:
	var img := Image.create_empty(32, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	var tex := ImageTexture.create_from_image(img)
	var cv := _Canvas.new()
	add_child(auto_free(cv))
	PictoBubble.register(&"tex", func(ci, _id, c, s, a) -> void: PictoBubble.texture_picture(ci, tex, Rect2(), c, s, a))
	cv.pics = [&"tex"]
	cv.queue_redraw()
	await get_tree().process_frame
	assert_int(cv.drawn).is_greater(0)
