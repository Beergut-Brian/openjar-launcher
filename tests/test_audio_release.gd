## Audio.release_all() leaves nothing playing or referenced, so quitting does not leak the music
## stream ("ObjectDB instances leaked / resources still in use" at exit).
class_name TestAudioRelease
extends GdUnitTestSuite


func after_test() -> void:
	Audio.release_all()


func test_release_all_drops_music_and_sfx() -> void:
	Audio.music("card_row_loop", 0.01)
	Audio.play("ui_move")
	await get_tree().create_timer(0.1).timeout
	assert_bool(Audio._music.playing).is_true()
	Audio.release_all()
	assert_bool(Audio._music.playing).is_false()
	assert_object(Audio._music.stream).is_null()
	for p in Audio._pool:
		assert_bool(p.playing).is_false()
		assert_object(p.stream).is_null()
	assert_int(Audio._cache.size()).is_equal(0)


func test_release_all_twice_is_safe() -> void:
	Audio.release_all()
	Audio.release_all()
	assert_object(Audio._music.stream).is_null()


func test_close_button_goes_through_audio_quit() -> void:
	assert_bool(get_tree().auto_accept_quit).is_false()
