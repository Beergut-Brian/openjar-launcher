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
const DEMO_STOP := 0.5            # --demo: a walking Jarling counts as "there" this close to the stand point
const DEMO_PAUSE := 1.6           # --demo tour: how long it stands at each jar before walking on
const INTRO_SECONDS := 2.6        # the camera glides in from the wide shot; input works throughout
## The wide shot: where the camera glide starts, and where the intro (HubIntro) ends.
const WIDE_POS := Vector3(0, 10.5, 27)
const WIDE_LOOK := Vector3(0, 1.5, -3)
const SKY_SHADER := preload("res://assets/shaders/hub/sky.gdshader")
## Fallback bodies by profile id, only if the Roster has no model for a pick (no data/roster.json).
const MODELS := {
	"p1": preload("res://assets/models/jarlings/grownup.glb"),
	"p2": preload("res://assets/models/jarlings/kid.glb"),
}
const SIZES := {"p1": 1.15, "p2": 0.86}
const CHARACTER_SIZE := 1.15      # every Roster character: their own build already sets their height
## Jeff (left) and Chuck (right) live on the island; nobody controls them. A resident who is the
## same character as one of the two held Jarlings is hidden, so nobody is on screen twice.
const RESIDENTS := [["jeff", Vector3(-5.6, 0, 1.4)], ["chuck", Vector3(5.6, 0, 1.4)]]
## The in-line chooser: Back / View / Select on the pad (JOY_BUTTON_BACK), Tab (P1) or / (P2) on the
## keyboard. A button nothing else in the hub uses and a small one a kid does not mash. GAME.md.
const CHANGE_BUTTON := JOY_BUTTON_BACK
const CHANGE_SOUND := "intro_pop"  # the chooser's swap sound, at once on every step
## Chooser voice (Kaden 2026-11-10; docs/roster.md "Chooser voice"): quiet this long after the last
## step (or P2's join, or a profile swap) has landed, then the character now shown says its
## catchphrase once. Launcher: the settle counts only once the Jarling's swap animation is done,
## since presses are ignored mid-swap (0.39 s, longer than the settle). Fast scrolling says only the
## one you stop on; standing still says nothing more.
const SAY_SETTLE := 0.3
## A-05: the launching character's own voice on top of the beat sounds: a happy bark as it leaps
## into the jar, another as it pops back out. First one the character has; none: just the beat sound.
const LEAP_BARKS := ["ready", "cheer", "join"]
const RETURN_BARKS := ["win", "join", "cheer"]
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
var _change_down: Array[bool] = [false, false]   # by player: the change button was down last frame

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
var _intro := 0.0
var _intro_hold := false
var _cam_pos := WIDE_POS
var _cam_look := WIDE_LOOK
var _clock := 0.0
var _demo: Array = []
var _demo_move := Vector2.ZERO
var _demo_move_until := 0.0
var _demo_goal: Array[int] = [-1, -1]   # by player: the jar a "go" command is walking to
var _demo_tour := false
var _demo_tour_dir := 1
var _demo_rest := 0.0
## Chooser voice: seconds until this player's catchphrase; < 0 nothing pending.
var _say_in := { Players.P1: -1.0, Players.P2: -1.0 }
## The opening (first boot of each day; A skips). null when it is not playing.
var intro: HubIntro = null
var _demo_zero := 0.0                    # demo times count from here (the end of the intro, if any)

@onready var camera: Camera3D = $Camera
@onready var world: Node3D = $World
@onready var spot_root: Node3D = $Spots
@onready var process_watch: Timer = $ProcessWatch


