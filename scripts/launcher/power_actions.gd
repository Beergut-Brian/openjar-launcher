## The one seam between the launcher and the TV box's power (NS-1, Kaden 2026-11-14: no Steam, the
## box boots straight into the launcher). The power menu calls these; tests swap in a fake that
## counts. dry_run (test and demo runs) only logs, so a scripted run can never put the box to sleep.
class_name PowerActions
extends RefCounted

const SLEEP := ["suspend"]
const SHUT_DOWN := ["poweroff"]

var dry_run := false          # systemctl is only logged
var dry_quit := false         # the dev quit is only logged (test runs: it would end the test runner)
var asked: Array[String] = []   # what was asked for, in order ("sleep", "shut_down", "quit")


## systemctl suspend. Returns the command's exit code (0 in a dry run).
func sleep() -> int:
	return _systemctl("sleep", SLEEP)


## systemctl poweroff.
func shut_down() -> int:
	return _systemctl("shut_down", SHUT_DOWN)


## The dev-only escape (--allow-quit): leave the process with exit code 0. On the TV the box service
## starts the launcher again; on a desktop you are back at the shell.
func quit(tree: SceneTree) -> void:
	asked.append("quit")
	print("launcher: power: dev quit, exit 0%s" % (" (dry run)" if dry_quit else ""))
	if dry_quit or tree == null:
		return
	var audio := tree.root.get_node_or_null("Audio")
	if audio != null:
		audio.quit(0)
	else:
		tree.quit(0)


func _systemctl(what: String, list: Array) -> int:
	var args := PackedStringArray(list)
	asked.append(what)
	print("launcher: power: %s (systemctl %s)%s" % [what, " ".join(args), " (dry run)" if dry_run else ""])
	if dry_run:
		return 0
	var code := OS.execute("systemctl", args)
	if code != 0:
		push_warning("launcher: power: systemctl %s exited %d" % [" ".join(args), code])
	return code
