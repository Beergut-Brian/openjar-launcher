## The chooser voice (docs/roster.md "Chooser voice"): Roster.catchphrase() and its bark fallback,
## and the hub's in-line chooser saying the shown character's catchphrase once, SAY_SETTLE s after
## the last step has landed. Own sandbox (Save profile, picks file) and a fixture roster
## (tests/fixtures/roster_voice.json), never the real roster: ana (catchphrase + bark), bo (bark
## only), cy (catchphrase file missing + bark), dee (nothing), eve (catchphrase only). P1 is ana,
## P2 is bo. The hub's own _process is off: the tests step the voice by hand.
class_name TestChooserVoice
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const Hub := preload("res://scripts/hub/hub.gd")
const HUB := "res://scenes/hub/hub.tscn"
const PROFILE := "test_chooser_voice"
const PICKS := "user://test_chooser_voice/players.json"
const VOICE := "res://tests/fixtures/roster_voice.json"
const PHRASE := "res://tests/voice_fixture/catchphrase.ogg"
const BARK := "res://tests/voice_fixture/cheer.ogg"

var _said: Array = []
var _saved_profile: String
var _saved_env: String


func before() -> void:
	Roster.said.connect(_on_said)


func after() -> void:
	Roster.said.disconnect(_on_said)


func before_test() -> void:
	_saved_env = OS.get_environment("OPENJAR_ROOT")
	_saved_profile = Save.profile
	Save.profile = PROFILE
	Save.wipe()
	_wipe_picks()
	Roster.picks_path = PICKS
	Roster.data_path = VOICE
	Roster.args_override = PackedStringArray(["--test-chooser-voice"])
	Roster.profile_override = ""
	Roster.reload()
	_said.clear()


func after_test() -> void:
	for p in [-1, P1, P2]:
		Roster.voice_player(p).stop()
	Audio.release_all()
	Save.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % PROFILE))
	Save.profile = _saved_profile
	Save._load()
	_wipe_picks()
	Roster.picks_path = Roster.TEST_PICKS
	Roster.data_path = "res://data/roster.json"
	Roster.args_override = PackedStringArray()
	Roster.profile_override = ""
	Roster.reload()
	OS.set_environment("OPENJAR_ROOT", _saved_env)
	OS.low_processor_usage_mode = false


