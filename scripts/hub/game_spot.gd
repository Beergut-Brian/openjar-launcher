## One installed game in the hub: a giant glass jar on a plinth with a tiny world inside (JarWorld):
## the game's own `jar` scene, or a generated diorama in the game's colours. 0 games: one sleepy jar.
## When a Jarling stands in front, the lid lifts, light pours out and the pad takes that player's colour.
## On launch the hub poses the jar and its lid from the LaunchSequence clock (launch_pose).
class_name GameSpot
extends Node3D

const GLASS_SHADER := preload("res://assets/shaders/hub/jar_glass.gdshader")
const BEAM_SHADER := preload("res://assets/shaders/hub/beam.gdshader")
const JAR_HEIGHT := 3.0
const JAR_RADIUS := 1.05
const PLINTH_HEIGHT := 0.3
const LID_REST := PLINTH_HEIGHT + JAR_HEIGHT + 0.06
const LID_LIFT := 0.75
const WORLD_SCALE := 1.05    # generated and fitted worlds are authored for a slightly smaller jar
const LID_HAT_SCALE := 0.62   # the flown-off lid shrinks a little so it sits on a Jarling like a hat
## A dev build's lid: charcoal, nearly matte, so the magic-hour sky doesn't turn it blue-grey (C-07).
const DEV_LID := Color("1c1d24")
## Bright jar colours for games without art, picked by slug so a game keeps its colour.
const TOY_COLORS := [Color("ffd23f"), Color("35b6ff"), Color("ff7ac8"), Color("5ef0c0"), Color("ff8a3d"), Color("a78bff")]

var entry: Dictionary = {}
var empty := true
var index := 0
var accent := Color("8fe3ff")
var custom_world := false      # the game shipped its own jar world and it loaded
var world_kind := -1           # JarWorld.Kind of the generated world, -1 for a custom or empty jar
var highlighted := false
var stand_point := Vector3.ZERO   # global, where a Jarling stands

var _jar: Node3D            # everything that squashes and stretches
var _glass: ShaderMaterial
var _beam: ShaderMaterial
var _lid: Node3D
var _inside: Node3D
var _light: OmniLight3D
var _pad: MeshInstance3D
var _pad_mat: StandardMaterial3D
var _lit := 0.0
var _lit_boost := 0.0       # extra glow asked for by the launch pose
var _calm := 0.0            # 0..1: the glow settles as the camera dives in, so the tiny world is not washed out
var _posed := false         # the hub is posing jar and lid (launch), or the lid is dropping back on
var _sparkles: CPUParticles3D
var _clock := 0.0
var _tween: Tween

var _bobbers: Array[Node3D] = []

static var _jar_mesh: ArrayMesh


## `kind` is the generated world to use if the game ships none (JarWorld.assign keeps neighbours apart).
func setup(e: Dictionary, i: int = 0, kind: int = -1) -> void:
	entry = e
	empty = e.is_empty()
	index = i
	var art: Texture2D = null
	var world: Node3D = null
	if empty:
		world = JarWorld.build_sleepy()
	else:
		art = _load_art(e.get("grid", ""))
		var slug := String(e.get("slug", ""))
		accent = accent_from(art) if art != null else TOY_COLORS[absi(slug.hash()) % TOY_COLORS.size()]
		accent = off_players(accent)   # V-08: green and red belong to the players
		world = JarWorld.load_custom(e.get("jar", ""))
		custom_world = world != null
		if world == null:
			world_kind = kind if kind >= 0 else JarWorld.kind_for(slug)
			world = JarWorld.build(world_kind, accent)
	_build(world, null if custom_world else art)
	_clock = i * 1.7


func set_highlighted(on: bool, color: Color = Color.WHITE) -> void:
	if on:
		_pad_mat.albedo_color = color
		_pad_mat.emission = color
	if on == highlighted:
		return
	highlighted = on
	if on and not empty:
		bounce()


## Squash, stretch, settle: the jar noticed you.
func bounce() -> void:
	if not _posed:
		_squash([Vector3(1.14, 0.84, 1.14), Vector3(0.93, 1.12, 0.93), Vector3.ONE], [0.09, 0.12, 0.2])


## "Nothing in here": a side-to-side shake with a little squash.
func wobble() -> void:
	if _posed:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_jar, "scale", Vector3(1.06, 0.94, 1.06), 0.06)
	for a in [0.12, -0.1, 0.07, -0.04, 0.0]:
		_tween.tween_property(_jar, "rotation:z", a, 0.07)
	_tween.parallel().tween_property(_jar, "scale", Vector3.ONE, 0.1)


