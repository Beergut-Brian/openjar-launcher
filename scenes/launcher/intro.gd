## Placeholder intro (~3 s): the jar wobbles, the lid pops, Jeff and Chuck tumble out,
## the logo lands with a thump. A skips. The Art lane replaces this scene with an
## AnimationPlayer version; keep the API in docs/contracts.md, "Launcher scenes".
extends Control

signal finished()

const LENGTH := 3.0

var _tween: Tween
var _done := true

@onready var jar: Control = $Jar
@onready var lid: Control = $Jar/Lid
@onready var jeff: Control = $Jeff
@onready var chuck: Control = $Chuck
@onready var logo: Control = $Logo
@onready var jar_rest := jar.position
@onready var jeff_rest := jeff.position
@onready var chuck_rest := chuck.position
@onready var logo_rest := logo.position


func play() -> void:
	_done = false
	visible = true
	_reset()
	_tween = create_tween()
	# 0.0–0.5 jar wobbles
	for a in [0.06, -0.06, 0.08, -0.08, 0.0]:
		_tween.tween_property(jar, "rotation", a, 0.1)
	# 0.5 lid pops off
	_tween.tween_callback(Audio.play.bind("intro_pop"))
	_tween.tween_property(lid, "position", lid.position + Vector2(260, -520), 0.4).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(lid, "rotation", 2.5, 0.4)
	# 0.6–1.6 characters tumble out to either side
	_tween.parallel().tween_callback(_tumble.bind(jeff, jeff_rest, -1)).set_delay(0.1)
	_tween.parallel().tween_callback(_tumble.bind(chuck, chuck_rest, 1)).set_delay(0.2)
	# 1.8–2.2 logo drops in, thump + shake
	_tween.tween_interval(0.9)
	_tween.tween_callback(func(): logo.visible = true)
	_tween.tween_property(logo, "position", logo_rest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_thump)
	_tween.tween_interval(LENGTH - 2.3)
	_tween.tween_callback(_finish)


func skip() -> void:
	if _done:
		return
	Audio.play("ui_confirm")
	_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("launcher_confirm"):
		skip()
		get_viewport().set_input_as_handled()


func _reset() -> void:
	jar.rotation = 0.0
	jar.position = jar_rest
	lid.position = Vector2(-20, -60)
	lid.rotation = 0.0
	for c in [jeff, chuck]:
		c.position = jar_rest + jar.size / 2.0 - c.size / 2.0
		c.scale = Vector2.ZERO
		c.rotation = 0.0
	logo.visible = false
	logo.position = logo_rest - Vector2(0, 700)


func _tumble(c: Control, rest: Vector2, dir: int) -> void:
	var tw := create_tween().set_parallel()
	var start := c.position
	var peak := (start + rest) / 2.0 - Vector2(0, 380)
	tw.tween_property(c, "scale", Vector2.ONE, 0.25)
	tw.tween_property(c, "rotation", dir * TAU, 1.0)
	# Quadratic arc start → peak → rest.
	tw.tween_method(func(t: float): c.position = start.lerp(peak, t).lerp(peak.lerp(rest, t), t), 0.0, 1.0, 1.0)


func _thump() -> void:
	Audio.play("intro_thump")
	var tw := create_tween()
	for o in [Vector2(0, 18), Vector2(0, -12), Vector2(0, 6), Vector2.ZERO]:
		tw.tween_property(self, "position", o, 0.05)


func _finish() -> void:
	if _done:
		return
	_done = true
	if _tween and _tween.is_valid():
		_tween.kill()
	position = Vector2.ZERO
	visible = false
	finished.emit()
