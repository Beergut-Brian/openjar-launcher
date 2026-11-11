## Sound on every action. Autoload: Audio.
## play("cue") looks for assets/audio/sfx/cue.ogg, or cue_1.ogg..cue_N.ogg and picks one.
## Missing cues warn once and never crash.
extends Node

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICE_DIR := "res://addons/openjar/characters/"
const POOL_SIZE := 12

var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _warned := {}
var _cache := {}
## The last cue play() was asked for (tests check "a sound on every action" with it).
var last_cue := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false   # the close button goes through quit() too
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	add_child(_music)


## Quit path. A stream that is still playing at quit keeps its playback alive in the AudioServer
## (which only drops stopped playbacks on its mix thread), so the engine reports "ObjectDB instances
## leaked / resources still in use" for it at exit. Every quit goes through quit() below, which
## stops everything and gives the mixer a moment first. The window close button does the same.
const QUIT_SETTLE_SECONDS := 0.1


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit(0)
	elif what == NOTIFICATION_EXIT_TREE:
		release_all()   # last resort if something called get_tree().quit() directly


## Stop all sound, let the mixer release it, then quit with exit_code. Use instead of get_tree().quit().
func quit(exit_code: int = 0) -> void:
	get_tree().paused = true   # nothing (the intro, a launch beat) starts a new sound while we settle
	release_all()
	await get_tree().create_timer(QUIT_SETTLE_SECONDS, true, false, true).timeout
	release_all()              # anything a process-always node started meanwhile
	await get_tree().process_frame
	get_tree().quit(exit_code)


## Stops every player, drops their streams and the cue cache. Safe to call more than once.
func release_all() -> void:
	for p in _pool + [_music]:
		if p == null:
			continue
		p.stop()
		p.stream = null
	# and every other voice in the tree (the intro's crowd, the Roster's chooser voices): quitting
	# mid-intro used to leave their playbacks alive and leak them at exit
	if is_inside_tree():
		_silence(get_tree().root)
	_cache.clear()


func _silence(at: Node) -> void:
	if at is AudioStreamPlayer or at is AudioStreamPlayer2D or at is AudioStreamPlayer3D:
		at.stop()
		at.stream = null
	for c in at.get_children():
		_silence(c)


func play(cue: String, _position = null) -> void:
	last_cue = cue
	var stream := _resolve(SFX_DIR, cue)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = randf_range(0.95, 1.05)
			p.play()
			return
	_pool[0].stream = stream
	_pool[0].play()


func music(track: String, fade: float = 0.5) -> void:
	var stream := _resolve(MUSIC_DIR, track)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	if _music.playing and _music.stream == stream:
		return
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(func():
		_music.stream = stream
		_music.volume_db = -40.0
		_music.play())
	tw.tween_property(_music, "volume_db", 0.0, fade)


func stop_music(fade: float = 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(_music.stop)


func bark(character: String, bark_name: String) -> void:
	var stream := _resolve("%s%s/voice/" % [VOICE_DIR, character], bark_name)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = 1.0
			p.play()
			return


func _resolve(dir: String, cue: String) -> AudioStream:
	var key := dir + cue
	if _cache.has(key):
		var variants: Array = _cache[key]
		return variants.pick_random() if not variants.is_empty() else null
	var variants: Array = []
	if ResourceLoader.exists(dir + cue + ".ogg"):
		variants.append(load(dir + cue + ".ogg"))
	else:
		var i := 1
		while ResourceLoader.exists("%s%s_%d.ogg" % [dir, cue, i]):
			variants.append(load("%s%s_%d.ogg" % [dir, cue, i]))
			i += 1
	_cache[key] = variants
	if variants.is_empty():
		if not _warned.has(key):
			_warned[key] = true
			push_warning("Audio: no file for cue '%s' in %s" % [cue, dir])
		return null
	return variants.pick_random()