func _ready() -> void:
	_build_sky_and_lights()
	HubWorld.build(world)
	profile = LauncherState.profile(Save)
	var demo := demo_script(OS.get_environment("HUB_DEMO"), OS.get_cmdline_args() + OS.get_cmdline_user_args())
	if not demo.is_empty():   # a demo or shots run never changes anybody's real picks
		Roster.picks_path = DEMO_PICKS
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DEMO_PICKS))
	Roster.profile_override = profile   # the picks entry follows the hub's profile, not the launcher's Save
	Roster.reload()
	for id: String in LaunchArgs.PROFILES:   # built as the picks straight away (lead = P1's pick)
		var pick := Roster.pick(Players.P1 if id == profile else Players.P2)
		var scene := character_scene(pick)
		var j := HubJarling.new()
		add_child(j)
		j.setup(scene if scene else MODELS[id], id, Players.COLOR[jarlings.size()],
				CHARACTER_SIZE if scene else SIZES[id])
		j.character_id = pick if scene else ""
		jarlings.append(j)
	for r: Array in RESIDENTS:
		var scene := character_scene(r[0])
		if scene == null:
			continue   # a roster without this resident (a fixture): no half-built Jarling left behind
		var j := HubJarling.new()
		add_child(j)
		j.setup(scene, "", Color.WHITE, CHARACTER_SIZE)
		j.character_id = r[0]
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
	two_players = Players.is_active(Players.P2)
	Players.player_joined.connect(_on_player_joined)
	Players.player_left.connect(_on_player_left)
	_apply_roles()
	apply_characters()
	_rescan(LauncherState.last_card(Save))
	process_watch.wait_time = POLL_SECONDS
	process_watch.timeout.connect(_on_process_watch)
	_parse_demo(demo)
	if wants_intro(demo, OS.get_cmdline_args(), LauncherState.should_play_intro(Save, LauncherState.today())):
		if demo.is_empty():
			LauncherState.mark_intro_played(Save, LauncherState.today())
			Save.flush()
		play_intro()
	else:
		Audio.music("card_row_loop")
	_update_camera(0.0)
	_report_cold_start()


## The intro plays on the first boot of each local day (GAME.md decisions), or when a demo script asks
## for it ("intro"). Other demo and shots runs, and test runs, never play it on their own.
static func wants_intro(demo: String, args: PackedStringArray, first_boot_today: bool) -> bool:
	if "intro" in demo.split(";", false):
		return true
	if not demo.is_empty() or Roster.is_test_run(args):
		return false
	return first_boot_today


func intro_playing() -> bool:
	return intro != null and is_instance_valid(intro) and intro.active


## The opening: the whole playable roster tumbles out of a big jar (HubIntro). The Jarlings wait
## out of sight and pop in when it ends (or A skips it).
func play_intro(who: Array[String] = HubIntro.cast()) -> HubIntro:
	intro = HubIntro.new()
	add_child(intro)
	intro.finished.connect(_on_intro_finished)
	for n: HubJarling in jarlings + residents:
		n.visible = false
	intro.start(who)
	_intro = 0.0
	return intro


func _on_intro_finished() -> void:
	intro = null
	_demo_zero = _clock
	_intro = 0.0   # the hub's glide carries on from the wide shot the intro ended on
	for j in jarlings:
		j.visible = true
		HubJarling.poof(self, j.position + Vector3(0, 0.6, 0), j.color)
		j.cheer(0.8)
	_update_residents()


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
	lead.position = stand
	lead.rotation.y = PI
	var other := jarlings[1 - jarlings.find(lead)]
	other.position = stand + Vector3(1.7 if stand.x <= 0.0 else -1.7, 0, 1.3)
	other.rotation.y = PI
	for j in jarlings:
		j.jar_count = count
		j.stop()
	focus = [-1, -1]
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
	_update_hints()


func _on_player_joined(player: int, _device: int) -> void:
	_update_hints()
	if player == Players.P2:
		join_second_player()


func _on_player_left(player: int) -> void:
	if player == Players.P2:
		cancel_say(Players.P2)
		two_players = false
		_apply_roles()


## P2 drops in (second pad, or the P2 keys): takes the tag-along Jarling, wherever it is.
func join_second_player() -> void:
	if two_players:
		return
	two_players = true
	_change_down[Players.P2] = true   # the press that joined never also changes the character
	_apply_roles()
	jarling_for(Players.P2).cheer()
	say_soon(Players.P2)   # the pick shown on joining says its catchphrase
	for r in residents:
		if r.visible:
			r.cheer()


## Solo profile pick: B swaps which Jarling you are. The pick is remembered.
func pick_profile(id: String) -> void:
	if two_players or launch.active or not id in LaunchArgs.PROFILES or id == profile:
		return
	var was := lead_jarling()
	profile = id
	LauncherState.set_profile(Save, id)
	Save.flush()
	Roster.profile_override = id   # that profile's picks
	Roster.reload()
	Audio.play("ui_confirm")
	# You stay where you are: the two Jarlings trade places, then show the new profile's picks.
	var now := lead_jarling()
	var at := [was.position, was.rotation.y]
	was.position = now.position
	was.rotation.y = now.rotation.y
	now.position = at[0]
	now.rotation.y = at[1]
	was.stop()
	now.stop()
	_apply_roles()
	apply_characters(true, true)
	_update_focus(true)
	say_soon(Players.P1)   # you are someone new: they say who they are


