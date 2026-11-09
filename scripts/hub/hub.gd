## The hub: a floating island at magic hour where Jarlings walk up to giant jars and jump in to play.
## Flow: boot → hub (standing at the last game's jar) → A → jump in → (game runs) → pop back out.
## Owns the Save keys (LauncherState), the manifest list and the child process.
## Start quits to Steam (exit code 0) except while a game runs.
extends Node3D

enum Screen { HUB, RUNNING }

const POLL_SECONDS := 0.5
const IDLE_SLEEP_USEC := 100000   # ~10 fps while a game runs
const RETURN_GRACE_MS := 600      # swallow the button that quit the game
## Minimise the launcher's window while a game runs and restore it (fullscreen) on return, so two
## fullscreen windows never fight for the TV. Off = the launcher only hides. GAME.md decisions.
const MINIMIZE_WHILE_RUNNING := true
const HOP_REPEAT := 0.45          # holding the stick sideways hops again this often
const INTRO_SECONDS := 2.6        # the camera glides in from the wide shot; input works throughout
const SKY_SHADER := preload("res://assets/shaders/hub/sky.gdshader")
## Profile id → Jarling. Jeff is the green one, Chuck the red one, always.
const MODELS := {
	"p1": preload("res://assets/models/jarlings/jeff.glb"),
	"p2": preload("res://assets/models/jarlings/chuck.glb"),
}
const SUN_DIR := Vector3(0.42, 0.2, -1.0)   # the sun you see: low behind the jars, a little to the right
## The light itself comes from higher up on the same bearing, so shadows stay short and crisp.
const LIGHT_DIR := Vector3(0.42, 0.46, -1.0)

signal launched(slug: String, profile_id: String)

var screen: Screen = Screen.HUB
var root_dir := ""
var all_entries: Array[Dictionary] = []
var entries: Array[Dictionary] = []      # the ones with a jar (dev filter applied)
var spots: Array[GameSpot] = []
var jarlings: Array[HubJarling] = []     # [Jeff (p1), Chuck (p2)]
var focus: Array[int] = [-1, -1]         # jar each Jarling is looking into, by Jarling index
var profile := "p1"                      # the Jarling picked for solo play; remembered
var two_players := false

var _pid := -1
var _running_slug := ""
var _launching := false
var _launcher_index := 0
var _window_mode_before_run := -1
var _input_from_ms := 0
var _dev_combo := HoldCombo.new(1.0)
var _hop_held := [false, false]
var _hop_timer := [0.0, 0.0]
var _hop_index := [-1, -1]
var _intro := 0.0
var _intro_hold := false
var _cam_pos := Vector3(0, 10.5, 27)
var _cam_look := Vector3(0, 1.5, -3)
var _clock := 0.0
var _demo: Array = []
var _demo_move := Vector2.ZERO
var _demo_move_until := 0.0

@onready var camera: Camera3D = $Camera
@onready var world: Node3D = $World
@onready var spot_root: Node3D = $Spots
@onready var process_watch: Timer = $ProcessWatch


func _ready() -> void:
	_build_sky_and_lights()
	HubWorld.build(world)
	for id: String in LaunchArgs.PROFILES:
		var j := HubJarling.new()
		add_child(j)
		j.setup(MODELS[id], id, Players.COLOR[jarlings.size()])
		jarlings.append(j)
	root_dir = ManifestScanner.default_root()
	profile = LauncherState.profile(Save)
	two_players = Players.is_active(Players.P2)
	Players.player_joined.connect(_on_player_joined)
	Players.player_left.connect(_on_player_left)
	_apply_roles()
	_rescan(LauncherState.last_card(Save))
	process_watch.wait_time = POLL_SECONDS
	process_watch.timeout.connect(_on_process_watch)
	_parse_demo(OS.get_environment("HUB_DEMO"))
	Audio.music("card_row_loop")
	_update_camera(0.0)
	_report_cold_start()


## Kid-design target: cold start to playing in under 10 s. Ticks count from engine start.
func _report_cold_start() -> void:
	await get_tree().process_frame
	print("launcher: interactive (hub, %d jars) after %d ms, unix %.3f" % [
		spots.size(), Time.get_ticks_msec(), Time.get_unix_time_from_system()])