## The launch animation at LaunchSequence time t; the hub calls this every frame of it.
## Rattle with the lid clamped down, then the lid spins off in an arc to `lid_target` (global) and
## wobbles to rest there like a dropped coin, the jar stretches, and gulps when the Jarling lands.
func launch_pose(t: float, lid_target: Vector3) -> void:
	if _tween:
		_tween.kill()
	_posed = true
	var L := LaunchSequence
	var build := L.phase(t, 0.0, L.T_POP)
	var y := 1.0 - 0.1 * build
	var shake := build * build
	if t >= L.T_POP:
		var u := t - L.T_POP
		y = 1.0 + 0.2 * exp(-u * 6.0) * cos(u * 17.0)
		shake = exp(-u * 10.0)
	if t >= L.T_DIVE:
		var u := t - L.T_DIVE
		y -= 0.16 * exp(-u * 7.0) * cos(u * 19.0)
	_jar.scale = Vector3(1.0 / sqrt(y), y, 1.0 / sqrt(y))
	_jar.rotation.z = sin(t * 46.0) * 0.06 * shake
	_lit_boost = 1.6 * build + (0.5 if t >= L.T_SPLASH else 0.0)
	_calm = L.smooth(L.phase(t, L.T_SPLASH, L.T_DIVE + 0.25))
	if t < L.T_POP:
		var down := L.smooth(L.phase(t, 0.0, 0.14))
		var shut := Vector3(0, LID_REST - JAR_HEIGHT * (1.0 - y) + absf(sin(t * 46.0)) * 0.07 * build, 0)
		_lid.position = _lid.position.lerp(shut, down)
		_lid.rotation = Vector3(0, 0, lerpf(_lid.rotation.z, sin(t * 52.0) * 0.08 * build, down))
		_lid.scale = Vector3.ONE
		return
	var k := L.phase(t, L.T_POP, L.T_LID_LAND)
	var p := Vector3(0, LID_REST, 0).lerp(to_local(lid_target), k)
	p.y += sin(k * PI) * 3.2
	var rest := maxf(t - L.T_LID_LAND, 0.0)
	p.y += absf(sin(rest * 15.0)) * 0.22 * exp(-rest * 6.0)
	_lid.position = p
	_lid.rotation = Vector3(TAU * 2.0 * k, TAU * k, sin(rest * 21.0) * 0.3 * exp(-rest * 5.0))
	_lid.scale = Vector3.ONE * lerpf(1.0, LID_HAT_SCALE, k)


## Sparkles out of the jar mouth: a Jarling just went in or came out.
func splash() -> void:
	_sparkles.restart()
	_lit = 3.2


## Back from a game: the lid falls out of the sky, spinning, and lands on the jar with a bonk.
func drop_lid(delay: float = 0.0) -> void:
	if _tween:
		_tween.kill()
	_posed = true
	_lit_boost = 0.0
	_calm = 0.0
	_jar.scale = Vector3.ONE
	_jar.rotation.z = 0.0
	_lid.scale = Vector3.ONE
	_lid.position = Vector3(0, LID_REST + 9.0, 0)
	_lid.rotation = Vector3(TAU * 1.5, 0, 0)
	_tween = create_tween()
	_tween.tween_interval(delay)
	_tween.tween_property(_lid, "position:y", LID_REST, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_lid, "rotation:x", 0.0, 0.42)
	_tween.tween_callback(func() -> void:
		Audio.play("lid_bonk")
		_lit = 0.0)   # so the lid sits shut for a moment before it lifts again
	for sc: Vector3 in [Vector3(1.16, 0.8, 1.16), Vector3(0.93, 1.12, 0.93), Vector3.ONE]:
		_tween.tween_property(_jar, "scale", sc, 0.1).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void: _posed = false)


## The jar's mouth (global): Jarlings go in and come out here.
func mouth_position() -> Vector3:
	return global_position + Vector3(0, PLINTH_HEIGHT + JAR_HEIGHT, 0)


## Where a tiny Jarling stands inside the jar's world (global): front of the floor, a little aside.
func inside_position() -> Vector3:
	return to_global(Vector3(0.34, PLINTH_HEIGHT + 0.26, 0.4))


func _squash(scales: Array, times: Array) -> void:
	if _tween:
		_tween.kill()
	_jar.rotation.z = 0.0
	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	for k in scales.size():
		_tween.tween_property(_jar, "scale", scales[k], times[k])


