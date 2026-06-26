extends BaseSkin

@onready var particle = $CPUParticles2D
@onready var landing_effect = $Sprite2D2


# 覆寫 (Override) 跳躍特效
func play_land():
	landing_effect.visible = true
	landing_effect.scale = Vector2.ONE * 0.2
	landing_effect.modulate.a = 1.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(landing_effect, "scale", Vector2.ONE, 0.2)
	tween.tween_property(landing_effect, "modulate:a", 0.5, 0.2)
	await tween.finished
	landing_effect.visible = false


# 覆寫出生特效
func play_spawn():
	scale = Vector2.ZERO
	var tween = create_tween()
	# 將 scale 恢復到 1.0 (也就是你在場景中編輯好的原始比例)，而不是強制縮小成 0.2
	tween.tween_property(self, "scale", Vector2.ONE, 0.5)


func play_die():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.5)
