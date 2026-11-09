## Builds the program + arguments for OS.create_process from a ManifestScanner entry.
## Handshake: docs/contracts.md, "Launcher" → "--profile=<id> handshake".
class_name LaunchArgs
extends RefCounted

const PROFILES := ["p1", "p2"]
const DEFAULT_PROFILE := "p1"


## {"path": String, "args": PackedStringArray}. path is "" if the entry cannot be launched.
static func build(entry: Dictionary, profile: String) -> Dictionary:
	if not profile in PROFILES:
		profile = DEFAULT_PROFILE
	var path := ""
	var args := PackedStringArray()
	var command: PackedStringArray = entry.get("command", PackedStringArray())
	if not command.is_empty():
		path = command[0]
		var local: String = String(entry.get("dir", "")).path_join(path)
		if not path.is_absolute_path() and FileAccess.file_exists(local):
			path = local
		args.append_array(command.slice(1))
	else:
		path = entry.get("binary", "")
	args.append("--profile=%s" % profile)
	args.append_array(entry.get("args", PackedStringArray()))
	return {"path": path, "args": args}