func _unhandled_input(event: InputEvent) -> void:
	if screen == Screen.RUNNING:
		return
	if event.is_action_pressed("launcher_quit"):
		get_viewport().set_input_as_handled()
		quit_to_steam()


func quit_to_steam() -> void:
	Audio.play("ui_back")
	Save.flush()
	set_process_unhandled_input(false)
	await get_tree().create_timer(0.25).timeout   # let the cue be heard
	Audio.quit(0)


# ---------------------------------------------------------------- jars

func _rescan(select_slug: String) -> void:
	all_entries = ManifestScanner.scan(root_dir)
	print("launcher: %d entries in %s" % [all_entries.size(), root_dir])
	set_entries(ManifestScanner.filter_dev(all_entries, LauncherState.show_dev(Save)), select_slug)


## Rebuilds the row of jars and stands the Jarlings at `select_slug`'s jar (the middle one if unknown).
func set_entries(list: Array[Dictionary], select_slug: String = "") -> void:
	for s in spots:
		spot_root.remove_child(s)
		s.queue_free()
	spots.clear()
	entries = list
	var count := HubLayout.spot_count(list.size())
	var selected := (count - 1) / 2
	var previous_toy := -1
	for i in count:
		var spot := GameSpot.new()
		spot_root.add_child(spot)
		spot.setup(list[i] if i < list.size() else {}, i, previous_toy)
		spot.place(HubLayout.jar_position(i, count), HubLayout.stand_position(i, count))
		previous_toy = spot.toy_index
		spots.append(spot)
		if not select_slug.is_empty() and spot.entry.get("slug", "") == select_slug:
			selected = i
	var lead := lead_jarling()
	var stand := HubLayout.stand_position(selected, count)
	lead.hop_goal = Vector3.INF
	lead.position = stand
	lead.rotation.y = PI
	var other := jarlings[1 - jarlings.find(lead)]
	other.hop_goal = Vector3.INF
	other.position = stand + Vector3(1.7 if stand.x <= 0.0 else -1.7, 0, 1.3)
	other.rotation.y = PI
	focus = [-1, -1]
	_hop_index = [-1, -1]
	_update_focus(true)


func selected_entry() -> Dictionary:
	var f: int = focus[jarlings.find(lead_jarling())]
	return spots[f].entry if f >= 0 else {}


# ---------------------------------------------------------------- Jarlings and players

func index_of_profile(id: String) -> int:
	return maxi(LaunchArgs.PROFILES.find(id), 0)


## The Jarling the camera favours: the picked one in solo play, Jeff when both are held.
func lead_jarling() -> HubJarling:
	return jarlings[0] if two_players else jarlings[index_of_profile(profile)]


## Solo: the one controller holds the picked Jarling and the other tags along.
## Two players: P1 always holds Jeff (green), P2 always holds Chuck (red).
func jarling_for(player: int) -> HubJarling:
	if two_players:
		return jarlings[player]
	return lead_jarling() if player == Players.P1 else null


func _apply_roles() -> void:
	var lead := lead_jarling()
	for j in jarlings:
		var held := two_players or j == lead
		j.follow = null if held else lead
		j.set_held(held)
		if not held:
			j.move_input = Vector2.ZERO
			j.hop_goal = Vector3.INF


func _on_player_joined(player: int, _device: int) -> void:
	if player == Players.P2:
		join_second_player()


func _on_player_left(player: int) -> void:
	if player == Players.P2:
		two_players = false
		_apply_roles()


## P2 drops in (second pad, or the P2 keys): takes Chuck, wherever he is.
func join_second_player() -> void:
	if two_players:
		return
	two_players = true
	_apply_roles()
	jarlings[1].cheer()


## Solo profile pick: B swaps which Jarling you are. The pick is remembered.
func pick_profile(id: String) -> void:
	if two_players or not id in LaunchArgs.PROFILES or id == profile:
		return
	profile = id
	LauncherState.set_profile(Save, id)
	Save.flush()
	Audio.play("ui_confirm")
	_apply_roles()
	lead_jarling().cheer()
	_update_focus(true)


