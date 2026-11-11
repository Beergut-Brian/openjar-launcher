## Facts behind tileworld/README.md "Planned for Life of a Worm": what today's API already does on a
## disk, without any change (polar chunk keys, gravity toward the core, regrowing a dug cell with
## set_tile back to its base tile, a castings tile as a plain palette entry).
class_name TestWormToday
extends GdUnitTestSuite

const DIRT := 1
const CASTING := 2


func _world() -> TileWorld:
	var pal: Array[TileDef] = []
	for row in [[&"air", false], [&"dirt", true], [&"casting", true]]:
		var d := TileDef.new()
		d.id = row[0]
		d.solid = row[1]
		pal.append(d)
	var g := LayeredGenerator.new()
	g.bands = [{"from": 0, "tile": DIRT}]
	g.cave_threshold = 2.0
	var w := TileWorld.new()
	w.water_hz = 0.0
	w.setup(DiskShape.new(80, 16), g, pal, 7)
	add_child(w)
	auto_free(w)
	return w


func test_chunk_key_is_ring_and_sector() -> void:
	var s := DiskShape.new(80, 16)
	var cell := Vector2i(40, 0)                  # 40.5 tiles out on +x: ring 2, sector 0
	assert_vector(s.chunk_of(cell)).is_equal(Vector2i(2, 0))
	assert_int(s.sectors_in(4)).is_greater(s.sectors_in(1))


func test_gravity_and_below_point_at_the_core() -> void:
	var s := DiskShape.new(80, 16)
	var g := s.gravity_at(Vector2(0, -500))
	assert_float(g.normalized().dot(Vector2.DOWN)).is_equal_approx(1.0, 0.001)
	assert_vector(s.below(Vector2i(30, 2))).is_equal(Vector2i(29, 2))
	assert_vector(s.below(Vector2i(2, -30))).is_equal(Vector2i(2, -29))


func test_a_dug_cell_regrows_with_set_tile_and_the_edit_disappears() -> void:
	var w := _world()
	var c := Vector2i(50, 3)
	w.dig(c)
	assert_int(w.get_tile(c)).is_equal(0)
	assert_array(w.to_save().edits).is_not_empty()
	w.set_tile(c, w.base_tile_of(c))           # "regrow": back to base clears the edit
	assert_int(w.get_tile(c)).is_equal(DIRT)
	assert_array(w.to_save().edits).is_empty()


func test_castings_fit_one_layer_when_they_fill_dug_cells() -> void:
	var w := _world()
	var c := Vector2i(-20, 40)
	w.dig(c)
	w.set_tile(c, CASTING)
	assert_bool(w.is_solid(c)).is_true()
	assert_array(w.to_save().edits).is_equal([c.x, c.y, CASTING])
