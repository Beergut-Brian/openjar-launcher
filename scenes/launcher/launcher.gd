## Launcher flow: intro → profile picker → card row → launch → (game runs) → card row.
## Owns Save keys (LauncherState), the manifest list and the child process.
## Start quits to Steam (exit code 0) from any screen except while a game runs.
extends Control

enum Screen { INTRO, PICKER, CARDS, RUNNING }

const POLL_SECONDS := 0.5
const IDLE_SLEEP_USEC := 100000   # ~10 fps while a game runs
const RETURN_GRACE_MS := 600      # swallow the button that quit the game

var screen: Screen = Screen.INTRO
var root_dir := ""
var all_entries: Array[Dictionary] = []
var profile := "p1"
var _pid := -1
var _running_slug := ""

@onready var intro: Control = $Intro
@onready var picker: Control = $ProfilePicker
@onready var card_row: Control = $CardRow
@onready var process_watch: Timer = $ProcessWatch


func _ready() -> void:
	root_dir = ManifestScanner.default_root()
	profile = LauncherState.profile(Save)
	_rescan(LauncherState.last_card(Save))
	intro.finished.connect(_show_picker)
	picker.confirmed.connect(_on_profile_confirmed)
	picker.back_requested.connect(_show_cards)
	card_row.launch_requested.connect(_launch)
	card_row.back_requested.connect(_show_picker)
	card_row.dev_toggle_requested.connect(_toggle_dev)
	process_watch.wait_time = POLL_SECONDS
	process_watch.timeout.connect(_on_process_watch)
	var today := LauncherState.today()
	if LauncherState.should_play_intro(Save, today):
		LauncherState.mark_intro_played(Save, today)
		Save.flush()
		_set_screen(Screen.INTRO)
		intro.play()
	else:
		_show_picker()


func _unhandled_input(event: InputEvent) -> void:
	if screen == Screen.RUNNING:
		return
	if event.is_action_pressed("launcher_quit"):
		get_viewport().set_input_as_handled()
		quit_to_steam()


func quit_to_steam() -> void:
	Audio.play("ui_back")
	Save.flush()
	set_process_unhandled_input(false)
	await get_tree().create_timer(0.25).timeout   # let the cue be heard
	get_tree().quit(0)


func _rescan(select_slug: String) -> void:
	all_entries = ManifestScanner.scan(root_dir)
	print("launcher: %d entries in %s" % [all_entries.size(), root_dir])
	card_row.set_entries(ManifestScanner.filter_dev(all_entries, LauncherState.show_dev(Save)), select_slug)


func _show_picker() -> void:
	_set_screen(Screen.PICKER)
	picker.open(profile)


func _show_cards() -> void:
	_set_screen(Screen.CARDS)
	card_row.set_active(true)


func _on_profile_confirmed(id: String) -> void:
	profile = id
	LauncherState.set_profile(Save, id)
	Save.flush()
	_show_cards()


func _toggle_dev() -> void:
	var on := not LauncherState.show_dev(Save)
	LauncherState.set_show_dev(Save, on)
	Save.flush()
	Audio.play("ui_toggle")
	var keep: String = card_row.selected_entry().get("slug", "")
	card_row.set_entries(ManifestScanner.filter_dev(all_entries, on), keep)
	card_row.badge_pop()
	print("launcher: dev builds %s" % ("shown" if on else "hidden"))


func _launch(entry: Dictionary) -> void:
	var cmd := LaunchArgs.build(entry, profile)
	LauncherState.set_last_card(Save, entry.slug)
	Save.flush()
	card_row.set_active(false)
	if not entry.binary.is_empty():
		_ensure_executable(entry.binary)
	Audio.play("launch")
	await card_row.selected_card().launch_zoom().finished
	print("launcher: starting %s %s" % [cmd.path, " ".join(cmd.args)])
	var pid := OS.create_process(cmd.path, cmd.args) if not cmd.path.is_empty() else -1
	if pid <= 0:
		push_warning("launcher: could not start %s" % cmd.path)
		Audio.play("ui_back")
		card_row.set_entries(card_row.entries, entry.slug)
		card_row.selected_card().wobble()
		card_row.set_active(true)
		return
	_pid = pid
	_running_slug = entry.slug
	_set_screen(Screen.RUNNING)


func _on_process_watch() -> void:
	if screen != Screen.RUNNING or OS.is_process_running(_pid):
		return
	print("launcher: %s exited (code %d)" % [_running_slug, OS.get_process_exit_code(_pid)])
	_pid = -1
	_rescan(_running_slug)   # pick up games installed or updated meanwhile
	_set_screen(Screen.CARDS)
	card_row.set_active(true, RETURN_GRACE_MS)
	card_row.selected_card().bounce()


## While a game runs: hidden, no input, ~10 fps. Display mode is never touched.
func _set_screen(to: Screen) -> void:
	screen = to
	var running := to == Screen.RUNNING
	intro.visible = to == Screen.INTRO
	picker.visible = to == Screen.PICKER
	card_row.visible = to == Screen.CARDS
	if to != Screen.PICKER:
		picker.close()
	if to != Screen.CARDS:
		card_row.set_active(false)
	for s in [intro, picker, card_row]:
		s.process_mode = Node.PROCESS_MODE_DISABLED if running else Node.PROCESS_MODE_INHERIT
	visible = not running
	OS.low_processor_usage_mode = running
	OS.low_processor_usage_mode_sleep_usec = IDLE_SLEEP_USEC if running else 6900
	if to == Screen.PICKER or to == Screen.CARDS:
		Audio.music("card_row_loop")   # no-op if already playing
	elif running:
		Audio.stop_music()
	if running:
		process_watch.start()
	else:
		process_watch.stop()


static func _ensure_executable(path: String) -> void:
	var perms := FileAccess.get_unix_permissions(path)
	var x := FileAccess.UNIX_EXECUTE_OWNER | FileAccess.UNIX_EXECUTE_GROUP | FileAccess.UNIX_EXECUTE_OTHER
	if perms != 0 and perms & FileAccess.UNIX_EXECUTE_OWNER == 0:
		FileAccess.set_unix_permissions(path, perms | x)
