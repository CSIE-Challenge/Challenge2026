extends Node

@export var game_manager: Node
@export var player: Player
@export var energy_ball: Node2D
@export var send_hz := 30.0

var _elapsed := 0.0


func _process(delta: float) -> void:
	if game_manager == null or player == null:
		return
	if send_hz <= 0.0:
		return

	_elapsed += delta
	if _elapsed < 1.0 / send_hz:
		return

	_elapsed = 0.0
	var player_position := player.position
	var player_parent := player.get_parent()
	if player_parent is Node2D:
		player_position = player_parent.to_local(player.global_position)

	var energy_ball_position := Vector2.ZERO
	var energy_ball_visible := false
	if energy_ball != null:
		energy_ball_position = energy_ball.position
		energy_ball_visible = energy_ball.visible

	var state := {
		"position": player_position,
		"velocity": player.velocity,
		"health": int(player.health),
		"energy": int(game_manager.energy_amount),
		"energy_balls": int(game_manager.energy_ball_count),
		"energy_ball_position": energy_ball_position,
		"energy_ball_visible": energy_ball_visible,
	}
	NetworkManager.request_update_broadcast_state(state)
