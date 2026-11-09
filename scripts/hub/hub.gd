## The hub: a floating island at magic hour where Jarlings walk up to giant jars and jump in to play.
## Flow: boot → hub (standing at the last game's jar) → A → launch animation (LaunchSequence: lid
## spins off, Jarling leaps in, camera dives into the jar's tiny world) → (game runs) → pop back out.
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
## Profile id → Jarling: two generic kit Jarlings, a grown-up and a kid. Not player-locked.
const MODELS := {
	"p1": preload("res://assets/models/jarlings/grownup.glb"),
	"p2": preload("res://assets/models/jarlings/kid.glb"),
}
const SIZES := {"p1": 1.15, "p2": 0.86}
## Jeff (P1 side, left) and Chuck (P2 side, right) live on the island; nobody controls them.
const RESIDENTS := [
	[preload("res://assets/models/jarlings/jeff.glb"), Vector3(-5.6, 0, 1.4)],
	[preload("res://assets/models/jarlings/chuck.glb"), Vector3(5.6, 0, 1.4)],
]
const SUN_DIR := Vector3(0.42, 0.2, -1.0)   # the sun you see: low behind the jars, a little to the right
## The light itself comes from higher up on the same bearing, so shadows stay short and crisp.
const LIGHT_DIR := Vector3(0.42, 0.46, -1.0)

signal launched(slug: String, profile_id: String)

var screen: Screen = Screen.HUB
var root_dir := ""
var all_entries: Array[Dictionary] = []
var entries: Array[Dictionary] = []      # the ones with a jar (dev filter applied)
var spots: Array[GameSpot] = []
var jarlings: Array[HubJarling] = []     # [grown-up (p1), kid (p2)]
var residents: Array[HubJarling] = []    # [Jeff, Chuck]
var launch := LaunchSequence.new()       # active while the launch animation plays
var focus: Array[int] = [-1, -1]         # jar each Jarling is looking into, by Jarling index
var profile := "p1"                      # the Jarling player 1 picked; remembered
var two_players := false

var _pid := -1
var _running_slug := ""
var _launcher_index := 0
var _launch_spot: GameSpot
var _launch_cmd := {}
var _launch_from := Vector3.ZERO         # where the Jarling stood when A was pressed
var _launch_cam: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _lid_ground := Vector3.ZERO
var _dived := false                      # the camera is inside the jar (until the game returns)
var _cam_snap := false
var _flash: ColorRect
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
		j.setup(MODELS[id], id, Players.COLOR[jarlings.size()], SIZES[id])
		jarlings.append(j)
	for r: Array in RESIDENTS:
		var j := HubJarling.new()
		add_child(j)
		j.setup(r[0], "", Color.WHITE)
		j.set_held(false)
		j.position = r[1]
		j.rotation.y = atan2(-j.position.x, 6.0)
		residents.append(j)
	var layer := CanvasLayer.new()
	add_child(layer)
	_flash = ColorRect.new()   # the launch ends in a flash of the jar's colour
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	layer.add_child(_flash)
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
	launch.cancel()
	for s in spots:
		spot_root.remove_child(s)
		s.queue_free()
	spots.clear()
	entries = list
	var count := HubLayout.spot_count(list.size())
	var selected := (count - 1) / 2
	var kinds := JarWorld.assign(list.map(func(e: Dictionary) -> String: return e.slug))
	for i in count:
		var spot := GameSpot.new()
		spot_root.add_child(spot)
		spot.setup(list[i] if i < list.size() else {}, i, kinds[i] if i < kinds.size() else -1)
		spot.place(HubLayout.jar_position(i, count), HubLayout.stand_position(i, count))
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


## Player 1's Jarling (the picked profile); the camera favours it.
func lead_jarling() -> HubJarling:
	return jarlings[index_of_profile(profile)]


## Player 1 holds the picked Jarling. The other one tags along until player 2 joins and takes it.
func jarling_for(player: int) -> HubJarling:
	if player == Players.P1:
		return lead_jarling()
	return jarlings[1 - index_of_profile(profile)] if two_players else null


## Rings are by player, not by Jarling: player 1 green, player 2 red.
func _apply_roles() -> void:
	var lead := lead_jarling()
	for j in jarlings:
		var held := two_players or j == lead
		j.follow = null if held else lead
		j.set_held(held, Players.COLOR[Players.P1 if j == lead else Players.P2])
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


