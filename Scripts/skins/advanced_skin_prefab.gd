extends BaseSkin

var tween: Tween

@onready var sprite = $Sprite2D
@onready var particles = $CPUParticles2D


func play_spawn():
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 1.0, 0.2)
	await get_tree().process_frame


func play_die():
	particles.emitting = true
	var die_tween = create_tween()
	die_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	await particles.finished


func play_eat_ball():
	if tween:
		tween.kill()
	tween = create_tween()
	sprite.scale = Vector2(0.25, 0.25)
	(
		tween
		. tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.2)
		. set_trans(Tween.TRANS_SPRING)
		. set_ease(Tween.EASE_OUT)
	)


func play_jump():
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.12, 0.28), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15)


func play_land():
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.28, 0.12), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15)