## Sideways push: run straight to the next jar that way. At the end of the row the jar just wobbles.
func hop(player: int, dir: int) -> void:
	var j := jarling_for(player)
	if j == null or j.busy:
		return
	var ji := jarlings.find(j)
	var from: int = _hop_index[ji] if j.hop_goal != Vector3.INF else focus[ji]
	var target := HubLayout.hop_target(from, dir, j.position, spots.size())
	Audio.play("ui_move")
	if target == from:
		spots[target].wobble()
		return
	_hop_index[ji] = target
	j.hop_to(spots[target].stand_point)


func _process(delta: float) -> void:
	_clock += delta
	_run_demo()
	if screen == Screen.HUB and not _launching and Time.get_ticks_msec() >= _input_from_ms:
		_read_players(delta)
		if _dev_combo.update(Input.is_action_pressed("launcher_lb"), Input.is_action_pressed("launcher_rb"), delta):
			_toggle_dev()
	_update_focus()
	_update_camera(delta)
	for n in get_tree().get_nodes_in_group("hub_bob"):
		n.position.y += sin(_clock * 0.5 + n.position.x) * 0.25 * delta
	for n in get_tree().get_nodes_in_group("hub_drift"):
		n.position.x += 0.35 * delta


func _read_players(delta: float) -> void:
	for player: int in [Players.P1, Players.P2]:
		var j := jarling_for(player)
		if j == null:
			for a: String in Players.ACTIONS:   # P2 keys with no pad: any press joins
				if Input.is_action_just_pressed(Players.action(player, a)) and not _same_key_as_p1(a):
					join_second_player()
			continue
		var v := Players.move_vector(player)
		if player == Players.P1 and _clock < _demo_move_until:
			v = _demo_move
		if j.busy:
			continue
		if HubLayout.is_hop_push(v):
			_hop_timer[player] -= delta
			if not _hop_held[player] or (_hop_timer[player] <= 0.0 and j.hop_goal == Vector3.INF):
				_hop_held[player] = true
				_hop_timer[player] = HOP_REPEAT
				hop(player, 1 if v.x > 0.0 else -1)
			j.move_input = Vector2.ZERO
		else:
			_hop_held[player] = false
			j.move_input = v
		if Input.is_action_just_pressed(Players.action(player, "action")):
			press_action(player)
		if Input.is_action_just_pressed(Players.action(player, "jump")):
			if two_players:
				Audio.play("ui_move")
				j.cheer(0.6)
			else:
				pick_profile(LaunchArgs.PROFILES[1 - index_of_profile(profile)])


## Before any pad joins, P1 and P2 pad events both match every device; only the keyboard can tell
## a P2 press apart, so a pad press never counts as "P2 joined" here (Players handles real pads).
func _same_key_as_p1(action_name: String) -> bool:
	return Input.is_action_pressed(Players.action(Players.P1, action_name))


## A: at a jar, jump in and play. At the empty jar, it wobbles. Anywhere else, a happy little cheer.
func press_action(player: int) -> void:
	var j := jarling_for(player)
	if j == null or j.busy or _launching:
		return
	var f: int = focus[jarlings.find(j)]
	if f < 0:
		Audio.play("ui_move")
		j.cheer(0.6)
	elif spots[f].empty:
		Audio.play("ui_back")
		spots[f].wobble()
	else:
		_launch(spots[f], j)


func _update_focus(silent: bool = false) -> void:
	var colors := {}
	for i in jarlings.size():
		var j := jarlings[i]
		var f := -1
		if j.follow == null and j.hop_goal == Vector3.INF:
			# mid-jump (into or out of a jar) a Jarling keeps the jar it was at
			f = focus[i] if j.busy and focus[i] >= 0 else HubLayout.focus_at(j.position, spots.size())
		if f != focus[i]:
			if f >= 0 and f != _hop_index[i] and not silent:
				Audio.play("ui_move")   # walked up to a jar (a hop already made its sound)
			if f >= 0:
				_hop_index[i] = -1
			focus[i] = f
		if f >= 0 and not colors.has(f):
			colors[f] = j.color
		j.face_point = spots[f].position if f >= 0 else Vector3(j.position.x * 0.6, 0, 40)
	for i in spots.size():
		spots[i].set_highlighted(colors.has(i), colors.get(i, Color.WHITE))


