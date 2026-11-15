## Graphics tiers (launcher-igpu-1, 2026-11-14). The TV box today is an Intel HD Graphics 530 (Skylake
## GT2, Mesa ANV); a GTX 1060 may go in later. `high` is the hub's look as it always was; `low` is the
## same picture made cheap enough for the HD 530 (no MSAA but FXAA, 0.75 render scale with FSR 1, one
## short shadow cascade, no glow, shorter draw distance hidden in thicker fog, half the particles, 60 fps
## cap, vsync). The values live in data/graphics.json; tests/test_graphics_tier.gd pins `high`.
##
## Pick, in order: `--graphics=low|high` on the command line, OPENJAR_GRAPHICS=low|high, then the GPU:
## NVIDIA or a discrete AMD card is `high`, anything else (Intel integrated, an AMD APU, llvmpipe, an
## adapter we don't know) is `low`.
class_name GraphicsTier
extends RefCounted

const DATA := "res://data/graphics.json"
const HIGH := "high"
const LOW := "low"
const FLAG := "--graphics="
const ENV := "OPENJAR_GRAPHICS"

## The tier in force (set by apply()); spots and particles built later read it through particles().
static var current := HIGH
static var settings: Dictionary = {}


## The tier for this adapter and these args. `why` (if given) gets a short reason for the log.
static func pick(adapter: String, vendor: String, args: PackedStringArray, env: String = "", why: Array = []) -> String:
	for a in args:
		if a.begins_with(FLAG):
			var t := a.trim_prefix(FLAG).strip_edges().to_lower()
			if t == HIGH or t == LOW:
				why.append("flag")
				return t
	var e := env.strip_edges().to_lower()
	if e == HIGH or e == LOW:
		why.append(ENV)
		return e
	why.append("auto")
	return LOW if is_weak_gpu(adapter, vendor) else HIGH


## True for everything that is not an NVIDIA or a discrete AMD card.
static func is_weak_gpu(adapter: String, vendor: String) -> bool:
	var s := (adapter + " " + vendor).to_lower()
	if s.contains("llvmpipe") or s.contains("swiftshader") or s.contains("software"):
		return true
	if s.contains("nvidia") or s.contains("geforce") or s.contains("quadro"):
		return false
	if s.contains("amd") or s.contains("radeon") or s.contains("ati "):
		# discrete Radeons name a family; the APUs say "Radeon(TM) Graphics", "Vega 8", "780M" ...
		for d in ["radeon rx", "rx ", "radeon pro", "r9 ", "r7 ", "radeon vii", "firepro"]:
			if s.contains(d):
				return false
		return true
	return true


static func load_tiers(path: String = DATA) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("graphics: no %s" % path)
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func tier_settings(tier: String, path: String = DATA) -> Dictionary:
	return load_tiers(path).get(tier, {})


## Applies `tier` to the viewport, environment, sun and camera given (any may be null), and to the
## engine (frame cap, vsync, the shadow atlas and filter). Returns the settings used.
static func apply(tier: String, viewport: Viewport, env: Environment, sun: DirectionalLight3D,
		camera: Camera3D, engine_wide: bool = true) -> Dictionary:
	var s := tier_settings(tier)
	if s.is_empty():
		push_warning("graphics: no settings for tier %s; leaving everything as it is" % tier)
		return s
	current = tier
	settings = s
	if viewport:
		viewport.msaa_3d = int(s.msaa_3d) as Viewport.MSAA
		viewport.screen_space_aa = int(s.screen_space_aa) as Viewport.ScreenSpaceAA
		viewport.scaling_3d_mode = int(s.scaling_3d_mode) as Viewport.Scaling3DMode
		viewport.scaling_3d_scale = float(s.scaling_3d_scale)
		viewport.mesh_lod_threshold = float(s.mesh_lod_threshold)
	if env:
		env.glow_enabled = bool(s.glow)
		env.ssao_enabled = bool(s.ssao)
		env.ssil_enabled = bool(s.ssil)
		env.ssr_enabled = bool(s.ssr)
		env.sdfgi_enabled = bool(s.sdfgi)
		env.volumetric_fog_enabled = bool(s.volumetric_fog)
		env.fog_density = float(s.fog_density)
	if sun:
		sun.shadow_enabled = bool(s.shadows)
		sun.directional_shadow_mode = int(s.shadow_mode) as DirectionalLight3D.ShadowMode
		sun.directional_shadow_max_distance = float(s.shadow_max_distance)
		sun.directional_shadow_split_1 = float(s.shadow_split_1)
		sun.shadow_blur = float(s.shadow_blur)
	if camera:
		camera.far = float(s.camera_far)
	if engine_wide:
		Engine.max_fps = int(s.max_fps)
		if DisplayServer.get_name() != "headless":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(s.vsync) else DisplayServer.VSYNC_DISABLED)
		RenderingServer.directional_soft_shadow_filter_set_quality(int(s.soft_shadow_quality) as RenderingServer.ShadowQuality)
		RenderingServer.directional_shadow_atlas_set_size(int(s.shadow_atlas_size), true)
	return s


## A particle count for the tier in force: `base` on high, scaled down (never below 1) on low.
static func particles(base: int) -> int:
	return maxi(1, roundi(base * float(settings.get("particle_scale", 1.0))))


## The adapter as the log and the bench print it.
static func adapter_text() -> String:
	return "%s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()]