func _process(delta: float) -> void:
	_clock += delta
	var want := 1.0 if highlighted and not empty else 0.0
	_lit = lerpf(_lit, want + (_lit_boost if _posed else 0.0), 1.0 - exp(-delta * 9.0))
	var k := clampf(_lit, 0.0, 1.0)
	var calm := _calm if _posed else 0.0
	_glass.set_shader_parameter("lit", _lit * (1.0 - calm))
	_beam.set_shader_parameter("strength", _lit * 1.1 * (1.0 - calm))
	if not _posed:
		_lid.position = Vector3(0.35 * k, LID_REST + LID_LIFT * k + sin(_clock * 2.3) * 0.06 * k, 0)
		_lid.rotation = Vector3(0, 0, -0.3 * k + sin(_clock * 1.7) * 0.05 * k)
	_light.light_energy = lerpf((0.25 if empty else 1.2) + _lit * 1.2, 0.7, calm)
	_inside.rotation.y += delta * (0.2 + 0.5 * k)   # a slow turntable, a bit keener when looked at
	for b in _bobbers:
		b.position.y += sin(_clock * TAU / float(b.get_meta("bob"))) * 0.12 * delta
	_pad.visible = highlighted
	_pad.scale = Vector3.ONE * (1.0 + sin(_clock * 5.0) * 0.05)


static func _load_art(path: String) -> Texture2D:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Green and red belong to the players (P1 green, P2 red): a saturated jar colour whose hue sits within
## the player's hue gap of either is turned just far enough away (red goes orange or pink, green goes
## lime or teal), so a jar never looks like it belongs to a player. Greys and pastels pass untouched.
## The toy mint stays as it is; the toy orange moves a hair further from red.
const PLAYER_HUE_GAP := 0.08
const GREEN_HUE_GAP := 0.09


static func hue_gap(player: int) -> float:
	return GREEN_HUE_GAP if player == Players.P1 else PLAYER_HUE_GAP


static func off_players(c: Color) -> Color:
	if c.s < 0.3:
		return c
	var h := c.h
	for p: int in Players.COLOR:
		var pc: Color = Players.COLOR[p]
		var gap := hue_gap(p)
		var d := wrapf(h - pc.h, -0.5, 0.5)
		if absf(d) < gap:
			# already leaning off it: keep going that way; dead on: red goes pink, green goes lime
			var side := signf(d) if absf(d) > gap * 0.5 else -1.0
			h = wrapf(pc.h + gap * side, 0.0, 1.0)
	return Color.from_hsv(h, c.s, c.v, c.a)


## The art's average colour, pushed bright and saturated, lights the jar and the ground round it.
static func accent_from(tex: Texture2D) -> Color:
	var img := tex.get_image()
	img.resize(4, 4, Image.INTERPOLATE_LANCZOS)
	var sum := Color(0, 0, 0)
	for y in 4:
		for x in 4:
			sum += img.get_pixel(x, y)
	var c := sum / 16.0
	return Color.from_hsv(c.h, clampf(c.s * 1.3 + 0.15, 0.45, 0.85), 1.0)


