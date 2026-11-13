## The hub's opening (C-02, C-04, A-01, A-02): a big jar in the middle of the plaza rattles, its lid
## pops off, and the whole playable roster tumbles out one after another, landing in rows in front
## of it. Each says a happy bark as it lands (vendored voices, at most IntroPlan.MAX_VOICES at once),
## the logo drops in with a thump, everybody cheers, then they all hop back into the jar, the lid
## drops on and the jar poofs away while the camera pulls out to the hub. A skips it at any point.
## Timeline and landing spots: IntroPlan (pure). Posed from `t` every frame, one-shot beats fire once.
class_name HubIntro
extends Node3D

signal finished

## Stand-in until Kaden picks a wordmark (V-01): a copy of art/logo/option_a.png, which art/logo/README.md
## marks "in the game for now" (art/ is not exported, so the game reads its own copy in assets/).
const LOGO := preload("res://assets/sprites/logo/intro_logo.png")
const LOGO_REST := Vector3(0, 6.2, -1.2)   # from IntroPlan.JAR_AT
const LOGO_DROP := 9.0
const CHARACTER_SIZE := 1.15
const JAR_TINT := Color("ffd23f")

var active := false
var t := 0.0
var ids: Array[String] = []           # who tumbles out, in order (the roster with a body)
var voiced: Array[String] = []        # what was said, in order (tests)
var landed := 0
var shake_at := -1.0               # intro time of the logo thump (its camera jolt); < 0 not yet

var _chars: Array[Node3D] = []
var _spots: Array[Vector3] = []
var _events: Array = []               # [time, kind, index], sorted
var _next := 0
var _jar: Node3D
var _lid: Node3D
var _logo: Sprite3D
var _voices: Array[AudioStreamPlayer] = []
var _land_at: Array[float] = []
var _pending: Array[String] = []      # threaded loads not collected yet (K-07)


## The roster in order, keeping only characters with a body to show (Jeff and Chuck first, as the
## roster lists them). Grows with the roster.
static func cast() -> Array[String]:
	var out: Array[String] = []
	for id in Roster.roster():
		var glb: String = Roster.info(id).get("glb", "")
		if glb != "" and ResourceLoader.exists(glb):
			out.append(id)
	return out


func start(who: Array[String]) -> void:
	ids = who
	var n := ids.size()
	_spots = IntroPlan.landing_spots(n)
	if _spots.size() < n:   # more characters than the island holds: the extras stay in the jar
		ids = ids.slice(0, _spots.size())
		n = ids.size()
	_build_jar()
	_build_logo()
	for i in IntroPlan.MAX_VOICES:
		var v := AudioStreamPlayer.new()
		v.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		add_child(v)
		_voices.append(v)
	# K-07: the bodies load on worker threads and each is built just before it tumbles out, so
	# the first frame (and A to skip) never waits on the whole roster's glTF.
	for i in n:
		var glb := str(Roster.info(ids[i]).glb)
		if glb != "" and not ResourceLoader.has_cached(glb) and glb not in _pending \
				and ResourceLoader.load_threaded_request(glb, "PackedScene") == OK:
			_pending.append(glb)
		var holder := Node3D.new()
		add_child(holder)
		holder.visible = false
		_chars.append(holder)
		_land_at.append(INF)
	_events = [[0.0, "rattle", -1], [IntroPlan.T_POP, "pop", -1],
		[IntroPlan.thump_time(n), "thump", -1], [IntroPlan.end_time(n) - IntroPlan.OUTRO, "lid", -1],
		[IntroPlan.end_time(n), "end", -1]]
	for i in n:
		_events.append([IntroPlan.land_time(i, n), "land", i])
	_events.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_next = 0
	t = 0.0
	landed = 0
	shake_at = -1.0
	active = true
	_pose()


## Jump to the end: everyone back in the jar in one poof, a "yes!" sound, and the hub takes over.
func skip() -> void:
	if not active:
		return
	Audio.play("ui_confirm")
	HubJarling.poof(get_parent() as Node3D, IntroPlan.JAR_AT + Vector3(0, 2.0, 0))
	_finish()


