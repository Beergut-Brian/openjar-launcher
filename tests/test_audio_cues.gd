## Every cue and track listed in assets/audio/CUES.md resolves the way Audio.gd resolves it
## (cue.ogg, or cue_1.ogg..cue_N.ogg) to files that load as AudioStreams, and the card-row
## music loops when Audio.music() plays it.
class_name TestAudioCues
extends GdUnitTestSuite

const CUES_MD := "res://assets/audio/CUES.md"
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"


## Rows of the CUES.md tables as [name, files_cell]. Header and divider rows are skipped.
static func cue_rows() -> Array:
	var rows := []
	for line in FileAccess.get_file_as_string(CUES_MD).split("\n"):
		if not line.begins_with("| "):
			continue
		var cells := line.split("|")
		var cue_name := cells[1].strip_edges()
		if cue_name.is_empty() or cue_name.begins_with("-") or cue_name.contains("("):
			continue
		rows.append([cue_name, cells[2].strip_edges()])
	return rows


static func variants(dir: String, cue_name: String) -> PackedStringArray:
	var found := PackedStringArray()
	if ResourceLoader.exists(dir + cue_name + ".ogg"):
		found.append(dir + cue_name + ".ogg")
		return found
	var i := 1
	while ResourceLoader.exists("%s%s_%d.ogg" % [dir, cue_name, i]):
		found.append("%s%s_%d.ogg" % [dir, cue_name, i])
		i += 1
	return found


func test_cues_md_lists_the_launcher_cues() -> void:
	var names := cue_rows().map(func(r): return r[0])
	for cue_name in ["ui_move", "ui_confirm", "ui_back", "ui_toggle", "intro_pop", "intro_thump",
			"launch", "player_join", "round_start", "round_end", "pause", "card_row_loop"]:
		assert_bool(names.has(cue_name)).override_failure_message("CUES.md missing " + cue_name).is_true()


func test_every_cue_resolves_to_loadable_streams() -> void:
	for row in cue_rows():
		var dir := MUSIC_DIR if row[1].begins_with("music/") else SFX_DIR
		var files := variants(dir, row[0])
		assert_int(files.size()).override_failure_message("no file for cue " + row[0]).is_greater(0)
		for path in files:
			var stream := load(path) as AudioStream
			assert_object(stream).override_failure_message("not an AudioStream: " + path).is_not_null()
			assert_float(stream.get_length()).override_failure_message("empty: " + path).is_greater(0.05)
			if dir == SFX_DIR:
				assert_float(stream.get_length()).override_failure_message("too long: " + path).is_less_equal(1.5)


func test_ui_move_has_variants() -> void:
	assert_int(variants(SFX_DIR, "ui_move").size()).is_greater_equal(2)


func test_card_row_loop_loops_when_played() -> void:
	Audio.music("card_row_loop", 0.01)
	var stream := load(MUSIC_DIR + "card_row_loop.ogg") as AudioStreamOggVorbis
	assert_object(stream).is_not_null()
	assert_bool(stream.loop).is_true()
	assert_float(stream.get_length()).is_between(16.0, 30.0)
	Audio.stop_music(0.01)
