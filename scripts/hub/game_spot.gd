## One installed game in the hub: a giant glass jar on a plinth with the game's card glowing inside.
## A game without card art gets a bright toy shape instead; an empty hub gets one sleepy empty jar.
## When a Jarling stands in front, the lid lifts, light pours out and the pad takes that player's colour.
class_name GameSpot
extends Node3D

const GLASS_SHADER := preload("res://assets/shaders/hub/jar_glass.gdshader")
const BEAM_SHADER := preload("res://assets/shaders/hub/beam.gdshader")
const JAR_HEIGHT := 3.0
const JAR_RADIUS := 1.05
const PLINTH_HEIGHT := 0.3
const LID_REST := PLINTH_HEIGHT + JAR_HEIGHT + 0.06
const LID_LIFT := 0.75
const TOY_COUNT := 5
const DEV_LID := Color("3a3f5c")
## Bright jar colours for games without art, picked by slug so a game keeps its colour.
const TOY_COLORS := [Color("ffd23f"), Color("35b6ff"), Color("ff7ac8"), Color("5ef0c0"), Color("ff8a3d"), Color("a78bff")]

var entry: Dictionary = {}
var empty := true
var index := 0
var accent := Color("8fe3ff")
var toy_index := -1            # 0..TOY_COUNT-1 when the jar shows a toy shape, -1 when it shows card art
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
var _clock := 0.0
var _tween: Tween

static var _jar_mesh: ArrayMesh


func setup(e: Dictionary, i: int = 0, previous_toy: int = -1) -> void:
	entry = e
	empty = e.is_empty()
	index = i
	var art: Texture2D = null
	if not empty:
		art = _load_art(e.get("grid", ""))
		var h: int = absi(String(e.get("slug", "")).hash())
		if art == null:
			toy_index = h % TOY_COUNT
			if toy_index == previous_toy:
				toy_index = (toy_index + 1) % TOY_COUNT
			accent = TOY_COLORS[h % TOY_COLORS.size()]
	_build(art)
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
	_squash([Vector3(1.14, 0.84, 1.14), Vector3(0.93, 1.12, 0.93), Vector3.ONE], [0.09, 0.12, 0.2])


## "Nothing in here": a side-to-side shake with a little squash.
func wobble() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_jar, "scale", Vector3(1.06, 0.94, 1.06), 0.06)
	for a in [0.12, -0.1, 0.07, -0.04, 0.0]:
		_tween.tween_property(_jar, "rotation:z", a, 0.07)
	_tween.parallel().tween_property(_jar, "scale", Vector3.ONE, 0.1)


## The launch flourish; await the returned tween's `finished`.
func launch_flash() -> Tween:
	_squash([Vector3(1.2, 0.8, 1.2), Vector3(0.88, 1.2, 0.88), Vector3(1.05, 1.05, 1.05)], [0.1, 0.16, 0.5])
	_lit = 2.2
	return _tween


## Where a Jarling ends up when it jumps in (global).
func mouth_position() -> Vector3:
	return global_position + Vector3(0, PLINTH_HEIGHT + JAR_HEIGHT * 0.45, 0)


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
	_lit = lerpf(_lit, want, 1.0 - exp(-delta * 9.0))
	var k := clampf(_lit, 0.0, 1.0)
	_glass.set_shader_parameter("lit", _lit)
	_beam.set_shader_parameter("strength", _lit * 1.1)
	_lid.position.y = LID_REST + LID_LIFT * k + sin(_clock * 2.3) * 0.06 * k
	_lid.rotation.z = -0.3 * k + sin(_clock * 1.7) * 0.05 * k
	_lid.position.x = 0.35 * k
	_light.light_energy = (0.25 if empty else 1.5) + _lit * 2.2
	_inside.position.y = PLINTH_HEIGHT + 1.48 + sin(_clock * 1.1) * 0.07
	if toy_index >= 0:
		_inside.rotation.y = _clock * 0.9
	else:
		_inside.rotation.y = sin(_clock * 0.6) * 0.22
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


func _build(art: Texture2D) -> void:
	if art != null:
		accent = accent_from(art)
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

	_inside = Node3D.new()
	add_child(_inside)
	_inside.position.y = PLINTH_HEIGHT + 1.48
	if art != null:
		var card := QuadMesh.new()
		card.size = Vector2(1.24, 1.86)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.BLACK
		m.emission_enabled = true
		m.emission_texture = art
		m.emission_energy_multiplier = 1.25
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_mesh(_inside, card, m, Vector3(0, 0, 0.012))
		var frame := BoxMesh.new()
		frame.size = Vector3(1.38, 2.0, 0.02)
		_mesh(_inside, frame, _glow(Color.WHITE, 0.9), Vector3.ZERO)
	elif not empty:
		_mesh(_inside, toy_mesh(toy_index), _glow(accent.lightened(0.15), 1.3), Vector3.ZERO)

	_lid = Node3D.new()
	add_child(_lid)   # not under _jar: the lid moves on its own while the jar squashes
	_lid.position.y = LID_REST
	var lid_color := DEV_LID if dev else accent.darkened(0.12)
	var lid_mat := _flat(lid_color)
	lid_mat.metallic = 0.5
	lid_mat.roughness = 0.35
	_mesh(_lid, _cyl(0.86, 0.86, 0.3), lid_mat, Vector3(0, 0.15, 0))
	_mesh(_lid, _cyl(0.6, 0.78, 0.1), lid_mat, Vector3(0, 0.34, 0))
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


## Big friendly toy shapes for games that have no card art yet.
static func toy_mesh(i: int) -> Mesh:
	match i:
		0:
			var s := SphereMesh.new()
			s.radius = 0.62
			s.height = 1.24
			return s
		1:
			var t := TorusMesh.new()
			t.inner_radius = 0.3
			t.outer_radius = 0.68
			return t
		2:
			var p := PrismMesh.new()
			p.size = Vector3(1.15, 1.1, 0.5)
			return p
		3:
			var b := BoxMesh.new()
			b.size = Vector3(0.9, 0.9, 0.9)
			return b
	var c := CapsuleMesh.new()
	c.radius = 0.38
	c.height = 1.3
	return c


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
