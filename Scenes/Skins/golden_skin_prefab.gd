extends BaseSkin

@onready var sprite = $Sprite2D
@onready var particles = $CPUParticles2D
@onready var death_particles = $DeathParticles


func play_spawn():
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	particles.emitting = true


func play_die():
	death_particles.restart()
	death_particles.emitting = true
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_IN
	)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.2)


func play_eat_ball():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.25, 0.25), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.2)


func play_jump():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.15, 0.25), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15)


func play_land():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.25, 0.15), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15)