func _wipe_picks() -> void:
	for f in [PICKS, PICKS + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


func _on_said(player: int, id: String, path: String) -> void:
	_said.append([player, id, path])


func _hub() -> Hub:
	OS.set_environment("OPENJAR_ROOT", ProjectSettings.globalize_path("res://tests/fixtures/hub_2"))
	var hub: Hub = auto_free(load(HUB).instantiate())
	add_child(hub)
	await get_tree().process_frame
	hub.set_process(false)   # only voice_step() below moves the settle
	_said.clear()
	return hub


## Wait (real frames) until every held Jarling's swap animation has landed.
func _land(hub: Hub) -> void:
	var t := 0.0
	while t < 3.0 and hub.jarlings.any(func(j: HubJarling) -> bool: return j.swapping):
		await get_tree().process_frame
		t += get_process_delta_time()


## A step that changed the character, landed.
func _step(hub: Hub, p: int) -> void:
	assert_bool(hub.change_character(p)).is_true()
	await _land(hub)


# --- Roster.catchphrase() ---

func test_catchphrase_plays_the_file() -> void:
	assert_bool(Roster.catchphrase("ana")).is_true()
	assert_str(Roster.last_said[-1]).is_equal(PHRASE)
	assert_object(Roster.voice_player().stream).is_equal(load(PHRASE))


func test_catchphrase_falls_back_to_bark() -> void:
	assert_bool(Roster.catchphrase("bo")).is_true()     # no catchphrase: a bark
	assert_str(Roster.last_said[-1]).is_equal(BARK)
	assert_bool(Roster.catchphrase("cy")).is_true()     # catchphrase file missing: a bark
	assert_str(Roster.last_said[-1]).is_equal(BARK)


func test_catchphrase_false_with_no_voice() -> void:
	assert_bool(Roster.catchphrase("dee")).is_false()
	assert_bool(Roster.catchphrase("nobody")).is_false()
	assert_array(_said).is_empty()


func test_catchphrase_is_not_a_bark() -> void:
	assert_array(Roster.info("ana").barks).is_equal(["cheer"])
	assert_bool(Roster.bark("eve")).is_false()          # a catchphrase alone is no bark
	assert_bool(Roster.catchphrase("eve")).is_true()


func test_each_slot_has_its_own_voice() -> void:
	assert_object(Roster.voice_player(P1)).is_not_same(Roster.voice_player(P2))
	assert_object(Roster.voice_player(P1)).is_not_same(Roster.voice_player())
	assert_bool(Roster.catchphrase("ana", P1)).is_true()
	assert_bool(Roster.catchphrase("bo", P2)).is_true()
	assert_object(Roster.voice_player(P1).stream).is_equal(load(PHRASE))   # P2 did not cut it
	assert_array(_said).is_equal([[P1, "ana", PHRASE], [P2, "bo", BARK]])
	var b1 := AudioServer.get_bus_index(Roster.voice_player(P1).bus)
	var b2 := AudioServer.get_bus_index(Roster.voice_player(P2).bus)
	assert_float((AudioServer.get_bus_effect(b1, 0) as AudioEffectPanner).pan).is_less(0.0)
	assert_float((AudioServer.get_bus_effect(b2, 0) as AudioEffectPanner).pan).is_greater(0.0)


# --- the hub's in-line chooser ---

func test_fast_steps_say_only_the_last_after_the_settle() -> void:
	var hub := await _hub()
	for i in 4:                                          # solo: ana -> bo -> cy -> dee -> eve
		if i > 0:
			hub.voice_step(0.1)                          # faster than the settle
		await _step(hub, P1)
	assert_str(Roster.pick(P1)).is_equal("eve")
	assert_array(_said).is_empty()                       # nothing while scrolling
	hub.voice_step(Hub.SAY_SETTLE - 0.05)
	assert_array(_said).is_empty()
	hub.voice_step(0.1)
	assert_array(_said).is_equal([[P1, "eve", PHRASE]])


func test_the_settle_waits_for_the_swap_to_land() -> void:
	var hub := await _hub()
	assert_bool(hub.change_character(P1)).is_true()     # ana -> bo, swap animation running
	assert_bool(hub.jarling_for(P1).swapping).is_true()
	hub.voice_step(1.0)
	assert_array(_said).is_empty()
	assert_bool(hub.say_pending(P1)).is_true()
	await _land(hub)
	hub.voice_step(Hub.SAY_SETTLE + 0.01)
	assert_array(_said).is_equal([[P1, "bo", BARK]])


func test_standing_still_never_repeats() -> void:
	var hub := await _hub()
	await _step(hub, P1)
	hub.voice_step(Hub.SAY_SETTLE + 0.01)
	assert_int(_said.size()).is_equal(1)
	for i in 20:
		hub.voice_step(0.5)
	assert_int(_said.size()).is_equal(1)
	assert_bool(hub.say_pending(P1)).is_false()


func test_every_settled_step_says_its_character() -> void:
	var hub := await _hub()
	for i in 5:                                          # ana -> bo -> cy -> dee -> eve -> ana
		await _step(hub, P1)
		hub.voice_step(1.0)
	# dee has no voice: the step's swap sound only
	assert_array(_said).is_equal([[P1, "bo", BARK], [P1, "cy", BARK], [P1, "eve", PHRASE],
			[P1, "ana", PHRASE]])


func test_a_head_shake_says_nothing() -> void:
	Roster.data_path = "res://tests/fixtures/roster_two.json"
	Roster.reload()
	var hub := await _hub()
	hub.join_second_player()
	hub.voice_step(1.0)
	_said.clear()
	assert_bool(hub.change_character(P1)).is_false()     # nobody free
	assert_bool(hub.say_pending(P1)).is_false()


func test_p2_joining_says_their_pick_once() -> void:
	var hub := await _hub()
	hub.join_second_player()
	assert_array(_said).is_empty()
	hub.voice_step(Hub.SAY_SETTLE + 0.01)
	assert_array(_said).is_equal([[P2, "bo", BARK]])
	hub.voice_step(1.0)
	assert_int(_said.size()).is_equal(1)


func test_two_players_each_on_their_own_voice() -> void:
	var hub := await _hub()
	hub.join_second_player()
	hub.voice_step(1.0)
	_said.clear()
	assert_bool(hub.change_character(P1)).is_true()      # ana -> cy (bo is P2's)
	assert_bool(hub.change_character(P2)).is_true()      # bo -> dee
	await _land(hub)
	await _step(hub, P2)                                 # dee -> eve
	hub.voice_step(Hub.SAY_SETTLE + 0.01)
	assert_int(_said.size()).is_equal(2)
	assert_array(_said).contains([[P1, "cy", BARK], [P2, "eve", PHRASE]])


func test_leaving_cancels_a_pending_line() -> void:
	var hub := await _hub()
	hub.join_second_player()
	hub._on_player_left(P2)                              # as Players.player_left does
	hub.voice_step(1.0)
	assert_array(_said).is_empty()


func test_launching_cancels_a_pending_line() -> void:
	var hub := await _hub()
	await _step(hub, P1)
	assert_bool(hub.say_pending(P1)).is_true()
	hub._launch(hub.spots[0], hub.lead_jarling())
	assert_bool(hub.launch.active).is_true()
	assert_bool(hub.say_pending(P1)).is_false()
	hub.voice_step(1.0)
	assert_array(_said).is_empty()
	hub.launch.cancel()


func test_a_profile_swap_says_who_you_are_now() -> void:
	var hub := await _hub()
	hub.pick_profile("p2" if hub.profile != "p2" else "p1")
	await _land(hub)
	hub.voice_step(Hub.SAY_SETTLE + 0.01)
	assert_int(_said.size()).is_equal(1)
	assert_that(_said[0][0]).is_equal(P1)
	assert_str(_said[0][1]).is_equal(Roster.pick(P1))
