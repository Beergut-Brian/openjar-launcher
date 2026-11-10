## A Jarling in the hub: walks and runs where the stick says, follows its friend, cheers, jumps into jars.
## The two held Jarlings are the players' Roster picks; swap_to() changes who one is in place, with
## the chooser's squash / poof / pop and a name tag. Residents use the same class and just stand about
## and cheer. A held Jarling that stands still for a moment shows the "change" hint by its ring.
## The model comes from openjar-characters (idle / run / cheer / kick, faces +Z, feet at y = 0).
class_name HubJarling
extends Node3D

const WALK_SPEED := 4.4            # stick most of the way over
const RUN_SPEED := 7.0             # stick (or D-pad / keys) all the way over: a run
const RUN_FROM := 0.85             # stick tilt where the walk starts turning into a run
const ACCEL := 14.0                # how fast it gets up to speed and stops: snappy, never icy
const FOLLOW_SPEED := 5.2
const TURN_RATE := 12.0
const SWAP_SQUASH := 0.07          # chooser swap: squash, become the next one in a poof, pop past full size
const SWAP_POP := 0.32
const TAG_SECONDS := 1.5           # the name tag over your head after a swap
const HINT_AFTER := 1.4            # standing still this long shows the "change" hint by the ring
const INK := Color("2b2140")
const CREAM := Color("fff4dc")
const EXPR := {"neutral": Vector3(0, 0, 0), "happy": Vector3(0.5, 0, 0),
		"surprised": Vector3(0, 0.5, 0), "determined": Vector3(0.5, 0.5, 0)}

var profile_id := "p1"
var color := Color.WHITE
var move_input := Vector2.ZERO     # stick, set by the hub each frame (x right, y towards the camera)
var follow: HubJarling = null      # set = nobody holds this Jarling, it tags along
var face_point := Vector3.INF      # look here while standing still
var busy := false                  # mid jump into / out of a jar
var moving := false
var jar_count := 0                 # jars on the plaza (the hub sets it), so it bumps into them
var size := 1.15                   # model scale
var height := 1.6                  # top of the head above the feet, in world units
var character_id := ""             # the Roster id it shows ("" = a generic fallback body)
var swapping := false              # mid swap_to(): the chooser ignores presses until it lands
var hint_enabled := false          # the hub allows the hint (held, in the hub, no launch playing)

var _model: Node3D
var _flip: Node3D                  # pivot at the tummy, so a somersault turns about the middle
var _anim: AnimationPlayer
var _ring: MeshInstance3D
var _face_mats: Array[StandardMaterial3D] = []
var _current := ""
var _held := false
var _clock := 0.0
var _vel := Vector3.ZERO
var _shape_tween: Tween
var _tag: Label3D
var _tag_tween: Tween
var _hint: Label3D
var _still := 0.0


func setup(model_scene: PackedScene, id: String, ring_color: Color, model_size: float = 1.15) -> void:
	profile_id = id
	color = ring_color
	size = model_size
	_flip = Node3D.new()
	add_child(_flip)
	_set_model(model_scene)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.56
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.6
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = mat
	_ring.scale = Vector3(1, 0.1, 1)
	_ring.position.y = 0.03
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_tag = _label(64, 16)
	_tag.visible = false
	_hint = _label(34, 10)
	_hint.top_level = true          # stays on the floor in front of the ring whichever way it faces
	_hint.modulate.a = 0.0
	_hint.visible = false
	_play("idle")


func _label(font_size: int, outline: int) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.shaded = false
	l.double_sided = true
	l.font_size = font_size
	l.outline_size = outline
	l.pixel_size = 0.006
	l.modulate = CREAM
	l.outline_modulate = INK
	l.render_priority = 2
	l.outline_render_priority = 1
	add_child(l)
	return l


## Put a new body in (no animation). Keeps the ring, the tag and the pose state.
func _set_model(model_scene: PackedScene) -> void:
	if _model != null:
		_flip.remove_child(_model)
		_model.queue_free()
	_face_mats.clear()
	_anim = null
	_current = ""
	_model = model_scene.instantiate()
	height = JarWorld.bounds(_model).end.y * size
	_flip.position.y = height * 0.5
	_flip.add_child(_model)
	_model.position.y = -height * 0.5
	_model.scale = Vector3.ONE * size
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_anim = players[0]
		for a in ["idle", "run", "cheer"]:
			if _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as StandardMaterial3D
			if m == null:
				continue
			m = m.duplicate()
			m.rim_enabled = true      # the Jarling look leans on rim light (avatar/README.md)
			m.rim = 0.45
			m.rim_tint = 0.35
			mi.set_surface_override_material(s, m)
			if m.resource_name.ends_with("_face"):
				_face_mats.append(m)


