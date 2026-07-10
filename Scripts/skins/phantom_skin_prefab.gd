extends BaseSkin

var hover_tween: Tween

@onready var sprite = $Sprite2D
@onready var ghost_fire = $GhostFire
@onready var death_particles = $DeathParticles


func _ready():
	sprite.modulate.a = 0.6  # 半透明幽靈


func play_spawn():
	scale = Vector2.ZERO
	ghost_fire.restart()
	ghost_fire.emitting = true
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SPRING).set_ease(
		Tween.EASE_OUT
	)
	_start_hover()
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_die():
	death_particles.restart()
	death_particles.emitting = true
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.5, 2.0), 0.4)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func _start_hover():
	if hover_tween:
		hover_tween.kill()
	hover_tween = create_tween().set_loops()
	(
		hover_tween
		. tween_property(sprite, "position:y", -10.0, 1.0)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	hover_tween.tween_property(sprite, "position:y", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)


func play_eat_ball():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.25, 0.25), 0.2)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.3)


func play_jump():
	var tween = create_tween()
	# 幽靈拉長
	tween.tween_property(sprite, "scale", Vector2(0.12, 0.3), 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.3).set_trans(Tween.TRANS_SINE)


func play_land():
	var tween = create_tween()
	# 幽靈稍微變扁
	tween.tween_property(sprite, "scale", Vector2(0.25, 0.15), 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.3).set_trans(Tween.TRANS_SINE)
