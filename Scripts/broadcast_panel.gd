@tool
extends Control

const ARENA_SIZE := Vector2(500, 500)
const ARENA_HALF_SIZE := ARENA_SIZE / 2.0
const PANEL_PADDING := 32.0
const HUD_HEIGHT := 64.0

var peer_id := 0
var state: Dictionary = {}


func set_peer_state(next_peer_id: int, next_state: Dictionary) -> void:
	peer_id = next_peer_id
	state = next_state
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.04, 0.04))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.25, 0.25), false, 2.0)

	var font := ThemeDB.fallback_font
	if state.is_empty():
		draw_string(font, Vector2(24, 40), "Waiting for player...")
		return

	var arena_rect := _get_arena_rect()
	draw_rect(arena_rect, Color(0.08, 0.08, 0.08))
	draw_rect(arena_rect, Color(0.55, 0.55, 0.55), false, 3.0)
	_draw_arena_grid(arena_rect)
	_draw_static_world(arena_rect)
	_draw_energy_ball(arena_rect)
	_draw_player(arena_rect)
	_draw_hud(font)


func _draw_arena_grid(arena_rect: Rect2) -> void:
	var grid_color := Color(0.18, 0.18, 0.18)
	for world_x in range(-200, 201, 100):
		var start := _world_to_panel(Vector2(world_x, -ARENA_HALF_SIZE.y), arena_rect)
		var end := _world_to_panel(Vector2(world_x, ARENA_HALF_SIZE.y), arena_rect)
		draw_line(start, end, grid_color, 1.0)
	for world_y in range(-200, 201, 100):
		var start := _world_to_panel(Vector2(-ARENA_HALF_SIZE.x, world_y), arena_rect)
		var end := _world_to_panel(Vector2(ARENA_HALF_SIZE.x, world_y), arena_rect)
		draw_line(start, end, grid_color, 1.0)


func _draw_static_world(arena_rect: Rect2) -> void:
	var wall_color := Color(0.75, 0.75, 0.75)
	var conveyor_rect := Rect2(
		_world_to_panel(Vector2(-190, -232), arena_rect), Vector2(76, 40) * _get_world_scale()
	)
	draw_rect(conveyor_rect, Color(0.15, 0.25, 0.45))
	draw_rect(conveyor_rect, Color(0.45, 0.65, 1.0), false, 2.0)

	var ring_center := _world_to_panel(Vector2.ZERO, arena_rect)
	draw_arc(ring_center, 95.0 * _get_world_scale(), 0.0, TAU, 64, Color(0.9, 0.3, 0.9), 2.0)

	var ripple_center := _world_to_panel(Vector2(-276, -24), arena_rect)
	draw_arc(ripple_center, 150.0 * _get_world_scale(), 0.0, TAU, 64, Color(1.0, 0.5, 0.15), 2.0)

	draw_line(
		_world_to_panel(Vector2(-250, -250), arena_rect),
		_world_to_panel(Vector2(250, -250), arena_rect),
		wall_color,
		4.0
	)
	draw_line(
		_world_to_panel(Vector2(-250, 250), arena_rect),
		_world_to_panel(Vector2(250, 250), arena_rect),
		wall_color,
		4.0
	)
	draw_line(
		_world_to_panel(Vector2(-250, -250), arena_rect),
		_world_to_panel(Vector2(-250, 250), arena_rect),
		wall_color,
		4.0
	)
	draw_line(
		_world_to_panel(Vector2(250, -250), arena_rect),
		_world_to_panel(Vector2(250, 250), arena_rect),
		wall_color,
		4.0
	)


func _draw_energy_ball(arena_rect: Rect2) -> void:
	if not bool(state.get("energy_ball_visible", false)):
		return

	var ball_position: Vector2 = state.get("energy_ball_position", Vector2.ZERO)
	draw_circle(_world_to_panel(ball_position, arena_rect), 7.0, Color(1.0, 0.9, 0.1))


func _draw_player(arena_rect: Rect2) -> void:
	var player_position: Vector2 = state.get("position", Vector2.ZERO)
	var player_velocity: Vector2 = state.get("velocity", Vector2.ZERO)
	var panel_position := _world_to_panel(player_position, arena_rect)

	draw_circle(panel_position, 10.0, Color.CYAN)
	if player_velocity.length() > 0.01:
		draw_line(
			panel_position, panel_position + player_velocity.normalized() * 24.0, Color.WHITE, 2.0
		)


func _draw_hud(font: Font) -> void:
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


func _get_arena_rect() -> Rect2:
	var available_size := Vector2(size.x - PANEL_PADDING * 2.0, size.y - HUD_HEIGHT - PANEL_PADDING)
	var arena_side = max(1.0, min(available_size.x, available_size.y))
	var arena_position := Vector2(
		(size.x - arena_side) / 2.0, HUD_HEIGHT + (available_size.y - arena_side) / 2.0
	)
	return Rect2(arena_position, Vector2(arena_side, arena_side))


func _get_world_scale() -> float:
	var arena_rect := _get_arena_rect()
	return arena_rect.size.x / ARENA_SIZE.x


func _world_to_panel(world_position: Vector2, arena_rect: Rect2) -> Vector2:
	var normalized := (world_position + ARENA_HALF_SIZE) / ARENA_SIZE
	return arena_rect.position + normalized * arena_rect.size
