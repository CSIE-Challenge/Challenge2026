extends BaseSkin

@onready var body = $Body
@onready var headband = $Body/Headband
@onready var smoke_particles = $SmokeParticles
@onready var death_particles = $DeathParticles


func play_spawn():
	scale = Vector2.ZERO
	smoke_particles.restart()
	smoke_particles.emitting = true
	var tween = create_tween()
	# 忍者瞬身術出現
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(
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
	tween.tween_property($Body, "modulate:a", 0.0, 0.1)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_eat_ball():
	# 吃球閃紅光
	body.modulate = Color(1.0, 0.2, 0.2, 1.0)
	var tween = create_tween()
	tween.tween_property(body, "modulate", Color(0.2, 0.2, 0.2, 1.0), 0.3)


func play_jump():
	smoke_particles.restart()
	smoke_particles.emitting = true
	var tween = create_tween()
	# 忍者瞬間拉長
	tween.tween_property(body, "scale", Vector2(0.1, 0.3), 0.1)
	tween.tween_property(body, "scale", Vector2(0.2, 0.2), 0.1)


func play_land():
	smoke_particles.restart()
	smoke_particles.emitting = true
	var tween = create_tween()
	# 忍者落地瞬間壓扁
	tween.tween_property(body, "scale", Vector2(0.3, 0.1), 0.05)
	tween.tween_property(body, "scale", Vector2(0.2, 0.2), 0.15)
