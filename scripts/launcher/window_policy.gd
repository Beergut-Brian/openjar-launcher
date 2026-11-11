## What the launcher does with its own window while a game runs. Pure, so it can be tested.
## The launcher only ever touches its own window; the game's display mode is the game's.
class_name WindowPolicy
extends RefCounted

const LEAVE := -1   # leave the window as it is
## A window manager applies a mode change some frames later (openbox: ~0.1 to 0.5 s), so the
## launcher checks this often, for at most SETTLE_CHECKS times, before it logs what it got.
const SETTLE_STEP := 0.1
const SETTLE_CHECKS := 15


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


## If the restore did not take after settling, try again this way: some window managers will not
## go straight from minimised to fullscreen, but will from windowed.
static func retry_steps(asked: int) -> Array[int]:
	if asked == DisplayServer.WINDOW_MODE_FULLSCREEN or asked == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		return [DisplayServer.WINDOW_MODE_WINDOWED, asked]
	return [asked]


## One log line after the launcher asked for `asked` and the window is now `got`, so a TV log shows
## whether the window manager went along with it (S-02 is checked on the TV from this line).
## waited_ms: how long the launcher waited for the window manager (-1: not said); retried: the
## restore was asked for a second time.
static func report(running: bool, asked: int, got: int, waited_ms: int = -1, retried: bool = false) -> String:
	var what := "minimise while the game runs" if running else "restore after the game"
	var after := (" after %d ms" % waited_ms if waited_ms >= 0 else "") + (", on the second try" if retried else "")
	if asked == got:
		return "window: %s, done (mode %d)%s" % [what, got, after]
	return "window: %s, asked mode %d, the window manager kept mode %d%s" % [what, asked, got, after]
