## Launch-ready-2: since openjar-characters v0.5.3 every real roster character speaks: loadable
## barks for the intro landing, and a catchphrase for the chooser (M-09, M-12, A-02). Jeff and Chuck,
## the default picks, are pinned by name. Reads data/roster.json only; the picks file is a test path.
class_name TestRealRosterVoices
extends GdUnitTestSuite

const PICKS := "user://test_real_roster_voices/players.json"

var _real := {}


func before() -> void:
	_real = { "data": Roster.data_path, "picks": Roster.picks_path }
	Roster.picks_path = PICKS
	Roster.data_path = "res://data/roster.json"
	Roster.args_override = PackedStringArray(["--test-real-roster-voices"])
	Roster.reload()


func after() -> void:
	for f in [PICKS, PICKS + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	Roster.data_path = _real.data
	Roster.picks_path = _real.picks
	Roster.args_override = PackedStringArray()
	Roster.reload()


func test_every_real_character_has_barks_and_a_catchphrase() -> void:
	var ids := Roster.roster()
	assert_int(ids.size()).is_equal(22)
	for id in ids:
		var who := Roster.info(id)
		assert_str(who.voice).override_failure_message("%s has no voice dir" % id).is_not_empty()
		assert_bool(ResourceLoader.exists(who.catchphrase)) \
			.override_failure_message("%s catchphrase missing" % id).is_true()
		assert_object(load(who.catchphrase)).is_instanceof(AudioStream)
		assert_int(who.barks.size()).override_failure_message("%s has no barks" % id).is_greater_equal(5)
		for b in who.barks:
			var path := "%s%s.ogg" % [who.voice, b]
			assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()


func test_every_real_character_lands_with_a_voice_not_a_tick() -> void:
	var ids := Roster.roster()
	for i in ids.size():
		var path := IntroPlan.voice_path(Roster.info(ids[i]), i, ids.size())
		assert_str(path).override_failure_message("%s lands silent" % ids[i]).is_not_empty()


func test_jeff_and_chuck_say_their_catchphrase() -> void:
	for id in ["jeff", "chuck"]:
		assert_str(Roster.info(id).catchphrase).ends_with("%s/voice/catchphrase.ogg" % id)
		assert_bool(Roster.catchphrase(id)).is_true()
		assert_str(str(Roster.last_said.values())).contains("%s/voice/catchphrase.ogg" % id)
	Audio.release_all()


func test_the_credits_say_every_character_speaks() -> void:
	var credits := FileAccess.get_file_as_string("res://assets/CREDITS.md")
	assert_str(credits).contains("all 22 playable")
	assert_str(credits).not_contains("four without a `voice/` folder")
