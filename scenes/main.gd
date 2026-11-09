## Boot scene: title card, controller detection, drop-in players, round loop.
## Replace the Arena node with this game's level scene; keep the node names other lanes use.
extends Node2D

@onready var title: Control = $UI/Title
@onready var prompt: Label = $UI/Title/Prompt
@onready var spawns: Node2D = $Arena/Spawns
@onready var players_root: Node2D = $Arena/Players

const PLAYER_SCENE := preload("res://scenes/players/player.tscn")
var _players := {}


func _ready() -> void:
	Players.player_joined.connect(_on_player_joined)
	Players.player_left.connect(_on_player_left)
	Game.state_changed.connect(_on_state_changed)
	prompt.text = "Press any button"
	title.visible = true


func _on_player_joined(player: int, _device: int) -> void:
	_spawn(player)
	if Game.state == Game.State.TITLE:
		Game.start_round()


func _on_player_left(player: int) -> void:
	if _players.has(player):
		_players[player].queue_free()
		_players.erase(player)


func _on_state_changed(_from: int, to: int) -> void:
	title.visible = to == Game.State.TITLE
	$UI/Pause.visible = to == Game.State.PAUSED


func _spawn(player: int) -> void:
	if _players.has(player):
		return
	var p := PLAYER_SCENE.instantiate()
	p.player = player
	p.global_position = spawns.get_child(player).global_position
	players_root.add_child(p)
	_players[player] = p
