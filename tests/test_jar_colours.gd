## V-08: jar colours keep off the players' green and red.
class_name TestJarColours
extends GdUnitTestSuite


func _gap(a: Color, b: Color) -> float:
	return absf(wrapf(a.h - b.h, -0.5, 0.5))


func test_red_and_green_jars_are_turned_away_from_the_players() -> void:
	for c: Color in [Color("e4393c"), Color("ff2020"), Color("d81b4a"), Color("3cc24a"), Color("22dd55"), Color("1fa83a")]:
		var out := GameSpot.off_players(c)
		for p: int in Players.COLOR:
			assert_float(_gap(out, Players.COLOR[p])).is_greater_equal(GameSpot.hue_gap(p) - 0.001)


func test_other_colours_and_greys_pass_untouched() -> void:
	for c: Color in [Color("35b6ff"), Color("ffd23f"), Color("a78bff"), Color("cccccc"), Color("f0d0d0")]:
		assert_bool(GameSpot.off_players(c).is_equal_approx(c)).is_true()


func test_a_dead_on_red_goes_pink_and_toy_colours_barely_move() -> void:
	var red := GameSpot.off_players(Color("e4393c"))
	assert_float(red.h).is_between(0.85, 0.93)   # pink, not orange next to P2
	for c: Color in GameSpot.TOY_COLORS:
		assert_float(_gap(GameSpot.off_players(c), c)).is_less(0.02)
