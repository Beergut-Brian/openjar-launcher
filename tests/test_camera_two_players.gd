## K-05: one camera that never loses a player. Two players at the far ends of the island (and one
## at the front edge) both stay on screen, feet and head. Own Save profile, fixture roster and jars.
class_name TestCameraTwoPlayers
extends GdUnitTestSuite

const PROFILE := "test_camera_two"
const HUB := "res://scenes/hub/hub.tscn"

var _saved_profile: String
var _saved_env: String


func before_test() -> void:
	_saved_env = OS.get_environment("OPENJAR_ROOT")
	_saved_profile = Save.profile
	Save.profile = PROFILE
	Save.wipe()
	Roster.picks_path = "user://test_camera_two/players.json"
	Roster.data_path = "res://tests/fixtures/roster_three.json"
	Roster.args_override = PackedStringArray(["--test-camera-two"])
	Roster.reload()


func after_test() -> void:
	Audio.release_all()
	Save.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % PROFILE))
	Save.profile = _saved_profile
	Save._load()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_camera_two/players.json"))
	Roster.picks_path = Roster.TEST_PICKS
	Roster.data_path = "res://data/roster.json"
	Roster.args_override = PackedStringArray()
	Roster.reload()
	OS.set_environment("OPENJAR_ROOT", _saved_env)


func test_two_players_at_opposite_ends_both_stay_in_shot() -> void:
	OS.set_environment("OPENJAR_ROOT", ProjectSettings.globalize_path("res://tests/fixtures/hub_8"))
	var hub: Node3D = auto_free(load(HUB).instantiate())
	add_child(hub)
	await get_tree().process_frame
	hub.set_process(false)
	hub.join_second_player()
	var a: HubJarling = hub.jarling_for(Players.P1)
	var b: HubJarling = hub.jarling_for(Players.P2)
	var r := HubLayout.WALK_RADIUS
	var cases := [
		[Vector3(-r, 0, 0), Vector3(r, 0, 0)],                   # left and right edges
		[Vector3(-r * 0.7, 0, -r * 0.7), Vector3(r * 0.7, 0, r * 0.7)],   # back left and front right
		[Vector3(0, 0, r), Vector3(-r * 0.7, 0, -r * 0.7)],      # front edge and back left
		[Vector3(r * 0.9, 0, 0.5), Vector3(r * 0.9, 0, 1.5)],   # both crowded on one side
	]
	for c: Array in cases:
		a.position = HubLayout.walkable(c[0], hub.spots.size())
		b.position = HubLayout.walkable(c[1], hub.spots.size())
		hub._intro = 1.0
		for i in 120:   # two seconds of the camera easing in
			hub._update_focus(true)
			hub._update_camera(1.0 / 60.0)
		var cam: Camera3D = hub.camera
		for j: HubJarling in [a, b]:
			for y in [0.05, j.height]:
				var p := j.global_position + Vector3(0, y, 0)
				assert_bool(cam.is_position_in_frustum(p)).override_failure_message(
						"lost %s at %s (camera %s)" % [j.character_id, p, cam.global_position]).is_true()
