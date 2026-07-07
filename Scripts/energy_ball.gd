extends Area2D

@export var player_node: Node2D
@export var energy_text: PackedScene
@export var coconut_bar: Node2D

var is_demo := false
var energy_ball_spawn_bounds := Rect2(Vector2(-220, -220), Vector2(440, 440))
var min_spawn_distance_from_player := 48.0
var max_spawn_attempts := 100
var coconut_flicker_frequency := 0.1
var coconut_rotate_frequency := 0.1
var coconut_rotate_amplitude := 0.1
var now_combo := 0
var time_elapsed := 0.0
var energy_gain: Array
var energy_ball_level: int = 0

var rng := RandomNumberGenerator.new()

@onready var coconut_sprite = $Coconut
@onready var stage_layer = get_node_or_null("../../../StageLayer")
@onready var collision_shape = $CollisionShape2D
@onready var twinkle_particle = $TwinkleParticle
@onready var eaten_coconut = preload("res://Scenes/coconut_bar/eaten_coconut.tscn")


func _ready() -> void:
	if is_demo:
		_reload_from_game_data()
		return

	_reload_from_game_data()
	body_entered.connect(_on_body_entered)
	_respawn_energy_ball()


func _reload_from_game_data() -> void:
	var game_data := GameData.new()
	var spawn_bounds = game_data.data["energy_ball"]["spawn_bounds"]
	energy_ball_spawn_bounds = Rect2(
		spawn_bounds["x"], spawn_bounds["y"], spawn_bounds["width"], spawn_bounds["height"]
	)
	min_spawn_distance_from_player = game_data.data["energy_ball"]["min_spawn_distance_from_player"]
	max_spawn_attempts = game_data.data["energy_ball"]["max_spawn_attempts"]
	coconut_flicker_frequency = game_data.data["energy_ball"]["coconut_flicker_speed"]
	coconut_rotate_frequency = game_data.data["energy_ball"]["coconut_rotate_speed"]
	coconut_rotate_amplitude = game_data.data["energy_ball"]["coconut_rotate_amplitude"]
	energy_gain = game_data.data["energy_ball"]["energy_gain"]


func _on_body_entered(body: Node2D) -> void:
	if collision_shape.disabled or body != player_node:
		return
	collision_shape.set_deferred("disabled", true)
	Global.energyball_collected.emit(energy_gain[energy_ball_level][now_combo])
	Audio.play_sfx(Audio.SFX.ENERGY_COLLECTED)
	_spawn_energy_text()
	now_combo = min(now_combo + 1, energy_gain[energy_ball_level].size() - 1)
	coconut_bar.spawn_eaten_coconut(self.global_position)
	_respawn_energy_ball()


func _spawn_energy_text() -> void:
	var text = energy_text.instantiate()
	stage_layer.add_child(text)
	text.text = "+%d" % energy_gain[energy_ball_level][now_combo]
	text.position = position + Vector2(552, 324)
	text.initialize(now_combo)


func level_up() -> void:
	energy_ball_level = min(energy_ball_level + 1, energy_gain.size() - 1)


func _respawn_energy_ball() -> void:
	var fade_out_tween = create_tween().set_parallel(true)

	fade_out_tween.tween_property(self, "scale:x", 1.5, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	fade_out_tween.tween_property(self, "scale:y", 0.1, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)

	fade_out_tween.chain().tween_property(self, "scale", Vector2.ZERO, 0.05)

	fade_out_tween.chain().tween_callback(
		func():
			position = _get_random_spawn_position()
			scale = Vector2(0.3, 1.8)

			var fade_in_tween = create_tween().set_parallel(true)
			(
				fade_in_tween
				. tween_property(self, "scale", Vector2.ONE, 0.15)
				. set_trans(Tween.TRANS_BACK)
				. set_ease(Tween.EASE_OUT)
			)

			fade_in_tween.chain().tween_callback(
				func():
					scale = Vector2.ONE
					collision_shape.set_deferred("disabled", false)
			)
	)


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


func _physics_process(delta: float) -> void:
	if not is_demo and player_node.isjumping:
		now_combo = 0
	time_elapsed += delta
	var rotate = coconut_rotate_amplitude * sin(time_elapsed * TAU * coconut_rotate_frequency)
	coconut_sprite.rotation = rotate
	var b = abs(sin(time_elapsed * TAU * coconut_flicker_frequency))
	var g = 0.75 + sin(time_elapsed * TAU * (coconut_flicker_frequency + 0.05)) * 0.25
	var color = Color(1, g, b, 1)
	coconut_sprite.material.set_shader_parameter("outline_color", color)
	var process_mat = twinkle_particle.process_material as ParticleProcessMaterial
	process_mat.color = color + Color(0, 0.2, 0.2, 1)
