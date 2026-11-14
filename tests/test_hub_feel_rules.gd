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
	Roster.data_path = "res://tests/fixtures/roster_three.json"   # a fixture, never the real roster's contents
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


## FR-3 (2026-11-13). The hub has no separate join/ready step: you join where you stand and the
## chooser is in-line on your Jarling (GAME.md, chooser). These pin each path of that step.

func _pad_on(device: int, button: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	e.pressed = down
	Input.parse_input_event(e)
	await get_tree().process_frame


func _join_p2_on_pad_one(hub: Node3D) -> void:
	await _pad(JOY_BUTTON_DPAD_DOWN)   # pad 0: P1
	await _pad_on(1, JOY_BUTTON_A, true)
	await _pad_on(1, JOY_BUTTON_A, false)
	assert_bool(hub.two_players).is_true()


func test_p2_joined_on_a_pad_gets_its_own_select_and_a_hints() -> void:
	var hub := await _hub()
	await _join_p2_on_pad_one(hub)
	_step(hub, 1)
	var p2: HubJarling = hub.jarling_for(Players.P2)
	assert_object(p2).is_not_null()
	assert_bool(hub.launch.active).is_false()   # P2 waits at a jar: the A that joins never launches
	assert_bool(p2.is_held()).is_true()
	assert_bool(p2.hint_enabled).is_true()   # the hint follows the join: P2's ring has its own
	assert_int(p2.hint_kind).is_equal(HintGlyph.Kind.SELECT)
	assert_int(p2.go_hint_kind).is_equal(HintGlyph.Kind.A)


func test_p2_joined_from_the_keyboard_gets_the_slash_and_enter_hints() -> void:
	var hub := await _hub()
	var k := _key_of("p2_action")
	k.pressed = true
	Input.parse_input_event(k)
	await get_tree().process_frame   # the hub's own frame reads the press: P2 joins
	await get_tree().process_frame
	k.pressed = false
	Input.parse_input_event(k)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(hub.two_players).is_true()
	assert_bool(hub.launch.active).is_false()   # the key that joins never also launches
	var p2: HubJarling = hub.jarling_for(Players.P2)
	assert_bool(p2.hint_enabled).is_true()
	assert_int(p2.hint_kind).is_equal(HintGlyph.Kind.SLASH)
	assert_int(p2.go_hint_kind).is_equal(HintGlyph.Kind.ENTER)


func test_p2_changes_character_with_select_on_their_own_pad_only() -> void:
	Roster.data_path = "res://tests/fixtures/roster_three.json"
	Roster.reload()
	var hub := await _hub()
	await _join_p2_on_pad_one(hub)
	var p1_was := Roster.pick(Players.P1)
	var p2_was := Roster.pick(Players.P2)
	await _pad_on(1, JOY_BUTTON_BACK, true)
	_step(hub, 1)
	await _pad_on(1, JOY_BUTTON_BACK, false)
	_step(hub, 1)
	assert_str(Roster.pick(Players.P2)).is_not_equal(p2_was)
	assert_str(Roster.pick(Players.P1)).is_equal(p1_was)
	assert_int(hub.refusals).is_equal(0)


## The D-pad on the chooser step: in this hub that step is walkable, and the D-pad walks (FR-1),
## so its left / right walk and never cycle the character. Pins the decision in REPORT.md.
func test_the_dpad_left_and_right_walk_and_never_change_the_character() -> void:
	Roster.data_path = "res://tests/fixtures/roster_three.json"
	Roster.reload()
	var hub := await _hub()
	var p1: HubJarling = hub.jarling_for(Players.P1)
	var was := Roster.pick(Players.P1)
	for b: int in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_LEFT]:
		var at := p1.position.x
		await _pad_on(0, b, true)
		_step(hub, 30)
		await _pad_on(0, b, false)
		_step(hub, 10)
		var moved := p1.position.x - at
		assert_float(moved if b == JOY_BUTTON_DPAD_RIGHT else -moved).is_greater(0.3)
		assert_str(Roster.pick(Players.P1)).is_equal(was)
	assert_int(hub.refusals).is_equal(0)
