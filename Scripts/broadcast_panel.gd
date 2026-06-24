extends Control

const WORLD_SCALE := 0.5

var peer_id := 0
var state: Dictionary = {}


func set_peer_state(next_peer_id: int, next_state: Dictionary) -> void:
	peer_id = next_peer_id
	state = next_state
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.04, 0.04))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.25, 0.25), false, 2.0)

	var font := ThemeDB.fallback_font
	if state.is_empty():
		draw_string(font, Vector2(24, 40), "Waiting for player...")
		return

	var player_position: Vector2 = state.get("position", Vector2.ZERO)
	var player_velocity: Vector2 = state.get("velocity", Vector2.ZERO)
	var panel_position := size / 2.0 + player_position * WORLD_SCALE
	panel_position = panel_position.clamp(Vector2(12, 64), size - Vector2(12, 12))

	draw_circle(panel_position, 10.0, Color.CYAN)
	draw_line(
		panel_position, panel_position + player_velocity.normalized() * 24.0, Color.WHITE, 2.0
	)

	var text := (
		"Peer: %d  HP: %d  Energy: %d  Balls: %d"
		% [
			peer_id,
			int(state.get("health", 0)),
			int(state.get("energy", 0)),
			int(state.get("energy_balls", 0)),
		]
	)
	draw_string(font, Vector2(24, 40), text)
