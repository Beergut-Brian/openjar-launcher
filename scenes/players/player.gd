## Placeholder player: a coloured box that moves and jumps. Systems lane owns.
## Gameplay/Art replace the Visual node; keep `player`, `move_vector`, and the signals.
extends CharacterBody2D

signal acted(player: int)
signal jumped(player: int)

@export var player: int = Players.P1
@export var speed := 600.0
@export var jump_velocity := -1100.0
@export var gravity := 2600.0

@onready var visual: ColorRect = $Visual


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	visual.color = Players.COLOR[player]


func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAYING:
		return
	var dir := Players.move_vector(player)
	velocity.x = dir.x * speed
	if not is_on_floor():
		velocity.y += gravity * delta
	elif Input.is_action_just_pressed(Players.action(player, "jump")):
		velocity.y = jump_velocity
		Audio.play("jump")
		_squash(Vector2(0.8, 1.25))
		jumped.emit(player)
	if Input.is_action_just_pressed(Players.action(player, "action")):
		Audio.play("action")
		_squash(Vector2(1.3, 0.75))
		acted.emit(player)
	move_and_slide()


func _squash(scale_to: Vector2) -> void:
	var tw := create_tween()
	tw.tween_property(visual, "scale", scale_to, 0.06)
	tw.tween_property(visual, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
