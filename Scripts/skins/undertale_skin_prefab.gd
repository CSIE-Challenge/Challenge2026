extends BaseSkin

@onready var sprite = $Sprite2D
@onready var death_shards = $DeathShards
@onready var crack = $Crack
@onready var heart_effect: CPUParticles2D = $HeartEffect


func play_spawn():
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(
		Tween.EASE_OUT
	)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_die():
	# 1. 產生裂痕 (Crack)
	crack.visible = true

	# 等待那令人絕望的瞬間
	await get_tree().create_timer(0.6).timeout

	# 2. 靈魂碎裂！
	sprite.visible = false
	crack.visible = false
	death_shards.restart()
	death_shards.emitting = true

	await get_tree().create_timer(1.0).timeout


func play_eat_ball():
	heart_effect.restart()
	heart_effect.emitting = true


func play_jump():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.08, 0.16), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.12, 0.12), 0.15)


func play_land():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.18, 0.08), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.12, 0.12), 0.15)
