## K-01: the chooser hint is a picture (HintGlyph), never words.
class_name TestHintGlyph
extends GdUnitTestSuite


func test_every_kind_draws_and_has_no_words() -> void:
	for kind in [HintGlyph.Kind.SELECT, HintGlyph.Kind.TAB, HintGlyph.Kind.SLASH]:
		var svg := HintGlyph.svg(kind, Players.COLOR[Players.P1])
		assert_bool(svg.contains("<text")).is_false()
		var tex := HintGlyph.texture(kind, Players.COLOR[Players.P1])
		assert_object(tex).is_not_null()
		assert_int(tex.get_width()).is_equal(HintGlyph.SIZE.x)


func test_the_swap_arrows_wear_the_player_colour() -> void:
	var p1 := HintGlyph.svg(HintGlyph.Kind.SELECT, Players.COLOR[Players.P1])
	var p2 := HintGlyph.svg(HintGlyph.Kind.SELECT, Players.COLOR[Players.P2])
	assert_str(p1).is_not_equal(p2)
	assert_bool(p1.contains(Players.COLOR[Players.P1].lightened(0.15).to_html(false))).is_true()
	assert_bool(HintGlyph.texture(HintGlyph.Kind.TAB, Color.RED) == HintGlyph.texture(HintGlyph.Kind.TAB, Color.RED)).is_true()
