## What the launcher does with its own window while a game runs. Pure, so it can be tested.
## The launcher only ever touches its own window; the game's display mode is the game's.
class_name WindowPolicy
extends RefCounted

const LEAVE := -1   # leave the window as it is


## Mode to set when a game starts (running = true) or exits (running = false).
## saved_mode is what the window was in just before the game started.
static func mode_for(running: bool, minimize: bool, saved_mode: int) -> int:
	if not minimize:
		return LEAVE
	if running:
		return DisplayServer.WINDOW_MODE_MINIMIZED
	return restore_mode(saved_mode)


## Never "restore" into minimised; the TV launcher lives in fullscreen.
static func restore_mode(saved_mode: int) -> int:
	if saved_mode < 0 or saved_mode == DisplayServer.WINDOW_MODE_MINIMIZED:
		return DisplayServer.WINDOW_MODE_FULLSCREEN
	return saved_mode


## One log line after the launcher asked for `asked` and the window is now `got`, so a TV log shows
## whether the window manager went along with it (S-02 is checked on the TV from this line).
static func report(running: bool, asked: int, got: int) -> String:
	var what := "minimise while the game runs" if running else "restore after the game"
	if asked == got:
		return "window: %s, done (mode %d)" % [what, got]
	return "window: %s, asked mode %d, the window manager kept mode %d" % [what, asked, got]
