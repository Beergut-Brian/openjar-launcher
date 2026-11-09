## HubLayout: where the jars stand for 0/1/2/8 games and where a sideways push hops to.
class_name TestHubLayout
extends GdUnitTestSuite


func test_spot_count_always_has_a_jar() -> void:
	assert_int(HubLayout.spot_count(0)).is_equal(1)   # the empty jar
	assert_int(HubLayout.spot_count(1)).is_equal(1)
	assert_int(HubLayout.spot_count(2)).is_equal(2)
	assert_int(HubLayout.spot_count(8)).is_equal(8)


func test_single_jar_is_straight_ahead() -> void:
	assert_vector(HubLayout.jar_position(0, 1)).is_equal_approx(Vector3(0, 0, -HubLayout.ARC_RADIUS), Vector3.ONE * 0.001)


func test_jars_run_left_to_right_and_never_touch() -> void:
	for count: int in [2, 8, 10]:
		for i in count - 1:
			var a := HubLayout.jar_position(i, count)
			var b := HubLayout.jar_position(i + 1, count)
			assert_bool(b.x > a.x).is_true()
			assert_bool(a.distance_to(b) > GameSpot.JAR_RADIUS * 2.0).is_true()
		assert_bool(HubLayout.stand_position(0, count).length() < HubLayout.WALK_RADIUS).is_true()


func test_focus_only_near_a_stand_point() -> void:
	assert_int(HubLayout.focus_at(HubLayout.stand_position(5, 8), 8)).is_equal(5)
	assert_int(HubLayout.focus_at(Vector3.ZERO, 8)).is_equal(-1)
	assert_int(HubLayout.focus_at(Vector3.ZERO, 0)).is_equal(-1)


func test_hop_steps_one_jar_and_clamps_at_the_ends() -> void:
	var pos := Vector3.ZERO
	assert_int(HubLayout.hop_target(3, 1, pos, 8)).is_equal(4)
	assert_int(HubLayout.hop_target(3, -1, pos, 8)).is_equal(2)
	assert_int(HubLayout.hop_target(7, 1, pos, 8)).is_equal(7)
	assert_int(HubLayout.hop_target(0, -1, pos, 8)).is_equal(0)
	assert_int(HubLayout.hop_target(0, 1, pos, 1)).is_equal(0)


func test_hop_while_roaming_goes_to_the_nearest_jar_that_way() -> void:
	var between := HubLayout.stand_position(2, 8).lerp(HubLayout.stand_position(3, 8), 0.4) + Vector3(0, 0, 1)
	assert_int(HubLayout.hop_target(-1, 1, between, 8)).is_equal(3)
	assert_int(HubLayout.hop_target(-1, -1, between, 8)).is_equal(2)


func test_only_a_sideways_push_is_a_hop() -> void:
	assert_bool(HubLayout.is_hop_push(Vector2(1, 0))).is_true()
	assert_bool(HubLayout.is_hop_push(Vector2(-0.9, 0.3))).is_true()
	assert_bool(HubLayout.is_hop_push(Vector2(0.7, 0.7))).is_false()
	assert_bool(HubLayout.is_hop_push(Vector2(0, 1))).is_false()
	assert_bool(HubLayout.is_hop_push(Vector2(0.3, 0))).is_false()
