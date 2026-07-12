extends BaseSkin

@onready var particle = $CPUParticles2D
@onready var landing_effect = $Sprite2D2
@onready var sprite = $Sprite2D


func _ready():
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.05
	var noise_tex = NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.noise = noise

	var mat = ShaderMaterial.new()
	mat.shader = preload("res://Scenes/skins/planet_surface.gdshader")
	mat.set_shader_parameter("time_scale", 0.2)
	mat.set_shader_parameter("base_color", Color(0.3, 1.0, 0.4, 1.0))
	mat.set_shader_parameter("dark_color", Color(0.0, 0.5, 0.1, 1.0))
	mat.set_shader_parameter("noise_tex", noise_tex)
	sprite.material = mat


# 覆寫 (Override) 跳躍特效
func play_land():
	landing_effect.top_level = true
	landing_effect.global_position = self.global_position
	landing_effect.visible = true
	landing_effect.scale = Vector2.ONE * 0.2
	landing_effect.modulate.a = 1.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(landing_effect, "scale", Vector2.ONE, 0.2)
	tween.tween_property(landing_effect, "modulate:a", 0.0, 0.2)
	await tween.finished
	landing_effect.visible = false


# 覆寫出生特效
func play_spawn():
	scale = Vector2.ZERO
	var tween = create_tween()
	# 將 scale 恢復到 1.0 (也就是你在場景中編輯好的原始比例)，而不是強制縮小成 0.2
	tween.tween_property(self, "scale", Vector2.ONE, 0.5)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_die():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.5)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame
