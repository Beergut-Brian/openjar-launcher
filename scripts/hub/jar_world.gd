## The tiny world inside a game's jar. A game ships its own (manifest key `jar`, docs/contracts.md
## "Jar world"); without one, build() makes a little diorama in the game's colours.
## The diorama-per-game idea, the eight worlds and the mesh shortcuts are ported from the other hub
## bake-off entry (branch feature/hub-opus: game_jar.gd, hub_look.gd, hub_mesh.gd), recoloured from
## each game's own colour and given glowing bits for the island's magic hour.
class_name JarWorld
extends RefCounted

enum Kind { MEADOW, SPACE, OCEAN, VOLCANO, FOREST, CASTLE, SNOW, CANDY }
const KINDS := 8
## A game's own world is scaled to fit this cylinder (metres, before the jar's own scale).
const FIT_RADIUS := 0.8
const FIT_HEIGHT := 1.9

static var _mats := {}


static func kind_for(slug: String) -> int:
	return absi(slug.hash()) % KINDS


## One kind per slug, in order. All different while there are <= KINDS games; after that only
## neighbours are kept different.
static func assign(slugs: Array) -> Array[int]:
	var out: Array[int] = []
	for slug: String in slugs:
		var w := kind_for(slug)
		for step in KINDS:
			var c := (w + step) % KINDS
			var taken := c in out if out.size() < KINDS else (not out.is_empty() and out[-1] == c)
			if not taken:
				w = c
				break
		out.append(w)
	return out


# ---------------------------------------------------------------- a game's own world

## The game's `jar` file as a node fitted to the jar, or null (with a warning) if it is unusable.
static func load_custom(path: String) -> Node3D:
	if path.is_empty():
		return null
	var node: Node = null
	if FileAccess.file_exists(path):
		match path.get_extension().to_lower():
			"glb", "gltf":
				var doc := GLTFDocument.new()
				var state := GLTFState.new()
				if doc.append_from_file(path, state) == OK:
					node = doc.generate_scene(state)
			"tscn":
				var text := FileAccess.get_file_as_string(path)
				if not (text.contains("ext_resource") or text.contains("Script") or text.contains("script =")):
					var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
					if packed != null and packed.can_instantiate():
						node = packed.instantiate()
	if node is Node3D:
		_strip(node)
		if _fit(node):
			_loop_animation(node)
			return node
	if node != null:
		node.free()
	push_warning("JarWorld: %s is not a usable jar world, using a generated one" % path)
	return null


## Jar worlds are data: no scripts, lights, cameras or sounds come along.
static func _strip(node: Node) -> void:
	for c in node.get_children():
		if c is Light3D or c is Camera3D or c is AudioStreamPlayer or c is AudioStreamPlayer3D:
			node.remove_child(c)
			c.free()
		else:
			_strip(c)
	node.set_script(null)


## Box around everything visible under node, in node's parent space.
static func bounds(node: Node, xf: Transform3D = Transform3D.IDENTITY) -> AABB:
	var box := AABB()
	if node is Node3D:
		xf = xf * (node as Node3D).transform
	if node is VisualInstance3D:
		box = xf * (node as VisualInstance3D).get_aabb()
	for c in node.get_children():
		var b := bounds(c, xf)
		if b.size != Vector3.ZERO:
			box = b if box.size == Vector3.ZERO else box.merge(b)
	return box


## Scales node uniformly into the FIT cylinder, centred, standing on y = 0. False if nothing shows.
static func _fit(node: Node3D) -> bool:
	node.transform = Transform3D.IDENTITY
	var box := bounds(node)
	if box.size.y <= 0.0001 or maxf(box.size.x, box.size.z) <= 0.0001:
		return false
	var s := minf(FIT_RADIUS * 2.0 / maxf(box.size.x, box.size.z), FIT_HEIGHT / box.size.y)
	var c := box.get_center()
	node.scale = Vector3.ONE * s
	node.position = -Vector3(c.x, box.position.y, c.z) * s
	return true


static func _loop_animation(node: Node) -> void:
	for ap: AnimationPlayer in node.find_children("*", "AnimationPlayer", true, false):
		var names := ap.get_animation_list()
		if names.is_empty():
			continue
		var pick: String = ap.autoplay
		if pick.is_empty() or not ap.has_animation(pick):
			pick = "idle" if ap.has_animation("idle") else names[0]
		ap.get_animation(pick).loop_mode = Animation.LOOP_LINEAR
		ap.autoplay = pick


