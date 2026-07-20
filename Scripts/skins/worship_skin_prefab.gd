extends BaseSkin

@export var shake_amplitude: Array[float]
@export var rainbow_speed: float = 0.5

var is_dead := false
var is_spawning := true
var is_flying := false
var health_icon_layer: CanvasLayer
var current_combo := 0
var _current_hue := 0.0

@onready var sprite = $Sprites/Sprite2D
@onready var square = $Sprites/Square
@onready var sprites = $Sprites
@onready var explosion: AnimatedSprite2D = $AnimatedSprite2D
@onready var twinkle_particle: GPUParticles2D = $TwinkleParticle


func play_spawn():
	twinkle_particle.emitting = false
	explosion.hide()
	sprites.modulate.a = 1.0
	sprites.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(sprites, "scale", Vector2.ONE * 1.0, 0.25)
	tween.tween_property(sprites, "scale", Vector2.ONE * 0.72, 0.08)
	tween.tween_property(sprites, "scale", Vector2.ONE * 1.0, 0.1)
	await tween.finished
	is_spawning = false


func _process(delta: float) -> void:
	if is_dead or is_spawning:
		return
	var vel = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if vel.x > 0:
		sprite.flip_h = true
	elif vel.x < 0:
		sprite.flip_h = false
	if not is_flying:
		if vel.x != 0:
			if vel.y > 0:
				sprite.frame = 3
			elif vel.y < 0:
				sprite.frame = 1
			else:
				sprite.frame = 2
		else:
			if vel.y > 0:
				sprite.frame = 4
			else:
				sprite.frame = 0
	if current_combo >= 1:
		sprite.position = (
			Vector2.from_angle(randf_range(0, TAU)).normalized()
			* randf_range(shake_amplitude[current_combo] / 3.0, shake_amplitude[current_combo])
		)
		sprite.rotation = randf_range(
			-shake_amplitude[current_combo] * 0.05, shake_amplitude[current_combo] * 0.05
		)
	if current_combo >= 5:
		_current_hue = fmod(_current_hue + rainbow_speed * delta, 1.0)
		square.modulate = Color.from_hsv(_current_hue, 1.0, 1.0)
		var mat = twinkle_particle.process_material as ParticleProcessMaterial
		mat.color = square.modulate


func play_jump():
	twinkle_particle.emitting = false
	current_combo = 0
	square.modulate = Color(0.573, 0.4, 0.8, 1.0)
	_current_hue = square.modulate.h
	var tween = create_tween()
	tween.tween_property(sprites, "scale", Vector2(0.6, 1.4), 0.1)
	tween.tween_property(sprites, "scale", Vector2(1.0, 1.0), 0.25)


func play_land():
	var tween = create_tween()
	tween.tween_property(sprites, "scale", Vector2(1.4, 0.6), 0.07)
	tween.tween_property(sprites, "scale", Vector2(1.0, 1.0), 0.12)


func play_eat_ball():
	current_combo = clampi(current_combo + 1, 0, 5)
	if current_combo == 5:
		twinkle_particle.emitting = true


func play_die():
	explosion.show()
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprites, "scale", Vector2(3, 3), 0.1)
	tween.tween_property(sprites, "modulate:a", 0.0, 0.15)
	explosion.play("explode")
	await explosion.animation_finished
