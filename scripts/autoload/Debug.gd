## F3 overlay, F12 screenshot, --screenshot-after=<s> for headless review. Autoload: Debug.
## Real frames without a monitor: --shots=1,3.5,6 [--shot-dir=/abs/dir] saves a PNG at each time (seconds
## after boot) and quits after the last one. Needs a real renderer: run it through scripts/tools/shots.sh.
## Soak: --soak-log=/abs/file.tsv [--soak-every=10] [--soak-seconds=1800] writes one line of engine
## monitors every soak-every seconds (frame time, objects, nodes, orphans, resources, memory, audio
## voices), then a summary, and quits through Audio.quit after soak-seconds. scripts/tools/soak.sh.
extends CanvasLayer

const SOAK_COLUMNS := ["t_s", "frames", "fps", "frame_ms_avg", "frame_ms_max", "objects", "nodes",
		"orphans", "resources", "static_mb", "voices", "voices_max"]

var _label: Label
var _shot_after := -1.0
var _shots: Array[float] = []
var _shot_dir := "user://screenshots"
var _clock := 0.0
var _soak_path := ""
var _soak_every := 10.0
var _soak_seconds := -1.0
var _soak_next := 0.0
var _soak_frames := 0
var _soak_last_usec := 0
var _soak_ms_sum := 0.0
var _soak_ms_max := 0.0
var _soak_voices_max := 0
var _soak_rows: Array = []
var _soak_done := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 20)
	_label.visible = false
	add_child(_label)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-after="):
			_shot_after = float(arg.trim_prefix("--screenshot-after="))
		elif arg.begins_with("--shots="):
			for s in arg.trim_prefix("--shots=").split(",", false):
				_shots.append(float(s))
			_shots.sort()
		elif arg.begins_with("--shot-dir="):
			_shot_dir = arg.trim_prefix("--shot-dir=")
		elif arg.begins_with("--soak-log="):
			_soak_path = arg.trim_prefix("--soak-log=")
		elif arg.begins_with("--soak-every="):
			_soak_every = maxf(1.0, float(arg.trim_prefix("--soak-every=")))
		elif arg.begins_with("--soak-seconds="):
			_soak_seconds = float(arg.trim_prefix("--soak-seconds="))
	if not _soak_path.is_empty():
		_soak_next = _soak_every
		var f := FileAccess.open(_soak_path, FileAccess.WRITE)
		if f:
			f.store_line("\t".join(SOAK_COLUMNS))


func _process(delta: float) -> void:
	if not _soak_path.is_empty():
		_soak_step(delta)
	if _label.visible:
		_label.text = "fps %d\nstate %s\nround %d\nplayers %s" % [
			Engine.get_frames_per_second(),
			Game.State.keys()[Game.state],
			Game.round_index,
			str(Players.active_players())]
	if not _shots.is_empty():
		_clock += delta
		if _clock >= _shots[0]:
			var t: float = _shots.pop_front()
			await screenshot("t%05.1fs" % t)
			if _shots.is_empty():
				Audio.quit()   # stops every voice first, so the exit leaks nothing
	if _shot_after >= 0.0:
		_shot_after -= delta
		if _shot_after < 0.0:
			await screenshot()
			Audio.quit()


## Playing AudioStreamPlayer(2D/3D) nodes anywhere in the tree: the sound voices in use right now.
func voices_playing() -> int:
	var n := 0
	for c in _all_nodes(get_tree().root):
		if (c is AudioStreamPlayer or c is AudioStreamPlayer2D or c is AudioStreamPlayer3D) and c.playing:
			n += 1
	return n


func _all_nodes(at: Node) -> Array[Node]:
	var out: Array[Node] = [at]
	for c in at.get_children():
		out.append_array(_all_nodes(c))
	return out


## One monitor row: the numbers a leak or a stall would show in.
func soak_row(t: float) -> Dictionary:
	return {
		"t_s": snappedf(t, 0.1),
		"frames": _soak_frames,
		"fps": Engine.get_frames_per_second(),
		"frame_ms_avg": snappedf(_soak_ms_sum / maxf(1.0, _soak_frames), 0.01),
		"frame_ms_max": snappedf(_soak_ms_max, 0.01),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"voices": voices_playing(),
		"voices_max": _soak_voices_max,
	}


func _soak_step(delta: float) -> void:
	if _soak_done:
		return
	# wall-clock frame time: the engine clamps delta (8 physics steps, 133 ms), which hides a slow frame
	var now := Time.get_ticks_usec()
	var ms := (now - _soak_last_usec) / 1000.0 if _soak_last_usec > 0 else delta * 1000.0
	_soak_last_usec = now
	_soak_frames += 1
	_soak_ms_sum += ms
	_soak_ms_max = maxf(_soak_ms_max, ms)
	if _soak_frames % 15 == 0:
		_soak_voices_max = maxi(_soak_voices_max, voices_playing())
	if _clock_soak() < _soak_next:
		return
	var row := soak_row(_clock_soak())
	_soak_rows.append(row)
	var vals: PackedStringArray = []
	for k: String in SOAK_COLUMNS:
		vals.append(str(row[k]))
	var f := FileAccess.open(_soak_path, FileAccess.READ_WRITE)
	if f:
		f.seek_end()
		f.store_line("\t".join(vals))
	print("soak: ", " ".join(vals))
	_soak_next += _soak_every
	_soak_frames = 0
	_soak_ms_sum = 0.0
	_soak_ms_max = 0.0
	_soak_voices_max = 0
	if _soak_seconds > 0.0 and _clock_soak() >= _soak_seconds:
		_soak_done = true
		print("soak: done after %.0f s, %d rows" % [_clock_soak(), _soak_rows.size()])
		Audio.quit(0)


func _clock_soak() -> float:
	return Time.get_ticks_msec() / 1000.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		_label.visible = not _label.visible
	elif event.is_action_pressed("debug_screenshot"):
		screenshot()


func screenshot(tag: String = "") -> String:
	if DisplayServer.get_name() == "headless":
		# No renderer: report state instead so the Reviewer still gets a signal of life.
		print("screenshot: headless, state=%s players=%s" % [Game.State.keys()[Game.state], str(Players.active_players())])
		return ""
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	var stamp := tag if tag != "" else Time.get_datetime_string_from_system().replace(":", "-")
	var path := _shot_dir.path_join("%s.png" % stamp)
	img.save_png(path)
	print("screenshot: ", ProjectSettings.globalize_path(path))
	return path
