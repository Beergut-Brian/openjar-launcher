## The launch animation's clock: beats come in order, the game beat (GO) is last and comes once,
## and a second start() while it plays is refused.
class_name TestLaunchSequence
extends GdUnitTestSuite

const ORDER := [LaunchSequence.Beat.RATTLE, LaunchSequence.Beat.LID_POP, LaunchSequence.Beat.LEAP,
	LaunchSequence.Beat.LID_LAND, LaunchSequence.Beat.SPLASH, LaunchSequence.Beat.DIVE, LaunchSequence.Beat.GO]


func test_idle_until_started() -> void:
	var seq := LaunchSequence.new()
	assert_bool(seq.active).is_false()
	assert_array(seq.advance(5.0)).is_empty()


func test_beats_in_order_and_go_is_last() -> void:
	var seq := LaunchSequence.new()
	assert_bool(seq.start()).is_true()
	var seen: Array[int] = []
	var frames := 0
	while seq.active and frames < 1000:
		var beats := seq.advance(1.0 / 60.0)
		if beats.has(LaunchSequence.Beat.GO):
			assert_float(seq.t).is_equal_approx(LaunchSequence.T_GO, 0.001)
		seen.append_array(beats)
		frames += 1
	assert_array(seen).is_equal(ORDER)
	assert_bool(seq.active).is_false()
	# about 2.3 s at 60 fps, and nothing more once it is over
	assert_int(frames).is_between(136, 140)
	assert_array(seq.advance(1.0)).is_empty()


func test_go_does_not_fire_before_its_time() -> void:
	var seq := LaunchSequence.new()
	seq.start()
	var seen := seq.advance(LaunchSequence.T_GO - 0.05)
	assert_bool(seen.has(LaunchSequence.Beat.GO)).is_false()
	assert_bool(seq.active).is_true()
	assert_array(seq.advance(0.1)).is_equal([LaunchSequence.Beat.GO])


func test_a_long_frame_skips_no_beat() -> void:
	var seq := LaunchSequence.new()
	seq.start()
	assert_array(seq.advance(10.0)).is_equal(ORDER)
	assert_bool(seq.active).is_false()


func test_start_is_refused_while_playing() -> void:
	var seq := LaunchSequence.new()
	assert_bool(seq.start()).is_true()
	seq.advance(1.0)
	assert_bool(seq.start()).is_false()       # A spam
	assert_float(seq.t).is_equal_approx(1.0, 0.001)
	var rest := seq.advance(10.0)
	assert_int(rest.count(LaunchSequence.Beat.GO)).is_equal(1)
	assert_bool(seq.start()).is_true()        # over: the next launch may start


func test_cancel_stops_without_go() -> void:
	var seq := LaunchSequence.new()
	seq.start()
	seq.advance(1.0)
	seq.cancel()
	assert_array(seq.advance(10.0)).is_empty()
	assert_bool(seq.start()).is_true()
	assert_float(seq.t).is_equal(0.0)
