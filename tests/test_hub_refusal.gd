## Every press answers on screen too (CLAUDE.md #7, Kaden's rule 5): one test per refusal path in
## the hub. The refusal count goes up (ui_back plays) and so does the visible answer: an idle
## Jarling shakes its head in place, a busy one (mid-jump, mid-swap, a launch playing) blinks its
## ring, and one out of sight (the intro) gets its player's bar along the bottom edge. Nobody is
## moved. Throwaway Save profile and picks file (never the real players.json or settings).
class_name TestHubRefusal
extends GdUnitTestSuite

const PROFILE := "test_hub_refusal"
const HUB := "res://scenes/hub/hub.tscn"
const PICKS := "user://test_hub_refusal/players.json"
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
	Roster.args_override = PackedStringArray(["--test-hub-refusal"])
	LauncherState.reset_session()


func after_test() -> void:
	for a in ["p1_action", "p1_jump", "p1_change", "p2_action", "p2_jump"]:
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


func _pad(device: int, button: int) -> void:
	for down in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = device
		e.button_index = button
		e.pressed = down
		Input.parse_input_event(e)
	await get_tree().process_frame


func test_an_unused_button_shakes_the_idle_jarling_in_place() -> void:
	var hub := await _hub()
	await _pad(0, JOY_BUTTON_DPAD_DOWN)   # pad 0 is P1 now
	var j: HubJarling = hub.jarling_for(Players.P1)
	j.stop()
	var at := j.global_position
	var before: int = hub.refusals
	await _pad(0, JOY_BUTTON_X)
	assert_int(hub.refusals - before).is_equal(1)
	assert_int(j.shakes).is_equal(1)
	assert_int(j.flashes).is_equal(0)
	await get_tree().create_timer(HubJarling.REFUSE_SECONDS + 0.1).timeout
	assert_float(j._flip.rotation.z).is_equal_approx(0.0, 0.001)   # the shake is over, upright again
	assert_float(j.global_position.distance_to(at)).is_less(0.01)   # never moved for them


func test_p2s_unused_button_answers_on_p2s_jarling_only() -> void:
	var hub := await _hub()
	await _pad(0, JOY_BUTTON_DPAD_DOWN)   # pad 0: P1
	await _pad(1, JOY_BUTTON_DPAD_DOWN)   # pad 1: P2 joins
	assert_bool(hub.two_players).is_true()
	await get_tree().create_timer(0.8).timeout   # the join's poof and hop play out
	var p1: HubJarling = hub.jarling_for(Players.P1)
	var p2: HubJarling = hub.jarling_for(Players.P2)
	var before: int = hub.refusals
	await _pad(1, JOY_BUTTON_Y)
	assert_int(hub.refusals - before).is_equal(1)
	assert_int(p2.shakes + p2.flashes).is_equal(1)
	assert_int(p1.shakes + p1.flashes).is_equal(0)


func test_a_mid_jump_blinks_the_ring() -> void:
	var hub := await _hub()
	var j: HubJarling = hub.jarling_for(Players.P1)
	j.busy = true
	await _tap(hub, "p1_action")
	assert_int(hub.refusals).is_equal(1)
	assert_int(j.flashes).is_equal(1)
	assert_int(j.shakes).is_equal(0)   # a jump is never shaken off course
	assert_bool(j.ring_flashing()).is_true()
	_step(hub, int(HubJarling.REFUSE_SECONDS / DT) + 2)
	assert_bool(j.ring_flashing()).is_false()   # short: gone after about 0.3 s
	j.busy = false


func test_the_chooser_mid_swap_blinks_the_ring() -> void:
	var hub := await _hub()
	var j: HubJarling = hub.jarling_for(Players.P1)
	j.swapping = true
	assert_bool(hub.change_character(Players.P1)).is_false()
	assert_int(hub.refusals).is_equal(1)
	assert_int(j.flashes).is_equal(1)
	assert_int(j.shakes).is_equal(0)
	j.swapping = false


func test_b_during_a_launch_blinks_the_ring_then_the_bar_once_inside() -> void:
	var hub := await _hub()
	hub.press_action(Players.P1)   # P1 starts at a jar: A launches it
	assert_bool(hub.launch.active).is_true()
	var j: HubJarling = hub.jarling_for(Players.P1)
	await _tap(hub, "p1_jump")
	assert_int(hub.refusals).is_equal(1)
	assert_int(j.flashes).is_equal(1)
	assert_int(j.shakes).is_equal(0)
	_step(hub, int((LaunchSequence.T_LEAP + 0.1) / DT))   # it has leapt: its ring is gone
	assert_bool(hub.launch.active).is_true()
	await _tap(hub, "p1_action")
	assert_int(hub.refusals).is_equal(2)
	assert_int(hub.bar_flashes).is_equal(1)
	assert_float(hub.refuse_bars[Players.P1].color.a).is_greater(0.0)
	hub.launch.cancel()


func test_b_during_the_intro_flashes_the_players_bar() -> void:
	var hub := await _hub()
	hub.play_intro()
	assert_bool(hub.intro_playing()).is_true()
	await _tap(hub, "p1_jump")
	assert_int(hub.refusals).is_equal(1)
	assert_int(hub.bar_flashes).is_equal(1)
	var bar: ColorRect = hub.refuse_bars[Players.P1]
	assert_object(bar.color).is_not_null()
	assert_bool(bar.color.is_equal_approx(Color(Players.COLOR[Players.P1], bar.color.a))).is_true()
	await get_tree().create_timer(HubJarling.REFUSE_SECONDS + 0.1).timeout
	assert_float(bar.color.a).is_equal_approx(0.0, 0.01)   # short: faded out again
	hub.intro.skip()
