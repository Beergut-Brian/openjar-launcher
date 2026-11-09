## CardLook: every fallback tile is reachable through card_tiles.gdshader's colour rule, the empty
## slot has its own flag and tint, neighbours never share a tile, and bounce really squashes.
class_name TestCardLook
extends GdUnitTestSuite

const SHADER := "res://assets/shaders/card_tiles.gdshader"


func test_each_tint_lands_on_its_tile() -> void:
	assert_int(CardLook.TILE_TINTS.size()).is_equal(CardLook.TILE_COUNT)
	for i in CardLook.TILE_COUNT:
		assert_int(CardLook.shader_tile(CardLook.tint_for(i))).is_equal(i)


func test_empty_tint_matches_shader_uniform() -> void:
	var code := FileAccess.get_file_as_string(SHADER)
	var re := RegEx.create_from_string("uniform vec3 empty_tint\\s*=\\s*vec3\\(([^)]*)\\)")
	var m := re.search(code)
	assert_object(m).is_not_null()
	var v := m.get_string(1).split_floats(",")
	var shader_tint := Vector3(v[0], v[1], v[2])
	var e := CardLook.EMPTY_TINT
	assert_float(shader_tint.distance_to(Vector3(e.r, e.g, e.b))).is_less(0.005)
	assert_int(CardLook.shader_tile(e)).is_equal(-1)
	assert_int(CardLook.shader_tile(e.lightened(0.1))).is_not_equal(-1)


func test_shader_tile_count_matches() -> void:
	var code := FileAccess.get_file_as_string(SHADER)
	assert_bool(code.contains("uniform float variants = %d.0;" % CardLook.TILE_COUNT)).is_true()


func test_placeholder_index_is_stable_and_in_range() -> void:
	for slug in ["smash-party", "worm-dig", "spaceballs", "jar-test", ""]:
		var i := CardLook.placeholder_index(slug)
		assert_int(i).is_between(0, CardLook.TILE_COUNT - 1)
		assert_int(CardLook.placeholder_index(slug)).is_equal(i)


func test_spread_never_repeats_neighbours() -> void:
	var slugs := []
	for n in 40:
		slugs.append("game-%d" % n)
	var tiles := CardLook.spread(slugs)
	assert_int(tiles.size()).is_equal(slugs.size())
	for i in range(1, tiles.size()):
		assert_int(tiles[i]).is_not_equal(tiles[i - 1])
	# A slug whose own tile does not clash keeps it.
	assert_int(CardLook.spread(["solo"])[0]).is_equal(CardLook.placeholder_index("solo"))


func test_spread_fixture_row_is_varied() -> void:
	var tiles := CardLook.spread(["jar-test", "smash-party", "spaceballs", "worm-dig"])
	for i in range(1, tiles.size()):
		assert_int(tiles[i]).is_not_equal(tiles[i - 1])


func test_bounce_squashes_then_stretches() -> void:
	var k := CardLook.BOUNCE_KEYS
	assert_float(k[0].x).is_greater(k[0].y)   # wide
	assert_float(k[1].y).is_greater(k[1].x)   # tall
	assert_vector(k[-1]).is_equal(Vector2.ONE)
	assert_int(CardLook.BOUNCE_TIMES.size()).is_equal(k.size())


func test_card_empty_flag_and_tile() -> void:
	var card: Control = auto_free(load("res://scenes/launcher/card.tscn").instantiate())
	add_child(card)
	card.setup({})
	assert_bool(card.empty).is_true()
	assert_int(CardLook.shader_tile(card.placeholder.color)).is_equal(-1)
	card.setup({"slug": "worm-dig", "name": "Worm Dig"})
	assert_bool(card.empty).is_false()
	assert_int(CardLook.shader_tile(card.placeholder.color)).is_equal(card.placeholder_index)
	card.set_placeholder_index(3)
	assert_int(CardLook.shader_tile(card.placeholder.color)).is_equal(3)
	card.set_empty(true)
	assert_int(CardLook.shader_tile(card.placeholder.color)).is_equal(-1)


func test_card_bounce_is_not_uniform() -> void:
	var card: Control = auto_free(load("res://scenes/launcher/card.tscn").instantiate())
	add_child(card)
	card.setup({"slug": "a"})
	card.bounce()
	await get_tree().create_timer(CardLook.BOUNCE_TIMES[0] + 0.01).timeout
	assert_float(card.scale.x).is_greater(card.scale.y)
	await get_tree().create_timer(0.4).timeout
	assert_vector(card.scale).is_equal_approx(Vector2.ONE * card.HIGHLIGHT_SCALE, Vector2(0.01, 0.01))


func test_row_neighbours_differ() -> void:
	var row: Control = auto_free(load("res://scenes/launcher/card_row.tscn").instantiate())
	add_child(row)
	var list: Array[Dictionary] = []
	for s in ["jar-test", "smash-party", "spaceballs", "worm-dig", "a", "b", "c"]:
		list.append({"slug": s, "name": s})
	row.set_entries(list)
	for i in range(1, row._cards.size()):
		assert_int(row._cards[i].placeholder_index).is_not_equal(row._cards[i - 1].placeholder_index)