# ---------------------------------------------------------------- generated worlds

## A little world of the given kind in the game's colour `c`. Radius 0.86, floor at y = 0.
static func build(kind: int, c: Color) -> Node3D:
	var D := Node3D.new()
	var dark := c.darkened(0.3)
	var pale := c.lerp(Color.WHITE, 0.6)
	var pop := Color.from_hsv(fposmod(c.h + 0.5, 1.0), 0.5, 1.0)   # the opposite colour, for small accents
	match posmod(kind, KINDS):
		Kind.MEADOW:
			_ground(D, Color("8fd45a").lerp(c, 0.2))
			_a(D, _sphere(0.32), _m(Color.WHITE, 0.4), Vector3(0.1, 0.42, 0.15))   # a big bouncy ball
			for i in 5:
				var a := TAU * i / 5.0
				_a(D, _sphere(0.1, 12), _m(c, 0.4), Vector3(0.1, 0.42, 0.15) + Vector3(sin(a), cos(a) * 0.6, cos(a)).normalized() * 0.27)
			var post := _m(Color.WHITE, 0.5)
			_a(D, _cyl(0.04, 0.04, 0.9), post, Vector3(-0.55, 0.55, -0.35))
			_a(D, _cyl(0.04, 0.04, 0.9), post, Vector3(0.45, 0.55, -0.55))
			_a(D, _cyl(0.04, 0.04, 1.06), post, Vector3(-0.05, 1.0, -0.45), Vector3(0, -21, 90))
			_a(D, _sphere(0.12, 12), _m(pop), Vector3(-0.5, 0.18, 0.45))
			_a(D, _sphere(0.1, 12), _m(pale), Vector3(-0.38, 0.15, 0.55))
		Kind.SPACE:
			_ground(D, Color("2b2a6b").lerp(c, 0.15))
			_a(D, _sphere(0.36), _m(c, 0.5, 0.35), Vector3(0, 0.95, 0))
			_a(D, _torus(0.48, 0.62, 40), _m(pop, 0.4, 0.5), Vector3(0, 0.95, 0), Vector3(22, 0, 12), Vector3(1, 0.15, 1))
			_a(D, _sphere(0.12, 12), _m(pale, 0.4, 0.4), Vector3(0.55, 1.45, 0.2))
			for i in 9:
				var a := TAU * i / 9.0
				_a(D, _sphere(0.035, 8), _glow(Color("fff6c8"), 2.5), Vector3(sin(a) * 0.68, 0.35 + fmod(i * 0.37, 1.2), cos(a) * 0.68))
			_rocket(D, Vector3(-0.35, 0.1, 0.35), pop)
		Kind.OCEAN:
			_ground(D, Color("1f8fd6").lerp(c, 0.25))
			for i in 6:
				var a := TAU * i / 6.0 + 0.3
				_a(D, _sphere(0.2, 12), _m(Color("5cd0ff").lerp(c, 0.25), 0.2), Vector3(sin(a) * 0.55, 0.08, cos(a) * 0.55), Vector3.ZERO, Vector3(1.2, 0.5, 1.2))
			_a(D, _sphere(0.32), _m(Color("ffd98a"), 0.8), Vector3(0.25, 0.02, -0.25), Vector3.ZERO, Vector3(1, 0.45, 1))
			_a(D, _cyl(0.04, 0.05, 0.6), _m(Color("8a5a2b")), Vector3(0.3, 0.4, -0.25), Vector3(0, 0, -10))
			_a(D, _sphere(0.2, 12), _m(Color("36c47a")), Vector3(0.36, 0.72, -0.25), Vector3.ZERO, Vector3(1.3, 0.4, 1.3))
			_a(D, _box(Vector3(0.5, 0.14, 0.24)), _m(pop, 0.4), Vector3(-0.25, 0.2, 0.25))
			_a(D, _cyl(0.02, 0.02, 0.5), _m(Color.WHITE), Vector3(-0.25, 0.5, 0.25))
			_a(D, _cyl(0.0, 0.2, 0.4, 3), _m(pale, 0.6), Vector3(-0.16, 0.5, 0.25), Vector3.ZERO, Vector3(1, 1, 0.15))
		Kind.VOLCANO:
			_ground(D, Color("6b4a3a").lerp(dark, 0.3))
			_a(D, _cyl(0.18, 0.7, 0.95), _m(Color("8c5a44").lerp(dark, 0.3), 0.9), Vector3(0, 0.55, 0))
			_a(D, _cyl(0.17, 0.17, 0.05), _glow(Color("ffb02e"), 3.0), Vector3(0, 1.03, 0))
			for i in 4:
				_a(D, _sphere(0.07 + i * 0.015, 10), _glow(Color("ff9a3a").lerp(c, 0.3), 2.5), Vector3(sin(i * 1.7) * 0.15, 1.2 + i * 0.16, cos(i * 1.7) * 0.15))
			_a(D, _sphere(0.12, 12), _m(pop), Vector3(0.6, 0.15, 0.3))
		Kind.FOREST:
			_ground(D, Color("5fbf6a").lerp(c, 0.2))
			for p: Vector3 in [Vector3(-0.35, 0, -0.2), Vector3(0.35, 0, -0.3), Vector3(0.05, 0, 0.35)]:
				var s := 0.8 + absf(p.x)
				_a(D, _cyl(0.06, 0.08, 0.5 * s), _m(Color("8a5a2b")), p + Vector3(0, 0.25 * s, 0))
				_a(D, _cyl(0.0, 0.32 * s, 0.6 * s, 16), _m(dark, 0.6), p + Vector3(0, 0.75 * s, 0))
				_a(D, _cyl(0.0, 0.25 * s, 0.45 * s, 16), _m(c, 0.6), p + Vector3(0, 1.05 * s, 0))
			_a(D, _cyl(0.04, 0.05, 0.16), _m(Color("fff3dc")), Vector3(0.45, 0.17, 0.3))
			_a(D, _sphere(0.13, 12), _m(pop, 0.4), Vector3(0.45, 0.27, 0.3), Vector3.ZERO, Vector3(1, 0.6, 1))
			_a(D, _sphere(0.04, 8), _glow(Color("fff6c8"), 2.5), Vector3(-0.1, 0.9, 0.5))   # a firefly
		Kind.CASTLE:
			_ground(D, Color("8fd45a").lerp(c, 0.15))
			var wall := _m(Color("f2e6ff"), 0.7)
			var roof := _m(c, 0.4)
			_a(D, _box(Vector3(0.7, 0.45, 0.45)), wall, Vector3(0, 0.33, 0))
			for x: float in [-0.42, 0.42]:
				_a(D, _cyl(0.15, 0.15, 0.8, 16), wall, Vector3(x, 0.5, 0))
				_a(D, _cyl(0.0, 0.21, 0.35, 16), roof, Vector3(x, 1.07, 0))
				_a(D, _box(Vector3(0.08, 0.12, 0.02)), _glow(Color("ffd98a"), 2.2), Vector3(x, 0.62, 0.15))   # lit windows
			_a(D, _cyl(0.18, 0.18, 0.65, 16), wall, Vector3(0, 0.85, 0))
			_a(D, _cyl(0.0, 0.25, 0.45, 16), roof, Vector3(0, 1.4, 0))
			_a(D, _box(Vector3(0.18, 0.12, 0.01)), _m(pop), Vector3(0.1, 1.72, 0))
			_a(D, _cyl(0.012, 0.012, 0.3), _m(Color.WHITE), Vector3(0, 1.7, 0))
			_a(D, _sphere(0.12, 12), _m(dark), Vector3(0, 0.2, 0.2), Vector3.ZERO, Vector3(1, 1.2, 0.3))
		Kind.SNOW:
			_ground(D, Color("f4fbff").lerp(c, 0.12))
			var snow := _m(Color.WHITE, 0.6)
			_a(D, _sphere(0.3), snow, Vector3(0.1, 0.32, 0.1))
			_a(D, _sphere(0.22), snow, Vector3(0.1, 0.75, 0.1))
			_a(D, _sphere(0.16), snow, Vector3(0.1, 1.08, 0.1))
			_a(D, _cyl(0.0, 0.04, 0.18, 8), _m(Color("ff8a3d")), Vector3(0.1, 1.08, 0.3), Vector3(90, 0, 0))
			_a(D, _torus(0.12, 0.2, 20), _m(c), Vector3(0.1, 0.93, 0.1), Vector3.ZERO, Vector3(1.05, 1.6, 1.05))
			for p: Vector3 in [Vector3(-0.45, 0, -0.3), Vector3(0.5, 0, -0.45)]:
				_a(D, _cyl(0.0, 0.26, 0.75, 12), _m(Color("2ec4a0").darkened(0.2)), p + Vector3(0, 0.42, 0))
				_a(D, _cyl(0.0, 0.17, 0.3, 12), snow, p + Vector3(0, 0.72, 0))
			for i in 10:   # snowflakes hanging in the air, like a shaken snow globe
				var a := i * 2.4
				_a(D, _sphere(0.03, 8), _glow(Color.WHITE, 1.6), Vector3(sin(a) * 0.6, 0.5 + fmod(i * 0.43, 1.2), cos(a) * 0.6))
		Kind.CANDY:
			_ground(D, Color("ffd1e8").lerp(c, 0.2))
			for i in 3:
				var p := Vector3([-0.4, 0.4, 0.0][i], 0, [-0.3, -0.2, 0.4][i])
				var h: float = [0.9, 0.7, 0.55][i]
				_a(D, _cyl(0.03, 0.03, h), _m(Color.WHITE), p + Vector3(0, h * 0.5, 0))
				_a(D, _cyl(0.22, 0.22, 0.08, 24), _m([c, pop, pale][i], 0.3), p + Vector3(0, h + 0.15, 0), Vector3(90, 0, 0))
			_a(D, _torus(0.1, 0.24, 24), _m(Color("c98a4b")), Vector3(0.3, 0.15, 0.3))
			_a(D, _torus(0.11, 0.23, 24), _m(c.lerp(Color.WHITE, 0.3)), Vector3(0.3, 0.2, 0.3), Vector3.ZERO, Vector3(1, 0.4, 1))
	return D


