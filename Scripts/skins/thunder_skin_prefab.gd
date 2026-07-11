extends BaseSkin

const LASER_SHADER = preload("res://Shaders/laser_beam.gdshader")

var jump_tween: Tween
var last_pos: Vector2
var walk_lightning_timer: float = 0.0

@onready var sprite = $Sprite2D
@onready var timer = $Timer
@onready var death_particles = $DeathParticles


func _process(delta):
	if global_position.distance_to(last_pos) > 1.0:
		walk_lightning_timer -= delta
		if walk_lightning_timer <= 0:
			walk_lightning_timer = randf_range(0.05, 0.2)
			_spawn_ground_lightning()
	last_pos = global_position


func _spawn_ground_lightning():
	if not is_inside_tree():
		return
	var line = Line2D.new()
	line.width = 10.0
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

	var start_pos = Vector2(randf_range(-15, 15), 10)
	var current_pos = start_pos
	line.add_point(current_pos)
	for i in range(3):
		current_pos += Vector2(randf_range(-5, 5), randf_range(5, 15))
		line.add_point(current_pos)

	line.top_level = true
	line.global_position = global_position
	add_child(line)

	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.15)
	tween.tween_callback(line.queue_free)


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

	timer.wait_time = randf_range(0.1, 0.4)


func play_eat_ball():
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 3.0, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color(0.2, 0.3, 0.9, 1.0), 0.3)


func play_jump():
	_spawn_massive_lightning()
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.12, 0.28), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.1)


func _spawn_massive_lightning():
	if not is_inside_tree():
		return
	'''
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 1)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.add_child(flash)
	add_child(canvas_layer)
	var tween_flash = create_tween()
	tween_flash.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween_flash.tween_callback(canvas_layer.queue_free)
	'''
	var line = Line2D.new()
	line.width = 40.0
	line.default_color = Color(0.8, 0.95, 1.0, 1.0)
	var mat = ShaderMaterial.new()
	mat.shader = LASER_SHADER
	mat.set_shader_parameter("noise_strength", 0.2)
	mat.set_shader_parameter("speed", 40.0)
	line.material = mat
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	var tex = PlaceholderTexture2D.new()
	tex.size = Vector2(32, 32)
	line.texture = tex

	line.top_level = true
	var target_global = global_position
	var camera = get_viewport().get_camera_2d()
	var screen_top_y = target_global.y - 600
	if camera:
		screen_top_y = camera.global_position.y - get_viewport_rect().size.y / 2 - 100

	var current_pos = Vector2(target_global.x + randf_range(-50, 50), screen_top_y)
	line.add_point(current_pos)

	var steps = 10
	var y_step = (target_global.y - screen_top_y) / steps
	for i in range(steps):
		var next_y = current_pos.y + y_step
		var next_x = current_pos.x + randf_range(-30, 30)
		if i == steps - 1:
			next_x = target_global.x
			next_y = target_global.y
		current_pos = Vector2(next_x, next_y)
		line.add_point(current_pos)

	add_child(line)
	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.4)
	tween.tween_callback(line.queue_free)


func play_land():
	for i in range(3):
		_spawn_lightning()
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.3, 0.12), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15)
