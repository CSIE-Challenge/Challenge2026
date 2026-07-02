extends BaseSkin

var jump_tween: Tween

@onready var sprite = $Sprite2D
@onready var death_particles = $DeathParticles


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
	var tween = create_tween()
	tween.tween_property(sprite.material, "shader_parameter/glitch_intensity", 0.3, 0.5)
	tween.tween_property(sprite.material, "shader_parameter/chromatic_aberration", 0.5, 0.5)


func play_jump():
	sprite.material.set_shader_parameter("glitch_intensity", 0.8)
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.12, 0.3), 0.15).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15).set_trans(Tween.TRANS_EXPO)


func play_land():
	sprite.material.set_shader_parameter("glitch_intensity", 0.3)
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.35, 0.1), 0.1).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15).set_trans(Tween.TRANS_EXPO)
