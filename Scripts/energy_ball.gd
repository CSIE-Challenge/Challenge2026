extends Area2D

@export var energy_ball_spawn_bounds := Rect2(Vector2(-220, -220), Vector2(440, 440))
@export var min_spawn_distance_from_player := 48.0
@export var max_spawn_attempts := 100
@export var player_node: Node2D
@export var coconut_flicker_speed := 0.1
@export var coconut_rotate_speed := 0.1
@export var coconut_rotate_amplitude := 0.1

var rng := RandomNumberGenerator.new()

@onready var coconut_sprite = $Coconut


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_respawn_energy_ball()


func _on_body_entered(body: Node2D) -> void:
	if not visible or body.name != "Player":
		return

	visible = false
	GlobalSignal.energyball_collected.emit()

	_respawn_energy_ball()


func _respawn_energy_ball() -> void:
	position = _get_random_spawn_position()
	print(position)
	visible = true


func _get_random_spawn_position() -> Vector2:
	var spawn_position := Vector2.ZERO
	var attempts := 0

	while attempts < max_spawn_attempts:
		spawn_position = Vector2(
			rng.randf_range(energy_ball_spawn_bounds.position.x, energy_ball_spawn_bounds.end.x),
			rng.randf_range(energy_ball_spawn_bounds.position.y, energy_ball_spawn_bounds.end.y)
		)

		if spawn_position.distance_to(player_node.position) >= min_spawn_distance_from_player:
			return spawn_position

		attempts += 1

	return energy_ball_spawn_bounds.get_center()


func _physics_process(_delta: float) -> void:
	var rotate = coconut_rotate_amplitude * sin(Engine.get_frames_drawn() * coconut_rotate_speed)
	coconut_sprite.rotation = rotate
	var b = abs(sin(Engine.get_frames_drawn() * coconut_flicker_speed))
	var g = 0.75 + sin(Engine.get_frames_drawn() * (coconut_flicker_speed + 0.05)) * 0.25
	coconut_sprite.material.set_shader_parameter("outline_color", Vector4(1, g, b, 1))