func _process(delta: float) -> void:
	if not active:
		return
	advance(delta)


## Step the clock (tests call this directly): fire the beats that came due, then pose everything.
func advance(delta: float) -> void:
	if not active:
		return
	t += delta
	while active and _next < _events.size() and t >= float(_events[_next][0]):
		var e: Array = _events[_next]
		_next += 1
		_beat(e[1], e[2])
	if active:
		_pose()


## Character i's body, built on first use: from its threaded load (waits only if that one isn't in
## yet) or the cache. Its holder stays empty if the glTF is gone.
func body(i: int) -> Node3D:
	var holder := _chars[i]
	if holder.get_child_count() > 0:
		return holder
	var glb := str(Roster.info(ids[i]).glb)
	var scene: PackedScene = null
	if glb != "":
		if glb in _pending:
			_pending.erase(glb)
			scene = ResourceLoader.load_threaded_get(glb) as PackedScene   # waits only if not in yet
		else:
			scene = load(glb) as PackedScene
	var b: Node3D = scene.instantiate() if scene else Node3D.new()
	b.scale = Vector3.ONE * CHARACTER_SIZE
	holder.add_child(b)
	_play_anim(holder, "idle")
	return holder


## How many bodies are built so far (tests).
func bodies_built() -> int:
	return _chars.filter(func(c: Node3D) -> bool: return c.get_child_count() > 0).size()


func _beat(kind: String, i: int) -> void:
	match kind:
		"rattle":
			Audio.play("jar_rattle")
		"pop":
			Audio.play("intro_pop")
			HubJarling.poof(self, _mouth(), JAR_TINT)
		"land":
			landed += 1
			_land_at[i] = t
			HubJarling.poof(self, _spots[i] + Vector3(0, 0.2, 0))
			_play_anim(body(i), "cheer")
			if not _say(i):
				Audio.play("ui_move")   # no voice (yet) for this one: a landing tick, never silent
		"thump":
			Audio.play("intro_thump")
			shake_at = t   # the camera feels it land (IntroPlan.shake), only here: never the chooser or a launch
			Audio.music("card_row_loop")
			for c in _chars:
				if c.get_child_count() > 0:
					_play_anim(c, "cheer")
		"lid":
			Audio.play("lid_bonk")
		"end":
			Audio.play("jar_pop_out")
			HubJarling.poof(get_parent() as Node3D, IntroPlan.JAR_AT + Vector3(0, 2.0, 0), JAR_TINT)
			_finish()


## One landing voice, through the chooser's voice call (Roster.say), on a free crowd voice; none
## free (MAX_VOICES talking already): false, and the caller plays the landing tick.
func _say(i: int) -> bool:
	var path := IntroPlan.voice_path(Roster.info(ids[i]), i, ids.size())
	if path == "":
		return false
	for v in _voices:
		if not v.playing:
			v.pitch_scale = 1.0
			if not Roster.say(-1, ids[i], path, v):
				return false
			voiced.append(path)
			return true
	return false


func voices_playing() -> int:
	return _voices.filter(func(v: AudioStreamPlayer) -> bool: return v.playing).size()


## Skipped before everyone was built: collect the loads still in flight once each is in, a frame at
## a time, so A never waits on them and none is left behind.
func _exit_tree() -> void:
	if not _pending.is_empty() and is_inside_tree():
		_collect(get_tree(), _pending.duplicate())
	_pending.clear()


static func _collect(tree: SceneTree, paths: Array[String]) -> void:
	while not paths.is_empty():
		for p in paths.duplicate():
			if ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				ResourceLoader.load_threaded_get(p)
				paths.erase(p)
		if not paths.is_empty():
			await tree.process_frame


## Loads still in flight (tests).
func pending_loads() -> int:
	return _pending.size()


func _finish() -> void:
	active = false
	Audio.music("card_row_loop")   # no-op if the thump already started it
	for v in _voices:
		v.stop()
	finished.emit()
	queue_free()


