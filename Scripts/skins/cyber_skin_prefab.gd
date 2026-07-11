extends BaseSkin

var jump_tween: Tween
var last_pos: Vector2

@onready var sprite = $Sprite2D
@onready var glow = $Glow
@onready var death_particles = $DeathParticles
@onready var eat_particles = $EatParticles

func _process(_delta):
	if global_position.distance_to(last_pos) > 10.0:
		spawn_trail()
		last_pos = global_position

func spawn_trail():
	var clone = Sprite2D.new()
	clone.texture = sprite.texture
	clone.material = sprite.material
	clone.modulate = Color(1.0, 1.0, 1.0, 0.5)
	clone.scale = sprite.scale
	clone.global_position = sprite.global_position
	clone.top_level = true
	add_child(clone)
	var tw = create_tween()
	tw.tween_property(clone, "modulate:a", 0.0, 0.3)
	tw.tween_callback(clone.queue_free)


func play_spawn():
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(
		Tween.EASE_OUT
	)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_die():
	death_particles.restart()
	death_particles.emitting = true
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(
		Tween.EASE_IN
	)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_eat_ball():
	sprite.material.set_shader_parameter("glitch_intensity", 1.0)
	sprite.material.set_shader_parameter("chromatic_aberration", 1.0)
	
	eat_particles.restart()
	eat_particles.emitting = true
	
	var tween = create_tween()
	tween.tween_property(sprite.material, "shader_parameter/glitch_intensity", 0.5, 0.5)
	tween.tween_property(sprite.material, "shader_parameter/chromatic_aberration", 0.8, 0.5)


func play_jump():
	sprite.material.set_shader_parameter("glitch_intensity", 1.0)
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.12, 0.3), 0.15).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15).set_trans(Tween.TRANS_EXPO)
	var glow_tween = create_tween()
	glow_tween.tween_property(glow, "scale", Vector2(0.16, 0.42), 0.15).set_trans(Tween.TRANS_EXPO)
	glow_tween.tween_property(glow, "scale", Vector2(0.28, 0.28), 0.15).set_trans(Tween.TRANS_EXPO)


func play_land():
	sprite.material.set_shader_parameter("glitch_intensity", 0.5)
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.35, 0.1), 0.1).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15).set_trans(Tween.TRANS_EXPO)
	var glow_tween = create_tween()
	glow_tween.tween_property(glow, "scale", Vector2(0.49, 0.14), 0.1).set_trans(Tween.TRANS_EXPO)
	glow_tween.tween_property(glow, "scale", Vector2(0.28, 0.28), 0.15).set_trans(Tween.TRANS_EXPO)
