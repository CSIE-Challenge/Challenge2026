extends BaseSkin

@onready var sprite = $Sprite2D
@onready var particles = $CPUParticles2D


func play_spawn():
	sprite.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE * 0.2, 0.2)
	await tween.finished


func play_die():
	particles.emitting = true
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	await tween.finished
	await get_tree().create_timer(0.35).timeout


func play_eat_ball():
	pass


func play_jump():
	pass


func play_land():
	pass
