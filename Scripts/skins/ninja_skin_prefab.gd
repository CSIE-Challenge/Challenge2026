extends BaseSkin

@onready var body = $Body
@onready var headband = $Body/Headband
@onready var smoke_particles = $SmokeParticles
@onready var death_particles = $DeathParticles

var last_pos: Vector2
var afterimage_timer: float = 0.0

func _process(delta):
	if global_position.distance_to(last_pos) > 1.0:
		afterimage_timer -= delta
		if afterimage_timer <= 0:
			afterimage_timer = 0.1
			_spawn_afterimage()
	last_pos = global_position

func _spawn_afterimage():
	if body.modulate.a == 0: return
	var clone = Sprite2D.new()
	clone.texture = body.texture
	clone.global_position = body.global_position
	clone.scale = body.global_scale
	clone.modulate = body.modulate
	clone.modulate.a = 0.4
	clone.top_level = true
	
	var headband_clone = Sprite2D.new()
	headband_clone.texture = headband.texture
	headband_clone.position = headband.position
	headband_clone.scale = headband.scale
	headband_clone.modulate = headband.modulate
	clone.add_child(headband_clone)

	add_child(clone)
	var tween = create_tween()
	tween.tween_property(clone, "modulate:a", 0.0, 0.3)
	tween.tween_callback(clone.queue_free)


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
	body.modulate.r = 1.0
	body.modulate.g = 0.2
	body.modulate.b = 0.2
	var tween = create_tween()
	tween.tween_property(body, "modulate:r", 0.2, 0.3)
	tween.parallel().tween_property(body, "modulate:g", 0.2, 0.3)
	tween.parallel().tween_property(body, "modulate:b", 0.2, 0.3)


func play_jump():
	smoke_particles.amount = 40
	smoke_particles.scale_amount_min = 0.05
	smoke_particles.scale_amount_max = 0.1
	smoke_particles.restart()
	smoke_particles.emitting = true
	
	body.modulate.a = 0.0


func play_land():
	smoke_particles.amount = 20
	smoke_particles.scale_amount_min = 0.02
	smoke_particles.scale_amount_max = 0.05
	smoke_particles.restart()
	smoke_particles.emitting = true
	
	body.modulate.a = 1.0
		
	var tween = create_tween()
	# 忍者落地瞬間壓扁
	tween.tween_property(body, "scale", Vector2(0.3, 0.1), 0.05)
	tween.tween_property(body, "scale", Vector2(0.2, 0.2), 0.15)
