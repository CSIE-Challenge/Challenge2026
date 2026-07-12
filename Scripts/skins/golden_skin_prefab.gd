extends BaseSkin

const GOLDEN_RING_SHADER = preload("res://Shaders/golden_ring.gdshader")

var died = false
@onready var sprite = $Sprite2D
@onready var particles = $CPUParticles2D
@onready var death_particles = $DeathParticles


func _process(_delta: float) -> void:
	if !died:
		sprite.material.set_shader_parameter("alpha", modulate.a)


func play_spawn():
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	particles.emitting = true
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_die():
	died = true
	sprite.material.set_shader_parameter("alpha", 1.0)
	death_particles.restart()
	death_particles.emitting = true
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_IN
	)
	tween.parallel().tween_property(sprite.material, "shader_parameter/alpha", 0.0, 0.2)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


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

	_spawn_golden_ring()


func _spawn_golden_ring():
	var ring = ColorRect.new()
	ring.size = Vector2(120, 120)
	ring.top_level = true

	var mat = ShaderMaterial.new()
	mat.shader = GOLDEN_RING_SHADER
	mat.set_shader_parameter("outer_radius", 0.0)
	mat.set_shader_parameter("inner_radius", 0.0)
	mat.set_shader_parameter("ring_color", Color(1.0, 0.8, 0.2, 0.8))  # alpha=0.8
	ring.material = mat

	add_child(ring)
	ring.global_position = self.global_position - ring.size / 2.0

	# 外緣會在 0.2 秒內到達自身大小 2 倍的位置 (半徑約 51.2，在 120 的矩形中對應 UV 約 0.43)
	var r_tween = create_tween()
	r_tween.tween_property(mat, "shader_parameter/outer_radius", 0.43, 0.2)

	# 內緣維持 0.1 秒的 radius=0，再花 0.3 秒追上外緣
	var r_inner_tween = create_tween()
	r_inner_tween.tween_interval(0.1)
	r_inner_tween.tween_property(mat, "shader_parameter/inner_radius", 0.43, 0.3)

	# 動畫總時長約 0.4 秒，完成後刪除
	var free_tween = create_tween()
	free_tween.tween_interval(0.45)
	free_tween.tween_callback(ring.queue_free)
