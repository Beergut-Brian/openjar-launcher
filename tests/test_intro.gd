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


func test_the_logo_thump_jolts_the_camera_and_the_jolt_dies_away() -> void:
	var who: Array[String] = ["jeff", "chuck", "pip"]
	var intro := _intro(who)
	var thump := IntroPlan.thump_time(who.size())
	var plain := func() -> Vector3: return IntroPlan.camera(intro.t, 3, Vector3(0, 10.5, 27), Vector3.ZERO)[0]
	while intro.t < thump - 0.03:
		intro.advance(0.02)
		assert_vector(intro.shake_offset()).is_equal(Vector3.ZERO)   # nothing before the logo lands
	assert_float(intro.shake_at).is_less(0.0)
	intro.advance(thump - intro.t + 0.01)   # the thump beat fires
	assert_float(intro.shake_at).is_greater_equal(0.0)
	var biggest := 0.0
	var last := INF
	while intro.t < intro.shake_at + IntroPlan.SHAKE_TIME:
		var jolt := intro.shake_offset()
		biggest = maxf(biggest, jolt.length())
		assert_float(jolt.length()).is_less_equal(IntroPlan.SHAKE_MAX + 0.0001)   # under 0.05 m
		var pose := intro.camera_pose(Vector3(0, 10.5, 27), Vector3.ZERO)
		assert_vector(pose[0] - plain.call()).is_equal_approx(jolt, Vector3.ONE * 0.0001)
		intro.advance(0.01)
	assert_float(biggest).is_greater(0.02)   # felt, not only heard
	assert_float(IntroPlan.SHAKE_TIME).is_less_equal(0.15)
	# it has decayed to nothing and stays there for the rest of the intro
	assert_vector(intro.shake_offset()).is_equal(Vector3.ZERO)
	while intro.active:
		assert_vector(intro.shake_offset()).is_equal(Vector3.ZERO)
		intro.advance(0.1)
	# decaying: the envelope only shrinks
	assert_float(IntroPlan.shake(0.12).length()).is_less(IntroPlan.SHAKE_MAX * 0.1)
	assert_vector(IntroPlan.shake(-0.01)).is_equal(Vector3.ZERO)


func test_landing_barks_go_through_the_chooser_voice_call_and_keep_their_cap() -> void:
	Roster.data_path = VOICE
	Roster.reload()
	var heard: Array = []
	var on_said := func(player: int, id: String, path: String) -> void: heard.append([player, id, path])
	Roster.said.connect(on_said)
	var who: Array[String] = ["ana", "bo", "cy", "ana", "bo", "cy", "ana", "bo", "dee", "eve"]
	var intro := _intro(who)
	var most := 0
	while intro.active and intro.t < IntroPlan.thump_time(who.size()):
		intro.advance(0.02)
		most = maxi(most, intro.voices_playing())
	Roster.said.disconnect(on_said)
	assert_int(most).is_less_equal(IntroPlan.MAX_VOICES)   # the cap: never more than 3 at once
	assert_int(most).is_greater(0)
	# every landing line was said by Roster.say (the chooser's call), in the same order, on the shared key
	assert_int(heard.size()).is_equal(intro.voiced.size())
	for k in heard.size():
		assert_int(heard[k][0]).is_equal(-1)
		assert_str(heard[k][2]).is_equal(intro.voiced[k])
	assert_str(heard[0][1]).is_equal("ana")
	assert_bool(heard.any(func(h: Array) -> bool: return h[1] == "dee")).is_false()   # no voice: a tick
	assert_str(Roster.last_said[-1]).is_equal(intro.voiced[-1])
	# full: the call is refused before Roster.say, so nothing more is said
	for v: AudioStreamPlayer in intro._voices:
		v.stream = load("res://tests/voice_fixture/cheer.ogg")
		v.play()
	var before := intro.voiced.size()
	assert_bool(intro._say(0)).is_false()
	assert_int(intro.voiced.size()).is_equal(before)


## K-07: start() builds no bodies (their glTF loads on worker threads), so the first frame never waits
## on the roster; each is built a flight before it leaps, and every one is in before it is seen.
func test_bodies_are_built_one_by_one_as_they_leap_not_before_the_first_frame() -> void:
	var cast := HubIntro.cast()
	var intro := _intro(cast)
	assert_int(intro.bodies_built()).is_equal(0)
	intro.advance(0.01)
	assert_int(intro.bodies_built()).is_less(cast.size())
	var n := cast.size()
	while intro.t < IntroPlan.land_time(n - 1, n):
		intro.advance(0.05)
		for i in n:
			if intro._chars[i].visible:
				assert_int(intro._chars[i].get_child_count()).is_equal(1)
	assert_int(intro.bodies_built()).is_equal(n)


## A skip before everyone was built leaves no threaded load behind (each would leak at exit).
func test_loads_still_in_flight_are_collected_without_waiting() -> void:
	var path := "res://icon.svg"
	assert_int(ResourceLoader.load_threaded_request(path)).is_equal(OK)
	var paths: Array[String] = [path]
	HubIntro._collect(get_tree(), paths)   # returns at once; finishes over the next frames
	for i in 300:
		if paths.is_empty():
			break
		await get_tree().process_frame
	assert_array(paths).is_empty()
	assert_int(ResourceLoader.load_threaded_get_status(path)).is_equal(ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)


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


# ---------------------------------------------------------------- A-05: launch and return voices

func _voice_hub() -> Node3D:
	Roster.data_path = VOICE
	Roster.reload()
	OS.set_environment("OPENJAR_ROOT", ProjectSettings.globalize_path("res://tests/fixtures/hub_2"))
	var hub: Node3D = auto_free(load(HUB).instantiate())
	add_child(hub)
	await get_tree().process_frame
	return hub


func test_bark_path_takes_the_first_bark_the_character_has() -> void:
	Roster.data_path = VOICE
	Roster.reload()
	var Hub := load("res://scripts/hub/hub.gd")
	assert_str(Hub.bark_path(Roster.info("ana"), ["ready", "cheer"])).is_equal("res://tests/voice_fixture/cheer.ogg")
	assert_str(Hub.bark_path(Roster.info("ana"), ["ready", "win"])).is_empty()
	assert_str(Hub.bark_path(Roster.info("dee"), ["cheer"])).is_empty()


func test_the_launcher_shouts_as_it_leaps_and_as_it_pops_back_out() -> void:
	var hub: Node3D = await _voice_hub()
	var lead: HubJarling = hub.lead_jarling()
	assert_str(lead.character_id).is_equal("ana")
	hub._launcher_index = hub.jarlings.find(lead)
	hub._on_launch_beat(LaunchSequence.Beat.LEAP)
	var v := Roster.voice_player(Players.P1)
	assert_bool(v.playing).is_true()
	assert_str(v.stream.resource_path).is_equal("res://tests/voice_fixture/cheer.ogg")
	v.stop()
	hub._play_return(lead)
	assert_bool(v.playing).is_true()   # "I'm back!" with the pop-out
	v.stop()
