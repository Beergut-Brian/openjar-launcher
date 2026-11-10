## HubLayout: where the jars stand for 0/1/2/8 games, which jar a Jarling has walked up to, where it can walk.
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


func test_walking_up_to_the_front_or_the_side_of_a_jar_focuses_it() -> void:
	var stand := HubLayout.stand_position(3, 8)
	var jar := HubLayout.jar_position(3, 8)
	# no exact spot: a bit short, a bit to the side, or right up against the glass all count
	assert_int(HubLayout.focus_at(stand + Vector3(0.6, 0, 1.0), 8)).is_equal(3)
	assert_int(HubLayout.focus_at(stand.lerp(jar, 0.6), 8)).is_equal(3)
	var side := jar + (HubLayout.jar_position(4, 8) - jar).normalized() * HubLayout.BLOCK_RADIUS
	assert_int(HubLayout.focus_at(HubLayout.walkable(side, 8), 8)).is_not_equal(-1)
	# the middle of the plaza is roaming
	assert_int(HubLayout.focus_at(Vector3(0, 0, 1), 8)).is_equal(-1)


func test_focus_holds_on_at_the_edge_of_its_range() -> void:
	var stand := HubLayout.stand_position(0, 2)
	var edge := stand + Vector3(0, 0, HubLayout.FOCUS_RANGE + HubLayout.FOCUS_HOLD * 0.5)
	assert_int(HubLayout.focus_at(edge, 2)).is_equal(-1)          # walking in: not yet
	assert_int(HubLayout.focus_at(edge, 2, 0)).is_equal(0)        # walking out: still yours
	var gone := stand + Vector3(0, 0, HubLayout.FOCUS_RANGE + HubLayout.FOCUS_HOLD + 0.1)
	assert_int(HubLayout.focus_at(gone, 2, 0)).is_equal(-1)


func test_a_neighbour_takes_focus_only_when_clearly_nearer() -> void:
	var a := HubLayout.stand_position(3, 8)
	var b := HubLayout.stand_position(4, 8)
	assert_int(HubLayout.focus_at(a.lerp(b, 0.55), 8, 3)).is_equal(3)
	assert_int(HubLayout.focus_at(a.lerp(b, 0.9), 8, 3)).is_equal(4)


func test_jarlings_bump_into_jars_and_stay_on_the_island() -> void:
	for i in 8:
		var jar := HubLayout.jar_position(i, 8)
		var p := HubLayout.walkable(jar + Vector3(0.1, 0, 0.1), 8)
		for k in 8:
			assert_float(Vector2(p.x, p.z).distance_to(Vector2(HubLayout.jar_position(k, 8).x, HubLayout.jar_position(k, 8).z))).is_greater_equal(HubLayout.BLOCK_RADIUS - 0.05)
	assert_float(HubLayout.walkable(Vector3(0, 0, 30), 8).length()).is_equal_approx(HubLayout.WALK_RADIUS, 0.001)
	assert_vector(HubLayout.walkable(Vector3(1, 0, 2), 8)).is_equal(Vector3(1, 0, 2))   # open plaza: untouched


func test_stick_is_analogue_and_full_tilt_runs() -> void:
	assert_vector(HubJarling.stick_velocity(Vector2(0.1, 0))).is_equal(Vector3.ZERO)
	assert_float(HubJarling.stick_velocity(Vector2(0.5, 0)).length()).is_equal_approx(0.5 * HubJarling.WALK_SPEED, 0.001)
	assert_float(HubJarling.stick_velocity(Vector2(1, 0)).length()).is_equal_approx(HubJarling.RUN_SPEED, 0.001)
	assert_float(HubJarling.stick_velocity(Vector2(0.71, 0.71)).length()).is_equal_approx(HubJarling.RUN_SPEED, 0.05)
	assert_vector(HubJarling.stick_velocity(Vector2(0, -1)).normalized()).is_equal_approx(Vector3(0, 0, -1), Vector3.ONE * 0.001)