## Three snoozing bubbles drifting up: the empty jar is waiting for a game, nothing is broken.
static func build_sleepy() -> Node3D:
	var D := Node3D.new()
	_ground(D, Color("d9d3e6"))
	for i in 3:
		var b := _a(D, _sphere(0.09 + i * 0.05, 14), _m(Color("bfe6ff"), 0.1, 0.4), Vector3(0.1 * i, 0.5 + i * 0.4, 0))
		b.set_meta("bob", 1.2 + i * 0.3)
	return D


static func _ground(D: Node3D, c: Color) -> void:
	_a(D, _cyl(0.84, 0.86, 0.22), _m(c, 0.7), Vector3(0, -0.02, 0))


static func _rocket(D: Node3D, p: Vector3, trim: Color) -> void:
	_a(D, _cyl(0.11, 0.11, 0.4, 16), _m(Color("f4f4f8"), 0.3), p + Vector3(0, 0.32, 0))
	_a(D, _cyl(0.0, 0.11, 0.2, 16), _m(trim, 0.4), p + Vector3(0, 0.62, 0))
	_a(D, _sphere(0.05, 10), _m(Color("7fe3ff"), 0.2, 0.5), p + Vector3(0, 0.4, 0.1))
	_a(D, _cyl(0.07, 0.0, 0.18, 10), _glow(Color("ffb02e"), 3.0), p + Vector3(0, 0.05, 0))


# ---------------------------------------------------------------- mesh shortcuts

static func _m(c: Color, rough: float = 0.55, emit: float = 0.0) -> StandardMaterial3D:
	var key := "%s %.2f %.2f" % [c.to_html(), rough, emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.4
	m.emission_enabled = true   # a little self-glow so the world reads in the jar at dusk
	m.emission = c
	m.emission_energy_multiplier = maxf(emit, 0.12)
	_mats[key] = m
	return m


static func _glow(c: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "glow %s %.2f" % [c.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c * energy
	_mats[key] = m
	return m


static func _a(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3 = Vector3.ZERO,
		rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _sphere(r: float, segs: int = 20) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = segs
	m.rings = segs / 2
	return m


static func _cyl(r_top: float, r_bottom: float, h: float, segs: int = 24) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	return m


static func _torus(inner: float, outer: float, segs: int = 28) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = segs
	m.ring_segments = 10
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m
