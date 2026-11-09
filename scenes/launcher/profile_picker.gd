## Two faces, no names. Left/right picks, A confirms (one press), B goes back to the card row.
## Profile ids: FaceP1 → "p1", FaceP2 → "p2". API in docs/contracts.md, "Launcher scenes".
extends Control

signal confirmed(profile_id: String)
signal back_requested()

const IDS := ["p1", "p2"]
const SELECTED_SCALE := 1.15
const OTHER_SCALE := 0.8

var active := false
var index := 0
var _ignore_until := 0

@onready var faces: Array[Control] = [$Faces/FaceP1, $Faces/FaceP2]


func open(selected_id: String, grace_ms: int = 150) -> void:
	index = maxi(IDS.find(selected_id), 0)
	active = true
	_ignore_until = Time.get_ticks_msec() + grace_ms
	_highlight(false)


func close() -> void:
	active = false


func _unhandled_input(event: InputEvent) -> void:
	if not active or Time.get_ticks_msec() < _ignore_until:
		return
	if event.is_action_pressed("launcher_left") or event.is_action_pressed("launcher_right"):
		var to := 0 if event.is_action_pressed("launcher_left") else 1
		Audio.play("ui_move")
		if to == index:
			_wobble(faces[index])
		else:
			index = to
			_highlight(true)
	elif event.is_action_pressed("launcher_confirm"):
		Audio.play("ui_confirm")
		_pop(faces[index])
		active = false
		confirmed.emit(IDS[index])
	elif event.is_action_pressed("launcher_back"):
		Audio.play("ui_back")
		active = false
		back_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _highlight(animate: bool) -> void:
	for i in faces.size():
		var f := faces[i]
		var s := Vector2.ONE * (SELECTED_SCALE if i == index else OTHER_SCALE)
		f.modulate = Color.WHITE if i == index else Color(1, 1, 1, 0.55)
		if animate:
			var tw := create_tween()
			if i == index:
				tw.tween_property(f, "scale", s * 1.12, 0.07)
			tw.tween_property(f, "scale", s, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			f.scale = s


func _wobble(f: Control) -> void:
	var tw := create_tween()
	for a in [0.1, -0.1, 0.05, 0.0]:
		tw.tween_property(f, "rotation", a, 0.05)


func _pop(f: Control) -> void:
	var tw := create_tween()
	tw.tween_property(f, "scale", Vector2.ONE * SELECTED_SCALE * 1.3, 0.1)
	tw.tween_property(f, "scale", Vector2.ONE * SELECTED_SCALE, 0.15)