## P2 drops in (second pad, or the P2 keys): takes the tag-along Jarling, wherever it is.
func join_second_player() -> void:
	if two_players:
		return
	two_players = true
	_apply_roles()
	jarling_for(Players.P2).cheer()
	residents[1].cheer()


## Solo profile pick: B swaps which Jarling you are. The pick is remembered.
func pick_profile(id: String) -> void:
	if two_players or launch.active or not id in LaunchArgs.PROFILES or id == profile:
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
	if j == null or j.busy or launch.active:
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
	if screen == Screen.HUB and not launch.active and Time.get_ticks_msec() >= _input_from_ms:
		_read_players(delta)
		if _dev_combo.update(Input.is_action_pressed("launcher_lb"), Input.is_action_pressed("launcher_rb"), delta):
			_toggle_dev()
	if launch.active:
		for beat in launch.advance(delta):
			_on_launch_beat(beat)
		_pose_launch()
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


## A: at a jar, the launch animation, then the game. At the empty jar, it wobbles. Anywhere else, a
## happy little cheer. Ignored while a launch is playing, so A spam never launches twice.
func press_action(player: int) -> void:
	var j := jarling_for(player)
	if j == null or j.busy or launch.active or screen != Screen.HUB:
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
	for r in residents:   # Jeff and Chuck watch whoever is playing
		r.face_point = lead_jarling().global_position if lead_jarling().visible else Vector3(0, 0, 40)
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


## A at a jar: remember the pick and start the launch animation. The game itself starts on its GO beat.
func _launch(spot: GameSpot, j: HubJarling) -> void:
	if not launch.start():
		return
	var entry := spot.entry
	_launch_cmd = LaunchArgs.build(entry, j.profile_id)
	LauncherState.set_last_card(Save, entry.slug)
	if not two_players:
		profile = j.profile_id
	LauncherState.set_profile(Save, profile)
	Save.flush()
	_launcher_index = jarlings.find(j)
	_launch_spot = spot
	_launch_from = j.global_position
	_launch_cam = [_cam_pos, _cam_look]
	# if nobody is near enough to wear it, the lid lands on the plaza beside the jar
	_lid_ground = spot.stand_point + spot.global_basis.x * 2.3 + Vector3(0, 0.02, 0)
	_flash.color = Color(spot.accent.lerp(Color.WHITE, 0.6), 0.0)
	for other in jarlings:
		other.move_input = Vector2.ZERO
	if not entry.binary.is_empty():
		_ensure_executable(entry.binary)


## One sound per beat, and the things that happen once. Everything else is posed from launch.t.
func _on_launch_beat(beat: int) -> void:
	var j := jarlings[_launcher_index]
	var friend := jarlings[1 - _launcher_index]
	match beat:
		LaunchSequence.Beat.RATTLE:
			Audio.play("jar_rattle")
			j.set_expression("determined")
		LaunchSequence.Beat.LID_POP:
			Audio.play("intro_pop")
			j.set_expression("surprised")
		LaunchSequence.Beat.LEAP:
			Audio.play("jarling_jump")
			j.set_expression("happy")
		LaunchSequence.Beat.LID_LAND:
			Audio.play("lid_land")
			if _lid_lands_on(friend):
				friend.set_expression("surprised")
				friend._squash()
		LaunchSequence.Beat.SPLASH:
			Audio.play("jar_splash")
			_launch_spot.splash()
		LaunchSequence.Beat.DIVE:
			Audio.play("launch")
			for r in residents:
				r.cheer(1.2)
		LaunchSequence.Beat.GO:
			_start_game()


func _lid_lands_on(friend: HubJarling) -> bool:
	return friend.visible and not friend.busy and friend.global_position.distance_to(_launch_spot.global_position) < 6.5


func _pose_launch() -> void:
	var j := jarlings[_launcher_index]
	var friend := jarlings[1 - _launcher_index]
	var t := launch.t
	var lid_to := friend.head_top() - Vector3(0, 0.12, 0) if _lid_lands_on(friend) else _lid_ground
	_launch_spot.launch_pose(t, lid_to)
	j.launch_pose(t, _launch_from, _launch_spot.mouth_position(), _launch_spot.inside_position())
	_flash.color.a = LaunchSequence.smooth(LaunchSequence.phase(t, LaunchSequence.T_GO - 0.18, LaunchSequence.T_GO))


