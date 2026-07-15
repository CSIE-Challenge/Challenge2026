extends BaseSkin

var color_a = Color(1.0, 0.2, 0.5, 1.0)
var color_b = Color(0.2, 0.8, 1.0, 1.0)
var time_passed = 0.0

@onready var main_square = $MainSquare
@onready var ghost_container = $GhostContainer
@onready var pixel_particles = $PixelParticles
@onready var trail_particles = $TrailParticles


func _process(delta):
	time_passed += delta
	# 復古閃爍效果 (每 0.5 秒切換一次顏色)
	if int(time_passed * 4) % 2 == 0:
		main_square.color = color_a
		trail_particles.color = color_a
		trail_particles.color.a = 0.5
	else:
		main_square.color = color_b
		trail_particles.color = color_b
		trail_particles.color.a = 0.5


func play_spawn():
	scale = Vector2.ZERO
	main_square.visible = true
	trail_particles.emitting = true
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.1)
	tween.tween_interval(0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_die():
	pixel_particles.color = main_square.color
	pixel_particles.restart()
	pixel_particles.emitting = true
	main_square.visible = false
	trail_particles.emitting = false

	var white_line = ColorRect.new()
	white_line.color = Color.WHITE
	white_line.size = Vector2(50, 2)
	white_line.position = Vector2(-25, -1)
	add_child(white_line)

	var tw = create_tween()
	tw.tween_property(white_line, "scale", Vector2(2.0, 0.1), 0.2)
	tw.parallel().tween_property(white_line, "color:a", 0.0, 0.2)
	tw.tween_callback(white_line.queue_free)

	await get_tree().create_timer(1.0).timeout


func play_eat_ball():
	# 瞬間放大再縮小
	main_square.scale = Vector2(1.5, 1.5)
	main_square.position = -main_square.size * 1.5 / 2.0
	await get_tree().create_timer(0.1).timeout
	main_square.scale = Vector2.ONE
	main_square.position = -main_square.size / 2.0


func play_jump():
	# 殘影特效
	for i in range(4):
		await get_tree().create_timer(0.05).timeout
		_spawn_ghost()


func _spawn_ghost():
	var ghost = ColorRect.new()
	ghost.size = main_square.size
	# 這裡要注意，Ghost Container 是跟著本體移動的，但我們希望殘影留在原地
	# 所以要將 ghost 放進一個全域的容器或是反向偏移
	# 為了簡單，我們把它加到場景的最上層
	ghost.global_position = main_square.global_position
	ghost.color = main_square.color
	ghost.color.a = 0.5
	get_tree().current_scene.add_child(ghost)

	var tw = create_tween()
	tw.tween_interval(0.1)
	tw.tween_property(ghost, "color:a", 0.0, 0.2)
	tw.tween_callback(ghost.queue_free)


func play_land():
	pixel_particles.color = main_square.color
	pixel_particles.restart()
	pixel_particles.emitting = true

	# 沒有平滑的形變，只有生硬的壓扁
	main_square.scale = Vector2(1.2, 0.5)
	main_square.position = Vector2(
		-main_square.size.x * 1.2 / 2.0,
		-main_square.size.y * 0.5 / 2.0 + (main_square.size.y * 0.25)
	)

	await get_tree().create_timer(0.1).timeout

	main_square.scale = Vector2.ONE
	main_square.position = -main_square.size / 2.0
