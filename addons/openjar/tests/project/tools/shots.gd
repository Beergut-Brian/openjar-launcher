## Harness autoload: `-- --shots=1,2.5 --shot-dir=<dir>` saves the root viewport at those seconds
## (real renderer only, e.g. godot-render), then quits after the last one. Inert without --shots.
extends Node

var _times: Array[float] = []
var _dir := ""
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			for t in a.get_slice("=", 1).split(","):
				_times.append(float(t))
		elif a.begins_with("--shot-dir="):
			_dir = a.get_slice("=", 1)
	_times.sort()
	set_process(not _times.is_empty() and _dir != "")


func _process(delta: float) -> void:
	_t += delta
	if _times.is_empty() or _t < _times[0]:
		return
	var at: float = _times.pop_front()
	var img := get_viewport().get_texture().get_image()
	var path := _dir.path_join("shot_%06.2f.png" % at)
	img.save_png(path)
	print("screenshot: ", path)
	if _times.is_empty():
		get_tree().quit()
