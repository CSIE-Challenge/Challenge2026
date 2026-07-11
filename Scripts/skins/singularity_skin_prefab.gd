extends BaseSkin

@onready var sprite = $Sprite2D
@onready var accretion_disk = $AccretionDisk
@onready var suck_particles = $SuckParticles
@onready var shockwave = $Shockwave


func _process(delta):
	accretion_disk.rotation += delta * 1.5


func _ready():
	shockwave.visible = false
	shockwave.modulate.a = 0.0


func play_spawn():
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SPRING).set_ease(
		Tween.EASE_OUT
	)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_die():
	# Implosion effect
	var tween = create_tween().set_parallel(true)
	(
		tween
		. tween_property(sprite, "scale", Vector2(0.01, 0.01), 0.3)
		. set_trans(Tween.TRANS_EXPO)
		. set_ease(Tween.EASE_IN)
	)
	tween.tween_property(sprite, "rotation", 10.0, 0.3)

	await get_tree().create_timer(0.3).timeout
	# Screen flash/glitch would be cool, but a simple blast is fine
	var blast = Sprite2D.new()
	blast.texture = sprite.texture
	blast.modulate = Color(0.8, 0.2, 1.0, 1.0)
	blast.scale = Vector2(0.01, 0.01)
	add_child(blast)

	var blast_tw = create_tween()
	(
		blast_tw
		. tween_property(blast, "scale", Vector2(1.0, 1.0), 0.2)
		. set_trans(Tween.TRANS_EXPO)
		. set_ease(Tween.EASE_OUT)
	)
	blast_tw.parallel().tween_property(blast, "modulate:a", 0.0, 0.2)
	blast_tw.tween_callback(blast.queue_free)


func play_eat_ball():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.3, 0.3), 0.1).set_trans(Tween.TRANS_SPRING)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.2)


func play_jump():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.12, 0.28), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15)

	# Ripple effect
	var ripple = Sprite2D.new()
	ripple.texture = sprite.texture
	ripple.modulate = Color(0.6, 0.1, 1.0, 0.5)
	ripple.scale = Vector2(0.2, 0.2)
	ripple.top_level = true
	add_child(ripple)
	ripple.global_position = self.global_position
	var rt = create_tween()
	rt.tween_property(ripple, "scale", Vector2(0.6, 0.6), 0.3).set_trans(Tween.TRANS_EXPO).set_ease(
		Tween.EASE_OUT
	)
	rt.parallel().tween_property(ripple, "modulate:a", 0.0, 0.3)
	rt.tween_callback(ripple.queue_free)


func play_land():
	suck_particles.top_level = true
	suck_particles.global_position = self.global_position
	suck_particles.restart()
	suck_particles.emitting = true

	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.3, 0.1), 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15)

	# Generate a new beautiful circular shockwave instead of the old ColorRect
	var blast_ripple = Sprite2D.new()
	blast_ripple.texture = sprite.texture
	blast_ripple.modulate = Color(0.6, 0.1, 1.0, 1.0)
	blast_ripple.top_level = true
	blast_ripple.global_position = self.global_position
	blast_ripple.scale = Vector2(0.1, 0.1)
	add_child(blast_ripple)

	var st = create_tween()
	(
		st
		. tween_property(blast_ripple, "scale", Vector2(1.5, 1.5), 0.3)
		. set_trans(Tween.TRANS_EXPO)
		. set_ease(Tween.EASE_OUT)
	)
	st.parallel().tween_property(blast_ripple, "modulate:a", 0.0, 0.3)
	st.tween_callback(blast_ripple.queue_free)