## The GO beat: the animation is over, hand the TV to the game.
func _start_game() -> void:
	var entry := _launch_spot.entry
	var j := jarlings[_launcher_index]
	_dived = true
	_flash.color.a = 1.0
	print("launcher: starting %s %s" % [_launch_cmd.path, " ".join(_launch_cmd.args)])
	var pid := OS.create_process(_launch_cmd.path, _launch_cmd.args) if not _launch_cmd.path.is_empty() else -1
	if pid <= 0:
		push_warning("launcher: could not start %s" % _launch_cmd.path)
		Audio.play("ui_back")
		_play_return(j)
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
	_play_return(jarlings[_launcher_index])


## Back in the hub: the flash clears, the Jarling pops out of its jar and the lid drops back on.
func _play_return(j: HubJarling) -> void:
	_dived = false
	_cam_snap = true
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
	for other in jarlings:
		other.set_expression("neutral")
	var f := HubLayout.focus_at(lead_jarling().position, spots.size())
	if f < 0 and _launch_spot != null and is_instance_valid(_launch_spot):
		f = spots.find(_launch_spot)
	if f >= 0:
		var spot := spots[f]
		Audio.play("jar_pop_out")
		spot.splash()
		spot.drop_lid(0.5)
		j.jump_out(spot.mouth_position(), spot.stand_point if j == lead_jarling() else _launch_from)
	else:
		j.jump_out(j.global_position, j.global_position)


## While a game runs: hidden, no input, ~10 fps, and minimised if MINIMIZE_WHILE_RUNNING.
func _set_screen(to: Screen) -> void:
	var was_running := screen == Screen.RUNNING
	screen = to
	var running := to == Screen.RUNNING
	if running != was_running:
		_apply_window_policy(running)
	visible = not running
	for n: Node in [world, spot_root] + jarlings + residents:
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
	if launch.active or _dived:
		_launch_camera()
		return
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
	var ease := 1.0 if delta <= 0.0 or _cam_snap else 1.0 - exp(-delta * 4.5)
	_cam_snap = false
	_cam_pos = _cam_pos.lerp(want, ease)
	_cam_look = _cam_look.lerp(look, ease)
	camera.fov = lerpf(52.0, 46.0, k)
	camera.look_at_from_position(_cam_pos, _cam_look)


## The launch shot: lean in while the jar rattles, look up after the lid and the leap, then dive
## through the glass into the jar's tiny world until it fills the screen.
func _launch_camera() -> void:
	var L := LaunchSequence
	var t := launch.t
	var spot := _launch_spot
	var jar := spot.global_position
	var lean := L.smooth(L.phase(t, 0.0, L.T_POP))
	var pos: Vector3 = _launch_cam[0].lerp(jar + Vector3(0, 2.0, 0), 0.1 * lean)
	var look: Vector3 = _launch_cam[1].lerp(jar + Vector3(0, 2.3, 0), 0.7 * lean)
	look.y += 1.5 * sin(PI * L.phase(t, L.T_POP, L.T_DIVE))
	pos.y += 0.5 * sin(PI * L.phase(t, L.T_POP, L.T_DIVE))
	# The dive: up over the rim after the Jarling and down through the jar mouth, until the tiny
	# world fills the screen.
	var d := L.smooth(L.phase(t, L.T_DIVE - 0.15, L.T_GO))
	var out := ((_launch_cam[0] - jar) * Vector3(1, 0, 1)).normalized()
	var target := jar + Vector3(0, GameSpot.PLINTH_HEIGHT + 0.5, 0)
	var over := jar + out * 0.9 + Vector3(0, GameSpot.PLINTH_HEIGHT + GameSpot.JAR_HEIGHT + 1.7, 0)
	var end_pos := jar + out * 0.45 + Vector3(0, GameSpot.PLINTH_HEIGHT + 1.75, 0)
	camera.fov = lerpf(46.0, 62.0, d)
	camera.look_at_from_position(pos.lerp(over, d).lerp(over.lerp(end_pos, d), d), look.lerp(target, minf(d * 1.6, 1.0)))


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
			"slow": Engine.time_scale = float(d[2])   # slow motion, for frame strips of the launch
			"return":   # the return animation without running a game
				jarlings[_launcher_index].visible = false
				_play_return(jarlings[_launcher_index])
			"swap": pick_profile(LaunchArgs.PROFILES[1 - index_of_profile(profile)])
			"walk":
				_demo_move = Vector2(float(d[2]), float(d[3]))
				_demo_move_until = _clock + float(d[4])
