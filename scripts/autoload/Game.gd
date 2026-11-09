## Session state machine. Autoload: Game.
extends Node

enum State { TITLE, PLAYING, PAUSED, ROUND_END }

signal state_changed(from: State, to: State)
signal round_started(round_index: int)
signal round_ended(round_index: int, result: Dictionary)

var state: State = State.TITLE
var round_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			pause()
		elif state == State.PAUSED:
			resume()
	elif event.is_action_pressed("restart") and state != State.TITLE:
		restart()


func start_round() -> void:
	round_index += 1
	get_tree().paused = false
	_set_state(State.PLAYING)
	Audio.play("round_start")
	round_started.emit(round_index)


func end_round(result: Dictionary = {}) -> void:
	_set_state(State.ROUND_END)
	Audio.play("round_end")
	Save.flush()
	round_ended.emit(round_index, result)


func pause() -> void:
	get_tree().paused = true
	Audio.play("pause")
	_set_state(State.PAUSED)


func resume() -> void:
	get_tree().paused = false
	Audio.play("pause")
	_set_state(State.PLAYING)


func restart() -> void:
	get_tree().paused = false
	Audio.play("ui_confirm")
	start_round()


func _set_state(to: State) -> void:
	if to == state:
		return
	var from := state
	state = to
	state_changed.emit(from, to)
