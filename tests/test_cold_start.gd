## K-07: cold start. The hub logs where its boot time went, and nothing heavy is preloaded that a
## normal boot never uses.
class_name TestColdStart
extends GdUnitTestSuite

const HUB := "res://scripts/hub/hub.gd"


func test_fallback_bodies_are_paths_loaded_only_when_needed() -> void:
	var script: GDScript = load(HUB)
	for id: String in script.MODELS:
		assert_bool(script.MODELS[id] is String).is_true()
		assert_bool(ResourceLoader.exists(script.MODELS[id])).is_true()
	assert_object(script.fallback_model("p2")).is_instanceof(PackedScene)
	assert_object(script.fallback_model("nobody")).is_instanceof(PackedScene)   # falls back to p1


func test_no_hub_script_preloads_a_model() -> void:
	for f: String in DirAccess.get_files_at("res://scripts/hub"):
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string("res://scripts/hub".path_join(f))
		assert_bool(src.contains('.glb")') and src.contains("preload(\"res://assets/models")) \
			.override_failure_message("%s preloads a model" % f).is_false()


func test_marks_say_when_each_step_ended_and_what_it_cost() -> void:
	var hub: Node3D = auto_free(load(HUB).new())
	hub._marks = [["ready", 400], ["characters", 550], ["first frame", 900]]
	assert_str(hub.cold_start_marks()) \
		.is_equal("ready 400 (+400), characters 550 (+150), first frame 900 (+350)")
