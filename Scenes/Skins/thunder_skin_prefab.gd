extends BaseSkin

const LASER_SHADER = preload("res://Shaders/laser_beam.gdshader")

var jump_tween: Tween

@onready var sprite = $Sprite2D
@onready var timer = $Timer
@onready var death_particles = $DeathParticles


func _ready():
	timer.timeout.connect(_spawn_lightning)


func play_spawn():
	scale = Vector2.ZERO
	timer.start()
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SPRING).set_ease(
		Tween.EASE_OUT
	)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_die():
	timer.stop()
	death_particles.restart()
	death_particles.emitting = true
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.2)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func _spawn_lightning():
	if not is_inside_tree():
		return
	var line = Line2D.new()
	line.width = 15.0  # 加寬以顯示發光效果
	line.default_color = Color(0.4, 0.8, 1.0, 1.0)

	var mat = ShaderMaterial.new()
	mat.shader = LASER_SHADER
	mat.set_shader_parameter("noise_strength", 0.15)
	mat.set_shader_parameter("speed", 30.0)
	line.material = mat
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH

	var tex = PlaceholderTexture2D.new()
	tex.size = Vector2(32, 32)
	line.texture = tex

	var start_pos = Vector2(randf_range(-10, 10), randf_range(-10, 10))
	line.add_point(start_pos)

	var current_pos = start_pos
	var angle = randf() * TAU
	for i in range(5):
		var step = Vector2(cos(angle), sin(angle)) * randf_range(15, 30)
		current_pos += step
		angle += randf_range(-0.8, 0.8)
		line.add_point(current_pos)

	add_child(line)
	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.25)
	tween.tween_callback(line.queue_free)

	timer.wait_time = randf_range(0.2, 1.0)


func play_eat_ball():
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 3.0, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color(0.2, 0.3, 0.9, 1.0), 0.3)


func play_jump():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.12, 0.28), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.1)


func play_land():
	for i in range(3):
		_spawn_lightning()
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.3, 0.12), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15)