## The intro's camera: IntroPlan.camera plus the thump's jolt (moves eye and target together).
func camera_pose(wide_pos: Vector3, wide_look: Vector3) -> Array[Vector3]:
	var pose := IntroPlan.camera(t, ids.size(), wide_pos, wide_look)
	var jolt := shake_offset()
	return [pose[0] + jolt, pose[1] + jolt]


## The camera jolt right now (zero before the thump and from SHAKE_TIME after it).
func shake_offset() -> Vector3:
	return IntroPlan.shake(t - shake_at) if shake_at >= 0.0 else Vector3.ZERO


# ---------------------------------------------------------------- posing

func _mouth() -> Vector3:
	return IntroPlan.JAR_AT + Vector3(0, (GameSpot.PLINTH_HEIGHT + GameSpot.JAR_HEIGHT) * IntroPlan.JAR_SCALE, 0)


func _pose() -> void:
	var n := ids.size()
	var P := IntroPlan
	# the jar: rattles harder and harder, a big squash on the pop, wobbles at each launch
	var rattle := smoothstep(0.0, P.T_POP, t) * (1.0 if t < P.T_POP else 0.0)
	_jar.rotation.z = sin(t * 42.0) * 0.06 * rattle
	var pop := exp(-maxf(t - P.T_POP, 0.0) * 6.0) * (1.0 if t >= P.T_POP else 0.0)
	var end := IntroPlan.end_time(n)
	var shrink := 1.0 - smoothstep(end - 0.2, end, t)
	_jar.scale = Vector3(1.0 + 0.18 * pop, 1.0 - 0.15 * pop, 1.0 + 0.18 * pop) * P.JAR_SCALE * maxf(shrink, 0.01)
	# the lid: spins up out of shot, then drops back on once everyone is home
	var rest := _mouth() + Vector3(0, 0.08, 0)
	var lid_back := end - P.OUTRO
	if t < P.T_POP:
		_lid.position = rest + Vector3(0, absf(sin(t * 30.0)) * 0.12 * rattle, 0)
		_lid.rotation = Vector3.ZERO
	elif t < lid_back - 0.35:
		var k := minf((t - P.T_POP) / 0.9, 1.0)
		_lid.position = rest + Vector3(3.5 * k, 14.0 * k - 4.0 * k * k, -2.0 * k)
		_lid.rotation = Vector3(t * 9.0, 0, t * 4.0)
	else:
		var k := smoothstep(lid_back - 0.35, lid_back, t)
		_lid.position = (rest + Vector3(0, 6.0, 0)).lerp(rest, k * k)
		_lid.rotation = Vector3.ZERO
	_lid.scale = Vector3.ONE * P.JAR_SCALE * maxf(shrink, 0.01)
	# the characters
	var cam := P.camera(t, n, Vector3(0, 10.5, 27), Vector3.ZERO)[0]
	var mouth := _mouth()
	for i in n:
		var c := _chars[i]
		var go := P.launch_time(i, n)
		var land := P.land_time(i, n)
		var back := P.back_time(i, n)
		var to := _spots[i]
		c.visible = t >= go and t < back + P.BACK_FLIGHT
		if t >= go - P.FLIGHT:   # built a beat before it leaps, never all at once
			body(i)
		if not c.visible:
			continue
		var face := atan2(cam.x - to.x, cam.z - to.z)
		if t < land:   # tumbling out: a high arc with a somersault, squeezing out of the jar mouth
			var k := (t - go) / P.FLIGHT
			c.position = mouth.lerp(to, k) + Vector3(0, 2.3 * sin(PI * k) + (1.0 - k) * 0.3, 0)
			c.rotation = Vector3(TAU * k * (1.0 if i % 2 == 0 else -1.0), lerp_angle(0.0, face, k), 0)
			c.scale = Vector3.ONE * lerpf(0.45, 1.0, minf(k * 3.0, 1.0))
		elif t < back:   # landed: squash, then bounce along to the logo
			var since := t - land
			var squash := exp(-since * 9.0) * cos(since * 26.0) * 0.28
			c.position = to
			var hop := 0.0
			var thump := P.thump_time(n)
			if t >= thump:
				hop = absf(sin((t - thump) * 6.5 + i * 0.7)) * 0.45 * exp(-(t - thump) * 0.8)
			c.position.y = hop
			c.rotation = Vector3(0, face, 0)
			c.scale = Vector3(1.0 + squash, 1.0 - squash, 1.0 + squash)
		else:   # hopping home: back into the jar mouth, shrinking as it goes in
			var k := (t - back) / P.BACK_FLIGHT
			c.position = to.lerp(mouth, k) + Vector3(0, 2.6 * sin(PI * k), 0)
			c.rotation = Vector3(0, face + PI * k, 0)
			c.scale = Vector3.ONE * lerpf(1.0, 0.3, k * k)
	# the logo: drops from the sky, thumps down with a squash, then rises away as the camera pulls out
	var lt := P.logo_time(n)
	_logo.visible = t >= lt
	if _logo.visible:
		var rest_at := P.JAR_AT + LOGO_REST
		var fall := minf((t - lt) / P.LOGO_FALL, 1.0)
		_logo.position = rest_at + Vector3(0, LOGO_DROP * (1.0 - fall * fall), 0)
		var since := maxf(t - P.thump_time(n), 0.0)
		var sq := exp(-since * 7.0) * cos(since * 22.0) * 0.22 if fall >= 1.0 else 0.0
		var away := smoothstep(end - 0.9, end, t)
		_logo.position.y += away * 4.0
		_logo.scale = Vector3(1.0 + sq, 1.0 - sq, 1.0)
		_logo.modulate.a = 1.0 - away


