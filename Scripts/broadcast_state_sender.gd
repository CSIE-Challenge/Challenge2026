extends Node

@export var game_manager: Node
@export var player: Player
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
	var state := {
		"position": player.global_position,
		"velocity": player.velocity,
		"health": int(player.health),
		"energy": int(game_manager.energy_amount),
		"energy_balls": int(game_manager.energy_ball_count),
	}
	NetworkManager.request_update_broadcast_state(state)