func _process(delta: float) -> void:
	_clock += delta
	_run_demo()
	voice_step(delta)
	if intro_playing():
		for p: int in [Players.P1, Players.P2]:
			if Input.is_action_just_pressed(Players.action(p, "action")):
				intro.skip()
				break
	elif screen == Screen.HUB and not launch.active and Time.get_ticks_msec() >= _input_from_ms:
		_read_players()
		if _dev_combo.update(Input.is_action_pressed("launcher_lb"), Input.is_action_pressed("launcher_rb"), delta):
			_toggle_dev()
	for j in jarlings:
		j.hint_enabled = screen == Screen.HUB and not launch.active and j.follow == null
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


## Every stick, D-pad or key direction walks the Jarling (full tilt runs). Nothing snaps to a jar:
## you walk up to one and it comes into focus.
func _read_players() -> void:
	for player: int in [Players.P1, Players.P2]:
		var j := jarling_for(player)
		var change := _change_just_pressed(player)
		if j == null:
			for a: String in Players.ACTIONS:   # P2 keys with no pad: any press joins
				if Input.is_action_just_pressed(Players.action(player, a)) and not _same_key_as_p1(a):
					join_second_player()
			continue
		var v := Players.move_vector(player)
		if player == Players.P1 and _clock < _demo_move_until:
			v = _demo_move
		if _demo_goal[player] >= 0:
			v = _demo_steer(player, j)
		if j.busy:
			continue
		j.move_input = v
		if Input.is_action_just_pressed(Players.action(player, "action")):
			press_action(player)
		if Input.is_action_just_pressed(Players.action(player, "jump")):
			if two_players:
				Audio.play("ui_move")
				j.cheer(0.6)
			else:
				pick_profile(LaunchArgs.PROFILES[1 - index_of_profile(profile)])
		if change:
			change_character(player)


## Edge of the change button for `player`: their key, or Back on their own pad (read by device, so
## one pad's Back never changes the other player's character). Updated every frame, held or not.
func _change_just_pressed(player: int) -> bool:
	var down := Input.is_action_pressed(Players.action(player, "change"))
	var dev := Players.device_of(player)
	if dev >= 0 and Input.is_joy_button_pressed(dev, CHANGE_BUTTON):
		down = true
	var edge := down and not _change_down[player]
	_change_down[player] = down
	return edge


## The in-line chooser. Cycles `player`'s Roster pick in roster order. Two players: the other
## player's pick is skipped (nobody free: a head shake and a low sound). Solo: the tag-along friend is
## nobody's pick in play, so cycling onto it trades with it. Works anywhere in the hub except during
## the launch (and while that Jarling is mid-jump or mid-swap). True if the character changed.
func change_character(player: int) -> bool:
	var j := jarling_for(player)
	if j == null or j.busy or j.swapping or launch.active or screen != Screen.HUB:
		return false
	var now := Roster.pick(player)
	var to := Roster.next_free(player, 1)
	if not two_players:
		var list := Roster.roster()
		to = list[(list.find(now) + 1) % list.size()] if not list.is_empty() else now
	if to == now or not Roster.set_pick(player, to, not two_players):
		Audio.play("ui_back")
		j.shake()
		return false
	apply_characters(true)
	Audio.play(CHANGE_SOUND)
	say_soon(player)
	return true


## Chooser voice: (re)start this player's settle; the catchphrase comes SAY_SETTLE s after the
## last call.
func say_soon(player: int) -> void:
	_say_in[player] = SAY_SETTLE


func cancel_say(player: int) -> void:
	_say_in[player] = -1.0


## Is a catchphrase waiting for its settle?
func say_pending(player: int) -> bool:
	return _say_in[player] >= 0.0


