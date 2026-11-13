## Who is holding which controller. Autoload: Players.
## First controller to press a button (or tilt its left stick past JOIN_TILT) becomes P1 (green),
## the next becomes P2 (red). A stick alone joins too, so two pads never drive the same Jarling.
## Joypad events in the p1_* / p2_* actions are rebound to the joined device so
## Input.is_action_pressed("p1_action") only fires for P1's pad. Keyboard stays as a fallback.
extends Node

const P1 := 0
const P2 := 1
const COLOR := { P1: Color("3cc24a"), P2: Color("e4393c") }
const PREFIX := { P1: "p1_", P2: "p2_" }
const JOIN_TILT := 0.5     # a left-stick push this far joins the pad, same as a button
const PARKED := 1000      # P2's pad events point here until P2 joins, so P1's pad never also drives P2
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "action", "jump"]

signal player_joined(player: int, device: int)
signal player_left(player: int)

var _device_of := { P1: -1, P2: -1 }


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind(P2, PARKED)


func _input(event: InputEvent) -> void:
	if not joins(event):
		return
	var device: int = event.device
	if device in _device_of.values():
		return
	for player in [P1, P2]:
		if _device_of[player] == -1:
			_assign(player, device)
			return


## Does this event claim its pad for a player? A button press, or a left-stick push past JOIN_TILT.
static func joins(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] and absf(event.axis_value) >= JOIN_TILT
	return false


func is_active(player: int) -> bool:
	return _device_of.get(player, -1) != -1


func device_of(player: int) -> int:
	return _device_of.get(player, -1)


func active_players() -> Array[int]:
	var out: Array[int] = []
	for p in [P1, P2]:
		if is_active(p):
			out.append(p)
	return out


func action(player: int, action_name: String) -> String:
	return PREFIX[player] + action_name


func move_vector(player: int) -> Vector2:
	return Input.get_vector(
		action(player, "move_left"), action(player, "move_right"),
		action(player, "move_up"), action(player, "move_down"))


func _assign(player: int, device: int) -> void:
	_device_of[player] = device
	_bind(player, device)
	Audio.play("player_join")
	player_joined.emit(player, device)


## Point `player`'s pad events at `device` (P2 is PARKED until a pad of its own joins: before that,
## p2_* would match every pad, P1's too, and a keys-only P2 would mirror P1's stick).
func _bind(player: int, device: int) -> void:
	for a in ACTIONS:
		for ev in InputMap.action_get_events(action(player, a)):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				ev.device = device


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		return
	for player in [P1, P2]:
		if _device_of[player] == device:
			_device_of[player] = -1
			if player == P2:
				_bind(P2, PARKED)
			player_left.emit(player)
