## Builds the program + arguments for OS.create_process from a ManifestScanner entry.
## Handshake: docs/contracts.md, "Launcher" → "--profile=<id> handshake".
class_name LaunchArgs
extends RefCounted

const PROFILES := ["p1", "p2"]
const DEFAULT_PROFILE := "p1"


const CHAR_ARG := {0: "--p1-char=", 1: "--p2-char="}   # by player slot (Players.P1 / P2)


## {"path": String, "args": PackedStringArray}. path is "" if the entry cannot be launched.
## chars: player slot → Roster id, passed as --p1-char= / --p2-char= after --profile= (the game's
## Roster reads them before the shared picks file). Ids that are not plain identifiers are dropped.
static func build(entry: Dictionary, profile: String, chars: Dictionary = {}) -> Dictionary:
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
	for p: int in [0, 1]:
		var id := str(chars.get(p, ""))
		if id.is_valid_identifier():
			args.append(CHAR_ARG[p] + id)
	args.append_array(entry.get("args", PackedStringArray()))
	return {"path": path, "args": args}