func _build(world: Node3D, art: Texture2D) -> void:
	var dev: bool = entry.get("dev", false)
	_mesh(self, _cyl(1.45, 1.6, PLINTH_HEIGHT), _flat(Color("d9c2b0")), Vector3(0, PLINTH_HEIGHT * 0.5, 0))
	_jar = Node3D.new()
	add_child(_jar)
	_jar.position.y = PLINTH_HEIGHT

	_glass = ShaderMaterial.new()
	_glass.shader = GLASS_SHADER
	_glass.set_shader_parameter("tint", accent)
	var glass := _mesh(_jar, jar_mesh(), _glass, Vector3.ZERO)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a glowing floor inside the jar
	_mesh(_jar, _cyl(0.92, 0.92, 0.08), _glow(accent, 1.6), Vector3(0, 0.1, 0))

	_inside = Node3D.new()   # the turntable the tiny world stands on; squashes with the jar
	_jar.add_child(_inside)
	_inside.position.y = 0.16
	_inside.scale = Vector3.ONE * WORLD_SCALE
	_inside.add_child(world)
	for n in world.get_children():
		if n.has_meta("bob"):
			_bobbers.append(n)
	if art != null:   # no jar world from the game: its poster hangs at the back as a small backdrop
		var card := QuadMesh.new()
		card.size = Vector2(0.84, 1.26)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.BLACK
		m.emission_enabled = true
		m.emission_texture = art
		m.emission_energy_multiplier = 0.9
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_mesh(_jar, card, m, Vector3(0, 1.42, -0.62))

	_lid = Node3D.new()
	add_child(_lid)   # not under _jar: the lid moves on its own while the jar squashes
	_lid.position.y = LID_REST
	var lid_color := DEV_LID if dev else accent.darkened(0.12)
	var lid_mat := _flat(lid_color)
	lid_mat.metallic = 0.15 if dev else 0.5
	lid_mat.roughness = 0.7 if dev else 0.35
	_mesh(_lid, _cyl(0.86, 0.86, 0.3), lid_mat, Vector3(0, 0.15, 0))
	_mesh(_lid, _cyl(0.6, 0.78, 0.1), lid_mat, Vector3(0, 0.34, 0))
	var knob := SphereMesh.new()   # so a spinning lid reads as spinning
	knob.radius = 0.17
	knob.height = 0.26
	_mesh(_lid, knob, _flat(Color("fff3dc")), Vector3(0, 0.43, 0))
	if dev:   # dev builds: a dark lid with a little glowing beacon, no text needed
		_mesh(_lid, _cyl(0.04, 0.04, 0.5), _flat(Color("c9cde0")), Vector3(0, 0.62, 0))
		var bulb := SphereMesh.new()
		bulb.radius = 0.14
		bulb.height = 0.28
		_mesh(_lid, bulb, _glow(Color("ffd23f"), 3.0), Vector3(0, 0.92, 0))

	_beam = ShaderMaterial.new()
	_beam.shader = BEAM_SHADER
	_beam.set_shader_parameter("tint", accent.lightened(0.3))
	var cone := CylinderMesh.new()
	cone.top_radius = 1.9
	cone.bottom_radius = 0.7
	cone.height = 7.0
	cone.cap_top = false
	cone.cap_bottom = false
	var beam := _mesh(self, cone, _beam, Vector3(0, PLINTH_HEIGHT + JAR_HEIGHT + 3.4, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_light = OmniLight3D.new()
	_light.light_color = accent
	_light.omni_range = 7.0
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = false
	add_child(_light)
	_light.position = Vector3(0, PLINTH_HEIGHT + 1.3, 0)

	_sparkles = CPUParticles3D.new()
	_sparkles.emitting = false
	_sparkles.one_shot = true
	_sparkles.amount = 36
	_sparkles.lifetime = 0.9
	_sparkles.explosiveness = 0.92
	_sparkles.direction = Vector3.UP
	_sparkles.spread = 38.0
	_sparkles.initial_velocity_min = 3.5
	_sparkles.initial_velocity_max = 7.0
	_sparkles.gravity = Vector3(0, -9.0, 0)
	_sparkles.scale_amount_min = 0.5
	_sparkles.scale_amount_max = 1.2
	var fade := Curve.new()
	fade.add_point(Vector2(0, 1))
	fade.add_point(Vector2(1, 0))
	_sparkles.scale_amount_curve = fade
	var spark := SphereMesh.new()
	spark.radius = 0.09
	spark.height = 0.18
	spark.radial_segments = 8
	spark.rings = 4
	spark.material = _glow(accent.lerp(Color.WHITE, 0.55), 3.0)
	_sparkles.mesh = spark
	_sparkles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparkles)
	_sparkles.position = Vector3(0, PLINTH_HEIGHT + JAR_HEIGHT, 0)

	var ring := TorusMesh.new()
	ring.inner_radius = 0.62
	ring.outer_radius = 0.82
	_pad_mat = _glow(Color.WHITE, 2.2)
	_pad = MeshInstance3D.new()
	_pad.mesh = ring
	_pad.material_override = _pad_mat
	_pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pad.top_level = true
	_pad.visible = false
	add_child(_pad)


func place(pos: Vector3, stand: Vector3) -> void:
	position = pos
	rotation.y = atan2(stand.x - pos.x, stand.z - pos.z)   # the card faces the stand point
	stand_point = stand
	_pad.transform = Transform3D(Basis.from_scale(Vector3(1, 0.12, 1)), stand + Vector3(0, 0.03, 0))


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _cyl(top: float, bottom: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = 32
	return c


static func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	return m


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## Jar silhouette spun round the Y axis: straight sides, round shoulder, short neck, lip.
static func jar_mesh() -> ArrayMesh:
	if _jar_mesh != null:
		return _jar_mesh
	var profile := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.9, 0.0), Vector2(1.02, 0.06), Vector2(JAR_RADIUS, 0.2),
		Vector2(JAR_RADIUS, 2.1), Vector2(1.01, 2.34), Vector2(0.9, 2.54), Vector2(0.78, 2.66),
		Vector2(0.76, 2.9), Vector2(0.82, 2.94), Vector2(0.82, JAR_HEIGHT), Vector2(0.7, JAR_HEIGHT)])
	var seg := 40
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for i in profile.size() - 1:
		for s in seg:
			var quad := [[i, s], [i + 1, s], [i + 1, s + 1], [i, s], [i + 1, s + 1], [i, s + 1]]
			for q: Array in quad:
				var p: Vector2 = profile[q[0]]
				var a: float = TAU * q[1] / seg
				st.set_uv(Vector2(float(q[1]) / seg, p.y / JAR_HEIGHT))
				st.add_vertex(Vector3(cos(a) * p.x, p.y, -sin(a) * p.x))
	st.generate_normals()
	_jar_mesh = st.commit()
	return _jar_mesh
