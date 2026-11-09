## Horizontal row of game cards. Left/right moves (clamped at the ends, with a wobble),
## A asks to launch, B asks for the profile picker, hold LB + RB for 1 s toggles dev builds.
## The launcher root owns what those requests do; this scene only handles input and visuals.
extends Control

signal launch_requested(entry: Dictionary)
signal back_requested()
signal dev_toggle_requested()

const CARD_SCENE := preload("res://scenes/launcher/card.tscn")
const SPACING := 440.0
const CENTER := Vector2(960, 560)

var active := false
var index := 0
var entries: Array[Dictionary] = []
var _cards: Array[Control] = []
var _hold := HoldCombo.new(1.0)
var _ignore_until := 0

@onready var track: Control = $Track
@onready var hold_meter: ColorRect = $HoldMeter
@onready var flash: ColorRect = $Flash


## Clamp, not wrap: the row is a strip the kid can see the ends of. Decision logged in GAME.md.
static func step(from: int, dir: int, count: int) -> int:
	if count <= 0:
		return 0
	return clampi(from + dir, 0, count - 1)


func set_entries(list: Array[Dictionary], select_slug: String = "") -> void:
	entries = list
	for c in _cards:
		c.queue_free()
	_cards.clear()
	var shown: Array[Dictionary] = entries.duplicate()
	if shown.is_empty():
		shown.append({})   # one empty grey card, so the screen is never blank
	for e in shown:
		var card := CARD_SCENE.instantiate()
		track.add_child(card)
		card.setup(e)
		_cards.append(card)
	index = 0
	for i in entries.size():
		if entries[i].slug == select_slug:
			index = i
	_layout(false)


func selected_entry() -> Dictionary:
	return entries[index] if index < entries.size() else {}


func selected_card() -> Control:
	return _cards[index] if index < _cards.size() else null


## Turn input on/off. grace_ms swallows input for a moment (e.g. the button that quit the game).
func set_active(on: bool, grace_ms: int = 150) -> void:
	active = on
	_hold = HoldCombo.new(1.0)
	_ignore_until = Time.get_ticks_msec() + grace_ms
	hold_meter.visible = false


func move(dir: int) -> void:
	var to := step(index, dir, entries.size())
	Audio.play("ui_move")
	if to == index:
		selected_card().wobble()
		return
	index = to
	_layout(true)
	selected_card().bounce()


func badge_pop() -> void:
	flash.modulate.a = 0.6
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.4)
	for c in _cards:
		c.badge_pop()


func _process(delta: float) -> void:
	if not active:
		return
	var fired := _hold.update(Input.is_action_pressed("launcher_lb"), Input.is_action_pressed("launcher_rb"), delta)
	hold_meter.visible = _hold.progress() > 0.0
	hold_meter.size.x = 600.0 * _hold.progress()
	hold_meter.position.x = 960.0 - hold_meter.size.x / 2.0
	if fired:
		dev_toggle_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not active or Time.get_ticks_msec() < _ignore_until:
		return
	if event.is_action_pressed("launcher_left"):
		move(-1)
	elif event.is_action_pressed("launcher_right"):
		move(1)
	elif event.is_action_pressed("launcher_confirm"):
		if entries.is_empty():
			Audio.play("ui_back")
			selected_card().wobble()
		else:
			launch_requested.emit(selected_entry())
	elif event.is_action_pressed("launcher_back"):
		Audio.play("ui_back")
		back_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _layout(animate: bool) -> void:
	for i in _cards.size():
		var card := _cards[i]
		var target := CENTER + Vector2((i - index) * SPACING, 0) - card.size / 2.0
		if animate:
			create_tween().tween_property(card, "position", target, 0.18) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			card.position = target
		card.set_highlighted(i == index)
