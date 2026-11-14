## Standing feel rules (2026-11-13): in the hub the D-pad walks the character, the same as the
## stick, on both pad slots, and never hops to a jar. Real pad events through Players and the input
## map. Throwaway Save profile and picks file (never the real players.json).
class_name TestHubDpad
extends GdUnitTestSuite

const PROFILE := "test_hub_dpad"
const HUB := "res://scenes/hub/hub.tscn"
const PICKS := "user://test_hub_dpad/players.json"
const DT := 1.0 / 60.0
const DPAD := [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]
const DIR := {JOY_BUTTON_DPAD_LEFT: Vector3.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector3.RIGHT,
		JOY_BUTTON_DPAD_UP: Vector3.FORWARD, JOY_BUTTON_DPAD_DOWN: Vector3.BACK}

var _saved_profile: String
var _saved_env: String


func before_test() -> void:
	_saved_env = OS.get_environment("OPENJAR_ROOT")
	_saved_profile = Save.profile
	Save.profile = PROFILE
	Save.wipe()
	Roster.picks_path = PICKS
	Roster.data_path = "res://tests/fixtures/roster_three.json"   # a fixture, never the real roster's contents
	Roster.args_override = PackedStringArray(["--test-hub-dpad"])
	LauncherState.reset_session()
	_free_pads()


func after_test() -> void:
	for d in [0, 1]:
		for b in DPAD:
			_button(d, b, false)
	await get_tree().process_frame
	_free_pads()
	Audio.release_all()
	Save.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % PROFILE))
	Save.profile = _saved_profile
	Save._load()
	for f in [PICKS, PICKS + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	Roster.picks_path = Roster.TEST_PICKS
	Roster.args_override = PackedStringArray()
	Roster.profile_override = ""
	Roster.reload()
	LauncherState.reset_session()
	OS.set_environment("OPENJAR_ROOT", _saved_env)
	OS.low_processor_usage_mode = false


## Nobody holds a pad: P1 matches every pad, P2 is parked (Players' own start state).
func _free_pads() -> void:
	Players._device_of[Players.P1] = -1
	Players._device_of[Players.P2] = -1
	Players._bind(Players.P1, -1)
	Players._bind(Players.P2, Players.PARKED)


func _hub() -> Node3D:
	OS.set_environment("OPENJAR_ROOT", ProjectSettings.globalize_path("res://tests/fixtures/hub_8"))
	var hub: Node3D = auto_free(load(HUB).instantiate())
	hub.really_quit = false
	add_child(hub)
	await get_tree().process_frame
	return hub


func _step(hub: Node3D, frames: int) -> void:
	hub.process_mode = Node.PROCESS_MODE_DISABLED
	for i in frames:
		hub._process(DT)
		for j: HubJarling in hub.jarlings:
			j._process(DT)
	hub.process_mode = Node.PROCESS_MODE_INHERIT


func _button(device: int, button: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	e.pressed = down
	Input.parse_input_event(e)


## Hold one D-pad direction on `device` for `frames`, let go, settle. The held Jarling's travel.
func _hold(hub: Node3D, device: int, button: int, j: HubJarling, frames: int = 30) -> Vector3:
	var at := j.position
	_button(device, button, true)
	await get_tree().process_frame
	_step(hub, frames)
	_button(device, button, false)
	await get_tree().process_frame
	_step(hub, 20)
	return j.position - at


## P1's pad (the first one to press): every D-pad direction walks P1's Jarling that way.
func test_dpad_walks_player_one_every_direction() -> void:
	var hub := await _hub()
	var p1: HubJarling = hub.jarling_for(Players.P1)
	_button(0, JOY_BUTTON_DPAD_DOWN, true)   # the first D-pad press claims the pad
	await get_tree().process_frame
	assert_int(Players.device_of(Players.P1)).is_equal(0)
	_button(0, JOY_BUTTON_DPAD_DOWN, false)
	await get_tree().process_frame
	_step(hub, 20)
	for b: int in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT]:
		var moved := await _hold(hub, 0, b, p1)
		var along := Vector3(moved.x, 0, moved.z).dot(DIR[b])
		assert_float(along).override_failure_message("P1 D-pad %d moved %s" % [b, moved]).is_greater(0.8)
	assert_int(hub.refusals).is_equal(0)   # walking is never a refusal


## P2's pad (the second one): its D-pad joins P2 and walks P2's Jarling, and never P1's.
func test_dpad_walks_player_two_every_direction() -> void:
	var hub := await _hub()
	_button(0, JOY_BUTTON_DPAD_DOWN, true)   # P1 takes pad 0 (not A: P1 starts at a jar, A would launch)
	await get_tree().process_frame
	_button(0, JOY_BUTTON_DPAD_DOWN, false)
	await get_tree().process_frame
	_button(1, JOY_BUTTON_DPAD_UP, true)   # a D-pad press on pad 1 joins P2
	await get_tree().process_frame
	assert_int(Players.device_of(Players.P2)).is_equal(1)
	assert_bool(hub.two_players).is_true()
	_button(1, JOY_BUTTON_DPAD_UP, false)
	await get_tree().process_frame
	_step(hub, 20)
	var p1: HubJarling = hub.jarling_for(Players.P1)
	var p2: HubJarling = hub.jarling_for(Players.P2)
	var p1_at := p1.position
	for b: int in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT]:
		var moved := await _hold(hub, 1, b, p2)
		var along := Vector3(moved.x, 0, moved.z).dot(DIR[b])
		assert_float(along).override_failure_message("P2 D-pad %d moved %s" % [b, moved]).is_greater(0.8)
	assert_float(p1.position.distance_to(p1_at)).is_less(0.05)   # P2's D-pad never drives P1


## No hop-to-next on the D-pad: held right, the Jarling walks up to the next jar, focuses it and
## keeps going past it; nothing pulls it onto a stand point.
func test_dpad_held_walks_past_a_jar_instead_of_hopping_to_it() -> void:
	var hub := await _hub()
	var j: HubJarling = hub.jarling_for(Players.P1)
	var start_focus: int = hub.focus[0]
	_button(0, JOY_BUTTON_DPAD_RIGHT, true)
	await get_tree().process_frame
	var frames := 0
	while hub.focus[0] == start_focus and frames < 180:
		_step(hub, 1)
		frames += 1
	assert_int(hub.focus[0]).is_equal(start_focus + 1)
	_step(hub, 30)
	assert_bool(j.moving).is_true()   # no stop at the jar
	var next: int = start_focus + 1
	assert_float(j.position.distance_to(HubLayout.stand_position(next, hub.spots.size()))).is_greater(0.5)
	_button(0, JOY_BUTTON_DPAD_RIGHT, false)
	await get_tree().process_frame
	_step(hub, 30)
	var still := j.position
	_step(hub, 60)
	assert_float(j.position.distance_to(still)).is_less(0.01)   # let go: it stays put, no drift to a jar
