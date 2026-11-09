## JSON save under user://saves/<profile>.json. Autoload: Save.
## The launcher passes --profile=<id>; default "p1".
extends Node

signal saved()
signal loaded()

var profile: String = "p1"
var _data: Dictionary = {}
var _dirty := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			profile = arg.trim_prefix("--profile=").strip_edges()
	_load()


func get_value(key: String, default = null):
	return _data.get(key, default)


func set_value(key: String, value) -> void:
	_data[key] = value
	_dirty = true


func flush() -> void:
	if not _dirty:
		return
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f == null:
		push_warning("Save: could not open %s" % _path())
		return
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()
	_dirty = false
	saved.emit()


func wipe() -> void:
	_data = {}
	_dirty = true
	flush()


func _path() -> String:
	return "user://saves/%s.json" % profile


func _load() -> void:
	if not FileAccess.file_exists(_path()):
		_data = {}
		return
	var text := FileAccess.get_file_as_string(_path())
	var parsed = JSON.parse_string(text)
	_data = parsed if parsed is Dictionary else {}
	loaded.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		flush()
