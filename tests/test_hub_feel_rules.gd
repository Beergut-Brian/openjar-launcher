## Standing feel rules (2026-11-13), the hub. Every press is heard: a press that does nothing (a
## button no hub action uses, or A / B / the chooser while a Jarling is mid-jump, mid-swap or a launch
## is playing) plays the refusal boop (ui_back). Both players join with A or their keys; Start or
## Escape held quits. Throwaway Save profile and picks file (never the real players.json).
class_name TestHubFeelRules
extends GdUnitTestSuite

const PROFILE := "test_hub_feel_rules"
const HUB := "res://scenes/hub/hub.tscn"
const PICKS := "user://test_hub_feel_rules/players.json"
const DT := 1.0 / 60.0

var _saved_profile: String
var _saved_env: String


func before_test() -> void:
	_saved_env = OS.get_environment("OPENJAR_ROOT")
	_saved_profile = Save.profile
	Save.profile = PROFILE
	Save.wipe()
	Roster.picks_path = PICKS
	Roster.data_path = "res://data/roster.json"
	Roster.args_override = PackedStringArray(["--test-hub-feel-rules"])
	LauncherState.reset_session()


func after_test() -> void:
	for a in ["p1_action", "p1_jump", "p1_change", "p1_move_right", "p2_action", "launcher_quit"]:
		Input.action_release(a)
	Players._device_of[Players.P1] = -1
	Players._device_of[Players.P2] = -1
	Players._bind(Players.P1, -1)
	Players._bind(Players.P2, Players.PARKED)
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


func _tap(hub: Node3D, action: String) -> void:
	Input.action_press(action)
	_step(hub, 1)
	Input.action_release(action)
	await get_tree().process_frame


func _pad(button: int) -> void:
	for down in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = 0
		e.button_index = button
		e.pressed = down
		Input.parse_input_event(e)
	await get_tree().process_frame


func test_buttons_no_hub_action_uses_refuse_out_loud() -> void:
	var hub := await _hub()
	await _pad(JOY_BUTTON_DPAD_DOWN)   # pad 0 is P1 now (not A: P1 starts at a jar, A would launch)
	var before: int = hub.refusals
	for b: int in [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK]:
		await _pad(b)
	assert_int(hub.refusals - before).is_equal(4)
	var key := InputEventKey.new()
	key.keycode = KEY_PAGEDOWN
	key.physical_keycode = KEY_PAGEDOWN
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	assert_int(hub.refusals - before).is_equal(5)


func test_buttons_that_do_something_never_refuse() -> void:
	var hub := await _hub()
	for b: int in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
			JOY_BUTTON_BACK, JOY_BUTTON_START]:
		await _pad(b)
	await _tap(hub, "p1_jump")     # B solo: swaps the profile, not a refusal
	await get_tree().create_timer(0.8).timeout   # the swap plays out (a press mid-swap is a "not now")
	await _tap(hub, "p1_action")   # A at the start jar: the launch, not a refusal
	assert_bool(hub.launch.active).is_true()
	hub.launch.cancel()
	assert_int(hub.refusals).is_equal(0)


func test_a_and_b_mid_jump_say_not_now() -> void:
	var hub := await _hub()
	var j: HubJarling = hub.jarling_for(Players.P1)
	j.busy = true
	await _tap(hub, "p1_action")
	await _tap(hub, "p1_jump")
	assert_int(hub.refusals).is_equal(2)
	j.busy = false


func test_the_chooser_mid_swap_says_not_now() -> void:
	var hub := await _hub()
	var j: HubJarling = hub.jarling_for(Players.P1)
	j.swapping = true
	assert_bool(hub.change_character(Players.P1)).is_false()
	assert_int(hub.refusals).is_equal(1)
	j.swapping = false


func test_presses_during_a_launch_say_not_now() -> void:
	var hub := await _hub()
	hub.press_action(Players.P1)   # P1 starts at a jar: A launches it
	assert_bool(hub.launch.active).is_true()
	await _tap(hub, "p1_jump")
	assert_int(hub.refusals).is_equal(1)
	await _tap(hub, "p1_action")   # A again mid-launch: never a second launch, a "not now"
	assert_int(hub.refusals).is_equal(2)
	hub.launch.cancel()


func _key_of(action: String) -> InputEventKey:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := InputEventKey.new()
			k.keycode = ev.keycode
			k.physical_keycode = ev.physical_keycode
			return k
	return null


func test_p2_joins_with_a_on_a_second_pad() -> void:
	var hub := await _hub()
	await _pad(JOY_BUTTON_DPAD_DOWN)   # pad 0: P1
	var e := InputEventJoypadButton.new()
	e.device = 1
	e.button_index = JOY_BUTTON_A
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	assert_int(Players.device_of(Players.P2)).is_equal(1)
	assert_bool(hub.two_players).is_true()
	e.pressed = false
	Input.parse_input_event(e)
	await get_tree().process_frame


func test_p2_joins_from_the_keyboard() -> void:
	var hub := await _hub()
	var k := _key_of("p2_action")
	assert_object(k).is_not_null()
	k.pressed = true
	Input.parse_input_event(k)
	await get_tree().process_frame   # parsed events land on the next frame
	_step(hub, 1)
	assert_bool(hub.two_players).is_true()
	assert_int(hub.refusals).is_equal(0)
	k.pressed = false
	Input.parse_input_event(k)
	await get_tree().process_frame


func test_escape_held_quits_and_a_tap_does_not() -> void:
	var hub := await _hub()
	var quit := [false]
	hub.quitting.connect(func() -> void: quit[0] = true)
	var k := _key_of("launcher_quit")
	assert_object(k).is_not_null()
	k.pressed = true
	Input.parse_input_event(k)
	await get_tree().process_frame
	_step(hub, 10)
	k.pressed = false
	Input.parse_input_event(k)
	await get_tree().process_frame
	_step(hub, 10)
	assert_bool(quit[0]).is_false()   # a tap never quits
	k.pressed = true
	Input.parse_input_event(k)
	await get_tree().process_frame
	_step(hub, int(hub.QUIT_HOLD * 60.0) + 10)
	assert_bool(quit[0]).is_true()
	k.pressed = false
	Input.parse_input_event(k)
	await get_tree().process_frame
