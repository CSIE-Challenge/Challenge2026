extends BaseSkin

const GOLDEN_RING_SHADER = preload("res://Shaders/golden_ring.gdshader")

var died = false
@onready var sprite = $Sprite2D
@onready var particles = $CPUParticles2D
@onready var death_particles = $DeathParticles


func _process(_delta: float) -> void:
	if !died:
		sprite.material.set_shader_parameter("alpha", modulate.a)
	if modulate == Color(0, 0, 0, 1):
		var tween = create_tween()
		tween.parallel().tween_property(
			sprite.material, "shader_parameter/base_color", Color(0, 0, 0, 1), 0
		)


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
	_spawn_expanding_twinkles()


func _spawn_golden_ring():
	var ring = ColorRect.new()
	ring.size = Vector2(300, 300)  # 擴大衝擊波最大尺寸
	ring.top_level = true

	var mat = ShaderMaterial.new()
	mat.shader = GOLDEN_RING_SHADER
	mat.set_shader_parameter("outer_radius", 0.0)
	mat.set_shader_parameter("inner_radius", 0.0)
	mat.set_shader_parameter("ring_color", Color(1.0, 0.85, 0.2, 0.15))  # 降低透明度，使其更為柔和
	ring.material = mat

	add_child(ring)
	ring.global_position = self.global_position - ring.size / 2.0

	# 1. 外圈：在 0.35 秒內快速向外擴散到最大半徑 0.5（使用 TRANS_EXPO 爆發性擴張）
	var r_tween = create_tween()
	(
		r_tween
		. tween_property(mat, "shader_parameter/outer_radius", 0.5, 0.35)
		. set_trans(Tween.TRANS_EXPO)
		. set_ease(Tween.EASE_OUT)
	)

	# 2. 內圈：延遲 0.07 秒才開始擴散，使用不同的二次方曲線 (TRANS_QUAD) 在 0.28 秒內追上外圈 (目標值為 0.5)
	# 這樣在動畫結束時，內圈會完全追上外圈，使環的厚度歸零並自然消失
	var r_inner_tween = create_tween()
	(
		r_inner_tween
		. tween_property(mat, "shader_parameter/inner_radius", 0.5, 0.28)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
		. set_delay(0.07)
	)

	# 3. 衝擊波本體淡出（採用 Ease out 曲線使淡出更平滑自然）
	var fade_tween = create_tween()
	fade_tween.tween_property(ring, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN
	)

	# 完成後銷毀
	var free_tween = create_tween()
	free_tween.tween_interval(0.4)
	free_tween.tween_callback(ring.queue_free)


func _spawn_expanding_twinkles():
	var steps = 8  # 採樣步數，沿途產生粒子
	var max_radius = 180.0

	for i in range(steps):
		if not is_inside_tree() or died:
			break

		var t = float(i) / (steps - 1)
		# 使用指數增長公式與衝擊波的擴張速度（TRANS_EXPO）完全同步
		var current_radius = max_radius * (1.0 - pow(2.0, -8.0 * t)) if t > 0 else 0.0

		# 每次在邊緣生成 2 個小星星，維持粒子數量少少的
		var count = 2
		for j in range(count):
			var angle = randf() * TAU
			var offset = Vector2(cos(angle), sin(angle)) * current_radius
			_spawn_single_twinkle(offset)

		# 每步的發射間隔時間，總共在 0.35 秒的擴散中完成
		await get_tree().create_timer(0.35 / steps).timeout


func _spawn_single_twinkle(offset: Vector2):
	var star = Sprite2D.new()
	star.texture = preload("res://Shapes/twinkle.svg")
	star.hframes = 2  # 圖片內含圓圈與星芒兩影格
	star.frame = randi() % 2  # 隨機展示圓圈或星芒

	# 設定閃爍的黃金色彩
	star.modulate = Color(1.0, randf_range(0.85, 1.0), 0.2, 1.0)

	# 小小的尺寸
	var max_scale = randf_range(0.015, 0.028)
	star.scale = Vector2.ZERO
	star.top_level = true

	add_child(star)
	star.global_position = self.global_position + offset

	# 每個粒子存活時間很短（0.15 ~ 0.25 秒）
	var lifetime = randf_range(0.25, 0.50)

	# 原地閃爍變換動畫 (快速放大後立刻縮小消失)
	var tween = create_tween()
	(
		tween
		. tween_property(star, "scale", Vector2(max_scale, max_scale), lifetime * 0.4)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	(
		tween
		. tween_property(star, "scale", Vector2.ZERO, lifetime * 0.6)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN)
	)
	tween.tween_callback(star.queue_free)