## Become `id` at once (boot, coming back from a game). No sound, no poof.
func set_character(id: String, model_scene: PackedScene) -> void:
	_kill_shape_tween()
	character_id = id
	_set_model(model_scene)
	_play("idle")


## The in-line chooser's swap, same beats as the template podiums: squash (70 ms), turn into `id` at
## the bottom in a cream poof, pop past full size (TRANS_BACK, 320 ms), and the name tag pops up over
## the head for TAG_SECONDS. The hub plays the bark / sound.
func swap_to(id: String, model_scene: PackedScene, tag_text: String) -> void:
	_kill_shape_tween()
	swapping = true
	character_id = id   # who it is now (the hub hides a twin resident at once); the body follows
	_shape_tween = create_tween()
	_shape_tween.tween_property(_model, "scale", Vector3(1.2, 0.7, 1.2) * size, SWAP_SQUASH)
	await _shape_tween.finished
	if not is_inside_tree():
		return
	_set_model(model_scene)
	_model.scale = Vector3(1.3, 0.15, 1.3) * size
	HubJarling.poof(self, Vector3(0, height * 0.35, 0), color)
	show_tag(tag_text)
	set_expression("happy")
	_play("cheer")
	_shape_tween = create_tween()
	_shape_tween.tween_property(_model, "scale", Vector3.ONE * size, SWAP_POP) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _shape_tween.finished
	swapping = false
	await get_tree().create_timer(0.4).timeout
	set_expression("neutral")
	if _current == "cheer" and not busy:
		_play("idle")


