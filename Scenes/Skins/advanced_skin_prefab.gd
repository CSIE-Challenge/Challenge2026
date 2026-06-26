extends BaseSkin

var tween: Tween

@onready var sprite = $Sprite2D
@onready var particles = $CPUParticles2D


func play_spawn():
	pass


func play_die():
	particles.emitting = true
	var die_tween = create_tween()
	die_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)


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
	pass


func play_land():
	pass
