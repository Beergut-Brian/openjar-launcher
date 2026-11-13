## Finds installed games: every <root>/<folder>/openjar.json (format in docs/contracts.md, "Launcher").
## Pure and static so tests can point it at a temp dir. Bad manifests warn and are skipped.
class_name ManifestScanner
extends RefCounted

const MANIFEST := "openjar.json"
const SKIP_FOLDERS := ["openjar-launcher", "openjar-launcher-dev"]
const DEFAULT_ROOT := "~/Games/openjar"


## $OPENJAR_ROOT, else ~/Games/openjar, with a leading ~ expanded.
static func default_root() -> String:
	var root := OS.get_environment("OPENJAR_ROOT").strip_edges()
	if root.is_empty():
		root = DEFAULT_ROOT
	return expand_home(root)


static func expand_home(path: String) -> String:
	if path == "~" or path.begins_with("~/"):
		return OS.get_environment("HOME") + path.substr(1)
	return path


## Every valid entry under root, sorted by folder name. Dev entries included; see filter_dev().
static func scan(root: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(root):
		push_warning("ManifestScanner: root %s does not exist" % root)
		return out
	var folders := Array(DirAccess.get_directories_at(root))
	folders.sort()
	for folder: String in folders:
		if folder in SKIP_FOLDERS or folder.begins_with("."):
			continue
		var entry := read_manifest(root.path_join(folder))
		if not entry.is_empty():
			out.append(entry)
	return out


## The jars to show. Off: stable builds only. On: one jar per game, never two (Kaden, playtest
## 2026-11-12: "Dev mode ... should only show the dev version"): its dev build if one is installed,
## else its stable build. Order follows `entries` (the first build of each game holds its place).
static func filter_dev(entries: Array[Dictionary], show_dev: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not show_dev:
		for e in entries:
			if not e.dev:
				out.append(e)
		return out
	var at := {}   # game -> index in out
	for e in entries:
		var game := game_of(e)
		if not at.has(game):
			at[game] = out.size()
			out.append(e)
		elif e.dev and not out[at[game]].dev:
			out[at[game]] = e
	return out


## Which game an entry is a build of: its slug. CI gives a game's stable and dev builds the same slug
## (the repo name, installed as `<repo>/` and `<repo>-dev/`); a hand-written dev manifest that kept
## the folder name as its slug (`smash-party-dev`) still counts as `smash-party`.
static func game_of(e: Dictionary) -> String:
	var slug: String = e.get("slug", "")
	if e.get("dev", false) and slug.ends_with("-dev"):
		return slug.trim_suffix("-dev")
	return slug


## One folder's manifest as a normalised entry, or {} (with a warning) if it is unusable.
## Entry keys: slug, name, version, dir, binary, command, args, grid, hero, clip, jar, dev.
## binary/grid/hero/clip/jar are absolute ("" when absent); command/args are PackedStringArray.
static func read_manifest(dir: String) -> Dictionary:
	var path := dir.path_join(MANIFEST)
	if not FileAccess.file_exists(path):
		push_warning("ManifestScanner: no %s in %s, skipped" % [MANIFEST, dir])
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("ManifestScanner: %s is not valid JSON (line %d: %s), skipped" % [
			path, json.get_error_line(), json.get_error_message()])
		return {}
	var data = json.data
	if not data is Dictionary:
		push_warning("ManifestScanner: %s is not a JSON object, skipped" % path)
		return {}
	var folder := dir.get_file()
	var slug := _string(data, "slug", folder)
	if slug in SKIP_FOLDERS:
		return {}
	var entry := {
		"slug": slug,
		"name": _string(data, "name", slug),
		"version": _string(data, "version", ""),
		"dir": dir,
		"binary": "",
		"command": PackedStringArray(),
		"args": PackedStringArray(),
		"grid": _rel_path(dir, data, "grid"),
		"hero": _rel_path(dir, data, "hero"),
		"clip": _rel_path(dir, data, "clip"),
		"jar": _rel_path(dir, data, "jar"),
		"dev": data.get("dev") is bool and data.dev,
	}
	if data.has("args"):
		if not _is_string_array(data.args):
			push_warning("ManifestScanner: %s 'args' must be an array of strings, skipped" % path)
			return {}
		entry.args = PackedStringArray(data.args)
	if data.has("command"):
		if not _is_string_array(data.command) or data.command.is_empty() or str(data.command[0]).is_empty():
			push_warning("ManifestScanner: %s 'command' must be a non-empty array of strings, skipped" % path)
			return {}
		entry.command = PackedStringArray(data.command)
		return entry
	var binary := _string(data, "binary", "")
	if binary.is_empty():
		push_warning("ManifestScanner: %s has neither 'binary' nor 'command', skipped" % path)
		return {}
	entry.binary = dir.path_join(binary)
	if not FileAccess.file_exists(entry.binary):
		push_warning("ManifestScanner: %s binary %s not found, skipped" % [path, entry.binary])
		return {}
	return entry


static func _string(data: Dictionary, key: String, default: String) -> String:
	var v = data.get(key)
	return v if v is String and not v.is_empty() else default


static func _rel_path(dir: String, data: Dictionary, key: String) -> String:
	var v := _string(data, key, "")
	return dir.path_join(v) if not v.is_empty() else ""


static func _is_string_array(v) -> bool:
	if not v is Array:
		return false
	for item in v:
		if not item is String:
			return false
	return true