## The name over the head: pops in past full size, holds, fades out. A new one restarts it.
func show_tag(text: String) -> void:
	if _tag_tween != null:
		_tag_tween.kill()
	_tag.text = text
	_tag.outline_modulate = INK.lerp(color, 0.35) if _held else INK
	_tag.position = Vector3(0, height + 0.45, 0)
	_tag.visible = true
	_tag.modulate.a = 1.0
	_tag.scale = Vector3.ONE * 0.2
	_tag_tween = create_tween()
	_tag_tween.tween_property(_tag, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tag_tween.tween_interval(TAG_SECONDS - 0.5)
	_tag_tween.tween_property(_tag, "modulate:a", 0.0, 0.25)
	_tag_tween.tween_callback(_tag.hide)


func tag_visible() -> bool:
	return _tag.visible


func hint_visible() -> bool:
	return _hint.visible and _hint.modulate.a > 0.5


## Nobody else to be: a quick no-no head shake (the hub plays the low sound).
func shake() -> void:
	var t := create_tween()
	for k in [0.35, -0.35, 0.2, 0.0]:
		t.tween_property(_flip, "rotation:z", k, 0.06)


## A burst of cream puffs from `at` (local to `parent`), freed after 0.45 s.
static func poof(parent: Node3D, at: Vector3, tint: Color = Color.WHITE) -> Node3D:
	var root := Node3D.new()
	root.name = "Poof"
	root.position = at
	parent.add_child(root)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = CREAM.lerp(tint, 0.18)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var puffs: Array[MeshInstance3D] = []
	for i in 9:
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 12
		sphere.rings = 6
		mi.mesh = sphere
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		puffs.append(mi)
	var pose := func(t: float) -> void:
		for i in puffs.size():
			var ang := TAU * i / puffs.size() + 0.35
			var d := lerpf(0.25, 1.25, t) * (1.0 if i % 2 == 0 else 0.8)
			puffs[i].position = Vector3(cos(ang) * d, sin(ang) * d * 0.6 + 0.3 * t, sin(ang * 2.0) * 0.25)
			puffs[i].scale = Vector3.ONE * lerpf(0.62, 0.16, t) * (1.0 if i % 2 == 0 else 0.75)
		mat.albedo_color.a = 1.0 - smoothstep(0.55, 1.0, t)
	pose.call(0.0)
	if root.is_inside_tree():
		var tw := root.create_tween()
		tw.tween_method(pose, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(root.queue_free)
	return root


func _kill_shape_tween() -> void:
	if _shape_tween != null and _shape_tween.is_valid():
		_shape_tween.kill()
	_shape_tween = null
	swapping = false
	if _model != null:
		_model.scale = Vector3.ONE * size


func set_expression(e: String) -> void:
	for m in _face_mats:
		m.uv1_offset = EXPR.get(e, Vector3.ZERO)


func cheer(seconds: float = 0.9) -> void:
	_play("cheer")
	set_expression("happy")
	_squash()
	await get_tree().create_timer(seconds).timeout
	set_expression("neutral")
	if _current == "cheer":
		_play("idle")


## Stand still now (the hub just placed it somewhere): no stick, no leftover speed.
func stop() -> void:
	move_input = Vector2.ZERO
	_vel = Vector3.ZERO


## Top of the head (global): where a flown-off jar lid lands.
func head_top() -> Vector3:
	return global_position + Vector3(0, height, 0)


## The launch animation at LaunchSequence time t (the hub calls this every frame of it): crouch while
## the jar rattles, flinch at the pop, leap with a somersault from `start` over the rim at `mouth`,
## drop in shrinking, and land tiny at `inside`, waving out at the camera.
func launch_pose(t: float, start: Vector3, mouth: Vector3, inside: Vector3) -> void:
	var L := LaunchSequence
	busy = true
	_vel = Vector3.ZERO
	_ring.visible = t < L.T_LEAP and _held
	var to_jar := atan2(mouth.x - start.x, mouth.z - start.z)
	var shape := Vector3.ONE
	var mult := 1.0
	_flip.rotation.x = 0.0
	rotation.y = to_jar
	if t < L.T_LEAP:
		var c := L.smooth(L.phase(t, 0.0, 0.3)) + 0.25 * L.phase(t, L.T_POP, L.T_POP + 0.08)
		var flinch := exp(-(t - L.T_POP) * 9.0) * 0.3 if t >= L.T_POP else 0.0
		shape = Vector3(1.0 + 0.2 * c, 1.0 - 0.28 * c + flinch, 1.0 + 0.2 * c)
		global_position = start + Vector3(sin(t * 61.0) * 0.012 * c, 0, 0)
		_play("idle")
	elif t < L.T_SPLASH:
		var k := L.phase(t, L.T_LEAP, L.T_SPLASH)
		var peak := mouth.y + 2.6
		var p := start.lerp(mouth, k)
		p.y = lerpf(lerpf(start.y, peak, k), lerpf(peak, mouth.y - 0.3, k), k)
		global_position = p
		var stretch := 1.0 - L.phase(k, 0.0, 0.5)
		shape = Vector3(1.0 - 0.16 * stretch, 1.0 + 0.32 * stretch, 1.0 - 0.16 * stretch)
		mult = lerpf(1.0, 0.5, L.smooth(L.phase(k, 0.45, 1.0)))
		_flip.rotation.x = TAU * L.smooth(L.phase(k, 0.08, 0.92))
		_play("cheer")
	else:
		var k := L.phase(t, L.T_SPLASH, L.T_DIVE)
		global_position = (mouth - Vector3(0, 0.3, 0)).lerp(inside, k * k)
		mult = lerpf(0.5, 0.3, k)
		var u := maxf(t - L.T_DIVE, 0.0)
		var land := 0.3 * exp(-u * 7.0) * cos(u * 18.0) if t >= L.T_DIVE else 0.0
		shape = Vector3(1.0 + land * 0.7, 1.0 - land, 1.0 + land * 0.7)
		rotation.y = lerp_angle(to_jar, to_jar + PI, L.smooth(L.phase(t, L.T_SPLASH, L.T_DIVE + 0.25)))
		_play("cheer")
	_flip.position.y = height * 0.5 * mult
	_model.position.y = -height * 0.5 * mult
	_model.scale = shape * size * mult


## Pop back out of the jar onto the stand point.
func jump_out(mouth: Vector3, stand: Vector3) -> void:
	visible = true
	busy = true
	_ring.visible = _held
	_flip.rotation.x = 0.0
	_flip.position.y = height * 0.5
	_model.position.y = -height * 0.5
	set_expression("happy")
	_play("cheer")
	_vel = Vector3.ZERO
	var arc := func(k: float) -> void:
		global_position = mouth.lerp(stand, k) + Vector3(0, sin(k * PI) * 2.2, 0)
		_model.scale = Vector3.ONE * size * lerpf(0.45, 1.0, k)
	var t := create_tween()
	t.tween_method(arc, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	await t.finished
	busy = false
	_squash()
	set_expression("neutral")
	_play("idle")


func _process(delta: float) -> void:
	_clock += delta
	_ring.scale = Vector3(1, 0.1, 1) * (1.0 + sin(_clock * 4.0) * 0.04)
	_update_hint(delta)
	if busy:
		return
	var vel := Vector3.ZERO
	if follow != null:
		var to := follow.global_position - global_position
		to.y = 0.0
		if to.length() > 1.9 and follow.visible:
			vel = to.normalized() * minf(FOLLOW_SPEED, (to.length() - 1.5) * 4.0)
	else:
		vel = stick_velocity(move_input)
	_vel = _vel.lerp(vel, 1.0 - exp(-delta * ACCEL))
	if _vel.length() < 0.05 and vel == Vector3.ZERO:
		_vel = Vector3.ZERO
	vel = _vel
	if vel != Vector3.ZERO:
		global_position = HubLayout.walkable(global_position + vel * delta, jar_count)
	moving = vel.length() > 0.3
	var look := vel
	if not moving and face_point != Vector3.INF:
		look = face_point - global_position
	look.y = 0.0
	if look.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), 1.0 - exp(-delta * TURN_RATE))
	if _current != "cheer" or moving:
		_play("run" if moving else "idle")
	if _anim != null and _current == "run":
		_anim.speed_scale = clampf(vel.length() / 3.6, 0.8, 2.2)


## The "change" hint: fades in on the floor just in front of the ring once you have stood still
## for HINT_AFTER seconds, and is gone the moment you move, swap, jump or a launch starts.
func _update_hint(delta: float) -> void:
	var calm := hint_enabled and _held and not busy and not moving and not swapping and visible \
			and move_input.length() < 0.2
	_still = _still + delta if calm else 0.0
	var want := 1.0 if _still >= HINT_AFTER else 0.0
	_hint.modulate.a = move_toward(_hint.modulate.a, want, delta * (3.0 if want > 0.0 else 12.0))
	_hint.visible = _hint.modulate.a > 0.01
	if _hint.visible:
		_hint.global_position = global_position + Vector3(0, 0.08, 0.9)


## What the hint says: "<button> Change". The hub sets it (keyboard players see their key).
func set_hint_text(text: String) -> void:
	_hint.text = text
	_hint.outline_modulate = INK.lerp(color, 0.45)


## Full analogue control: a small tilt tiptoes, most of the way walks, all the way over runs.
static func stick_velocity(v: Vector2) -> Vector3:
	var tilt := minf(v.length(), 1.0)
	if tilt < 0.2:
		return Vector3.ZERO
	var speed := tilt * WALK_SPEED
	if tilt > RUN_FROM:
		speed = lerpf(RUN_FROM * WALK_SPEED, RUN_SPEED, (tilt - RUN_FROM) / (1.0 - RUN_FROM))
	return Vector3(v.x, 0.0, v.y).normalized() * speed


func _play(a: String) -> void:
	if _anim == null or _current == a or not _anim.has_animation(a):
		return
	_current = a
	_anim.speed_scale = 1.0
	_anim.play(a, 0.12)


func _squash() -> void:
	if swapping:
		return
	_kill_shape_tween()
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	_shape_tween = t
	t.tween_property(_model, "scale", Vector3(1.13, 0.8, 1.13) * size, 0.07)
	t.tween_property(_model, "scale", Vector3(0.92, 1.1, 0.92) * size, 0.1)
	t.tween_property(_model, "scale", Vector3.ONE * size, 0.14)


## The ring shows which Jarlings are held by a player, in that player's colour (P1 green, P2 red);
## a tag-along friend or a resident has none.
func set_held(on: bool, player_color: Color = color) -> void:
	_held = on
	color = player_color
	var mat: StandardMaterial3D = _ring.material_override
	mat.albedo_color = color
	mat.emission = color
	_ring.visible = on
