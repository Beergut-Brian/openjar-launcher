## Builds the hub's scenery from primitives: the floating island, trees, string lights, far islands,
## the cloud sea, drifting clouds and fireflies. Everything is original and made in code; the only
## textures in the hub are the games' own card art and the Jarlings' faces.
class_name HubWorld
extends RefCounted

const GROUND_SHADER := preload("res://assets/shaders/hub/ground.gdshader")
const CLOUD_SHADER := preload("res://assets/shaders/hub/cloud_sea.gdshader")
const ISLAND_RADIUS := 12.6
const LEAF := [Color("2f9e5a"), Color("45b85c"), Color("6fce52"), Color("38a86e")]
const BULBS := [Color("ffd23f"), Color("ff7ac8"), Color("5ef0c0"), Color("35b6ff"), Color("ff8a3d")]


static func build(root: Node3D) -> void:
	_island(root)
	_trees(root)
	_string_lights(root)
	_far_islands(root)
	_clouds(root)
	_fireflies(root)


static func _island(root: Node3D) -> void:
	var ground := ShaderMaterial.new()
	ground.shader = GROUND_SHADER
	var top := _cyl(ISLAND_RADIUS, ISLAND_RADIUS, 0.6, 64)
	_add(root, top, ground, Vector3(0, -0.3, 0))
	_add(root, _cyl(ISLAND_RADIUS + 0.25, ISLAND_RADIUS - 0.6, 0.9, 64), _flat(Color("3f9a4f")), Vector3(0, -0.75, 0))
	_add(root, _cyl(ISLAND_RADIUS - 0.5, 6.5, 4.0, 24), _flat(Color("8a5a6e")), Vector3(0, -3.1, 0))
	_add(root, _cyl(6.5, 1.2, 6.0, 16), _flat(Color("6e4868")), Vector3(0, -8.0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 9:   # boulders round the rim so the edge is not a ruler line
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.4, 0.8)
		_add(root, _sphere(r), _flat(Color("d6b8a8")), Vector3(sin(a), 0, cos(a)) * (ISLAND_RADIUS - 0.4) + Vector3(0, r * 0.2, 0))


static func _tree(root: Node3D, pos: Vector3, size: float, tint: int) -> void:
	var t := Node3D.new()
	root.add_child(t)
	t.position = pos
	_add(t, _cyl(0.16 * size, 0.24 * size, 1.8 * size, 10), _flat(Color("8a5a3c")), Vector3(0, 0.9 * size, 0))
	var blobs := [[Vector3(0, 2.5, 0), 1.25], [Vector3(0.7, 3.2, 0.2), 0.9], [Vector3(-0.6, 3.4, -0.2), 0.8], [Vector3(0.1, 4.0, 0.1), 0.7]]
	for k in blobs.size():
		_add(t, _sphere(blobs[k][1] * size), _flat(LEAF[(tint + k) % LEAF.size()]), blobs[k][0] * size)


static func _trees(root: Node3D) -> void:
	# behind the jars and out to the sides, never between the camera and the plaza
	var spots := [[-78.0, 11.3, 1.25], [-52.0, 11.6, 1.0], [-27.0, 11.4, 1.35], [-4.0, 11.7, 1.1], [18.0, 11.5, 1.3],
			[44.0, 11.4, 1.0], [70.0, 11.5, 1.2], [-102.0, 10.6, 0.9], [96.0, 10.8, 0.95]]
	for i in spots.size():
		_tree(root, HubLayout.on_arc(deg_to_rad(spots[i][0]), spots[i][1]), spots[i][2], i)


## Posts behind the jars with sagging strings of coloured bulbs: one MultiMesh for every bulb.
static func _string_lights(root: Node3D) -> void:
	var posts := 8
	var radius := 10.3
	var height := 4.6
	var pts: Array[Vector3] = []
	for i in posts:
		var a := deg_to_rad(-91.0 + 182.0 * i / (posts - 1))
		var p := HubLayout.on_arc(a, radius)
		pts.append(p + Vector3(0, height, 0))
		_add(root, _cyl(0.07, 0.1, height, 8), _flat(Color("f4ead8")), p + Vector3(0, height * 0.5, 0))
	var per := 9
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _sphere(0.11, 8)
	mm.instance_count = (posts - 1) * per
	var n := 0
	for i in posts - 1:
		for k in per:
			var t := (k + 0.5) / per
			var p := pts[i].lerp(pts[i + 1], t) - Vector3(0, sin(t * PI) * 0.9, 0)
			mm.set_instance_transform(n, Transform3D(Basis(), p))
			mm.set_instance_color(n, BULBS[n % BULBS.size()])
			n += 1
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(2.2, 2.2, 2.2)   # over 1.0 so the bulbs bloom
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## Little islands hanging in the haze, each with a tree and a tiny glowing jar: more worlds out there.
static func _far_islands(root: Node3D) -> void:
	var defs := [[Vector3(-34, 3, -52), 4.5], [Vector3(30, -2, -44), 3.6], [Vector3(-62, 9, -95), 7.0],
			[Vector3(70, 6, -110), 8.0], [Vector3(8, 12, -140), 9.0], [Vector3(-22, -4, -30), 2.4], [Vector3(47, 10, -70), 3.0]]
	for i in defs.size():
		var isl := Node3D.new()
		root.add_child(isl)
		isl.position = defs[i][0]
		isl.add_to_group("hub_bob")
		var r: float = defs[i][1]
		_add(isl, _cyl(r, r * 0.85, r * 0.25, 20), _flat(Color("4bb05a")), Vector3.ZERO)
		_add(isl, _cyl(r * 0.85, r * 0.1, r * 1.3, 12), _flat(Color("7c5270")), Vector3(0, -r * 0.77, 0))
		_tree(isl, Vector3(-r * 0.35, r * 0.1, 0), r * 0.3, i)
		var glow := GameSpot._glow(BULBS[i % BULBS.size()], 3.0)
		var jar := _cyl(r * 0.16, r * 0.18, r * 0.5, 12)
		_add(isl, jar, glow, Vector3(r * 0.35, r * 0.38, 0))


static func _clouds(root: Node3D) -> void:
	var sea_mat := ShaderMaterial.new()
	sea_mat.shader = CLOUD_SHADER
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	_add(root, plane, sea_mat, Vector3(0, -11, -60))
	var puff := StandardMaterial3D.new()
	puff.albedo_color = Color("fff1ea")
	puff.roughness = 1.0
	puff.emission_enabled = true
	puff.emission = Color("b88ad0")   # lifts the shadow side to lilac instead of grey
	puff.emission_energy_multiplier = 0.45
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 11:
		var c := Node3D.new()
		root.add_child(c)
		var a := deg_to_rad(rng.randf_range(-80.0, 80.0))
		var d := rng.randf_range(38.0, 130.0)
		c.position = Vector3(sin(a) * d, rng.randf_range(-7.0, 16.0), -cos(a) * d)
		c.add_to_group("hub_drift")
		var s := d * 0.07
		for k in 5:
			var b := _add(c, _sphere(s * rng.randf_range(0.7, 1.3), 16), puff, Vector3((k - 2) * s * 1.1, rng.randf_range(-0.2, 0.3) * s, rng.randf_range(-0.5, 0.5) * s))
			b.scale.y = 0.62
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _fireflies(root: Node3D) -> void:
	var p := CPUParticles3D.new()
	p.amount = 70
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(13, 2.2, 11)
	p.position = Vector3(0, 2.6, -2)
	p.gravity = Vector3.ZERO
	p.direction = Vector3(1, 0.3, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.5
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var q := _sphere(0.05, 8)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(3.0, 2.6, 1.0)
	q.material = m
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)


static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	return GameSpot._mesh(parent, mesh, mat, pos)


static func _flat(color: Color) -> StandardMaterial3D:
	return GameSpot._flat(color)


static func _cyl(top: float, bottom: float, height: float, seg: int) -> CylinderMesh:
	var c := GameSpot._cyl(top, bottom, height)
	c.radial_segments = seg
	return c


static func _sphere(radius: float, seg: int = 24) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s
