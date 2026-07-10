extends BaseSkin

var jump_tween: Tween

@onready var core = $Core
@onready var ring1 = $Ring1
@onready var ring2 = $Ring2
@onready var confetti = $Confetti
@onready var death_particles = $DeathParticles


func _process(delta: float):
	ring1.rotation += delta * 2.0
	ring2.rotation -= delta * 3.0


func play_spawn():
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(
		Tween.EASE_OUT
	)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_die():
	death_particles.restart()
	death_particles.emitting = true
	var tween = create_tween().set_parallel(true)
	tween.tween_property(core, "scale", Vector2.ZERO, 0.2)
	tween.tween_property(ring1, "scale", Vector2.ZERO, 0.2)
	tween.tween_property(ring2, "scale", Vector2.ZERO, 0.2)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_eat_ball():
	var tween = create_tween()
	tween.tween_property(core, "scale", Vector2(0.2, 0.2), 0.1)
	tween.tween_property(core, "scale", Vector2(0.1, 0.1), 0.2)


func play_jump():
	var tween = create_tween()
	tween.tween_property(core, "scale", Vector2(0.08, 0.12), 0.1)
	tween.tween_property(core, "scale", Vector2(0.1, 0.1), 0.1)


func play_land():
	confetti.restart()
	confetti.emitting = true
	var tween = create_tween()
	tween.tween_property(core, "scale", Vector2(0.12, 0.08), 0.1)
	tween.tween_property(core, "scale", Vector2(0.1, 0.1), 0.1)
