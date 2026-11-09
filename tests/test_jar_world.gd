## The tiny world in each jar: the game's own `jar` scene when it ships one (data only, fitted to
## the jar), a generated diorama otherwise.
class_name TestJarWorld
extends GdUnitTestSuite

const MOON_GOLF := "res://tests/fixtures/hub_8/moon-golf/store/jar.tscn"

var tmp: String


func before_test() -> void:
	tmp = OS.get_cache_dir().path_join("openjar_jar_world_test_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(tmp)


func after_test() -> void:
	for f in DirAccess.get_files_at(tmp):
		DirAccess.remove_absolute(tmp.path_join(f))
	DirAccess.remove_absolute(tmp)


func _fits(node: Node3D) -> void:
	var box := JarWorld.bounds(node)
	assert_bool(box.size.y > 0.2).is_true()
	assert_float(box.position.y).is_greater_equal(-0.01)
	assert_float(box.end.y).is_less_equal(JarWorld.FIT_HEIGHT + 0.01)
	for edge: float in [box.position.x, box.end.x, box.position.z, box.end.z]:
		assert_float(absf(edge)).is_less_equal(JarWorld.FIT_RADIUS + 0.01)


func test_every_fallback_kind_builds_a_world_with_no_text() -> void:
	for kind in JarWorld.KINDS:
		var world: Node3D = auto_free(JarWorld.build(kind, Color(0.3, 0.7, 0.9)))
		assert_bool(world.find_children("*", "MeshInstance3D", true, false).size() >= 3).is_true()
		assert_array(world.find_children("*", "Label3D", true, false)).is_empty()
		assert_array(world.find_children("*", "Light3D", true, false)).is_empty()
		var box := JarWorld.bounds(world)
		assert_float(box.end.y).is_less_equal(JarWorld.FIT_HEIGHT + 0.25)
		assert_float(maxf(box.size.x, box.size.z)).is_less_equal(JarWorld.FIT_RADIUS * 2.0 + 0.5)


func test_fallback_kind_is_stable_and_neighbours_differ() -> void:
	assert_int(JarWorld.kind_for("moon-golf")).is_equal(JarWorld.kind_for("moon-golf"))
	assert_int(JarWorld.kind_for("moon-golf")).is_between(0, JarWorld.KINDS - 1)
	var slugs := ["a", "a", "a", "ball-bash", "bubble-pop", "comet-kick", "dino-dash", "jelly-jump"]
	var kinds := JarWorld.assign(slugs)
	assert_int(kinds.size()).is_equal(slugs.size())
	for i in range(1, kinds.size()):
		assert_int(kinds[i]).is_not_equal(kinds[i - 1])
	assert_array(JarWorld.assign(slugs)).is_equal(kinds)


func test_custom_tscn_is_loaded_stripped_fitted_and_animated() -> void:
	var world: Node3D = auto_free(JarWorld.load_custom(ProjectSettings.globalize_path(MOON_GOLF)))
	assert_object(world).is_not_null()
	assert_array(world.find_children("*", "Light3D", true, false)).is_empty()   # the fixture has a lamp
	assert_bool(world.find_children("*", "MeshInstance3D", true, false).size() >= 3).is_true()
	_fits(world)
	add_child(world)
	var players := world.find_children("*", "AnimationPlayer", true, false)
	assert_int(players.size()).is_equal(1)
	assert_bool((players[0] as AnimationPlayer).is_playing()).is_true()
	remove_child(world)


func test_custom_glb_is_loaded_and_fitted() -> void:
	var scene := Node3D.new()
	var big := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(40, 10, 20)     # far too big for a jar, and off centre
	big.mesh = box
	scene.add_child(big)
	big.owner = scene
	big.position = Vector3(30, 50, 0)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert_int(doc.append_from_scene(scene, state)).is_equal(OK)
	var path := tmp.path_join("jar.glb")
	assert_int(doc.write_to_filesystem(state, path)).is_equal(OK)
	scene.free()
	var world: Node3D = auto_free(JarWorld.load_custom(path))
	assert_object(world).is_not_null()
	_fits(world)


func test_scenes_with_scripts_or_outside_resources_are_refused() -> void:
	var scripted := tmp.path_join("scripted.tscn")
	var f := FileAccess.open(scripted, FileAccess.WRITE)
	f.store_string("[gd_scene load_steps=2 format=3]\n\n[sub_resource type=\"GDScript\" id=\"1\"]\nscript/source = \"extends Node3D\nfunc _ready():\n\tget_tree().quit()\n\"\n\n[node name=\"Jar\" type=\"Node3D\"]\nscript = SubResource(\"1\")\n")
	f.close()
	var linked := tmp.path_join("linked.tscn")
	f = FileAccess.open(linked, FileAccess.WRITE)
	f.store_string("[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"PackedScene\" path=\"res://scenes/hub/hub.tscn\" id=\"1\"]\n\n[node name=\"Jar\" type=\"Node3D\"]\n")
	f.close()
	assert_object(JarWorld.load_custom(scripted)).is_null()
	assert_object(JarWorld.load_custom(linked)).is_null()
	assert_object(JarWorld.load_custom(tmp.path_join("missing.glb"))).is_null()
	assert_object(JarWorld.load_custom("")).is_null()
