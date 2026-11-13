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


## K-07 budget, the whole boot headless: a real `godot` process from engine start (autoloads, the
## boot scene, the hub, 8 jars) to its "launcher: interactive" line. ~0.5 to 1.4 s headless on the
## producer box; the 10 s target minus the first-frame compile on a real GPU is what this pins.
## User data and the shared picks file go to a scratch dir under user://, never the real ones.
const BOOT_BUDGET_MS := 5000
const BOOT_SCRATCH := "user://test_cold_start_boot"


static func interactive_ms(log_text: String) -> int:
	var re := RegEx.create_from_string("launcher: interactive \\(hub, \\d+ jars\\) after (\\d+) ms")
	var m := re.search(log_text)
	return int(m.get_string(1)) if m else -1


func test_the_interactive_line_is_parsed() -> void:
	assert_int(interactive_ms("x\nlauncher: interactive (hub, 8 jars) after 812 ms, unix 1.0 (ready 10)\n")) \
		.is_equal(812)
	assert_int(interactive_ms("launcher: version v?")).is_equal(-1)


## Each step's own cost ("+N") from the interactive line: {"ready": 250, "characters": 105, ...}.
static func step_costs(log_text: String) -> Dictionary:
	var out := {}
	var line := RegEx.create_from_string("launcher: interactive [^\n]*\\((ready [^\n]*)\\)").search(log_text)
	if line == null:
		return out
	for m: RegExMatch in RegEx.create_from_string("([a-z ]+) \\d+ \\(\\+(\\d+)\\)").search_all(line.get_string(1)):
		out[m.get_string(1).strip_edges()] = int(m.get_string(2))
	return out


## Per-step budgets for a headless boot, ms. Measured on the producer box (gap-close-6, 2026-11-13,
## load average 4 to 23): ready 245 to 1040, characters 100 to 550, jars 67 to 230, intro 2 to 3,
## first frame 2 to 4. About 3x the worst seen, so a slow CI runner passes; the intro and first-frame
## budgets catch the old cost (the intro built all 22 characters before the first frame: +540 ms).
const STEP_BUDGET_MS := {"ready": 3000, "characters": 1500, "jars": 1000, "intro": 300, "first frame": 300}


func test_step_costs_are_parsed() -> void:
	var line := "launcher: interactive (hub, 8 jars) after 431 ms, unix 1.0 (ready 251 (+251), characters " + \
		"357 (+106), jars 426 (+69), intro 429 (+3), first frame 431 (+2))\n"
	assert_dict(step_costs("x\n" + line)).is_equal(
		{"ready": 251, "characters": 106, "jars": 69, "intro": 3, "first frame": 2})
	assert_dict(step_costs("launcher: version v?")).is_empty()


## Boots the real project in its own godot process, user data in the scratch dir. demo "" is a plain
## boot (the first of the day, so the intro plays); "follow" skips the intro.
func _boot(demo: String) -> String:
	var scratch := ProjectSettings.globalize_path(BOOT_SCRATCH)
	OS.execute("rm", ["-rf", scratch])
	DirAccess.make_dir_recursive_absolute(scratch.path_join("data"))
	DirAccess.make_dir_recursive_absolute(scratch.path_join("config"))
	var script := scratch.path_join("boot.sh")
	var f := FileAccess.open(script, FileAccess.WRITE)
	f.store_string("#!/bin/sh\nXDG_DATA_HOME=\"$1/data\" XDG_CONFIG_HOME=\"$1/config\" OPENJAR_ROOT=\"$2\" " +
		"HUB_DEMO=\"$5\" exec \"$3\" --headless --path \"$4\" --quit-after 5 2>&1\n")
	f.close()
	var out: Array = []
	var code := OS.execute("sh", [script, scratch, ProjectSettings.globalize_path("res://tests/fixtures/hub_8"),
		OS.get_executable_path(), ProjectSettings.globalize_path("res://"), demo], out, true)
	var log_text := "\n".join(out)
	assert_int(code).override_failure_message(log_text).is_equal(0)
	assert_str(log_text).not_contains("SCRIPT ERROR")
	assert_bool(DirAccess.dir_exists_absolute(scratch.path_join("data/godot/app_userdata"))).is_true()
	OS.execute("rm", ["-rf", scratch])
	return log_text


func _assert_steps_inside_budget(log_text: String, steps: Array) -> void:
	var costs := step_costs(log_text)
	assert_array(costs.keys()).override_failure_message(log_text).is_equal(steps)
	for step: String in costs:
		assert_int(costs[step]).override_failure_message("%s took %d ms (budget %d)\n%s" % [
			step, costs[step], STEP_BUDGET_MS[step], log_text]).is_less(STEP_BUDGET_MS[step])


## The first boot of the day: the intro plays, and its 22 characters load on worker threads while it
## runs, so neither the intro step nor the first frame waits on them.
func test_a_first_boot_of_the_day_with_the_intro_is_interactive_inside_every_step_budget() -> void:
	var log_text := _boot("")
	var ms := interactive_ms(log_text)
	assert_int(ms).override_failure_message("no interactive line:\n" + log_text).is_greater(0)
	assert_int(ms).override_failure_message("boot took %d ms" % ms).is_less(BOOT_BUDGET_MS)
	_assert_steps_inside_budget(log_text, ["ready", "characters", "jars", "intro", "first frame"])


func test_a_headless_boot_is_interactive_well_inside_the_budget() -> void:
	var log_text := _boot("follow")
	assert_bool(log_text.contains("launcher: 8 entries")).override_failure_message(log_text).is_true()
	var ms := interactive_ms(log_text)
	assert_int(ms).override_failure_message("no interactive line:\n" + log_text).is_greater(0)
	assert_int(ms).override_failure_message("boot took %d ms" % ms).is_less(BOOT_BUDGET_MS)
	_assert_steps_inside_budget(log_text, ["ready", "characters", "jars", "first frame"])
