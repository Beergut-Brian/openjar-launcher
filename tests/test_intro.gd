## The hub intro (C-02, C-04, A-01, A-02): IntroPlan's timeline and landing spots, HubIntro tumbling a
## fixture roster out of the jar with landing voices (never more than MAX_VOICES at once), and the hub
## hiding the Jarlings while it plays and handing back on A or at the end. Own Save profile, own
## picks file, fixture rosters (tests/fixtures/roster_three.json, roster_voice.json) only.
class_name TestIntro
extends GdUnitTestSuite

const PROFILE := "test_intro"
const HUB := "res://scenes/hub/hub.tscn"
const PICKS := "user://test_intro/players.json"
const THREE := "res://tests/fixtures/roster_three.json"
const VOICE := "res://tests/fixtures/roster_voice.json"

var _saved_profile: String
var _saved_env: String


func before_test() -> void:
	_saved_env = OS.get_environment("OPENJAR_ROOT")
	_saved_profile = Save.profile
	Save.profile = PROFILE
	Save.wipe()
	Roster.picks_path = PICKS
	Roster.data_path = THREE
	Roster.args_override = PackedStringArray(["--test-intro"])
	Roster.profile_override = ""
	Roster.reload()


func after_test() -> void:
	Input.action_release("p1_action")
	Audio.release_all()
	Save.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % PROFILE))
	Save.profile = _saved_profile
	Save._load()
	for f in [PICKS, PICKS + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	Roster.picks_path = Roster.TEST_PICKS
	Roster.data_path = "res://data/roster.json"
	Roster.args_override = PackedStringArray()
	Roster.profile_override = ""
	Roster.reload()
	OS.set_environment("OPENJAR_ROOT", _saved_env)


func _intro(who: Array[String]) -> HubIntro:
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var intro := HubIntro.new()
	holder.add_child(intro)
	intro.set_process(false)   # the test steps the clock
	intro.start(who)
	return intro


# ---------------------------------------------------------------- IntroPlan (pure)

func test_everyone_gets_their_own_spot_in_front_of_the_jar() -> void:
	for n in [1, 2, 3, 7, 22, 40]:
		var spots := IntroPlan.landing_spots(n)
		assert_int(spots.size()).is_equal(n)
		for i in n:
			var p: Vector3 = spots[i]
			assert_float(Vector2(p.x, p.z).length()).is_less_equal(IntroPlan.MAX_RADIUS)
			assert_float(p.z).is_greater(IntroPlan.JAR_AT.z)   # camera side of the jar
			for k in i:
				assert_float(p.distance_to(spots[k])).is_greater_equal(IntroPlan.SEAT * 0.85)
	# Jeff (first) lands front and centre
	assert_float(absf(IntroPlan.landing_spots(22)[0].x)).is_less(0.6)


func test_the_tumble_grows_with_the_roster_but_the_intro_stays_short() -> void:
	assert_float(IntroPlan.gap(3)).is_equal(IntroPlan.GAP_MAX)
	assert_float(IntroPlan.gap(40)).is_less(IntroPlan.gap(22))
	for n in [1, 3, 22, 40]:
		assert_float(IntroPlan.end_time(n)).is_less(9.0)
		assert_float(IntroPlan.T_POP).is_less(IntroPlan.launch_time(0, n))
		assert_float(IntroPlan.land_time(n - 1, n)).is_less(IntroPlan.logo_time(n))
		assert_float(IntroPlan.thump_time(n)).is_less(IntroPlan.back_time(0, n))
		assert_float(IntroPlan.back_time(n - 1, n)).is_less(IntroPlan.end_time(n))


func test_the_camera_ends_on_the_wide_shot() -> void:
	var wide := [Vector3(0, 10.5, 27), Vector3(0, 1.5, -3)]
	var pose := IntroPlan.camera(IntroPlan.end_time(22), 22, wide[0], wide[1])
	assert_vector(pose[0]).is_equal_approx(wide[0], Vector3.ONE * 0.01)
	assert_vector(pose[1]).is_equal_approx(wide[1], Vector3.ONE * 0.01)


func test_landing_voices_are_happy_barks_and_the_last_says_its_catchphrase() -> void:
	Roster.data_path = VOICE
	Roster.reload()
	var ana := Roster.info("ana")
	assert_str(IntroPlan.voice_path(ana, 0, 5)).is_equal("res://tests/voice_fixture/cheer.ogg")
	assert_str(IntroPlan.voice_path(ana, 4, 5)).is_equal("res://tests/voice_fixture/catchphrase.ogg")
	assert_str(IntroPlan.voice_path(Roster.info("bo"), 4, 5)).is_equal("res://tests/voice_fixture/cheer.ogg")
	assert_str(IntroPlan.voice_path(Roster.info("dee"), 3, 5)).is_empty()   # no voice: the hub plays a tick
	assert_str(IntroPlan.voice_path(Roster.info("eve"), 1, 5)).is_equal("res://tests/voice_fixture/catchphrase.ogg")
	assert_str(IntroPlan.voice_path({}, 0, 5)).is_empty()


# ---------------------------------------------------------------- HubIntro

func test_the_whole_fixture_roster_tumbles_out_lands_and_goes_home() -> void:
	var cast := HubIntro.cast()
	assert_array(cast).is_equal(["jeff", "chuck", "pip"])   # the roster's order, Jeff and Chuck first
	var intro := _intro(cast)
	var done := [false]
	intro.finished.connect(func() -> void: done[0] = true)
	intro.advance(IntroPlan.launch_time(0, 3) - 0.05)
	assert_int(intro.landed).is_equal(0)
	intro.advance(IntroPlan.land_time(2, 3) - intro.t + 0.01)
	assert_int(intro.landed).is_equal(3)
	assert_bool(intro.active).is_true()
	while intro.active:
		intro.advance(0.1)
	assert_bool(done[0]).is_true()


func test_landing_voices_never_pile_up() -> void:
	Roster.data_path = VOICE
	Roster.reload()
	var who: Array[String] = ["ana", "bo", "cy", "ana", "bo", "cy", "ana", "bo", "eve"]
	var intro := _intro(who)
	var most := 0
	while intro.active and intro.t < IntroPlan.thump_time(who.size()):
		intro.advance(0.02)
		most = maxi(most, intro.voices_playing())
	assert_int(most).is_less_equal(IntroPlan.MAX_VOICES)
	assert_int(intro.voiced.size()).is_greater_equal(1)
	assert_str(intro.voiced[0]).is_equal("res://tests/voice_fixture/cheer.ogg")


func test_skip_ends_it_at_once() -> void:
	var intro := _intro(HubIntro.cast())
	intro.advance(1.2)
	var done := [false]
	intro.finished.connect(func() -> void: done[0] = true)
	intro.skip()
	assert_bool(done[0]).is_true()
	assert_bool(intro.active).is_false()


# ---------------------------------------------------------------- the hub

func test_intro_plays_on_the_first_boot_of_the_day_only_and_never_in_tests_or_plain_demos() -> void:
	var plain := PackedStringArray(["--path", "."])
	var Hub := load("res://scripts/hub/hub.gd")
	assert_bool(Hub.wants_intro("", plain, true)).is_true()
	assert_bool(Hub.wants_intro("", plain, false)).is_false()
	assert_bool(Hub.wants_intro("follow;1:go:3", plain, true)).is_false()
	assert_bool(Hub.wants_intro("intro;follow", plain, false)).is_true()
	assert_bool(Hub.wants_intro("", PackedStringArray(["-s", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"]), true)).is_false()


func test_hub_hides_the_jarlings_during_the_intro_and_a_skips_it() -> void:
	OS.set_environment("OPENJAR_ROOT", ProjectSettings.globalize_path("res://tests/fixtures/hub_2"))
	var hub: Node3D = auto_free(load(HUB).instantiate())
	add_child(hub)
	await get_tree().process_frame
	assert_bool(hub.intro_playing()).is_false()   # a test run never plays it by itself
	var intro: HubIntro = hub.play_intro()
	assert_bool(hub.intro_playing()).is_true()
	for j in hub.jarlings:
		assert_bool(j.visible).is_false()
	await get_tree().create_timer(0.3).timeout
	var ev := InputEventAction.new()
	ev.action = "p1_action"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = "p1_action"
	Input.parse_input_event(up)
	await get_tree().process_frame
	assert_bool(hub.intro_playing()).is_false()
	assert_bool(is_instance_valid(intro) and not intro.is_queued_for_deletion()).is_false()
	for j in hub.jarlings:
		assert_bool(j.visible).is_true()
	assert_int(hub.launch.active as int).is_equal(0)   # the A that skipped never launches a game
