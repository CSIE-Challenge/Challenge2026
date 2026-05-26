extends Node2D

@export var player: CharacterBody2D
@export var health_label: Label
@export var energy_ball: Area2D
@export var energy_counter_label: Label
@export var energy_ball_spawn_bounds := Rect2(Vector2(-220, -220), Vector2(440, 440))
@export var min_spawn_distance_from_player := 48.0
@export var max_spawn_attempts := 100

var energy_ball_count := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	GlobalSignal.player_hit.connect(on_player_hit)
	energy_ball.connect("collected", _on_energy_ball_collected)
	health_label.text = "Health: %d" % player.max_health
	_update_energy_counter()
	_respawn_energy_ball()


func on_player_hit(damage: int) -> void:
	print("玩家受到了", damage, "點傷害")
	player.health = max(player.health - damage, 0.0)
	health_label.text = "Health: %d" % player.health
	if player.health <= 0.0:
		print("玩家死掉了！")


func _respawn_energy_ball() -> void:
	energy_ball.position = _get_random_spawn_position()
	energy_ball.visible = true


func _get_random_spawn_position() -> Vector2:
	var spawn_position := Vector2.ZERO
	var attempts := 0

	while attempts < max_spawn_attempts:
		spawn_position = Vector2(
			rng.randf_range(energy_ball_spawn_bounds.position.x, energy_ball_spawn_bounds.end.x),
			rng.randf_range(energy_ball_spawn_bounds.position.y, energy_ball_spawn_bounds.end.y)
		)

		if spawn_position.distance_to(player.position) >= min_spawn_distance_from_player:
			return spawn_position

		attempts += 1

	return energy_ball_spawn_bounds.get_center()


func _on_energy_ball_collected() -> void:
	energy_ball_count += 1
	_update_energy_counter()
	call_deferred("_respawn_energy_ball")


func _update_energy_counter() -> void:
	energy_counter_label.text = "Energy Balls: %d" % energy_ball_count