func _build_jar() -> void:
	_jar = Node3D.new()
	add_child(_jar)
	_jar.position = IntroPlan.JAR_AT
	GameSpot._mesh(_jar, GameSpot._cyl(1.45, 1.6, GameSpot.PLINTH_HEIGHT), GameSpot._flat(Color("d9c2b0")),
			Vector3(0, GameSpot.PLINTH_HEIGHT * 0.5, 0))
	var glass_mat := ShaderMaterial.new()
	glass_mat.shader = GameSpot.GLASS_SHADER
	glass_mat.set_shader_parameter("tint", JAR_TINT)
	var glass := GameSpot._mesh(_jar, GameSpot.jar_mesh(), glass_mat, Vector3(0, GameSpot.PLINTH_HEIGHT, 0))
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	GameSpot._mesh(_jar, GameSpot._cyl(0.92, 0.92, 0.08), GameSpot._glow(JAR_TINT, 2.2),
			Vector3(0, GameSpot.PLINTH_HEIGHT + 0.1, 0))
	var light := OmniLight3D.new()
	light.light_color = JAR_TINT
	light.light_energy = 2.0
	light.omni_range = 6.0
	light.position = Vector3(0, 2.0, 0)
	_jar.add_child(light)
	_lid = Node3D.new()
	add_child(_lid)
	var lid_mat := GameSpot._flat(Color("ff7ac8"))
	lid_mat.metallic = 0.5
	lid_mat.roughness = 0.35
	GameSpot._mesh(_lid, GameSpot._cyl(0.86, 0.86, 0.3), lid_mat, Vector3(0, 0.15, 0))
	GameSpot._mesh(_lid, GameSpot._cyl(0.6, 0.78, 0.1), lid_mat, Vector3(0, 0.34, 0))
	var knob := SphereMesh.new()
	knob.radius = 0.17
	knob.height = 0.26
	GameSpot._mesh(_lid, knob, GameSpot._flat(Color("fff3dc")), Vector3(0, 0.43, 0))


func _build_logo() -> void:
	_logo = Sprite3D.new()
	_logo.texture = LOGO
	_logo.pixel_size = 0.0062
	_logo.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_logo.shaded = false
	_logo.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_logo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_logo.render_priority = 3
	_logo.visible = false
	add_child(_logo)


static func _play_anim(holder: Node3D, anim: String) -> void:
	var players := holder.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var ap: AnimationPlayer = players[0]
	var name := anim if ap.has_animation(anim) else ("idle" if ap.has_animation("idle") else "")
	if name == "":
		return
	ap.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	ap.play(name)
