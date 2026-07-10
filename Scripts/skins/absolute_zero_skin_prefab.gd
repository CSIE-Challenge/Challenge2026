extends BaseSkin

@onready var sprite = $Sprite2D
@onready var snow_particles = $SnowParticles
@onready var spikes_container = $SpikesContainer


func play_spawn():
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(
		Tween.EASE_OUT
	)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_die():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.1)

	# Shatter into ice shards
	var st: Tween
	for i in range(12):
		var shard = Polygon2D.new()
		shard.color = Color(0.6, 0.9, 1.0, 0.8)
		shard.polygon = PackedVector2Array(
			[Vector2(-5, -5), Vector2(5, -2), Vector2(2, 8), Vector2(-4, 4)]
		)
		shard.position = Vector2.ZERO
		add_child(shard)

		var angle = randf() * PI * 2.0
		var dist = randf_range(50.0, 150.0)
		var target_pos = Vector2(cos(angle), sin(angle)) * dist
		var rot = randf_range(-10.0, 10.0)

		st = create_tween().set_parallel(true)
		st.tween_property(shard, "position", target_pos, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(
			Tween.EASE_OUT
		)
		st.tween_property(shard, "rotation", rot, 0.4)
		st.tween_property(shard, "scale", Vector2.ZERO, 0.4).set_delay(0.2)
		st.chain().tween_callback(shard.queue_free)
	if st:
		await st.finished
	else:
		await get_tree().process_frame


func play_eat_ball():
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color(0.6, 0.9, 1.0, 0.7), 0.2)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.25, 0.25), 0.1)
	tween.chain().tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.2)


func play_jump():
	snow_particles.restart()
	snow_particles.emitting = true

	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.15, 0.25), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15)

	var rot_tween = create_tween()
	(
		rot_tween
		. tween_property(sprite, "rotation", sprite.rotation + PI, 0.4)
		. set_trans(Tween.TRANS_QUART)
		. set_ease(Tween.EASE_OUT)
	)


func play_land():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.28, 0.12), 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15)

	# Spawn Ice Spikes
	for i in range(5):
		var spike = Polygon2D.new()
		spike.color = Color(0.7, 0.95, 1.0, 0.9)
		# Triangle pointing UP
		spike.polygon = PackedVector2Array([Vector2(-4, 0), Vector2(4, 0), Vector2(0, -30)])

		# Spread them along the bottom
		var offset_x = (i - 2) * 12.0
		spike.top_level = true

		# Angle outward slightly
		spike.rotation = offset_x * 0.02

		# Start small
		spike.scale = Vector2(1.0, 0.0)
		spikes_container.add_child(spike)
		spike.global_position = self.global_position + Vector2(offset_x, 0)

		var st = create_tween()
		var delay = randf_range(0.0, 0.05)
		st.tween_interval(delay)
		(
			st
			. tween_property(spike, "scale", Vector2(1.0, randf_range(0.8, 1.5)), 0.1)
			. set_trans(Tween.TRANS_EXPO)
			. set_ease(Tween.EASE_OUT)
		)
		st.tween_interval(0.1)
		(
			st
			. tween_property(spike, "scale", Vector2(1.0, 0.0), 0.2)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN)
		)
		st.tween_callback(spike.queue_free)
