## Launch-ready-2: a character swap drops the old body's rim-light override materials before the
## body is freed, so the swap logs no `"material" is null` engine error (13 of them per test run before).
class_name TestJarlingSwapClean
extends GdUnitTestSuite

const JEFF := "res://assets/characters/jeff/jeff.glb"
const CHUCK := "res://assets/characters/chuck/chuck.glb"


func _overrides(model: Node) -> int:
	var n := 0
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.get_surface_override_material_count():
			if mi.get_surface_override_material(s) != null:
				n += 1
	return n


func test_the_old_body_lets_go_of_its_materials_before_it_goes() -> void:
	var a: HubJarling = auto_free(HubJarling.new())
	add_child(a)
	a.setup(load(JEFF), "p1", Color.GREEN)
	var b: HubJarling = auto_free(HubJarling.new())   # a second Jeff, as the resident is
	add_child(b)
	b.setup(load(JEFF), "p2", Color.RED)
	var old: Node3D = a._model
	assert_int(_overrides(old)).is_greater(0)   # the rim look is on
	a.set_character("chuck", load(CHUCK))
	assert_int(_overrides(old)).is_equal(0)
	assert_int(_overrides(a._model)).is_greater(0)   # the new body has its own rim look
	assert_int(_overrides(b._model)).is_greater(0)   # the other Jeff keeps his
	await get_tree().process_frame
	assert_bool(is_instance_valid(old)).is_false()