# ---------------------------------------------------------------- launch and return

func _toggle_dev() -> void:
	var on := not LauncherState.show_dev(Save)
	LauncherState.set_show_dev(Save, on)
	Save.flush()
	Audio.play("ui_toggle")
	var keep: String = selected_entry().get("slug", "")
	set_entries(ManifestScanner.filter_dev(all_entries, on), keep)
	for s in spots:
		if s.entry.get("dev", false):
			s.bounce()
	print("launcher: dev builds %s" % ("shown" if on else "hidden"))


func _launch(spot: GameSpot, j: HubJarling) -> void:
	var entry := spot.entry
	var cmd := LaunchArgs.build(entry, j.profile_id)
	LauncherState.set_last_card(Save, entry.slug)
	LauncherState.set_profile(Save, j.profile_id)   # whoever jumps in is the profile that plays
	if not two_players:
		profile = j.profile_id
	Save.flush()
	_launching = true
	_launcher_index = jarlings.find(j)
	if not entry.binary.is_empty():
		_ensure_executable(entry.binary)
	Audio.play("launch")
	spot.launch_flash()
	await j.jump_into(spot.mouth_position()).finished
	print("launcher: starting %s %s" % [cmd.path, " ".join(cmd.args)])
	var pid := OS.create_process(cmd.path, cmd.args) if not cmd.path.is_empty() else -1
	_launching = false
	if pid <= 0:
		push_warning("launcher: could not start %s" % cmd.path)
		Audio.play("ui_back")
		spot.wobble()
		j.jump_out(spot.mouth_position(), spot.stand_point)
		return
	_pid = pid
	_running_slug = entry.slug
	launched.emit(entry.slug, j.profile_id)
	_set_screen(Screen.RUNNING)


func _on_process_watch() -> void:
	if screen != Screen.RUNNING or OS.is_process_running(_pid):
		return
	print("launcher: %s exited (code %d)" % [_running_slug, OS.get_process_exit_code(_pid)])
	_pid = -1
	_rescan(_running_slug)   # pick up games installed or updated meanwhile
	_set_screen(Screen.HUB)
	_input_from_ms = Time.get_ticks_msec() + RETURN_GRACE_MS
	var j := jarlings[_launcher_index]
	var f := HubLayout.focus_at(lead_jarling().position, spots.size())
	if f >= 0:
		var spot := spots[f]
		j.jump_out(spot.mouth_position(), spot.stand_point if j == lead_jarling() else j.position)
		spot.bounce()
	else:
		j.visible = true
		j.busy = false


## While a game runs: hidden, no input, ~10 fps, and minimised if MINIMIZE_WHILE_RUNNING.
func _set_screen(to: Screen) -> void:
	var was_running := screen == Screen.RUNNING
	screen = to
	var running := to == Screen.RUNNING
	if running != was_running:
		_apply_window_policy(running)
	visible = not running
	for n: Node in [world, spot_root] + jarlings:
		n.process_mode = Node.PROCESS_MODE_DISABLED if running else Node.PROCESS_MODE_INHERIT
	OS.low_processor_usage_mode = running
	OS.low_processor_usage_mode_sleep_usec = IDLE_SLEEP_USEC if running else 6900
	if running:
		Audio.stop_music()
		process_watch.start()
	else:
		Audio.music("card_row_loop")   # no-op if already playing
		process_watch.stop()