## Count the settles down; a finished one says the shown character once, on the player's own voice
## (it cuts off only that player's previous line). No catchphrase or bark: nothing more (the step
## already made its swap sound). Nothing during a launch.
func voice_step(delta: float) -> void:
	for p in [Players.P1, Players.P2]:
		if _say_in[p] < 0.0:
			continue
		var j := jarling_for(p)
		if j != null and j.swapping:
			continue   # the settle starts once the new character has popped in (swap_to: 0.39 s)
		_say_in[p] -= delta
		if _say_in[p] > 0.0:
			continue
		_say_in[p] = -1.0
		var id := Roster.pick(p)
		if (p == Players.P2 and not two_players) or launch.active or id == "":
			continue
		var ok := Roster.catchphrase(id, p)
		print("Chooser voice: P%d %s %s (t=%.2f s)" % [p + 1, id,
				Roster.last_said.get(p, "") if ok else "(no voice)", Time.get_ticks_msec() / 1000.0])


## The first of `names` that this Jarling's character has as a voice bark, on its player's voice
## (a tag-along uses the shared one). The path said, or "" if it has none (the beat sound covers it).
func shout(j: HubJarling, names: Array) -> String:
	var path := bark_path(Roster.info(j.character_id), names)
	if path == "":
		return ""
	var player := -1
	if j == lead_jarling():
		player = Players.P1
	elif two_players:
		player = Players.P2
	var v := Roster.voice_player(player)
	if v == null:
		return ""
	v.stop()
	v.stream = load(path)
	v.play()
	return path


static func bark_path(info: Dictionary, names: Array) -> String:
	var voice: String = info.get("voice", "")
	var barks: Array = info.get("barks", [])
	if voice == "":
		return ""
	for b: String in names:
		var path := "%s%s.ogg" % [voice, b]
		if barks.has(b) and ResourceLoader.exists(path):
			return path
	return ""


## A Roster character's model, or null if it has none (the hub then keeps the fallback body).
func character_scene(id: String) -> PackedScene:
	var who := Roster.info(id)
	if who.is_empty() or who.glb == "" or not ResourceLoader.exists(who.glb):
		return null
	return load(who.glb) as PackedScene


## Dress the held Jarlings as the picks: player 1's Jarling (the lead) is Roster.pick(P1), the other
## one (player 2's, or the tag-along) Roster.pick(P2). animate: the chooser's swap for the ones that
## change (and for the lead even if unchanged when `always_lead`, the profile swap's "it's you" pop).
## Then hide any resident who is now on screen twice.
func apply_characters(animate: bool = false, always_lead: bool = false) -> void:
	var lead := lead_jarling()
	for j in jarlings:
		var id := Roster.pick(Players.P1 if j == lead else Players.P2)
		var scene := character_scene(id)
		if scene == null:
			if j.character_id != "":
				j.set_character("", MODELS[j.profile_id])
			continue
		if j.character_id == id and not (animate and always_lead and j == lead):
			continue
		if animate and not j.busy:
			j.swap_to(id, scene, str(Roster.info(id).name))
		else:
			j.set_character(id, scene)
	_update_residents()
	_update_hints()


func _update_residents() -> void:
	for r in residents:
		r.visible = jarlings.all(func(j: HubJarling) -> bool: return j.character_id != r.character_id)


## The chooser hint by each held ring, a picture (K-01): the pad's Select button and swap arrows in
## the player's colour; with no pad at all, the player's key (Tab for P1, slash for P2).
func _update_hints() -> void:
	var pads := not Input.get_connected_joypads().is_empty()
	for p: int in [Players.P1, Players.P2]:
		var j := jarling_for(p)
		if j != null:
			var key := HintGlyph.Kind.TAB if p == Players.P1 else HintGlyph.Kind.SLASH
			j.set_hint_glyph(HintGlyph.Kind.SELECT if Players.device_of(p) >= 0 or pads else key, Players.COLOR[p])


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
		if j.follow == null:
			# mid-jump (into or out of a jar) a Jarling keeps the jar it was at
			f = focus[i] if j.busy and focus[i] >= 0 else HubLayout.focus_at(j.position, spots.size(), focus[i])
		if f != focus[i]:
			if f >= 0 and not silent:
				Audio.play("ui_move")   # walked up to a jar: a sound, the jar bounces and its pad lights
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
	cancel_say(Players.P1)
	cancel_say(Players.P2)
	var entry := spot.entry
	_launch_cmd = LaunchArgs.build(entry, j.profile_id, current_chars())
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
			shout(j, LEAP_BARKS)   # "here I go!" in the character's own voice
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
	Roster.reload()           # a pick changed inside the game shows up here
	apply_characters()
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
		shout(j, RETURN_BARKS)   # "I'm back!"
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
	print("launcher: %s" % WindowPolicy.report(running, mode, DisplayServer.window_get_mode()))


