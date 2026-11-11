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


## K-07 budget, the part that runs headless: everything the hub does on the CPU before its first
## frame (scene, characters, jars) for the 8-jar fixture. Headless it takes ~0.2 s on the producer
## box; the budget leaves room for a loaded CI runner. The rest of the 10 s is the renderer.
const HUB_SCENE := "res://scenes/hub/hub.tscn"
const HUB_BUDGET_MS := 2500
const PICKS := "user://test_cold_start/players.json"


func test_the_hub_is_ready_with_8_jars_well_inside_the_budget() -> void:
	var saved_env := OS.get_environment("OPENJAR_ROOT")
	var saved_profile: String = Save.profile
	Save.profile = "test_cold_start"
	Roster.picks_path = PICKS   # never the shared players.json
	OS.set_environment("OPENJAR_ROOT", ProjectSettings.globalize_path("res://tests/fixtures/hub_8"))
	var t0 := Time.get_ticks_msec()
	var hub: Node3D = auto_free(load(HUB_SCENE).instantiate())
	add_child(hub)
	var ready_ms := Time.get_ticks_msec() - t0
	await get_tree().process_frame
	await get_tree().process_frame
	OS.set_environment("OPENJAR_ROOT", saved_env)
	assert_int(hub.spots.size()).is_equal(8)
	assert_int(ready_ms).override_failure_message("hub took %d ms to get ready" % ready_ms) \
		.is_less(HUB_BUDGET_MS)
	var steps := (hub._marks as Array).map(func(m: Array) -> String: return m[0])
	assert_array(steps).is_equal(["ready", "characters", "jars", "first frame"])
	var marks: Array = hub._marks
	var own_ms: int = marks[2][1] - marks[0][1]   # ready -> jars: the hub's own work
	assert_int(own_ms).is_less(HUB_BUDGET_MS)
	Audio.release_all()
	Save.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/test_cold_start.json"))
	Save.profile = saved_profile
	Save._load()
	for f: String in [PICKS, PICKS + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	Roster.picks_path = Roster.TEST_PICKS
	Roster.profile_override = ""
	Roster.reload()


## A test run never reads or writes the real shared picks file.
func test_a_test_run_keeps_its_picks_away_from_the_shared_file() -> void:
	assert_bool(Roster.is_test_run(OS.get_cmdline_args())).is_true()
	assert_str(Roster.picks_path).is_equal(Roster.TEST_PICKS)
	assert_str(ProjectSettings.globalize_path(Roster.TEST_PICKS)).is_not_equal(Roster.shared_path())
