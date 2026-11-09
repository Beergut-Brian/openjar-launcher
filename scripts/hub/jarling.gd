## A Jarling in the hub: walks, runs to a jar on a hop, follows its friend, cheers, jumps into jars.
## The model comes from openjar-characters (idle / run / cheer / kick, faces +Z, feet at y = 0).
class_name HubJarling
extends Node3D

const WALK_SPEED := 4.4
const HOP_SPEED := 9.0
const FOLLOW_SPEED := 5.2
const TURN_RATE := 12.0
const EXPR := {"neutral": Vector3(0, 0, 0), "happy": Vector3(0.5, 0, 0),
		"surprised": Vector3(0, 0.5, 0), "determined": Vector3(0.5, 0.5, 0)}

signal arrived()

var profile_id := "p1"
var color := Color.WHITE
var move_input := Vector2.ZERO     # stick, set by the hub each frame (x right, y towards the camera)
var hop_goal := Vector3.INF        # set = running to a jar, the stick is ignored until it gets there
var follow: HubJarling = null      # set = nobody holds this Jarling, it tags along
var face_point := Vector3.INF      # look here while standing still
var busy := false                  # mid jump into / out of a jar
var moving := false

var _model: Node3D
var _anim: AnimationPlayer
var _ring: MeshInstance3D
var _face_mats: Array[StandardMaterial3D] = []
var _current := ""
var _clock := 0.0


func setup(model_scene: PackedScene, id: String, ring_color: Color) -> void:
	profile_id = id
	color = ring_color
	_model = model_scene.instantiate()
	add_child(_model)
	_model.scale = Vector3.ONE * 1.15
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


func hop_to(goal: Vector3) -> void:
	hop_goal = goal


## Jump up and into the jar, shrinking. Await the tween's `finished`.
func jump_into(mouth: Vector3) -> Tween:
	busy = true
	hop_goal = Vector3.INF
	_play("cheer")
	set_expression("happy")
	var start := global_position
	var arc := func(k: float) -> void:
		global_position = start.lerp(mouth, k) + Vector3(0, sin(k * PI) * 2.6, 0)
		_model.scale = Vector3.ONE * 1.15 * lerpf(1.0, 0.45, k * k)
	var t := create_tween()
	t.tween_method(arc, 0.0, 1.0, 0.75).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void: visible = false)
	return t


## Pop back out of the jar onto the stand point.
func jump_out(mouth: Vector3, stand: Vector3) -> void:
	visible = true
	busy = true
	var arc := func(k: float) -> void:
		global_position = mouth.lerp(stand, k) + Vector3(0, sin(k * PI) * 2.2, 0)
		_model.scale = Vector3.ONE * 1.15 * lerpf(0.45, 1.0, k)
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
	if hop_goal != Vector3.INF:
		var to := hop_goal - global_position
		to.y = 0.0
		var step := HOP_SPEED * delta
		if to.length() <= step:
			global_position = hop_goal
			hop_goal = Vector3.INF
			_squash()
			arrived.emit()
		else:
			vel = to.normalized() * HOP_SPEED
	elif follow != null:
		var to := follow.global_position - global_position
		to.y = 0.0
		if to.length() > 1.9 and follow.visible:
			vel = to.normalized() * minf(FOLLOW_SPEED, (to.length() - 1.5) * 4.0)
	elif move_input.length() > 0.2:
		vel = Vector3(move_input.x, 0.0, move_input.y) * WALK_SPEED
	if vel != Vector3.ZERO:
		var p := global_position + vel * delta
		p.y = 0.0
		var flat := Vector2(p.x, p.z).limit_length(HubLayout.WALK_RADIUS)
		global_position = Vector3(flat.x, 0.0, flat.y)
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


func _play(a: String) -> void:
	if _anim == null or _current == a or not _anim.has_animation(a):
		return
	_current = a
	_anim.speed_scale = 1.0
	_anim.play(a, 0.12)


func _squash() -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(_model, "scale", Vector3(1.3, 0.92, 1.3), 0.07)
	t.tween_property(_model, "scale", Vector3(1.06, 1.26, 1.06), 0.1)
	t.tween_property(_model, "scale", Vector3.ONE * 1.15, 0.14)


## The coloured ring shows which Jarlings are held by a player; a tag-along friend has none.
func set_held(on: bool) -> void:
	_ring.visible = on
