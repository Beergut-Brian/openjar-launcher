## HoldCombo: the LB + RB hold-for-1s dev toggle timing, without real input.
class_name TestHoldCombo
extends GdUnitTestSuite


func test_fires_once_after_hold_time() -> void:
	var c := HoldCombo.new(1.0)
	assert_bool(c.update(true, true, 0.5)).is_false()
	assert_float(c.progress()).is_equal_approx(0.5, 0.001)
	assert_bool(c.update(true, true, 0.49)).is_false()
	assert_bool(c.update(true, true, 0.02)).is_true()
	# Keeps holding: no repeat.
	for i in 100:
		assert_bool(c.update(true, true, 0.1)).is_false()
	assert_float(c.progress()).is_equal(0.0)


func test_one_button_never_fires() -> void:
	var c := HoldCombo.new(1.0)
	for i in 30:
		assert_bool(c.update(true, false, 0.1)).is_false()
		assert_bool(c.update(false, true, 0.1)).is_false()


func test_releasing_resets_and_rearms() -> void:
	var c := HoldCombo.new(1.0)
	assert_bool(c.update(true, true, 0.9)).is_false()
	assert_bool(c.update(true, false, 0.016)).is_false()   # let go of RB just before 1 s
	assert_float(c.progress()).is_equal(0.0)
	assert_bool(c.update(true, true, 0.9)).is_false()
	assert_bool(c.update(true, true, 0.1)).is_true()
	assert_bool(c.update(false, false, 0.016)).is_false()
	assert_bool(c.update(true, true, 1.0)).is_true()        # second toggle after re-press