func _apply_window_policy(running: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if running:
		_window_mode_before_run = DisplayServer.window_get_mode()
	var mode := WindowPolicy.mode_for(running, MINIMIZE_WHILE_RUNNING, _window_mode_before_run)
	if mode == WindowPolicy.LEAVE:
		return
	DisplayServer.window_set_mode(mode)
	if not running:
		DisplayServer.window_move_to_foreground()


static func _ensure_executable(path: String) -> void:
	var perms := FileAccess.get_unix_permissions(path)
	var x := FileAccess.UNIX_EXECUTE_OWNER | FileAccess.UNIX_EXECUTE_GROUP | FileAccess.UNIX_EXECUTE_OTHER
	if perms != 0 and perms & FileAccess.UNIX_EXECUTE_OWNER == 0:
		FileAccess.set_unix_permissions(path, perms | x)


# ---------------------------------------------------------------- camera, sky, lights

## One camera, never loses a player: it frames the held Jarlings and leans towards the jar in focus.
func _update_camera(delta: float) -> void:
	if not _intro_hold:
		_intro = minf(_intro + delta / INTRO_SECONDS, 1.0)
	var centre := Vector3.ZERO
	var spread := 0.0
	var held := 0
	for j in jarlings:
		if j.follow == null:
			centre += Vector3(j.position.x, 0, j.position.z)
			held += 1
	centre /= maxf(held, 1)
	if held == 2:
		spread = jarlings[0].position.distance_to(jarlings[1].position)
	var look := centre + Vector3(0, 1.3, -1.2)
	var f: int = focus[jarlings.find(lead_jarling())]
	var back := 9.6 + spread * 0.55
	var height := 3.1 + spread * 0.22
	if f >= 0 and held == 1:
		look = look.lerp(spots[f].position + Vector3(0, 1.9, 0), 0.5)
		back = 8.4
	var want := Vector3(centre.x * 0.62, height, centre.z + back)
	var k := smoothstep(0.0, 1.0, _intro)
	want = Vector3(0, 10.5, 27).lerp(want, k)
	look = Vector3(0, 1.5, -3).lerp(look, k)
	var ease := 1.0 if delta <= 0.0 else 1.0 - exp(-delta * 4.5)
	_cam_pos = _cam_pos.lerp(want, ease)
	_cam_look = _cam_look.lerp(look, ease)
	camera.fov = lerpf(52.0, 46.0, k)
	camera.look_at_from_position(_cam_pos, _cam_look)


func _build_sky_and_lights() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("sun_dir", SUN_DIR.normalized())
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_QUALITY   # the sky is static: built once
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_light_color = Color("e98aa0")
	env.fog_density = 0.0016
	env.fog_aerial_perspective = 0.55
	env.fog_sun_scatter = 0.08
	env.fog_sky_affect = 0.0
	env.fog_height = -7.0
	env.fog_height_density = 0.035
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()   # warm key from behind the jars: rim light on everything
	sun.light_color = Color("ffc48a")
	sun.light_energy = 2.3
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 36.0
	sun.directional_shadow_split_1 = 0.3
	sun.shadow_blur = 2.6
	add_child(sun)
	sun.look_at_from_position(LIGHT_DIR.normalized() * 10.0, Vector3.ZERO)
	var fill := DirectionalLight3D.new()  # cool fill from the camera side so faces never go dark
	fill.light_color = Color("b9b4ff")
	fill.light_energy = 0.75
	fill.shadow_enabled = false
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)
	fill.look_at_from_position(Vector3(-0.5, 0.7, 1.0) * 10.0, Vector3.ZERO)


# ---------------------------------------------------------------- scripted demo (screenshots only)

## HUB_DEMO="wide;2:follow;3:right;5:walk:-0.6:0.7:1.5;7:p2;8:a" drives the hub without a pad so
## shots.sh can frame it. Entries are `time:command[:args]`; a bare first word runs at time 0.
func _parse_demo(text: String) -> void:
	for part in text.split(";", false):
		var bits := part.split(":")
		if not bits[0].is_valid_float():
			bits.insert(0, "0")
		_demo.append(bits)


func _run_demo() -> void:
	while not _demo.is_empty() and _clock >= float(_demo[0][0]):
		var d: PackedStringArray = _demo.pop_front()
		match d[1]:
			"wide": _intro_hold = true
			"follow": _intro_hold = false
			"left": hop(Players.P1, -1)
			"right": hop(Players.P1, 1)
			"left2": hop(Players.P2, -1)
			"right2": hop(Players.P2, 1)
			"p2": join_second_player()
			"lead":   # lead:p1 / lead:p2, without touching the save
				profile = d[2]
				_apply_roles()
				set_entries(entries, LauncherState.last_card(Save))
			"a": press_action(Players.P1)
			"swap": pick_profile(LaunchArgs.PROFILES[1 - index_of_profile(profile)])
			"walk":
				_demo_move = Vector2(float(d[2]), float(d[3]))
				_demo_move_until = _clock + float(d[4])
