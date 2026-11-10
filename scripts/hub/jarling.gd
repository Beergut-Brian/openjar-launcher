## A Jarling in the hub: walks and runs where the stick says, follows its friend, cheers, jumps into jars.
## The two profile Jarlings (a grown-up and a kid, generic kit Jarlings) are the ones players hold;
## Jeff and Chuck use the same class as residents that just stand about and cheer.
## The model comes from openjar-characters (idle / run / cheer / kick, faces +Z, feet at y = 0).
class_name HubJarling
extends Node3D

const WALK_SPEED := 4.4            # stick most of the way over
const RUN_SPEED := 7.0             # stick (or D-pad / keys) all the way over: a run
const RUN_FROM := 0.85             # stick tilt where the walk starts turning into a run
const ACCEL := 14.0                # how fast it gets up to speed and stops: snappy, never icy
const FOLLOW_SPEED := 5.2
const TURN_RATE := 12.0
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
var size := 1.15                   # model scale: the kid profile is smaller
var height := 1.6                  # top of the head above the feet, in world units

var _model: Node3D
var _flip: Node3D                  # pivot at the tummy, so a somersault turns about the middle
var _anim: AnimationPlayer
var _ring: MeshInstance3D
var _face_mats: Array[StandardMaterial3D] = []
var _current := ""
var _held := false
var _clock := 0.0
var _vel := Vector3.ZERO


func setup(model_scene: PackedScene, id: String, ring_color: Color, model_size: float = 1.15) -> void:
	profile_id = id
	color = ring_color
	size = model_size
	_model = model_scene.instantiate()
	height = JarWorld.bounds(_model).end.y * size
	_flip = Node3D.new()
	add_child(_flip)
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
	_play("idle")


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
	var t := create_tween().set_trans(Tween.TRANS_SINE)
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
