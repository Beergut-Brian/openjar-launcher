## launcher-igpu-1: graphics tiers. The pick from adapter strings (Intel HD 530 / Mesa Intel → low,
## NVIDIA GTX 1060 → high, the flag and OPENJAR_GRAPHICS override), the low settings land on the
## viewport, environment, sun and camera (also through the real hub), `high` is pinned to the look the
## hub had before tiers existed, and --bench quits by itself with its summary line.
## Own Save profile, fixture roster and jars, own picks file.
class_name TestGraphicsTier
extends GdUnitTestSuite

const PROFILE := "test_graphics_tier"
const HUB := "res://scenes/hub/hub.tscn"
const PICKS := "user://test_graphics_tier/players.json"

var _saved_profile: String
var _saved_env: String
var _saved_gfx: String


func before_test() -> void:
	_saved_env = OS.get_environment("OPENJAR_ROOT")
	_saved_gfx = OS.get_environment(GraphicsTier.ENV)
	_saved_profile = Save.profile
	Save.profile = PROFILE
	Save.wipe()
	Roster.picks_path = PICKS
	Roster.data_path = "res://tests/fixtures/roster_three.json"
	Roster.args_override = PackedStringArray(["--test-graphics-tier"])
	Roster.reload()


func after_test() -> void:
	Audio.release_all()
	Save.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % PROFILE))
	Save.profile = _saved_profile
	Save._load()
	for f in [PICKS, PICKS + ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	Roster.picks_path = Roster.TEST_PICKS
	Roster.data_path = "res://data/roster.json"
	Roster.args_override = PackedStringArray()
	Roster.reload()
	OS.set_environment("OPENJAR_ROOT", _saved_env)
	OS.set_environment(GraphicsTier.ENV, _saved_gfx)
	# the runner's own window back to the high look (the hub applies the tier to it)
	GraphicsTier.apply(GraphicsTier.HIGH, get_tree().root, null, null, null, false)


# ---------------------------------------------------------------- the pick

func test_intel_integrated_is_low() -> void:
	var none := PackedStringArray()
	for a: Array in [
			["Intel(R) HD Graphics 530 (SKL GT2)", "Intel"],
			["Mesa Intel(R) HD Graphics 530 (SKL GT2)", "Intel"],
			["Intel(R) HD Graphics 530", "Intel Corporation"],
			["Mesa Intel(R) UHD Graphics 630 (CFL GT2)", "Intel"],
			["AMD Radeon(TM) Graphics (RADV RENOIR)", "AMD"],     # an APU
			["llvmpipe (LLVM 19.1.7, 256 bits)", "Mesa"],         # software
			["", ""],                                             # unknown / headless
			["Some Future GPU", "Unknown"]]:
		assert_str(GraphicsTier.pick(a[0], a[1], none)).override_failure_message(str(a)).is_equal("low")


func test_nvidia_and_discrete_amd_are_high() -> void:
	var none := PackedStringArray()
	for a: Array in [
			["NVIDIA GeForce GTX 1060 6GB", "NVIDIA"],
			["NVIDIA GeForce GTX 1060 3GB/PCIe/SSE2", "NVIDIA Corporation"],
			["NVIDIA GeForce RTX 3060", "NVIDIA"],
			["AMD Radeon RX 580 Series (RADV POLARIS10)", "AMD"]]:
		assert_str(GraphicsTier.pick(a[0], a[1], none)).override_failure_message(str(a)).is_equal("high")


func test_flag_and_env_override_the_gpu() -> void:
	var why: Array = []
	assert_str(GraphicsTier.pick("NVIDIA GeForce GTX 1060 6GB", "NVIDIA", PackedStringArray(["--graphics=low"]), "", why)).is_equal("low")
	assert_str(why[0]).is_equal("flag")
	assert_str(GraphicsTier.pick("Mesa Intel(R) HD Graphics 530 (SKL GT2)", "Intel", PackedStringArray(["--graphics=high"]))).is_equal("high")
	assert_str(GraphicsTier.pick("Mesa Intel(R) HD Graphics 530 (SKL GT2)", "Intel", PackedStringArray(), "high")).is_equal("high")
	# the flag beats the env; a bad value is ignored and the GPU decides
	assert_str(GraphicsTier.pick("Intel(R) HD Graphics 530", "Intel", PackedStringArray(["--graphics=high"]), "low")).is_equal("high")
	why.clear()
	assert_str(GraphicsTier.pick("Intel(R) HD Graphics 530", "Intel", PackedStringArray(["--graphics=ultra"]), "", why)).is_equal("low")
	assert_str(why[0]).is_equal("auto")


# ---------------------------------------------------------------- the settings

func test_low_settings_land_on_viewport_environment_sun_and_camera() -> void:
	var vp: SubViewport = auto_free(SubViewport.new())
	var env := Environment.new()
	env.glow_enabled = true
	var sun: DirectionalLight3D = auto_free(DirectionalLight3D.new())
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	var cam: Camera3D = auto_free(Camera3D.new())
	GraphicsTier.apply(GraphicsTier.LOW, vp, env, sun, cam, false)
	assert_int(vp.msaa_3d).is_equal(Viewport.MSAA_DISABLED)
	assert_int(vp.screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_FXAA)
	assert_int(vp.scaling_3d_mode).is_equal(Viewport.SCALING_3D_MODE_FSR)
	assert_float(vp.scaling_3d_scale).is_equal_approx(0.75, 0.001)
	assert_float(vp.mesh_lod_threshold).is_greater(1.0)
	assert_bool(env.glow_enabled).is_false()
	for k in ["ssao_enabled", "ssil_enabled", "ssr_enabled", "sdfgi_enabled", "volumetric_fog_enabled"]:
		assert_bool(env.get(k)).override_failure_message(k).is_false()
	assert_float(env.fog_density).is_greater(0.0016)   # thicker haze hides the shorter draw distance
	assert_int(sun.directional_shadow_mode).is_equal(DirectionalLight3D.SHADOW_ORTHOGONAL)   # one cascade
	assert_float(sun.directional_shadow_max_distance).is_less_equal(20.0)
	assert_float(cam.far).is_less(600.0)
	assert_int(GraphicsTier.particles(70)).is_equal(35)
	var s := GraphicsTier.tier_settings(GraphicsTier.LOW)
	assert_int(int(s.max_fps)).is_equal(60)
	assert_bool(s.vsync).is_true()
	GraphicsTier.apply(GraphicsTier.HIGH, null, null, null, null, false)
	assert_int(GraphicsTier.particles(70)).is_equal(70)


## The look before tiers: project.godot (MSAA 2x, soft shadows medium) and hub.gd's environment and
## sun as they were at dev e765f99. If one of these moves, `high` no longer looks like the hub did.
func test_high_is_pinned_to_the_look_as_it_was() -> void:
	var s := GraphicsTier.tier_settings(GraphicsTier.HIGH)
	var was := {"msaa_3d": 1, "screen_space_aa": 0, "scaling_3d_mode": 0, "scaling_3d_scale": 1.0,
			"mesh_lod_threshold": 1.0, "shadows": true, "shadow_mode": 1, "shadow_max_distance": 36.0,
			"shadow_split_1": 0.3, "shadow_blur": 2.6, "soft_shadow_quality": 3, "shadow_atlas_size": 4096,
			"glow": true, "ssao": false, "ssil": false, "ssr": false, "sdfgi": false, "volumetric_fog": false,
			"fog_density": 0.0016, "camera_far": 600.0, "particle_scale": 1.0, "max_fps": 0, "vsync": true}
	assert_int(s.size()).is_equal(was.size())
	for k: String in was:
		assert_bool(s.has(k)).override_failure_message("high lacks " + k).is_true()
		var same: bool = s.get(k) == was[k] if was[k] is bool else is_equal_approx(float(s.get(k)), float(was[k]))
		assert_bool(same).override_failure_message("%s: %s, was %s" % [k, s.get(k), was[k]]).is_true()
	assert_int(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d"))).is_equal(int(was.msaa_3d))
	assert_int(int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"))).is_equal(int(was.soft_shadow_quality))
	assert_int(int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size"))).is_equal(int(was.shadow_atlas_size))
	# and both tiers carry the same keys, so nothing is left at whatever the last tier set
	assert_array(GraphicsTier.tier_settings(GraphicsTier.LOW).keys()).contains_exactly_in_any_order(s.keys())
	# applied to fresh objects, high is what hub.gd built before
	var vp: SubViewport = auto_free(SubViewport.new())
	var env := Environment.new()
	var sun: DirectionalLight3D = auto_free(DirectionalLight3D.new())
	var cam: Camera3D = auto_free(Camera3D.new())
	GraphicsTier.apply(GraphicsTier.HIGH, vp, env, sun, cam, false)
	assert_int(vp.msaa_3d).is_equal(Viewport.MSAA_2X)
	assert_int(vp.screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_DISABLED)
	assert_float(vp.scaling_3d_scale).is_equal(1.0)
	assert_bool(env.glow_enabled).is_true()
	assert_float(env.fog_density).is_equal_approx(0.0016, 0.000001)
	assert_bool(sun.shadow_enabled).is_true()
	assert_int(sun.directional_shadow_mode).is_equal(DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	assert_float(sun.directional_shadow_max_distance).is_equal(36.0)
	assert_float(sun.shadow_blur).is_equal_approx(2.6, 0.0001)
	assert_float(cam.far).is_equal(600.0)


func test_the_hub_applies_low_to_its_window_and_world() -> void:
	OS.set_environment(GraphicsTier.ENV, "low")
	var hub := await _hub()
	assert_str(hub.graphics_tier).is_equal("low")
	var vp := hub.get_viewport()
	assert_int(vp.msaa_3d).is_equal(Viewport.MSAA_DISABLED)
	assert_int(vp.screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_FXAA)
	assert_int(vp.scaling_3d_mode).is_equal(Viewport.SCALING_3D_MODE_FSR)
	assert_bool(hub.environment.glow_enabled).is_false()
	assert_int(hub.sun_light.directional_shadow_mode).is_equal(DirectionalLight3D.SHADOW_ORTHOGONAL)
	assert_float(hub.camera.far).is_less(600.0)
	var flies := _particles(hub)
	assert_bool(flies.is_empty()).is_false()
	for p in flies:
		assert_int(p.amount).is_less(36)


func test_the_hub_on_high_looks_as_it_was() -> void:
	OS.set_environment(GraphicsTier.ENV, "high")
	var hub := await _hub()
	assert_str(hub.graphics_tier).is_equal("high")
	assert_int(hub.get_viewport().msaa_3d).is_equal(Viewport.MSAA_2X)
	assert_int(hub.get_viewport().scaling_3d_mode).is_equal(Viewport.SCALING_3D_MODE_BILINEAR)
	assert_bool(hub.environment.glow_enabled).is_true()
	assert_float(hub.environment.glow_intensity).is_equal_approx(0.6, 0.0001)
	assert_int(hub.sun_light.directional_shadow_mode).is_equal(DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	assert_float(hub.camera.far).is_equal(600.0)
	var amounts := []
	for p in _particles(hub):
		amounts.append(p.amount)
	assert_array(amounts).contains([70, 36])


# ---------------------------------------------------------------- the bench

func test_bench_stats() -> void:
	var ms := PackedFloat32Array()
	for i in 99:
		ms.append(10.0)
	ms.append(50.0)
	var s := BenchRun.stats(ms)
	assert_float(s.ms).is_equal_approx(10.4, 0.001)
	assert_float(s.avg).is_equal_approx(1000.0 / 10.4, 0.01)
	assert_float(s.low1).is_equal_approx(20.0, 0.001)   # the slowest 1%: the one 50 ms frame
	assert_float(s.max_ms).is_equal(50.0)
	assert_bool(BenchRun.wanted(PackedStringArray(["--bench"]))).is_true()
	assert_bool(BenchRun.wanted(PackedStringArray(["--benchy"]))).is_false()
	assert_float(BenchRun.seconds_from(PackedStringArray(["--bench", "--bench-seconds=6"]))).is_equal(6.0)
	assert_float(BenchRun.seconds_from(PackedStringArray(["--bench"]))).is_equal(60.0)


func test_bench_quits_by_itself_with_the_summary_line() -> void:
	OS.set_environment(GraphicsTier.ENV, "low")
	var hub := await _hub()
	hub._parse_demo(BenchRun.ROUTE)
	var quits := [0]
	var b := BenchRun.new()
	b.quit_fn = func() -> void: quits[0] += 1
	b.warmup = 0.1
	b.setup(hub, 0.6)
	hub.add_child(b)
	var t := 0.0
	while quits[0] == 0 and t < 5.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	assert_int(quits[0]).is_equal(1)
	assert_bool(hub.two_players).is_true()   # the route brought P2 in
	assert_str(b.lines[0]).starts_with("BENCH start tier=low")
	var regex := RegEx.create_from_string("^BENCH avg=[0-9.]+ low1=[0-9.]+ tier=low ")
	assert_object(regex.search(b.summary)).is_not_null()
	assert_str(b.lines[b.lines.size() - 1]).is_equal(b.summary)
	await get_tree().process_frame
	assert_int(quits[0]).is_equal(1)   # once


## launcher-k06-1: `--bench-trace` is opt-in, prints only TRACE lines (the box script greps BENCH) and
## leaves the bench's own lines and maths as they were.
func test_bench_trace_is_opt_in_and_never_touches_the_bench_lines() -> void:
	assert_bool(BenchTrace.wanted(PackedStringArray(["--bench"]))).is_false()
	assert_bool(BenchTrace.wanted(PackedStringArray(["--bench", "--bench-trace"]))).is_true()
	assert_int(BenchTrace.compilations().size()).is_equal(5)
	OS.set_environment(GraphicsTier.ENV, "low")
	var hub := await _hub()
	hub._parse_demo(BenchRun.ROUTE)
	var quits := [0]
	var b := BenchRun.new()
	b.quit_fn = func() -> void: quits[0] += 1
	b.warmup = 0.1
	b.setup(hub, 1.3)
	hub.add_child(b)
	var trace := BenchTrace.new()
	hub.add_child(trace)
	var t := 0.0
	while quits[0] == 0 and t < 6.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	assert_int(quits[0]).is_equal(1)
	assert_str(trace.lines[0]).starts_with("TRACE start pso=")
	var seconds := 0
	for line in trace.lines:
		assert_str(line).starts_with("TRACE ")
		assert_bool(line.contains("BENCH")).is_false()
		if line.begins_with("TRACE s="):
			seconds += 1
			assert_object(RegEx.create_from_string("process_max_ms=[0-9.]+ pso=\\+[0-9]+ \\(canvas [0-9]+ mesh "
					+ "[0-9]+ surface [0-9]+ draw [0-9]+ spec [0-9]+\\) draws=").search(line)).is_not_null()
	assert_int(seconds).is_greater_equal(1)
	for line in b.lines:
		assert_str(line).starts_with("BENCH ")
	assert_object(RegEx.create_from_string("^BENCH avg=[0-9.]+ low1=[0-9.]+ tier=low ").search(b.summary)).is_not_null()


func _hub() -> Node3D:
	OS.set_environment("OPENJAR_ROOT", ProjectSettings.globalize_path("res://tests/fixtures/hub_8"))
	var hub: Node3D = auto_free(load(HUB).instantiate())
	hub.really_quit = false
	add_child(hub)
	await get_tree().process_frame
	return hub


func _particles(at: Node) -> Array:
	var out := []
	if at is CPUParticles3D:
		out.append(at)
	for c in at.get_children():
		out.append_array(_particles(c))
	return out