## The picks on screen, for the game's --p1-char= / --p2-char= (its Roster reads them first).
func current_chars() -> Dictionary:
	var out := {}
	for p: int in [Players.P1, Players.P2]:
		if Roster.pick(p) != "":
			out[p] = Roster.pick(p)
	return out


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
	if intro_playing():
		var pose := intro.camera_pose(WIDE_POS, WIDE_LOOK)
		_cam_pos = pose[0]
		_cam_look = pose[1]
		camera.fov = 52.0
		camera.look_at_from_position(_cam_pos, _cam_look)
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
	want = WIDE_POS.lerp(want, k)
	look = WIDE_LOOK.lerp(look, k)
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

## The default scripted tour for `--demo` (when HUB_DEMO is not set): the Jarling runs from jar to
## jar along the row and back, forever, and player 2 joins after a while. It never presses A.
const DEMO_TOUR := "tour;9:p2"
## Demo runs keep their picks here (fresh each run), never in the shared players.json.
const DEMO_PICKS := "user://demo_players.json"


## HUB_DEMO wins; else `--demo` on the command line plays DEMO_TOUR; else nothing.
static func demo_script(env: String, args: PackedStringArray) -> String:
	if not env.is_empty():
		return env
	return DEMO_TOUR if args.has("--demo") else ""


## HUB_DEMO="wide;2:follow;3:go:4;5:walk:-0.6:0.7:1.5;7:p2;8:a" drives the hub without a pad so
## shots.sh can frame it. Entries are `time:command[:args]`; a bare first word runs at time 0.
## go:<jar> / go2:<jar> walk player 1 / 2 to that jar with a simulated stick (running, then easing
## in); tour keeps player 1 walking along the row.
func _parse_demo(text: String) -> void:
	for part in text.split(";", false):
		var bits := part.split(":")
		if not bits[0].is_valid_float():
			bits.insert(0, "0")
		_demo.append(bits)


func _run_demo() -> void:
	if intro_playing():
		return   # the script waits for the intro; its times count from the intro's end
	if _demo_tour and _demo_goal[Players.P1] < 0 and spots.size() > 1 and not launch.active:
		_demo_rest -= get_process_delta_time()
		if _demo_rest <= 0.0:
			var at := HubLayout.nearest(lead_jarling().position, spots.size())
			if at + _demo_tour_dir < 0 or at + _demo_tour_dir >= spots.size():
				_demo_tour_dir = -_demo_tour_dir
			_demo_goal[Players.P1] = at + _demo_tour_dir
			_demo_rest = DEMO_PAUSE
	while not _demo.is_empty() and _clock - _demo_zero >= float(_demo[0][0]):
		var d: PackedStringArray = _demo.pop_front()
		match d[1]:
			"intro": pass   # handled in _ready (wants_intro)
			"wide": _intro_hold = true
			"follow": _intro_hold = false
			"go": _demo_goal[Players.P1] = clampi(int(d[2]), 0, spots.size() - 1)
			"go2": _demo_goal[Players.P2] = clampi(int(d[2]), 0, spots.size() - 1)
			"tour": _demo_tour = true
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
			"change": change_character(Players.P1)    # the in-line chooser, as if Select was pressed
			"change2": change_character(Players.P2)
			"walk":
				_demo_move = Vector2(float(d[2]), float(d[3]))
				_demo_move_until = _clock + float(d[4])


## A pretend stick for "go": full tilt towards the jar's stand point, easing off at the end, and let
## go once there (the walk-up focus does the rest, as it would for a kid).
func _demo_steer(player: int, j: HubJarling) -> Vector2:
	var goal := spots[_demo_goal[player]].stand_point - j.position
	var flat := Vector2(goal.x, goal.z)
	if flat.length() < DEMO_STOP or j.busy:
		_demo_goal[player] = -1
		return Vector2.ZERO
	return flat.normalized() * clampf(flat.length() / 1.5, 0.35, 1.0)
